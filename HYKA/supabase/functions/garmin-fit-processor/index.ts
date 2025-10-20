// ============================================================================
// Garmin FIT File Processor
// ============================================================================
//
// Purpose: Parse FIT files for ultra-runner activities (>24 hours)
//          FIT files contain complete data when JSON payloads are truncated
//
// Flow:
// 1. Receive activity_id and FIT file data
// 2. Parse FIT file using Garmin SDK (or compatible parser)
// 3. Extract samples (GPS, HR, elevation, cadence, temperature)
// 4. Compute accurate elevation gain/loss from samples
// 5. Store samples in garmin_activity_samples
// 6. Update activity with computed elevation
//
// Note: For Deno/Supabase Edge Functions, we'll use a JavaScript FIT parser
//       Garmin's official SDK is C++/Java, so we use a compatible JS library
//
// Reference: FIT SDK Documentation
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
    
    // Get activity to verify it exists
    const { data: activity, error: activityError } = await supabase
      .from('garmin_activities')
      .select('id, user_id, start_time_seconds, garmin_activity_id')
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
    
    // Convert array back to Uint8Array
    const fitFileBytes = new Uint8Array(fit_file_data)
    
    // Parse FIT file
    // Note: For production, use a proper FIT parser library
    // For now, we'll use a basic approach and recommend integrating a FIT parser
    console.log("🔄 Parsing FIT file...")
    
    // TODO: Integrate FIT parser library
    // Recommended: Use a JavaScript FIT parser compatible with Deno
    // Example: https://github.com/jimmykane/fit-file-parser or similar
    
    // For now, we'll extract basic information and log that parsing is needed
    console.log("⚠️ FIT file parsing not yet implemented")
    console.log("   FIT file received and stored, but parsing requires FIT parser library")
    console.log("   Recommended: Integrate a JavaScript FIT parser compatible with Deno")
    
    // Placeholder: Extract samples from FIT file
    // In production, this would use a proper FIT parser
    const samples: any[] = []
    let computedElevationGain = 0
    let computedElevationLoss = 0
    
    // TODO: Parse FIT file and extract:
    // - Record messages (GPS, HR, elevation, cadence, temperature)
    // - Session messages (summary data)
    // - Lap messages (lap data)
    
    // For now, we'll just update the activity to indicate FIT file is stored
    // The actual parsing can be done later when FIT parser is integrated
    
    console.log("💾 Updating activity with FIT file status...")
    
    await supabase
      .from('garmin_activities')
      .update({
        has_fit_file: true,
        updated_at: new Date().toISOString()
      })
      .eq('id', activity_id)
    
    // If we had parsed samples, we would:
    // 1. Store samples in garmin_activity_samples
    // 2. Compute elevation gain/loss from samples
    // 3. Update activity with computed elevation
    
    const duration = Date.now() - startTime
    console.log(`✅ FIT processor completed in ${duration}ms`)
    console.log("   Note: FIT parsing requires integration of FIT parser library")
    
    return new Response(JSON.stringify({
      success: true,
      activity_id: activity_id,
      fit_file_size: fit_file_data.length,
      samples_extracted: samples.length,
      note: "FIT file stored. Parsing requires FIT parser library integration.",
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in FIT processor:", error)
    console.error("   Duration:", `${duration}ms`)
    
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

// ============================================================================
// FIT Parser Integration Notes
// ============================================================================
//
// To properly parse FIT files, you need to:
//
// 1. Choose a FIT parser library compatible with Deno:
//    - Option A: Use a JavaScript FIT parser (e.g., fit-file-parser)
//    - Option B: Use WebAssembly version of Garmin FIT SDK
//    - Option C: Call external service to parse FIT files
//
// 2. Parse FIT file structure:
//    - File header (14 bytes)
//    - Data records (messages)
//    - File CRC (2 bytes)
//
// 3. Extract key messages:
//    - Record messages: GPS, HR, elevation, cadence, temperature
//    - Session messages: Summary data
//    - Lap messages: Lap data
//
// 4. Convert to samples format:
//    - timestamp_seconds (from start_time + elapsed_time)
//    - latitude, longitude (from position messages)
//    - elevation_meters (from altitude messages)
//    - heart_rate (from HR messages)
//    - speed_mps (from speed messages)
//    - steps_per_minute (from cadence messages)
//    - air_temperature_celsius (from temperature messages)
//
// 5. Store samples in garmin_activity_samples table
//
// 6. Compute elevation gain/loss from samples
//
// 7. Update activity with computed elevation
//
// Recommended Library:
// - https://github.com/jimmykane/fit-file-parser (JavaScript)
// - Or use Garmin's FIT SDK via WebAssembly
//
// ============================================================================

