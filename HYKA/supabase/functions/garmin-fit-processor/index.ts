// ============================================================================
// Garmin FIT File Processor
// ============================================================================
//
// Purpose: Parse FIT files and extract detailed samples
//
// Flow:
// 1. Receive activity_id and FIT file data
// 2. Parse FIT file to extract samples (GPS, HR, cadence, etc.)
// 3. Store samples in garmin_activity_samples table
// 4. Update activity with has_fit_file = true
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// @deno-types="https://esm.sh/@types/node@18/index.d.ts"
import FitParser from 'https://esm.sh/fit-file-parser@1.21.0'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("📦 Garmin FIT File Processor started")
    
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
    
    // Get activity to verify it exists and get start time
    const { data: activity, error: activityError } = await supabase
      .from('garmin_activities')
      .select('id, user_id, start_time, start_time_seconds, garmin_activity_id')
      .eq('id', activity_id)
      .single()
    
    if (activityError || !activity) {
      console.error("❌ Activity not found:", activityError)
      return new Response(JSON.stringify({ error: "Activity not found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("✅ Activity found:", activity.garmin_activity_id)
    
    // Convert array back to Uint8Array/Buffer
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
        // The fit-file-parser returns data in a specific structure
        // Records are typically in data.activity.sessions[].records
        let records: any[] = []
        let insertedCount = 0 // Declare outside if block for use in response
        
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
          // Sometimes records are nested in sessions at root level
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
            if (depth > 5) return [] // Prevent infinite recursion
            if (Array.isArray(obj) && obj.length > 0) {
              // Check if this array contains record-like objects (has timestamp)
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
          if (data.activity) {
            console.log("   Activity keys:", Object.keys(data.activity))
            if (data.activity.sessions && Array.isArray(data.activity.sessions)) {
              console.log(`   Sessions: ${data.activity.sessions.length}`)
              if (data.activity.sessions.length > 0) {
                console.log("   First session keys:", Object.keys(data.activity.sessions[0]))
              }
            }
          }
        } else {
          // Log first record structure to see available fields
          if (records.length > 0) {
            console.log("   First record keys:", Object.keys(records[0]))
            const firstRecordSample: any = {}
            for (const key of Object.keys(records[0])) {
              if (key.toLowerCase().includes('temp') || key.toLowerCase().includes('temperature')) {
                firstRecordSample[key] = records[0][key]
              }
            }
            if (Object.keys(firstRecordSample).length > 0) {
              console.log("   Temperature-related fields in first record:", firstRecordSample)
            } else {
              console.log("   ⚠️ No temperature-related fields found in first record")
            }
          }
          
          // Convert records to our database format
          // FIT file parser returns records with fields like:
          // - timestamp (Date or number)
          // - position_lat, position_long (degrees or semicircles)
          // - altitude (meters)
          // - heart_rate (bpm)
          // - speed (m/s or km/h)
          // - cadence (steps/min)
          // - temperature (celsius) - may be named differently
          
          const samplesToInsert = records
            .filter((record: any) => {
              // Only include records with timestamps
              return record.timestamp !== undefined && record.timestamp !== null
            })
            .map((record: any) => {
              // Convert timestamp to seconds since epoch
              let timestampSeconds: number
              if (record.timestamp instanceof Date) {
                timestampSeconds = Math.floor(record.timestamp.getTime() / 1000)
              } else if (typeof record.timestamp === 'number') {
                // If it's already in seconds, use it; if it's milliseconds, convert
                timestampSeconds = record.timestamp > 1e12 
                  ? Math.floor(record.timestamp / 1000) 
                  : Math.floor(record.timestamp)
              } else {
                return null
              }
              
              // Convert sample_time to ISO string
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
                  // Try multiple possible field names for temperature
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
            .filter((sample: any) => sample !== null) // Remove null entries
          
          console.log(`   💾 Preparing ${samplesToInsert.length} samples for database insertion...`)
          
          // Insert samples in batches (PostgreSQL has a limit on batch size)
          const batchSize = 1000
          
          for (let i = 0; i < samplesToInsert.length; i += batchSize) {
            const batch = samplesToInsert.slice(i, i + batchSize)
            const batchNum = Math.floor(i / batchSize) + 1
            const totalBatches = Math.ceil(samplesToInsert.length / batchSize)
            
            console.log(`   💾 Inserting batch ${batchNum}/${totalBatches} (${batch.length} samples)...`)
            
            const { data: insertedData, error: insertError } = await supabase
              .from('garmin_activity_samples')
              .insert(batch)
              .select('id')
            
            if (insertError) {
              console.error(`❌ Error inserting batch ${batchNum}:`, insertError)
              console.error(`   Error details:`, JSON.stringify(insertError).substring(0, 500))
              // Check if it's a duplicate key error
              if (insertError.code === '23505' || insertError.message?.includes('duplicate')) {
                console.log(`   ⚠️ Duplicate key error - some samples may already exist`)
                // Try inserting one by one to see which ones fail
                let successCount = 0
                for (const sample of batch) {
                  const { error: singleError } = await supabase
                    .from('garmin_activity_samples')
                    .insert(sample)
                    .select('id')
                  if (!singleError) {
                    successCount++
                  }
                }
                insertedCount += successCount
                console.log(`   ✅ Inserted ${successCount}/${batch.length} samples from batch ${batchNum} (duplicates skipped)`)
              } else {
                // Other error - log and continue
                console.error(`   ⚠️ Skipping batch ${batchNum} due to error`)
              }
            } else {
              insertedCount += batch.length
              console.log(`   ✅ Inserted batch ${batchNum} (${batch.length} samples)`)
              if (insertedData && insertedData.length > 0) {
                console.log(`   ✅ Confirmed: ${insertedData.length} rows inserted`)
              }
            }
          }
          
          console.log(`   ✅ Total samples inserted: ${insertedCount} out of ${samplesToInsert.length} attempted`)
          
          // Verify insertion by counting records in database
          const { count, error: countError } = await supabase
            .from('garmin_activity_samples')
            .select('*', { count: 'exact', head: true })
            .eq('activity_id', activity_id)
          
          if (!countError && count !== null) {
            console.log(`   📊 Database now has ${count} samples for this activity`)
            if (count !== insertedCount) {
              console.warn(`   ⚠️ Mismatch: inserted ${insertedCount} but database shows ${count}`)
            }
          }
        }
        
        // Update activity to mark FIT file as processed
        console.log("💾 Updating activity with has_fit_file = true...")
        const { error: updateError } = await supabase
          .from('garmin_activities')
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
        console.log(`✅ FIT processor completed in ${duration}ms`)
        
        return resolve(new Response(JSON.stringify({
          success: true,
          activity_id: activity_id,
          fit_file_size: fit_file_data.length,
          records_found: records.length,
          samples_extracted: records.length,
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
    console.error("❌ Error in Garmin FIT processor:", error)
    
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
