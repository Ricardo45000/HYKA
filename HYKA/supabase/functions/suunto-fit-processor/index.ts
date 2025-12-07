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
// 4. Store samples in suunto_activity_samples (to be created)
// 5. Update activity with computed metrics
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
    
    // Placeholder for FIT parsing
    console.log("⚠️ FIT file parsing not yet implemented (requires library)")
    console.log("   Recommended: Integrate a JavaScript FIT parser compatible with Deno")
    
    // TODO: Parse FIT file and extract samples
    const samples: any[] = []
    
    console.log("💾 Updating activity with FIT file status...")
    
    await supabase
      .from('suunto_activities')
      .update({
        has_fit_file: true,
        updated_at: new Date().toISOString()
      })
      .eq('id', activity_id)
    
    const duration = Date.now() - startTime
    console.log(`✅ FIT processor completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      success: true,
      activity_id: activity_id,
      fit_file_size: fit_file_data.length,
      samples_extracted: samples.length,
      note: "FIT file received. Parsing requires FIT parser library integration.",
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
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

