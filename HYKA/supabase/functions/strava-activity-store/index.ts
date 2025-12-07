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
    console.log("📥 Strava Activity Store started")
    
    const body = await req.json()
    const userId = body.user_id
    const activityId = body.activity_id

    if (!userId || !activityId) {
      return new Response(JSON.stringify({
        error: "Missing user_id or activity_id"
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get Strava connection
    const { data: connection, error: connError } = await supabase
      .from('strava_connections')
      .select('access_token, refresh_token, token_expires_at')
      .eq('user_id', userId)
      .single()

    if (connError || !connection) {
      throw new Error(`Strava connection not found: ${connError?.message}`)
    }

    // Check if token needs refresh
    let accessToken = connection.access_token
    const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
    
    if (!accessToken) {
      throw new Error("Strava access token is missing or null")
    }
    
    if (expiresAt && expiresAt <= new Date()) {
      console.log("🔄 Refreshing Strava token...")
      // TODO: Implement token refresh
      // accessToken = await refreshStravaToken(connection.refresh_token)
    }

    console.log("🔑 Using access token:", accessToken ? `${accessToken.substring(0, 20)}...` : "MISSING")

    // Fetch activity from Strava API
    // ⚠️ CRITICAL: Must include Authorization header!
    const stravaResponse = await fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,  // ✅ REQUIRED!
        'Accept': 'application/json'
      }
    })
    
    console.log("📤 Strava API request:", {
      url: `https://www.strava.com/api/v3/activities/${activityId}`,
      hasAuthHeader: !!accessToken,
      status: stravaResponse.status
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
        user_id: userId,
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

    console.log("✅ Activity stored:", activityId)

    // Trigger Notification
    console.log("🔔 Triggering notification...")
    // Using garmin-activity-notify as generic notifier for now
    const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
    const notifyPayload = {
        user_id: userId,
        activity_id: activity.id.toString(),
        activity_name: activity.name,
        activity_type: activity.type,
        distance_meters: activity.distance,
        duration_seconds: activity.moving_time || activity.elapsed_time
    }

    fetch(notifyUrl, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(notifyPayload)
    }).then(async (res) => {
        if (res.ok) {
            console.log(`✅ Notification triggered successfully: ${res.status}`)
        } else {
            const text = await res.text()
            console.error(`❌ Notification trigger failed: ${res.status} - ${text}`)
        }
    }).catch(err => {
        console.error("❌ Error calling notification function:", err)
    })

    return new Response(JSON.stringify({
      success: true,
      activity_id: activityId
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error("❌ Error in Strava activity store:", error)
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

