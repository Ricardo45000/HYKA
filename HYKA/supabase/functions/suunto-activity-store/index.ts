import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Suunto Activity Store
 * 
 * Fetches a specific workout from Suunto API and stores it in Supabase.
 * Can be called manually or triggered by webhooks.
 * 
 * POST body:
 * {
 *   "user_id": "uuid",           // Supabase user ID
 *   "activity_id": "string"      // Suunto workout ID
 * }
 */

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

  const startTime = Date.now()

  try {
    console.log("📥 Suunto Activity Store started")
    
    const body = await req.json()
    const userId = body.user_id
    const activityId = body.activity_id || body.workout_id

    if (!userId || !activityId) {
      return new Response(JSON.stringify({
        error: "Missing user_id or activity_id"
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }

    console.log("📋 Request:", { userId, activityId })

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get Suunto connection
    const { data: connection, error: connError } = await supabase
      .from('suunto_connections')
      .select('access_token, refresh_token, token_expires_at, suunto_user_id')
      .eq('user_id', userId)
      .single()

    if (connError || !connection) {
      throw new Error(`Suunto connection not found: ${connError?.message}`)
    }

    // Get subscription key for Suunto API
    const subscriptionKey = Deno.env.get('SUUNTO_SUBSCRIPTION_KEY') || '8e6bcafebd494d7c94df5cf7d5154fde'

    // Check if token needs refresh
    let accessToken = connection.access_token
    const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
    
    if (!accessToken) {
      throw new Error("Suunto access token is missing or null")
    }
    
    if (expiresAt && expiresAt <= new Date()) {
      console.log("🔄 Token expired, attempting to refresh...")
      // TODO: Implement token refresh using refresh_token
      // For now, try with existing token (may fail)
    }

    console.log("🔑 Using access token:", accessToken.substring(0, 20) + "...")
    console.log("🔑 Using subscription key:", subscriptionKey.substring(0, 10) + "...")

    // Fetch activity from Suunto API
    const suuntoResponse = await fetch(`https://cloudapi.suunto.com/v2/workouts/${activityId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json',
        'Ocp-Apim-Subscription-Key': subscriptionKey
      }
    })
    
    console.log("📤 Suunto API request:", {
      url: `https://cloudapi.suunto.com/v2/workouts/${activityId}`,
      status: suuntoResponse.status
    })

    if (!suuntoResponse.ok) {
      const errorText = await suuntoResponse.text()
      console.error("❌ Suunto API error:", suuntoResponse.status, errorText)
      throw new Error(`Suunto API error: ${suuntoResponse.status} - ${errorText}`)
    }

    const workout = await suuntoResponse.json()
    console.log("✅ Fetched workout:", workout.id || activityId)

    // Store activity in database
    const { data: storedActivity, error: storeError } = await supabase
      .from('suunto_activities')
      .upsert({
        user_id: userId,
        suunto_activity_id: activityId,
        activity_name: workout.name || workout.workoutName,
        activity_type: workout.activityType || workout.sport,
        sport_type: workout.sport,
        start_time: workout.startTime || workout.start_time,
        start_time_local: workout.localStartTime || workout.local_start_time,
        duration_seconds: workout.duration || workout.totalTime,
        moving_seconds: workout.movingTime || workout.moving_time,
        distance_meters: workout.totalDistance || workout.distance,
        total_elevation_gain_meters: workout.totalAscent || workout.elevation_gain,
        total_elevation_loss_meters: workout.totalDescent || workout.elevation_loss,
        average_heart_rate: workout.avgHR || workout.average_heart_rate,
        max_heart_rate: workout.maxHR || workout.max_heart_rate,
        average_speed_mps: workout.avgSpeed || workout.average_speed,
        max_speed_mps: workout.maxSpeed || workout.max_speed,
        calories: workout.calories || workout.totalCalories,
        steps: workout.steps,
        average_cadence: workout.avgCadence || workout.average_cadence,
        max_cadence: workout.maxCadence || workout.max_cadence,
        device_name: workout.deviceName || workout.device_name,
        raw_summary: workout,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,suunto_activity_id'
      })
      .select('id')
      .single()

    if (storeError || !storedActivity) {
      throw new Error(`Failed to store activity: ${storeError?.message}`)
    }

    // ------------------------------------------------------------------------
    // Fetch & Store FIT File
    // ------------------------------------------------------------------------
    try {
        console.log("📥 Fetching FIT file from Suunto...")
        const fitUrl = `https://cloudapi.suunto.com/v2/workouts/${activityId}/export?format=fit`
        
        const fitResponse = await fetch(fitUrl, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Ocp-Apim-Subscription-Key': subscriptionKey
            }
        })
        
        if (fitResponse.ok) {
            const arrayBuffer = await fitResponse.arrayBuffer()
            const fileData = Array.from(new Uint8Array(arrayBuffer))
            
            if (fileData.length > 0) {
                console.log(`✅ Downloaded FIT file: ${fileData.length} bytes`)
                
                const { error: fileError } = await supabase
                    .from('suunto_fit_files')
                    .upsert({
                        activity_id: storedActivity.id,
                        file_data: fileData,
                        file_format: 'fit',
                        file_size: fileData.length,
                        created_at: new Date().toISOString()
                    }, { onConflict: 'activity_id' })
                    
                if (fileError) console.error("❌ Failed to store FIT file:", fileError)
                else console.log("💾 FIT file stored in suunto_fit_files")
            }
        } else {
            console.warn(`⚠️ Failed to download FIT file: ${fitResponse.status}`)
        }
    } catch (fileErr) {
        console.error("❌ Error fetching/storing FIT file:", fileErr)
    }

    const duration = Date.now() - startTime
    console.log(`✅ Activity stored: ${activityId} (${duration}ms)`)

    // Trigger Notification
    console.log("🔔 Triggering notification...")
    const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
    const notifyPayload = {
        user_id: userId,
        activity_id: activityId,
        activity_name: workout.name || workout.workoutName,
        activity_type: workout.activityType || workout.sport,
        distance_meters: workout.totalDistance || workout.distance,
        duration_seconds: workout.duration || workout.totalTime
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
      activity_id: activityId,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in Suunto activity store:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
})

