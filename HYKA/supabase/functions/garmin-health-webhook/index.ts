// ============================================================================
// Garmin Health Webhook Handler
// ============================================================================
//
// Purpose: Handles Garmin health data webhooks (User Metrics, Health Snapshot, etc.)
// 
// Health Data Includes:
// - Fitness Age
// - VO2 Max
// - Body Composition
// - Blood Pressure
// - Sleep Data
// - Stress
// - HRV Summary
// - And more...
//
// Flow:
// 1. Receive health webhook from Garmin
// 2. Parse health data (User Metrics, Health Snapshot, etc.)
// 3. Store in garmin_health_metrics table
// 4. Return 200 OK to Garmin
//
// Reference: Garmin Health API documentation
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("🏥 Garmin Health Webhook received")
    console.log("   Method:", req.method)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Verify request is from Garmin
    const userAgent = req.headers.get('user-agent') || ''
    if (!userAgent.includes('Garmin')) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
      // Still return 200 to prevent retries
    }
    
    // Parse request body
    const body = await req.json()
    console.log("   Body keys:", Object.keys(body))
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Extract Garmin user ID
    const garminUserId = body.userId || body.garminUserId || body.user_id
    
    if (!garminUserId) {
      console.error("❌ Missing garminUserId in health webhook")
      return new Response("OK", { status: 200 })
    }
    
    console.log("   Garmin User ID:", garminUserId)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Look up HYKA user
    console.log("🔍 Looking up HYKA user...")
    
    const { data: connection, error: lookupError } = await supabase
      .from('garmin_connections')
      .select('user_id')
      .eq('garmin_user_id', garminUserId)
      .single()
    
    if (lookupError || !connection) {
      console.log("⚠️ No HYKA user found for Garmin user:", garminUserId)
      return new Response("OK", { status: 200 })
    }
    
    console.log("✅ Found HYKA user:", connection.user_id)
    
    // Determine webhook type and extract data
    const webhookType = body.type || body.eventType || 'unknown'
    let metricsData: any = null
    
    // Handle different health webhook types
    if (body.userMetrics) {
      // User Metrics webhook (contains fitness age, VO2 max, etc.)
      metricsData = body.userMetrics
      console.log("📊 Processing User Metrics")
    } else if (body.healthSnapshot) {
      // Health Snapshot webhook
      metricsData = body.healthSnapshot
      console.log("📊 Processing Health Snapshot")
    } else if (body.bodyComposition) {
      // Body Composition webhook
      metricsData = body.bodyComposition
      console.log("📊 Processing Body Composition")
    } else {
      // Generic health data
      metricsData = body
      console.log("📊 Processing generic health data")
    }
    
    // Extract key metrics
    const fitnessAge = metricsData?.fitnessAge || metricsData?.fitness_age || null
    const vo2Max = metricsData?.vo2Max || metricsData?.vo2_max || metricsData?.vo2max || null
    const timestamp = metricsData?.timestamp || metricsData?.timestampInSeconds || Date.now() / 1000
    
    console.log("   Fitness Age:", fitnessAge)
    console.log("   VO2 Max:", vo2Max)
    console.log("   Timestamp:", timestamp)
    
    // Store health metrics
    if (fitnessAge !== null || vo2Max !== null || metricsData) {
      console.log("💾 Storing health metrics...")
      
      const { error: insertError } = await supabase
        .from('garmin_health_metrics')
        .upsert({
          user_id: connection.user_id,
          garmin_user_id: garminUserId,
          timestamp: timestamp ? new Date(timestamp * 1000).toISOString() : new Date().toISOString(),
          fitness_age: fitnessAge,
          vo2_max: vo2Max,
          raw_data: metricsData || body,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'user_id,timestamp'
        })
      
      if (insertError) {
        console.error("❌ Error storing health metrics:", insertError)
      } else {
        console.log("✅ Health metrics stored")
      }
    } else {
      console.log("ℹ️ No fitness age or VO2 max data in webhook")
    }
    
    const duration = Date.now() - startTime
    console.log(`✅ Health webhook processed in ${duration}ms`)
    
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error processing health webhook:", error)
    console.error("   Duration:", `${duration}ms`)
    
    // Always return 200 to Garmin (even on error) to prevent retries
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
  }
})

// ============================================================================
// Configuration Required
// ============================================================================
//
// 1. Create garmin_health_metrics table (see schema below)
//
// 2. Configure webhooks in Garmin Developer Portal:
//    - User Metrics: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook
//    - Health Snapshot: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook
//
// 3. Deploy this function:
//    supabase functions deploy garmin-health-webhook
//
// ============================================================================

