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
    
    // Data is likely array of bytes
    const fileBytes = new Uint8Array(file_data)
    const fileText = new TextDecoder().decode(fileBytes)
    
    // Placeholder for TCX parsing
    console.log("⚠️ TCX parsing not yet implemented")
    console.log("   Recommended: Integrate an XML parser to extract TrackPoints")
    
    // TODO: Parse TCX XML
    // TCX Structure: <Trackpoint><Time>...</Time><Position>...</Position><AltitudeMeters>...</AltitudeMeters><HeartRateBpm>...</HeartRateBpm></Trackpoint>
    
    const samples: any[] = []
    
    console.log("💾 Updating activity with File status...")
    
    await supabase
      .from('polar_activities')
      .update({
        has_fit_file: true,
        updated_at: new Date().toISOString()
      })
      .eq('id', activity_id)
    
    const duration = Date.now() - startTime
    console.log(`✅ File processor completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      success: true,
      activity_id: activity_id,
      file_size: file_data.length,
      samples_extracted: samples.length,
      note: "TCX file received. Parsing requires XML parser integration.",
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

