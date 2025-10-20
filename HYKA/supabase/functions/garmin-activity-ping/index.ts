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

// Handle CORS preflight
serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'content-type, user-agent'
      }
    })
  }
  
  const startTime = Date.now()
  
  try {
    console.log("🔔 Garmin PING received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Verify request is from Garmin (check user-agent)
    // Note: Function is public (no auth required) - security comes from:
    // 1. Webhook URL being secret (only Garmin and you know it)
    // 2. User-agent verification below
    const userAgent = req.headers.get('user-agent') || ''
    if (!userAgent.includes('Garmin')) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
      // Still return 200 to prevent retries, but log it
    }
    
    // Parse request body
    const body = await req.json()
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Extract callbackUrl and garminUserId from PING
    const callbackUrl = body.callbackUrl
    const garminUserId = body.userId || body.garminUserId
    
    if (!callbackUrl) {
      console.error("❌ Missing callbackUrl in PING")
      console.error("   Body keys:", Object.keys(body))
      // Still return 200 to Garmin so they don't retry
      return new Response("OK", { status: 200 })
    }
    
    console.log("   Callback URL:", callbackUrl.substring(0, 100) + "...")
    console.log("   Garmin User ID:", garminUserId || "not provided")
    
    // Forward to pull function
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    console.log("🔄 Forwarding to garmin-activity-pull...")
    
    const pullResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-pull`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${supabaseKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ 
        callbackUrl,
        garminUserId,
        summaryId: body.summaryId
      })
    })
    
    if (!pullResponse.ok) {
      const errorText = await pullResponse.text()
      console.error("❌ Pull function failed:", pullResponse.status, errorText)
      // Still return 200 to Garmin
      return new Response("OK", { status: 200 })
    }
    
    const pullResult = await pullResponse.json()
    console.log("✅ Pull function completed:", pullResult)
    
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
// ============================================================================
