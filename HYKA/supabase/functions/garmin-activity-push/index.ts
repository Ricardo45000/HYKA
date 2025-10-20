// ============================================================================
// Garmin Activity PUSH Webhook (Official Specification)
// ============================================================================
//
// Purpose: Receives PUSH notifications from Garmin with full activity data included
// 
// Difference from PING:
// - PING: Notification only (triggers fetch via callbackUrl)
// - PUSH: Full activity summary JSON included in webhook payload
//
// Flow:
// 1. Garmin sends PUSH with garminUserId + activities array (full summaries)
// 2. Look up HYKA user from garminUserId
// 3. For each activity:
//    - Store summary directly from payload
//    - Optionally fetch details (samples) via callbackUrl/details
//    - Optionally fetch FIT file via callbackUrl/file (for ultra-runners)
// 4. Forward to garmin-activity-store
// 5. Return 200 OK to Garmin
//
// Reference: Garmin Activity API 1.2.3 - Push Service
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    // Log request details
    console.log("📦 Garmin PUSH received")
    console.log("   Method:", req.method)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Parse request body
    const body = await req.json()
    console.log("   Body keys:", Object.keys(body))
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Extract Garmin user ID and activities
    const garminUserId = body.userId || body.garminUserId || body.userAccessToken
    const activities = body.activities || body.activityList || []
    
    if (!garminUserId) {
      console.error("❌ Missing garminUserId in PUSH")
      return new Response(JSON.stringify({ 
        success: false, 
        error: "Missing garminUserId" 
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   Garmin User ID:", garminUserId)
    console.log("   Activities count:", activities.length)
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Look up HYKA user
    console.log("🔍 Looking up HYKA user...")
    
    const { data: connection, error: lookupError } = await supabase
      .from('garmin_connections')
      .select('user_id, access_token')
      .eq('garmin_user_id', garminUserId)
      .single()
    
    if (lookupError || !connection) {
      console.log("⚠️ No HYKA user found for Garmin user:", garminUserId)
      return new Response(JSON.stringify({ 
        success: true, 
        message: "No connection found" 
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("✅ Found HYKA user:", connection.user_id)
    
    // Process activities - forward each to store function
    // PUSH mode includes full summaries, but we still need to fetch details/FIT files
    let processedCount = 0
    const activityTypes = ['Running', 'Hiking', 'Walking'] // Capitalized as per spec
    
    for (const activitySummary of activities) {
      try {
        // Extract activity data from PUSH payload
        const activityType = activitySummary.activityType || ''
        
        // Filter by activity type (only Running, Hiking, Walking - capitalized)
        if (!activityTypes.includes(activityType)) {
          console.log(`⏭️ Skipping activity type: ${activityType}`)
          continue
        }
        
        const activityId = activitySummary.summaryId || activitySummary.activityId
        
        if (!activityId) {
          console.log("⚠️ Activity missing ID, skipping")
          continue
        }
        
        console.log(`📦 Processing activity: ${activityId} (${activityType})`)
        
        // PUSH mode: Summary is in payload, but we may need to fetch details/FIT file
        // Check if callbackUrl is provided for fetching details
        const callbackUrl = activitySummary.callbackUrl || null
        
        // Forward to store function
        // Store function will handle samples and FIT files if callbackUrl is available
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        
        const storeResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${supabaseKey}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            summary: activitySummary, // Full summary from PUSH payload
            details: null, // Will be fetched if callbackUrl available
            garminUserId: garminUserId,
            callbackUrl: callbackUrl // For fetching details/FIT file if needed
          })
        })
        
        if (storeResponse.ok) {
          processedCount++
          console.log(`✅ Processed activity ${activityId}`)
        } else {
          const errorText = await storeResponse.text()
          console.error(`❌ Error processing activity ${activityId}:`, errorText)
        }
        
      } catch (activityError) {
        console.error("❌ Error processing activity:", activityError)
        // Continue with next activity
      }
    }
    
    // Update last_sync_at
    await supabase
      .from('garmin_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('user_id', connection.user_id)
    
    const duration = Date.now() - startTime
    console.log(`✅ PUSH processed in ${duration}ms - processed ${processedCount}/${activities.length} activities`)
    
    return new Response(JSON.stringify({ 
      success: true,
      activitiesReceived: activities.length,
      activitiesProcessed: processedCount,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error processing PUSH:", error)
    console.error("   Duration:", `${duration}ms`)
    
    // Always return 200 to prevent Garmin retries
    return new Response(JSON.stringify({ 
      success: false,
      error: error.message 
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

// ============================================================================
// Configuration Required
// ============================================================================
//
// 1. Configure webhook in Garmin Developer Portal:
//    - URL: https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push
//    - Method: POST
//    - Events: Activity uploads (PUSH type)
//
// 2. Garmin may send PUSH for some endpoints and PING for others
//    - Configure both garmin-activity-ping AND garmin-activity-push
//
// ============================================================================

