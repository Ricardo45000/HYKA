import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }

  try {
    console.log("📥 Strava Activity Webhook started")
    
    // Strava webhook verification (GET request)
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const mode = url.searchParams.get('hub.mode')
      const token = url.searchParams.get('hub.verify_token')
      const challenge = url.searchParams.get('hub.challenge')

      const verifyToken = Deno.env.get('STRAVA_WEBHOOK_VERIFY_TOKEN') || 'strava-webhook-verify-token-2025'

      if (mode === 'subscribe' && token === verifyToken) {
        console.log("✅ Strava webhook verified")
        return new Response(JSON.stringify({
          'hub.challenge': challenge
        }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        })
      } else {
        console.error("❌ Strava webhook verification failed")
        return new Response(JSON.stringify({
          error: "Verification failed"
        }), {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        })
      }
    }

    // Handle webhook event (POST request)
    const body = await req.json()
    const objectType = body.object_type
    const objectId = body.object_id
    const aspectType = body.aspect_type
    const ownerId = body.owner_id

    console.log("📨 Webhook event:", {
      object_type: objectType,
      object_id: objectId,
      aspect_type: aspectType,
      owner_id: ownerId
    })

    // Only process activity creation/updates
    if (objectType !== 'activity' || aspectType !== 'create') {
      console.log("⏭️ Skipping event (not activity creation)")
      return new Response(JSON.stringify({
        success: true,
        message: "Event skipped"
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Find user by Strava athlete ID
    const { data: connection, error: connError } = await supabase
      .from('strava_connections')
      .select('user_id, access_token, refresh_token, token_expires_at')
      .eq('strava_athlete_id', ownerId.toString())
      .single()

    if (connError || !connection) {
      console.error("❌ Strava connection not found for athlete:", ownerId)
      return new Response(JSON.stringify({
        success: false,
        error: "Connection not found"
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }

    // Check if token needs refresh
    let accessToken = connection.access_token
    if (!accessToken) {
      throw new Error("Strava access token is missing or null")
    }

    const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
    if (expiresAt && expiresAt <= new Date()) {
      console.log("🔄 Token expired, need to refresh (TODO)")
      // TODO: Implement token refresh
    }

    // Fetch activity from Strava API
    // ⚠️ CRITICAL: Must include Authorization header!
    const stravaResponse = await fetch(`https://www.strava.com/api/v3/activities/${objectId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,  // ✅ REQUIRED!
        'Accept': 'application/json'
      }
    })

    if (!stravaResponse.ok) {
      const errorText = await stravaResponse.text()
      console.error("❌ Strava API error:", stravaResponse.status, errorText)
      throw new Error(`Strava API error: ${stravaResponse.status} - ${errorText}`)
    }

    const activity = await stravaResponse.json()

    // Store activity in database
    const { error: storeError } = await supabase
      .from('strava_activities')
      .upsert({
        user_id: connection.user_id,
        strava_activity_id: activity.id.toString(),
        activity_name: activity.name,
        activity_type: activity.type,
        start_date: activity.start_date,
        elapsed_time: activity.elapsed_time,
        distance_meters: activity.distance,
        total_elevation_gain_meters: activity.total_elevation_gain,
        average_heart_rate: activity.average_heartrate,
        max_heart_rate: activity.max_heartrate,
        average_speed_mps: activity.average_speed,
        max_speed_mps: activity.max_speed,
        calories: activity.calories,
        average_cadence: activity.average_cadence,
        device_name: activity.device_name,
        raw_summary: activity,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,strava_activity_id'
      })

    if (storeError) {
      throw new Error(`Failed to store activity: ${storeError.message}`)
    }

    console.log("✅ Activity stored from webhook:", objectId)

    return new Response(JSON.stringify({
      success: true,
      activity_id: objectId
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error("❌ Error in Strava webhook:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
})


