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
  
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, User-Agent',
        'Access-Control-Max-Age': '86400',
      },
    })
  }
  
  try {
    console.log("🏥 Garmin Health Webhook received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Extract webhook secret from URL path
    // Expected format: /functions/v1/garmin-health-webhook/SECRET_TOKEN
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(p => p)
    const functionNameIndex = pathParts.findIndex(p => p === 'garmin-health-webhook')
    const secretFromPath = functionNameIndex >= 0 && pathParts[functionNameIndex + 1] 
      ? pathParts[functionNameIndex + 1] 
      : null
    
    // Get expected webhook secret from environment (optional)
    const expectedSecret = Deno.env.get('GARMIN_WEBHOOK_SECRET') || 'garmin-webhook-secret-2024'
    
    // Verify secret if provided in path
    if (secretFromPath) {
      if (secretFromPath === expectedSecret) {
        console.log("✅ Valid webhook secret verified")
      } else {
        console.log("⚠️ Invalid webhook secret provided")
      }
    } else {
      console.log("ℹ️ No webhook secret in URL path")
    }
    
    // Verify request is from Garmin (but don't reject - just log)
    const userAgent = req.headers.get('user-agent') || ''
    if (!userAgent.includes('Garmin')) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
      // Still process - might be from testing or other sources
    } else {
      console.log("✅ Verified Garmin User-Agent")
    }
    
    // Parse request body (handle both JSON and form data)
    let body: any
    try {
      const contentType = req.headers.get('content-type') || ''
      if (contentType.includes('application/json')) {
        body = await req.json()
      } else {
        // Try to parse as JSON anyway (Garmin usually sends JSON)
        const text = await req.text()
        body = text ? JSON.parse(text) : {}
      }
    } catch (parseError) {
      console.error("❌ Error parsing request body:", parseError)
      // Return 200 to prevent Garmin from retrying
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    console.log("   Body keys:", Object.keys(body))
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Extract Garmin user ID
    // Garmin sends userId nested in arrays: userMetrics[0].userId
    let garminUserId = body.userId || body.garminUserId || body.user_id
    
    // If not at top level, check inside userMetrics array
    if (!garminUserId && body.userMetrics && Array.isArray(body.userMetrics) && body.userMetrics.length > 0) {
      garminUserId = body.userMetrics[0].userId || body.userMetrics[0].garminUserId
    }
    
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
    console.log("   Searching for garmin_user_id:", garminUserId)
    
    const { data: connection, error: lookupError } = await supabase
      .from('garmin_connections')
      .select('user_id')
      .eq('garmin_user_id', garminUserId)
      .single()
    
    if (lookupError || !connection) {
      console.log("⚠️ No HYKA user found for Garmin user:", garminUserId)
      console.log("   Lookup error:", lookupError?.message || "No connection found")
      console.log("   This could mean:")
      console.log("   - User disconnected their Garmin")
      console.log("   - Connection not yet established")
      console.log("   - garmin_user_id mismatch")
      return new Response("OK", { status: 200 })
    }
    
    console.log("✅ Found HYKA user:", connection.user_id)
    
    // Determine webhook type and extract data
    const webhookType = body.type || body.eventType || 'unknown'
    let metricsData: any = null
    
    // Handle different health webhook types
    // Garmin sends data in arrays, so extract first element
    if (body.userMetrics) {
      // User Metrics webhook (contains fitness age, VO2 max, etc.)
      // Can be array or object
      metricsData = Array.isArray(body.userMetrics) && body.userMetrics.length > 0 
        ? body.userMetrics[0] 
        : body.userMetrics
      console.log("📊 Processing User Metrics")
    } else if (body.healthSnapshot) {
      // Health Snapshot webhook
      metricsData = Array.isArray(body.healthSnapshot) && body.healthSnapshot.length > 0
        ? body.healthSnapshot[0]
        : body.healthSnapshot
      console.log("📊 Processing Health Snapshot")
    } else if (body.bodyComposition) {
      // Body Composition webhook
      metricsData = Array.isArray(body.bodyComposition) && body.bodyComposition.length > 0
        ? body.bodyComposition[0]
        : body.bodyComposition
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
      console.log("💾 Storing health metrics in database...")
      console.log("   Table: garmin_health_metrics")
      console.log("   User ID:", connection.user_id)
      console.log("   Garmin User ID:", garminUserId)
      
      const healthData = {
        user_id: connection.user_id,
        garmin_user_id: garminUserId,
        timestamp: timestamp ? new Date(timestamp * 1000).toISOString() : new Date().toISOString(),
        fitness_age: fitnessAge,
        vo2_max: vo2Max,
        raw_data: metricsData || body,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
      
      console.log("   Health data to insert:", JSON.stringify(healthData, null, 2))
      
      const { data: insertedData, error: insertError } = await supabase
        .from('garmin_health_metrics')
        .upsert(healthData, {
          onConflict: 'user_id,timestamp'
        })
        .select()
      
      if (insertError) {
        console.error("❌ Error storing health metrics in database")
        console.error("   Error:", insertError)
        console.error("   Error message:", insertError?.message)
        console.error("   Error details:", JSON.stringify(insertError, null, 2))
        console.error("   Health data that failed:", JSON.stringify(healthData, null, 2))
      } else {
        console.log("✅ Health metrics stored successfully in database")
        console.log("   Inserted data:", JSON.stringify(insertedData, null, 2))
      }
    } else {
      console.log("ℹ️ No fitness age or VO2 max data in webhook")
      console.log("   Metrics data:", JSON.stringify(metricsData, null, 2))
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
// IMPORTANT: This function must be configured to allow anonymous access
// in Supabase Dashboard, otherwise Garmin webhooks will receive 401 errors.
//
// To make this function public:
// 1. Go to Supabase Dashboard → Edge Functions → garmin-health-webhook
// 2. Configure the function to allow unauthenticated requests
//    OR use the anon key in the webhook URL (not recommended for security)
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
// 4. Make function public in Supabase Dashboard (required for webhooks)
//
// ============================================================================

