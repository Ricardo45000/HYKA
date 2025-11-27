// ============================================================================
// Strava Activity Webhook Handler
// ============================================================================
//
// Purpose: Receives webhook notifications from Strava when activities are created
// 
// Strava sends webhook with:
// {
//   "object_type": "activity",
//   "object_id": 12345,
//   "aspect_type": "create",
//   "updates": {},
//   "owner_id": 67890,
//   "subscription_id": 1,
//   "event_time": 1234567890
// }
//
// Flow:
// 1. Receive webhook from Strava
// 2. Verify webhook (optional - can verify signature)
// 3. Extract activity ID and athlete ID
// 4. Fetch activity details from Strava API
// 5. Forward to strava-activity-store function
// 6. Return 200 OK to Strava
//
// Reference: Strava API v3 Webhooks
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
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      },
    })
  }
  
  // Handle Strava webhook verification (GET request)
  if (req.method === 'GET') {
    const url = new URL(req.url)
    const mode = url.searchParams.get('hub.mode')
    const token = url.searchParams.get('hub.verify_token')
    const challenge = url.searchParams.get('hub.challenge')
    
    // Verify token (should match your configured token)
    const verifyToken = Deno.env.get('STRAVA_WEBHOOK_VERIFY_TOKEN') || 'strava-webhook-verify-token'
    
    if (mode === 'subscribe' && token === verifyToken) {
      console.log("✅ Strava webhook verification successful")
      return new Response(JSON.stringify({
        'hub.challenge': challenge
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    } else {
      console.log("❌ Strava webhook verification failed")
      return new Response(JSON.stringify({ error: "Verification failed" }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }
  
  try {
    console.log("🔔 Strava Activity Webhook received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Parse request body
    let body: any
    try {
      const contentType = req.headers.get('content-type') || ''
      if (contentType.includes('application/json')) {
        body = await req.json()
      } else {
        const text = await req.text()
        body = text ? JSON.parse(text) : {}
      }
    } catch (parseError) {
      console.error("❌ Error parsing request body:", parseError)
      // Return 200 to prevent Strava from retrying
      return new Response("OK", { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    
    console.log("   Body keys:", Object.keys(body))
    console.log("   Full body:", JSON.stringify(body, null, 2))
    
    // Extract webhook data
    const objectType = body.object_type
    const objectId = body.object_id
    const aspectType = body.aspect_type
    const ownerId = body.owner_id
    
    // Only process activity creation events
    if (objectType !== 'activity' || aspectType !== 'create') {
      console.log(`ℹ️ Ignoring webhook: object_type=${objectType}, aspect_type=${aspectType}`)
      return new Response("OK", { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    
    if (!objectId || !ownerId) {
      console.error("❌ Missing object_id or owner_id in webhook")
      return new Response("OK", { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    
    console.log("   Activity ID:", objectId)
    console.log("   Athlete ID:", ownerId)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Find user by Strava athlete ID
    const { data: connection, error: connectionError } = await supabase
      .from('strava_connections')
      .select('user_id, access_token, refresh_token, token_expires_at')
      .eq('strava_athlete_id', ownerId)
      .eq('permission_revoked', false)
      .single()
    
    if (connectionError || !connection) {
      console.error("❌ No active connection found for athlete:", ownerId)
      return new Response("OK", { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    
    console.log("✅ Found connection for user:", connection.user_id)
    
    // Check if token needs refresh
    let accessToken = connection.access_token
    const tokenExpiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
    const now = new Date()
    
    if (tokenExpiresAt && tokenExpiresAt <= now) {
      console.log("🔄 Token expired, refreshing...")
      // Refresh token logic would go here
      // For now, we'll use the existing token and let the store function handle refresh
    }
    
    // Fetch activity details from Strava API
    console.log("🔄 Fetching activity details from Strava...")
    const activityUrl = `https://www.strava.com/api/v3/activities/${objectId}`
    
    const activityResponse = await fetch(activityUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })
    
    if (!activityResponse.ok) {
      const errorText = await activityResponse.text()
      console.error("❌ Failed to fetch activity:", activityResponse.status, errorText)
      
      // If 401, token might be expired - try refresh
      if (activityResponse.status === 401) {
        console.log("🔄 Token expired, attempting refresh...")
        // Token refresh logic would go here
        // For now, return OK to prevent retries
      }
      
      return new Response("OK", { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    
    const activityData = await activityResponse.json()
    console.log("✅ Activity fetched:", activityData.id)
    console.log("   Type:", activityData.type, activityData.sport_type)
    
    // Filter activities: only process Run, TrailRun, Walk, Hike
    const allowedTypes = ['Run', 'TrailRun', 'Walk', 'Hike']
    if (!allowedTypes.includes(activityData.type) && !allowedTypes.includes(activityData.sport_type)) {
      console.log(`ℹ️ Skipping activity type: ${activityData.type}/${activityData.sport_type}`)
      return new Response("OK", { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    
    // Forward to store function
    console.log("🔄 Forwarding to store function...")
    const storeUrl = `${supabaseUrl}/functions/v1/strava-activity-store`
    
    fetch(storeUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseKey}`,
        'apikey': supabaseKey
      },
      body: JSON.stringify({
        activity: activityData,
        userId: connection.user_id,
        stravaAthleteId: ownerId
      })
    }).then(response => {
      if (!response.ok) {
        console.error(`⚠️ Store function returned ${response.status}`)
      } else {
        console.log("✅ Activity forwarded to store function")
      }
    }).catch(error => {
      console.error("❌ Error forwarding to store function:", error)
    })
    
    // Return 200 OK immediately to Strava
    return new Response("OK", { 
      status: 200,
      headers: { 'Content-Type': 'text/plain' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in webhook handler:", error)
    console.error("   Duration:", `${duration}ms`)
    
    // Return 200 to prevent Strava from retrying
    return new Response("OK", { 
      status: 200,
      headers: { 'Content-Type': 'text/plain' }
    })
  }
})

