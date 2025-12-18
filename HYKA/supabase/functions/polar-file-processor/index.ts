// ============================================================================
// Polar File Processor (TCX)
// ============================================================================
//
// Purpose: Parse TCX files for Polar activities
//
// Flow:
// 1. Receive activity_id and File data (TCX)
// 2. Parse TCX XML (using a simple XML parser or regex for now)
// 3. Extract samples (GPS, HR, elevation, cadence)
// 4. Store samples in polar_activity_samples (to be created)
// 5. Update activity with computed metrics
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Parse TCX XML file and extract TrackPoint samples
 * TCX Structure:
 * <Trackpoint>
 *   <Time>2024-01-01T12:00:00Z</Time>
 *   <Position>
 *     <LatitudeDegrees>51.5</LatitudeDegrees>
 *     <LongitudeDegrees>-0.1</LongitudeDegrees>
 *   </Position>
 *   <AltitudeMeters>100.0</AltitudeMeters>
 *   <HeartRateBpm>
 *     <Value>150</Value>
 *   </HeartRateBpm>
 *   <Cadence>90</Cadence>
 *   <Extensions>
 *     <TPX>
 *       <Speed>3.5</Speed>
 *     </TPX>
 *   </Extensions>
 * </Trackpoint>
 */
function parseTCX(tcxText: string, activityStartDate: string | null): any[] {
  const samples: any[] = []
  
  // Get base timestamp from activity start date if available
  let baseTimestamp: number | null = null
  if (activityStartDate) {
    try {
      baseTimestamp = Math.floor(new Date(activityStartDate).getTime() / 1000)
    } catch (e) {
      console.warn("⚠️ Could not parse activity start date:", e)
    }
  }
  
  // Use regex to extract TrackPoints
  // Match <Trackpoint>...</Trackpoint> blocks
  const trackpointRegex = /<Trackpoint[^>]*>([\s\S]*?)<\/Trackpoint>/gi
  let trackpointMatch
  let sampleIndex = 0
  
  while ((trackpointMatch = trackpointRegex.exec(tcxText)) !== null) {
    const trackpointXml = trackpointMatch[1]
    
    // Extract Time
    const timeMatch = trackpointXml.match(/<Time[^>]*>([^<]+)<\/Time>/i)
    let timestampSeconds: number | null = null
    let sampleTime: string | null = null
    
    if (timeMatch) {
      try {
        const timeStr = timeMatch[1].trim()
        const date = new Date(timeStr)
        if (!isNaN(date.getTime())) {
          timestampSeconds = Math.floor(date.getTime() / 1000)
          sampleTime = date.toISOString()
        }
      } catch (e) {
        // If parsing fails, use base timestamp + sample index
        if (baseTimestamp !== null) {
          timestampSeconds = baseTimestamp + sampleIndex
          sampleTime = new Date(timestampSeconds * 1000).toISOString()
        }
      }
    } else if (baseTimestamp !== null) {
      // No time in trackpoint, use base + index
      timestampSeconds = baseTimestamp + sampleIndex
      sampleTime = new Date(timestampSeconds * 1000).toISOString()
    }
    
    // Extract Position (Latitude/Longitude)
    let latitude: number | null = null
    let longitude: number | null = null
    
    const latMatch = trackpointXml.match(/<LatitudeDegrees[^>]*>([^<]+)<\/LatitudeDegrees>/i)
    const lonMatch = trackpointXml.match(/<LongitudeDegrees[^>]*>([^<]+)<\/LongitudeDegrees>/i)
    
    if (latMatch) {
      const lat = parseFloat(latMatch[1].trim())
      if (!isNaN(lat)) latitude = lat
    }
    
    if (lonMatch) {
      const lon = parseFloat(lonMatch[1].trim())
      if (!isNaN(lon)) longitude = lon
    }
    
    // Extract Altitude
    let elevationMeters: number | null = null
    const altMatch = trackpointXml.match(/<AltitudeMeters[^>]*>([^<]+)<\/AltitudeMeters>/i)
    if (altMatch) {
      const alt = parseFloat(altMatch[1].trim())
      if (!isNaN(alt)) elevationMeters = alt
    }
    
    // Extract Heart Rate
    let heartRate: number | null = null
    const hrMatch = trackpointXml.match(/<HeartRateBpm[^>]*>[\s\S]*?<Value[^>]*>([^<]+)<\/Value>/i)
    if (hrMatch) {
      const hr = parseInt(hrMatch[1].trim(), 10)
      if (!isNaN(hr) && hr > 0) heartRate = hr
    }
    
    // Extract Cadence (steps per minute)
    let stepsPerMinute: number | null = null
    const cadenceMatch = trackpointXml.match(/<Cadence[^>]*>([^<]+)<\/Cadence>/i)
    if (cadenceMatch) {
      const cad = parseInt(cadenceMatch[1].trim(), 10)
      if (!isNaN(cad) && cad > 0) stepsPerMinute = cad
    }
    
    // Extract Speed (from Extensions/TPX)
    let speedMps: number | null = null
    const speedMatch = trackpointXml.match(/<Speed[^>]*>([^<]+)<\/Speed>/i)
    if (speedMatch) {
      const speed = parseFloat(speedMatch[1].trim())
      if (!isNaN(speed) && speed > 0) speedMps = speed
    }
    
    // Only add sample if we have at least a timestamp
    if (timestampSeconds !== null) {
      samples.push({
        timestamp_seconds: timestampSeconds,
        sample_time: sampleTime,
        latitude: latitude,
        longitude: longitude,
        elevation_meters: elevationMeters,
        heart_rate: heartRate,
        speed_mps: speedMps,
        steps_per_minute: stepsPerMinute,
        air_temperature_celsius: null // TCX doesn't typically include temperature
      })
      sampleIndex++
    }
  }
  
  return samples
}

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("📦 Polar File Processor started")
    
    const { activity_id, file_data, file_format } = await req.json()
    
    if (!activity_id || !file_data) {
      console.error("❌ Missing activity_id or file_data")
      return new Response(JSON.stringify({ error: "Missing activity_id or file_data" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   Activity ID:", activity_id)
    console.log("   File format:", file_format || 'tcx')
    console.log("   File size:", file_data.length, "bytes")
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Get activity to verify it exists
    const { data: activity, error: activityError } = await supabase
      .from('polar_activities')
      .select('id, user_id, start_date, polar_activity_id')
      .eq('id', activity_id)
      .single()
    
    if (activityError || !activity) {
      console.error("❌ Activity not found:", activityError)
      return new Response(JSON.stringify({ error: "Activity not found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("✅ Activity found:", activity.polar_activity_id)
    
    // Convert file data to text
    const fileBytes = new Uint8Array(file_data)
    const fileText = new TextDecoder().decode(fileBytes)
    
    // Parse TCX XML
    console.log("📖 Parsing TCX XML...")
    const samples = parseTCX(fileText, activity.start_date)
    
    console.log(`   ✅ Extracted ${samples.length} samples from TCX file`)
    
    // Store samples in database if we have any
    if (samples.length > 0) {
      console.log(`   💾 Inserting ${samples.length} samples into polar_activity_samples...`)
      
      // Insert samples in batches (PostgreSQL has a limit on batch size)
      const batchSize = 1000
      let insertedCount = 0
      
      for (let i = 0; i < samples.length; i += batchSize) {
        const batch = samples.slice(i, i + batchSize).map(sample => ({
          activity_id: activity_id,
          timestamp_seconds: sample.timestamp_seconds,
          sample_time: sample.sample_time || null,
          latitude: sample.latitude || null,
          longitude: sample.longitude || null,
          elevation_meters: sample.elevation_meters || null,
          heart_rate: sample.heart_rate || null,
          speed_mps: sample.speed_mps || null,
          steps_per_minute: sample.steps_per_minute || null,
          air_temperature_celsius: sample.air_temperature_celsius || null
        }))
        
        const { error: insertError } = await supabase
          .from('polar_activity_samples')
          .insert(batch)
        
        if (insertError) {
          console.error(`❌ Error inserting batch ${Math.floor(i / batchSize) + 1}:`, insertError)
          // Continue with next batch
        } else {
          insertedCount += batch.length
          console.log(`   ✅ Inserted batch ${Math.floor(i / batchSize) + 1} (${batch.length} samples)`)
        }
      }
      
      console.log(`   ✅ Total samples inserted: ${insertedCount}`)
    } else {
      console.warn("⚠️ No samples extracted from TCX file")
    }
    
    // Update activity to mark file as processed
    console.log("💾 Updating activity with has_fit_file = true...")
    const { error: updateError } = await supabase
      .from('polar_activities')
      .update({
        has_fit_file: true,
        updated_at: new Date().toISOString()
      })
      .eq('id', activity_id)
    
    if (updateError) {
      console.error("❌ Failed to update activity:", updateError)
      return new Response(JSON.stringify({ error: "Failed to update activity" }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("✅ Activity updated with has_fit_file = true")
    
    const duration = Date.now() - startTime
    console.log(`✅ File processor completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      success: true,
      activity_id: activity_id,
      file_size: file_data.length,
      samples_extracted: samples.length,
      samples_inserted: samples.length,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in Polar File processor:", error)
    
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

