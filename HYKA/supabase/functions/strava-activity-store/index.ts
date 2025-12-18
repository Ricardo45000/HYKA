import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Strava Activity Store
 * 
 * Fetches activity from Strava API including:
 * 1. Activity summary data
 * 2. Activity streams (GPS, HR, cadence, temperature, etc.)
 * 
 * Stores:
 * - Activity summary in strava_activities table
 * - Time-series samples in strava_activity_samples table
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

  try {
    console.log("📥 Strava Activity Store started")
    
    const body = await req.json()
    console.log("📋 Request body:", JSON.stringify(body, null, 2))
    
    // Support both formats:
    // 1. Direct format: { user_id, activity_id }
    // 2. Webhook format: { object_id, owner_id, ... } (from historical sync or webhook)
    let userId = body.user_id
    let activityId = body.activity_id || body.object_id
    
    // If webhook format, we need to find user_id from strava_athlete_id
    if (!userId && body.owner_id) {
      console.log("🔍 Webhook format detected, looking up user by Strava athlete ID:", body.owner_id)
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      const { data: connection, error: connError } = await supabase
        .from('strava_connections')
        .select('user_id')
        .eq('strava_athlete_id', body.owner_id.toString())
        .single()
      
      if (connError || !connection) {
        console.error("❌ Could not find user for Strava athlete ID:", body.owner_id)
        return new Response(JSON.stringify({
          error: `Strava connection not found for athlete ID: ${body.owner_id}`
        }), {
          status: 404,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        })
      }
      
      userId = connection.user_id
      console.log("✅ Found user_id:", userId)
    }

    if (!userId || !activityId) {
      return new Response(JSON.stringify({
        error: "Missing user_id or activity_id. Received: " + JSON.stringify({ userId: !!userId, activityId: !!activityId, bodyKeys: Object.keys(body) })
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }
    
    console.log("✅ Using user_id:", userId, "activity_id:", activityId)

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
    let refreshToken = connection.refresh_token
    
    if (!accessToken) {
      throw new Error("Strava access token is missing or null")
    }
    
    // Refresh token if expired or expiring soon (within 5 minutes)
    const needsRefresh = expiresAt && (expiresAt <= new Date(Date.now() + 5 * 60 * 1000))
    
    if (needsRefresh && refreshToken) {
      console.log("🔄 Refreshing Strava token (expires at:", expiresAt?.toISOString(), ")...")
      
      try {
        const clientId = Deno.env.get('STRAVA_CLIENT_ID')
        const clientSecret = Deno.env.get('STRAVA_CLIENT_SECRET')
        
        if (!clientId || !clientSecret) {
          console.error("❌ STRAVA_CLIENT_ID or STRAVA_CLIENT_SECRET not set, cannot refresh token")
          throw new Error("Server configuration error: Strava credentials not set")
        }
        
        const refreshParams = new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: "refresh_token",
          refresh_token: refreshToken
        })
        
        const refreshResponse = await fetch("https://www.strava.com/oauth/token", {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json'
          },
          body: refreshParams.toString()
        })
        
        if (!refreshResponse.ok) {
          const errorText = await refreshResponse.text()
          console.error("❌ Token refresh failed:", refreshResponse.status, errorText)
          throw new Error(`Token refresh failed: ${refreshResponse.status} - ${errorText}`)
        }
        
        const refreshData = await refreshResponse.json()
        accessToken = refreshData.access_token
        refreshToken = refreshData.refresh_token || refreshToken // Keep old refresh token if new one not provided
        const newExpiresAt = refreshData.expires_at 
          ? new Date(refreshData.expires_at * 1000).toISOString()
          : null
        
        console.log("✅ Token refreshed successfully")
        console.log("   New expires at:", newExpiresAt)
        
        // Update connection in database with new tokens
        const { error: updateError } = await supabase
          .from('strava_connections')
          .update({
            access_token: accessToken,
            refresh_token: refreshToken,
            token_expires_at: newExpiresAt,
            updated_at: new Date().toISOString()
          })
          .eq('user_id', userId)
        
        if (updateError) {
          console.error("⚠️ Failed to update connection with new tokens:", updateError)
          // Continue anyway - we have the new token in memory
        } else {
          console.log("✅ Connection updated with new tokens")
        }
      } catch (refreshError) {
        console.error("❌ Error refreshing token:", refreshError)
        // If refresh fails, try with old token anyway (might still work)
        console.log("⚠️ Attempting to use existing token despite refresh failure")
      }
    }

    console.log("🔑 Using access token:", accessToken ? `${accessToken.substring(0, 20)}...` : "MISSING")

    // Helper function to fetch activity from Strava API
    async function fetchActivity(token: string): Promise<Response> {
      return fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      })
    }

    // Fetch activity from Strava API
    let stravaResponse = await fetchActivity(accessToken)
    
    console.log("📤 Strava API request:", {
      url: `https://www.strava.com/api/v3/activities/${activityId}`,
      hasAuthHeader: !!accessToken,
      status: stravaResponse.status
    })

    // If 401 and we have a refresh token, try refreshing and retry once
    if (stravaResponse.status === 401 && refreshToken) {
      console.log("🔄 Got 401, attempting token refresh and retry...")
      
      try {
        const clientId = Deno.env.get('STRAVA_CLIENT_ID')
        const clientSecret = Deno.env.get('STRAVA_CLIENT_SECRET')
        
        if (!clientId || !clientSecret) {
          throw new Error("Strava credentials not configured for token refresh")
        }
        
        const refreshParams = new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: "refresh_token",
          refresh_token: refreshToken
        })
        
        const refreshResponse = await fetch("https://www.strava.com/oauth/token", {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json'
          },
          body: refreshParams.toString()
        })
        
        if (!refreshResponse.ok) {
          const errorText = await refreshResponse.text()
          throw new Error(`Token refresh failed: ${refreshResponse.status} - ${errorText}`)
        }
        
        const refreshData = await refreshResponse.json()
        accessToken = refreshData.access_token
        refreshToken = refreshData.refresh_token || refreshToken
        const newExpiresAt = refreshData.expires_at 
          ? new Date(refreshData.expires_at * 1000).toISOString()
          : null
        
        console.log("✅ Token refreshed successfully")
        console.log("   New expires at:", newExpiresAt)
        
        // Update connection in database
        await supabase
          .from('strava_connections')
          .update({
            access_token: accessToken,
            refresh_token: refreshToken,
            token_expires_at: newExpiresAt,
            updated_at: new Date().toISOString()
          })
          .eq('user_id', userId)
        
        console.log("✅ Connection updated with new tokens, retrying API request...")
        
        // Retry the original request with new token
        stravaResponse = await fetchActivity(accessToken)
        console.log("📤 Retry Strava API request status:", stravaResponse.status)
      } catch (retryError) {
        console.error("❌ Retry after refresh failed:", retryError)
        // Fall through to throw the original error
      }
    }

    if (!stravaResponse.ok) {
      const errorText = await stravaResponse.text()
      console.error("❌ Strava API error:", stravaResponse.status, errorText)
      throw new Error(`Strava API error: ${stravaResponse.status} - ${errorText}`)
    }

    const activity = await stravaResponse.json()
    
    // Log heart rate data for debugging
    console.log("📊 Strava activity heart rate data:", {
      average_heartrate: activity.average_heartrate,
      max_heartrate: activity.max_heartrate,
      has_heartrate: !!activity.average_heartrate || !!activity.max_heartrate
    })

    // Check if this is a new activity or an update
    const { data: existingActivity } = await supabase
      .from('strava_activities')
      .select('id, created_at, updated_at')
      .eq('user_id', userId)
      .eq('strava_activity_id', activity.id.toString())
      .single()
    
    const isNewActivity = !existingActivity
    const now = new Date().toISOString()
    
    if (isNewActivity) {
      console.log("🆕 Storing new activity:", activityId)
    } else {
      const lastUpdated = new Date(existingActivity.updated_at).getTime()
      const timeSinceUpdate = Date.now() - lastUpdated
      console.log("🔄 Updating existing activity:", activityId)
      console.log(`   Last updated: ${existingActivity.updated_at} (${Math.round(timeSinceUpdate / 1000)}s ago)`)
    }

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
        updated_at: now,
        ...(isNewActivity && { created_at: now })
      }, {
        onConflict: 'user_id,strava_activity_id'
      })

    if (storeError) {
      throw new Error(`Failed to store activity: ${storeError.message}`)
    }

    // Get the stored activity ID for samples
    const { data: storedActivity } = await supabase
      .from('strava_activities')
      .select('id')
      .eq('user_id', userId)
      .eq('strava_activity_id', activity.id.toString())
      .single()

    console.log("✅ Activity stored:", activityId, "DB ID:", storedActivity?.id)

    // ========================================================================
    // Fetch Activity Streams (GPS, HR, Cadence, Temperature, etc.)
    // ========================================================================
    if (storedActivity?.id) {
      try {
        console.log("📊 Fetching activity streams from Strava...")
        
        // Request all available stream types
        const streamTypes = [
          'time',           // Time in seconds
          'latlng',         // GPS coordinates
          'altitude',       // Elevation
          'heartrate',      // Heart rate
          'cadence',        // Steps/pedal cadence
          'temp',           // Temperature
          'watts',          // Power (cycling)
          'velocity_smooth' // Speed
        ].join(',')
        
        const streamsUrl = `https://www.strava.com/api/v3/activities/${activityId}/streams?keys=${streamTypes}&key_by_type=true`
        
        const streamsResponse = await fetch(streamsUrl, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/json'
          }
        })
        
        if (streamsResponse.ok) {
          const streams = await streamsResponse.json()
          console.log("✅ Streams fetched, available types:", Object.keys(streams))
          
          // Get the base timestamp from activity start
          const activityStartTime = activity.start_date 
            ? Math.floor(new Date(activity.start_date).getTime() / 1000)
            : null
          
          // Extract stream data
          const timeStream = streams.time?.data || []
          const latlngStream = streams.latlng?.data || []
          const altitudeStream = streams.altitude?.data || []
          const heartrateStream = streams.heartrate?.data || []
          const cadenceStream = streams.cadence?.data || []
          const tempStream = streams.temp?.data || []
          const speedStream = streams.velocity_smooth?.data || []
          
          console.log(`   📈 Stream lengths: time=${timeStream.length}, latlng=${latlngStream.length}, hr=${heartrateStream.length}`)
          
          // Build samples array (time stream is the index)
          if (timeStream.length > 0 && activityStartTime) {
            const samples = timeStream.map((seconds: number, index: number) => {
              const timestampSeconds = activityStartTime + seconds
              const latlng = latlngStream[index] || null
              
              return {
                activity_id: storedActivity.id,
                timestamp_seconds: timestampSeconds,
                sample_time: new Date(timestampSeconds * 1000).toISOString(),
                latitude: latlng ? latlng[0] : null,
                longitude: latlng ? latlng[1] : null,
                elevation_meters: altitudeStream[index] ?? null,
                heart_rate: heartrateStream[index] ?? null,
                speed_mps: speedStream[index] ?? null,
                steps_per_minute: cadenceStream[index] ? cadenceStream[index] * 2 : null, // Strava cadence is per leg for running
                air_temperature_celsius: tempStream[index] ?? null
              }
            })
            
            console.log(`   💾 Preparing ${samples.length} samples for insertion...`)
            
            // Delete existing samples first to avoid duplicates on re-sync
            await supabase
              .from('strava_activity_samples')
              .delete()
              .eq('activity_id', storedActivity.id)
            
            // Insert samples in batches
            const batchSize = 1000
            let insertedCount = 0
            
            for (let i = 0; i < samples.length; i += batchSize) {
              const batch = samples.slice(i, i + batchSize)
              const { error: insertError } = await supabase
                .from('strava_activity_samples')
                .insert(batch)
              
              if (insertError) {
                console.error(`   ❌ Error inserting batch ${Math.floor(i/batchSize) + 1}:`, insertError.message)
              } else {
                insertedCount += batch.length
              }
            }
            
            console.log(`   ✅ Inserted ${insertedCount}/${samples.length} samples`)
            
            // Update activity to mark it has samples
            await supabase
              .from('strava_activities')
              .update({ has_fit_file: true, updated_at: now })
              .eq('id', storedActivity.id)
          } else {
            console.log("   ⚠️ No time stream data available")
          }
        } else {
          const errorText = await streamsResponse.text()
          console.warn(`   ⚠️ Could not fetch streams: ${streamsResponse.status} - ${errorText}`)
        }
      } catch (streamsError) {
        console.error("   ❌ Error fetching streams:", streamsError)
        // Continue - streams are optional
      }
    }

    // Trigger Notification - Only for new activities or if activity was updated more than 5 minutes ago
    // This prevents duplicate notifications from multiple webhook events
    let shouldNotify = false
    if (isNewActivity) {
      shouldNotify = true
      console.log("🔔 Triggering notification for NEW activity")
    } else {
      const lastUpdated = new Date(existingActivity.updated_at).getTime()
      const timeSinceUpdate = Date.now() - lastUpdated
      const fiveMinutes = 5 * 60 * 1000
      
      // Only notify if activity was last updated more than 5 minutes ago
      // This handles legitimate updates (e.g., user edits activity on Strava)
      if (timeSinceUpdate > fiveMinutes) {
        shouldNotify = true
        console.log("🔔 Triggering notification for UPDATED activity (last update was >5min ago)")
      } else {
        console.log(`⏭️ Skipping notification - activity was recently updated (${Math.round(timeSinceUpdate / 1000)}s ago)`)
        console.log("   This prevents duplicate notifications from multiple webhook events")
      }
    }

    if (shouldNotify) {
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
    }

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

