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
    // Log request details
    console.log("📦 Garmin PUSH received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Extract webhook secret from URL path
    // Expected format: /functions/v1/garmin-activity-push/SECRET_TOKEN
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(p => p)
    const functionNameIndex = pathParts.findIndex(p => p === 'garmin-activity-push')
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
      return new Response(JSON.stringify({ 
        success: false,
        error: "Invalid request body"
      }), { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json'
        }
      })
    }
    
    console.log("   Body keys:", Object.keys(body))
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Extract Garmin user ID and activities
    // Garmin sends userId nested in arrays: activities[0].userId
    const activities = body.activities || body.activityList || []
    
    // Try top level first, then check inside activities array
    let garminUserId = body.userId || body.garminUserId || body.userAccessToken
    if (!garminUserId && activities.length > 0) {
      garminUserId = activities[0].userId || activities[0].garminUserId
    }
    
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
    
    // Log all activity types received
    if (activities.length > 0) {
      const activityTypes = activities.map(a => a.activityType || 'unknown').filter(Boolean)
      console.log("   Activity types received:", activityTypes)
    }
    
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
    
    // Accept any activity type that contains "Running", "Hiking", or "Walking" (case-insensitive)
    // Garmin may send: "Running", "Trail Running", "Road Running", "Treadmill Running", etc.
    const allowedActivityTypeKeywords = ['running', 'hiking', 'walking']
    
    for (const activitySummary of activities) {
      try {
        // Extract activity data from PUSH payload
        const activityType = activitySummary.activityType || ''
        const activityTypeLower = activityType.toLowerCase()
        
        // Filter by activity type (must contain one of: running, hiking, walking)
        const isAllowedActivity = allowedActivityTypeKeywords.some(keyword => 
          activityTypeLower.includes(keyword)
        )
        
        if (!isAllowedActivity) {
          console.log(`⏭️ Skipping activity type: ${activityType} (not Running/Hiking/Walking)`)
          continue
        }
        
        const activityId = activitySummary.summaryId || activitySummary.activityId
        
        if (!activityId) {
          console.log("⚠️ Activity missing ID, skipping")
          continue
        }
        
        console.log(`📦 Processing activity: ${activityId} (${activityType})`)
        console.log(`   Activity summary keys:`, Object.keys(activitySummary))
        console.log(`   Activity summary structure:`, JSON.stringify(activitySummary, null, 2))
        
        // PUSH mode: Summary is in payload, but we may need to fetch details/FIT file
        // Check if callbackUrl is provided for fetching details
        const callbackUrl = activitySummary.callbackUrl || null
        
        // Check for required fields that store function needs
        const hasActivityId = !!(activitySummary.summaryId || activitySummary.id || activitySummary.activityId)
        const hasStartTime = !!(activitySummary.startTimeInSeconds || activitySummary.startTimeGMT || activitySummary.beginTimestamp || activitySummary.summaryStartTimeInSeconds)
        
        console.log(`   ✅ Has activity ID: ${hasActivityId}`)
        console.log(`   ✅ Has start time: ${hasStartTime}`)
        console.log(`   ✅ Has callbackUrl: ${!!callbackUrl}`)
        
        if (!hasActivityId || !hasStartTime) {
          console.error(`❌ Activity missing required fields - skipping`)
          console.error(`   Missing activityId: ${!hasActivityId}`)
          console.error(`   Missing startTime: ${!hasStartTime}`)
          continue
        }
        
        // Forward to store function
        // Store function will handle samples and FIT files if callbackUrl is available
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        
        const payloadToStore = {
          summary: activitySummary, // Full summary from PUSH payload
          details: null, // Will be fetched if callbackUrl available
          garminUserId: garminUserId,
          callbackUrl: callbackUrl // For fetching details/FIT file if needed
        }
        
        console.log(`   📤 Sending to store function...`)
        console.log(`   Payload keys:`, Object.keys(payloadToStore))
        console.log(`   Summary keys in payload:`, Object.keys(payloadToStore.summary))
        
        const storeResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${supabaseKey}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify(payloadToStore)
        })
        
        if (storeResponse.ok) {
          processedCount++
          const storeResult = await storeResponse.json()
          console.log(`✅ Activity ${activityId} stored successfully`)
          console.log(`   Store result:`, JSON.stringify(storeResult, null, 2))
          
          // Check if this activity matches a pending backfill request
          // Activities from backfill requests will have summaryStartTimeInSeconds
          const activityStartTime = activitySummary.summaryStartTimeInSeconds || 
                                   activitySummary.startTimeInSeconds ||
                                   activitySummary.startTimeGMTInSeconds
          
          if (activityStartTime) {
            // Find pending backfill requests where this activity falls within the date range
            // Activity must be: start <= activity <= end
            // Use a wider range check to catch activities that might be slightly outside due to timezone issues
            const bufferSeconds = 24 * 60 * 60 // 1 day buffer for timezone issues
            const { data: matchingBackfills } = await supabase
              .from('garmin_backfill_requests')
              .select('id, summary_start_time_seconds, summary_end_time_seconds, created_at')
              .eq('user_id', connection.user_id)
              .eq('status', 'pending')
              .lte('summary_start_time_seconds', activityStartTime + bufferSeconds) // activity >= start (with buffer)
              .gte('summary_end_time_seconds', activityStartTime - bufferSeconds) // activity <= end (with buffer)
            
            console.log(`   Checking ${matchingBackfills?.length || 0} pending backfill requests for match`)
            if (matchingBackfills && matchingBackfills.length > 0) {
              console.log(`   Activity timestamp: ${activityStartTime} (${new Date(activityStartTime * 1000).toISOString()})`)
              for (const backfill of matchingBackfills) {
                console.log(`   Backfill range: ${backfill.summary_start_time_seconds} to ${backfill.summary_end_time_seconds}`)
                console.log(`   Backfill dates: ${new Date(backfill.summary_start_time_seconds * 1000).toISOString()} to ${new Date(backfill.summary_end_time_seconds * 1000).toISOString()}`)
              }
            }
            
            if (matchingBackfills && matchingBackfills.length > 0) {
              // Mark matching backfill requests as completed
              for (const backfill of matchingBackfills) {
                await supabase
                  .from('garmin_backfill_requests')
                  .update({ 
                    status: 'completed',
                    completed_at: new Date().toISOString()
                  })
                  .eq('id', backfill.id)
                
                console.log(`✅ Marked backfill request ${backfill.id} as completed (activity timestamp: ${activityStartTime})`)
              }
            }
          }
        } else {
          const errorText = await storeResponse.text()
          console.error(`❌ Store function failed for activity ${activityId}`)
          console.error(`   Status: ${storeResponse.status}`)
          console.error(`   Error: ${errorText}`)
          console.error(`   Activity summary:`, JSON.stringify(activitySummary, null, 2))
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
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      }
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
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
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
// 1. Go to Supabase Dashboard → Edge Functions → garmin-activity-push
// 2. Configure the function to allow unauthenticated requests
//    OR use the anon key in the webhook URL (not recommended for security)
//
// 1. Configure webhook in Garmin Developer Portal:
//    - URL: https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push
//    - Method: POST
//    - Events: Activity uploads (PUSH type)
//
// 2. Garmin may send PUSH for some endpoints and PING for others
//    - Configure both garmin-activity-ping AND garmin-activity-push
//
// 3. Make function public in Supabase Dashboard (required for webhooks)
//
// ============================================================================


// 1. Configure webhook in Garmin Developer Portal:
//    - URL: https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push
//    - Method: POST
//    - Events: Activity uploads (PUSH type)
//
// 2. Garmin may send PUSH for some endpoints and PING for others
//    - Configure both garmin-activity-ping AND garmin-activity-push
//
// 3. Make function public in Supabase Dashboard (required for webhooks)
//
// ============================================================================

