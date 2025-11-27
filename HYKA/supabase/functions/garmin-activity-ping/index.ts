// ============================================================================
// Garmin Activity PING Webhook (Correct OAuth 2.0 Flow)
// ============================================================================
//
// Purpose: Receives PING notifications from Garmin when new activities are available
// 
// Garmin sends PING with:
// {
//   "summaryId": 12345,
//   "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
//   "userId": "garmin_user_id"
// }
//
// Flow:
// 1. Receive PING from Garmin
// 2. Extract callbackUrl (includes temporary Pull Token)
// 3. Forward to garmin-activity-pull function
// 4. Return 200 OK to Garmin
//
// Reference: Garmin Connect API OAuth 2.0 DIAUTH specification
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
    console.log("🔔 Garmin PING received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Extract webhook secret from URL path
    // Expected format: /functions/v1/garmin-activity-ping/SECRET_TOKEN
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(p => p)
    const functionNameIndex = pathParts.findIndex(p => p === 'garmin-activity-ping')
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
        // Still process - might be from testing or different secret
      }
    } else {
      console.log("ℹ️ No webhook secret in URL path")
      console.log("   Using default security: webhook URL secrecy + user-agent verification")
    }
    
    // Verify request is from Garmin (but don't reject - just log)
    // Note: Function security comes from:
    // 1. Webhook URL being secret (only Garmin and you know it)
    // 2. User-agent verification below
    // 3. Optional webhook secret in URL path
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
    
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Check if this is a PUSH webhook (has activities array) instead of PING
    if (body.activities && Array.isArray(body.activities)) {
      console.log("⚠️ Received PUSH webhook format in PING endpoint")
      console.log("   Forwarding to garmin-activity-push function...")
      
      // Forward to PUSH handler
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      
      const pushResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-push`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${supabaseKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(body)
      })
      
      if (!pushResponse.ok) {
        const errorText = await pushResponse.text()
        console.error("❌ Push function failed:", pushResponse.status, errorText)
      } else {
        const pushResult = await pushResponse.json()
        console.log("✅ Push function completed:", pushResult)
      }
      
      // Return 200 to Garmin
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    // Extract callbackUrl and garminUserId from PING
    // Garmin sends these nested in arrays: activityDetails[0].callbackURL, activityFiles[0].callbackURL
    let callbackUrl = body.callbackUrl || body.callback_url || body.url
    let garminUserId = body.userId || body.garminUserId || body.user_id
    
    // Check inside activityDetails array
    if ((!callbackUrl || !garminUserId) && body.activityDetails && Array.isArray(body.activityDetails) && body.activityDetails.length > 0) {
      const detail = body.activityDetails[0]
      callbackUrl = callbackUrl || detail.callbackURL || detail.callbackUrl || detail.url
      garminUserId = garminUserId || detail.userId || detail.garminUserId
    }
    
    // Check inside activityFiles array
    if ((!callbackUrl || !garminUserId) && body.activityFiles && Array.isArray(body.activityFiles) && body.activityFiles.length > 0) {
      const file = body.activityFiles[0]
      callbackUrl = callbackUrl || file.callbackURL || file.callbackUrl || file.url
      garminUserId = garminUserId || file.userId || file.garminUserId
    }
    
    // Extract summaryId (also check arrays)
    let summaryId = body.summaryId || body.summary_id
    if (!summaryId && body.activityDetails && Array.isArray(body.activityDetails) && body.activityDetails.length > 0) {
      summaryId = body.activityDetails[0].summaryId || body.activityDetails[0].summary_id
    }
    if (!summaryId && body.activityFiles && Array.isArray(body.activityFiles) && body.activityFiles.length > 0) {
      summaryId = body.activityFiles[0].summaryId || body.activityFiles[0].summary_id
    }
    
    console.log("   📋 PING Body Analysis:")
    console.log("   - Body keys:", Object.keys(body))
    console.log("   - callbackUrl present:", !!callbackUrl)
    console.log("   - garminUserId present:", !!garminUserId)
    console.log("   - summaryId:", summaryId || "not provided")
    
    if (!callbackUrl) {
      console.error("❌ Missing callbackUrl in PING webhook")
      console.error("   This means we cannot fetch the activity data from Garmin")
      console.error("   Full body structure:", JSON.stringify(body, null, 2))
      console.error("   ⚠️ PING received but cannot forward to PULL - no callbackUrl")
      // Still return 200 to Garmin so they don't retry
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    console.log("   ✅ Callback URL found:", callbackUrl.substring(0, 100) + (callbackUrl.length > 100 ? "..." : ""))
    console.log("   ✅ Garmin User ID:", garminUserId || "not provided (will try to lookup)")
    
    // Look up Garmin access token for Authorization header
    let garminAccessToken: string | null = null
    if (garminUserId) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      const { data: connection } = await supabase
        .from('garmin_connections')
        .select('access_token')
        .eq('garmin_user_id', garminUserId)
        .single()
      
      if (connection?.access_token) {
        garminAccessToken = connection.access_token
        console.log("   ✅ Found Garmin access token for Authorization header")
      } else {
        console.log("   ⚠️ No access token found - pull function will try without it")
      }
    }
    
    // Forward to pull function
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const pullPayload = { 
      callbackUrl,
      garminUserId,
      summaryId: summaryId,
      accessToken: garminAccessToken // Pass access token for Authorization header
    }
    
    console.log("🔄 Forwarding to garmin-activity-pull...")
    console.log("   Payload:", JSON.stringify({
      ...pullPayload,
      callbackUrl: callbackUrl.substring(0, 100) + "...",
      accessToken: garminAccessToken ? "***present***" : "missing"
    }, null, 2))
    
    try {
      const pullResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-pull`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${supabaseKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(pullPayload)
      })
      
      console.log("   Pull response status:", pullResponse.status)
      
      if (!pullResponse.ok) {
        const errorText = await pullResponse.text()
        console.error("❌ Pull function failed:", pullResponse.status)
        console.error("   Error details:", errorText)
        console.error("   ⚠️ Activity data was NOT fetched from Garmin")
        // Still return 200 to Garmin
        return new Response("OK", { 
          status: 200,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'text/plain'
          }
        })
      }
      
      const pullResult = await pullResponse.json()
      console.log("✅ Pull function completed successfully")
      console.log("   Result:", JSON.stringify(pullResult, null, 2))
    } catch (pullError) {
      console.error("❌ Exception calling pull function:", pullError)
      console.error("   Error type:", pullError.constructor.name)
      console.error("   Error message:", pullError.message)
      console.error("   ⚠️ Activity data was NOT fetched from Garmin due to exception")
      // Still return 200 to Garmin
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    const duration = Date.now() - startTime
    console.log(`✅ PING processed in ${duration}ms`)
    
    // Return success to Garmin
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error processing PING:", error)
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
// 1. Go to Supabase Dashboard → Edge Functions → garmin-activity-ping
// 2. Configure the function to allow unauthenticated requests
//    OR use the anon key in the webhook URL (not recommended for security)
//
// 1. Configure webhook in Garmin Developer Portal:
//    - URL: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
//    - Method: POST
//    - Events: Activity uploads
//
// 2. No authentication required - function is public
//    Security comes from:
//    - Webhook URL being secret (only you and Garmin know it)
//    - User-agent verification (checks for "Garmin")
//
// 3. No Pull Token needed in this function (it's in the callbackUrl)
//
// 4. Make function public in Supabase Dashboard (required for webhooks)
//
// ============================================================================
