// ============================================================================
// Suunto FIT File Processor
// ============================================================================
//
// Purpose: Parse FIT files for Suunto activities
//
// Flow:
// 1. Receive activity_id and FIT file data
// 2. Parse FIT file using JS FIT parser
// 3. Extract samples (GPS, HR, elevation, cadence, temperature)
// 4. Store samples in suunto_activity_samples table
// 5. Update activity with computed metrics
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// @deno-types="https://esm.sh/@types/node@18/index.d.ts"
import FitParser from 'https://esm.sh/fit-file-parser@1.21.0'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("📦 Suunto FIT File Processor started")
    
    const { activity_id, fit_file_data } = await req.json()
    
    if (!activity_id || !fit_file_data) {
      console.error("❌ Missing activity_id or fit_file_data")
      return new Response(JSON.stringify({ error: "Missing activity_id or fit_file_data" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   Activity ID:", activity_id)
    console.log("   FIT file size:", fit_file_data.length, "bytes")
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Get activity to verify it exists
    const { data: activity, error: activityError } = await supabase
      .from('suunto_activities')
      .select('id, user_id, start_time, suunto_activity_id')
      .eq('id', activity_id)
      .single()
    
    if (activityError || !activity) {
      console.error("❌ Activity not found:", activityError)
      return new Response(JSON.stringify({ error: "Activity not found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("✅ Activity found:", activity.suunto_activity_id)
    
    // Convert array back to Uint8Array
    const fitFileBytes = new Uint8Array(fit_file_data)
    
    // Basic FIT file validation
    if (fitFileBytes.length < 14) {
      console.error("❌ FIT file too small")
      return new Response(JSON.stringify({ error: "Invalid FIT file" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Parse FIT file using fit-file-parser library
    console.log("🔍 Parsing FIT file with fit-file-parser library...")
    
    return new Promise((resolve) => {
      const fitParser = new FitParser({
        force: true,
        speedUnit: 'm/s',
        lengthUnit: 'm',
        temperatureUnit: 'celsius',
        elapsedRecordField: true,
        mode: 'cascade',
      })
      
      fitParser.parse(fitFileBytes, async (error: any, data: any) => {
        if (error) {
          console.error("❌ FIT parsing error:", error)
          const duration = Date.now() - startTime
          return resolve(new Response(JSON.stringify({
            success: false,
            error: error.message || "FIT parsing failed",
            duration: `${duration}ms`
          }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          }))
        }
        
        console.log("✅ FIT file parsed successfully")
        console.log("   Data keys:", Object.keys(data))
        
        // Extract samples from parsed data
        let records: any[] = []
        let insertedCount = 0
        
        // Check data.activity.sessions first (most common location)
        if (data.activity && data.activity.sessions && Array.isArray(data.activity.sessions)) {
          console.log(`   Found ${data.activity.sessions.length} session(s) in data.activity.sessions`)
          for (const session of data.activity.sessions) {
            if (session.records && Array.isArray(session.records)) {
              records = records.concat(session.records)
              console.log(`   Session has ${session.records.length} records`)
            }
            // Also check laps within sessions
            if (session.laps && Array.isArray(session.laps)) {
              for (const lap of session.laps) {
                if (lap.records && Array.isArray(lap.records)) {
                  records = records.concat(lap.records)
                  console.log(`   Lap has ${lap.records.length} records`)
                }
              }
            }
          }
          console.log(`   Found ${records.length} total records in sessions`)
        } else if (data.records && Array.isArray(data.records)) {
          records = data.records
          console.log(`   Found ${records.length} records in data.records`)
        } else if (data.activity && data.activity.records && Array.isArray(data.activity.records)) {
          records = data.activity.records
          console.log(`   Found ${records.length} records in data.activity.records`)
        } else if (data.sessions && Array.isArray(data.sessions) && data.sessions.length > 0) {
          for (const session of data.sessions) {
            if (session.records && Array.isArray(session.records)) {
              records = records.concat(session.records)
            }
          }
          console.log(`   Found ${records.length} records in sessions`)
        } else {
          // Try to find records anywhere in the data structure
          console.log("   Searching for records in data structure...")
          const findRecords = (obj: any, depth = 0): any[] => {
            if (depth > 5) return []
            if (Array.isArray(obj) && obj.length > 0) {
              if (obj[0] && typeof obj[0] === 'object' && (obj[0].timestamp || obj[0].position_lat || obj[0].heart_rate)) {
                return obj
              }
            }
            if (typeof obj === 'object' && obj !== null) {
              for (const key in obj) {
                if (key.toLowerCase().includes('record')) {
                  const found = findRecords(obj[key], depth + 1)
                  if (found.length > 0) return found
                }
              }
            }
            return []
          }
          records = findRecords(data)
          console.log(`   Found ${records.length} records in data structure`)
        }
        
        console.log(`   ✅ Extracted ${records.length} records from FIT file`)
        
        if (records.length === 0) {
          console.log("⚠️ No records found in FIT file")
          console.log("   Available data keys:", Object.keys(data))
        } else {
          // Log first record structure
          if (records.length > 0) {
            console.log("   First record keys:", Object.keys(records[0]))
          }
          
          // Convert records to database format
          const samplesToInsert = records
            .filter((record: any) => record.timestamp !== undefined && record.timestamp !== null)
            .map((record: any) => {
              let timestampSeconds: number
              if (record.timestamp instanceof Date) {
                timestampSeconds = Math.floor(record.timestamp.getTime() / 1000)
              } else if (typeof record.timestamp === 'number') {
                timestampSeconds = record.timestamp > 1e12 
                  ? Math.floor(record.timestamp / 1000) 
                  : Math.floor(record.timestamp)
              } else {
                return null
              }
              
              let sampleTime: string | null = null
              if (record.timestamp instanceof Date) {
                sampleTime = record.timestamp.toISOString()
              } else if (typeof record.timestamp === 'number') {
                const date = new Date(timestampSeconds * 1000)
                sampleTime = date.toISOString()
              }
              
              return {
                activity_id: activity_id,
                timestamp_seconds: timestampSeconds,
                sample_time: sampleTime,
                latitude: record.position_lat !== undefined && record.position_lat !== null 
                  ? (typeof record.position_lat === 'number' ? record.position_lat : parseFloat(record.position_lat))
                  : null,
                longitude: record.position_long !== undefined && record.position_long !== null
                  ? (typeof record.position_long === 'number' ? record.position_long : parseFloat(record.position_long))
                  : null,
                elevation_meters: record.altitude !== undefined && record.altitude !== null
                  ? (typeof record.altitude === 'number' ? record.altitude : parseFloat(record.altitude))
                  : null,
                heart_rate: record.heart_rate !== undefined && record.heart_rate !== null
                  ? Math.floor(typeof record.heart_rate === 'number' ? record.heart_rate : parseFloat(record.heart_rate))
                  : null,
                speed_mps: record.speed !== undefined && record.speed !== null
                  ? (typeof record.speed === 'number' ? record.speed : parseFloat(record.speed))
                  : null,
                steps_per_minute: record.cadence !== undefined && record.cadence !== null
                  ? Math.floor(typeof record.cadence === 'number' ? record.cadence : parseFloat(record.cadence))
                  : null,
                air_temperature_celsius: (() => {
                  const temp = record.temperature || 
                              record.temp || 
                              record.air_temperature || 
                              record.temperature_celsius ||
                              record.temp_celsius
                  return temp !== undefined && temp !== null
                    ? (typeof temp === 'number' ? temp : parseFloat(temp))
                    : null
                })()
              }
            })
            .filter((sample: any) => sample !== null)
          
          console.log(`   💾 Preparing ${samplesToInsert.length} samples for database insertion...`)
          
          // Insert samples in batches
          const batchSize = 1000
          
          for (let i = 0; i < samplesToInsert.length; i += batchSize) {
            const batch = samplesToInsert.slice(i, i + batchSize)
            const batchNum = Math.floor(i / batchSize) + 1
            const totalBatches = Math.ceil(samplesToInsert.length / batchSize)
            
            console.log(`   💾 Inserting batch ${batchNum}/${totalBatches} (${batch.length} samples)...`)
            
            const { data: insertedData, error: insertError } = await supabase
              .from('suunto_activity_samples')
              .insert(batch)
              .select('id')
            
            if (insertError) {
              console.error(`❌ Error inserting batch ${batchNum}:`, insertError)
              if (insertError.code === '23505' || insertError.message?.includes('duplicate')) {
                console.log(`   ⚠️ Duplicate key error - some samples may already exist`)
                let successCount = 0
                for (const sample of batch) {
                  const { error: singleError } = await supabase
                    .from('suunto_activity_samples')
                    .insert(sample)
                    .select('id')
                  if (!singleError) {
                    successCount++
                  }
                }
                insertedCount += successCount
                console.log(`   ✅ Inserted ${successCount}/${batch.length} samples from batch ${batchNum}`)
              }
            } else {
              insertedCount += batch.length
              console.log(`   ✅ Inserted batch ${batchNum} (${batch.length} samples)`)
            }
          }
          
          console.log(`   ✅ Total samples inserted: ${insertedCount}`)
        }
        
        // Update activity to mark FIT file as processed
        console.log("💾 Updating activity with has_fit_file = true...")
        const { error: updateError } = await supabase
          .from('suunto_activities')
          .update({
            has_fit_file: true,
            updated_at: new Date().toISOString()
          })
          .eq('id', activity_id)
        
        if (updateError) {
          console.error("❌ Failed to update activity:", updateError)
          const duration = Date.now() - startTime
          return resolve(new Response(JSON.stringify({ error: "Failed to update activity" }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          }))
        }
        
        console.log("✅ Activity updated with has_fit_file = true")
        
        const duration = Date.now() - startTime
        console.log(`✅ Suunto FIT processor completed in ${duration}ms`)
        
        return resolve(new Response(JSON.stringify({
          success: true,
          activity_id: activity_id,
          fit_file_size: fit_file_data.length,
          records_found: records.length,
          samples_inserted: insertedCount || 0,
          duration: `${duration}ms`
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        }))
      })
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in Suunto FIT processor:", error)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
