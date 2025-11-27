// ============================================================================
// Strava Activity Store
// ============================================================================
//
// Purpose: Store activity data in Supabase database
//
// Flow:
// 1. Receive activity data from webhook handler
// 2. Find HYKA user from stravaAthleteId
// 3. Store activity in strava_activities table
// 4. Fetch and store activity streams (samples) if available
// 5. Trigger push notification
//
// Reference: Strava API v3
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("💾 Strava Activity Store started")
    
    const requestBody = await req.json()
    console.log("   📥 Request body keys:", Object.keys(requestBody))
    
    const { activity, userId, stravaAthleteId } = requestBody
    
    if (!activity) {
      console.error("❌ Missing activity data")
      return new Response(JSON.stringify({ error: "Missing activity" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   ✅ Activity received")
    console.log("   Activity ID:", activity.id)
    console.log("   Activity Type:", activity.type, activity.sport_type)
    console.log("   User ID:", userId || "not provided")
    console.log("   Athlete ID:", stravaAthleteId || "not provided")
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // 1. Find HYKA user from stravaAthleteId
    let finalUserId: string | null = userId || null
    
    if (!finalUserId && stravaAthleteId) {
      console.log("🔍 Looking up HYKA user for Strava athlete:", stravaAthleteId)
      
      const { data: connection, error: lookupError } = await supabase
        .from('strava_connections')
        .select('user_id')
        .eq('strava_athlete_id', stravaAthleteId)
        .single()
      
      if (lookupError || !connection) {
        console.log("⚠️ No HYKA user found for Strava athlete:", stravaAthleteId)
        return new Response(JSON.stringify({
          success: false,
          message: "No connection found for user"
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      finalUserId = connection.user_id
      console.log("✅ Found HYKA user:", finalUserId)
    }
    
    if (!finalUserId) {
      console.error("❌ No user ID available")
      return new Response(JSON.stringify({
        success: false,
        message: "No user ID provided"
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // 2. Parse activity data
    console.log("   🔍 Parsing activity data...")
    
    const activityId = activity.id?.toString()
    const activityType = activity.type || 'Run'
    const sportType = activity.sport_type || activity.type || 'Run'
    const startDate = activity.start_date ? new Date(activity.start_date).toISOString() : null
    const startDateLocal = activity.start_date_local ? new Date(activity.start_date_local).toISOString() : null
    const elapsedTime = activity.elapsed_time || 0
    const movingTime = activity.moving_time || elapsedTime
    const distanceMeters = activity.distance || 0
    const elevationGainMeters = activity.total_elevation_gain || 0
    const averageSpeedMps = activity.average_speed || 0
    const maxSpeedMps = activity.max_speed || 0
    const averageCadence = activity.average_cadence || null
    const averageHeartRate = activity.average_heartrate || null
    const maxHeartRate = activity.max_heartrate || null
    const calories = activity.calories || null
    const deviceName = activity.device_name || null
    const trainer = activity.trainer || false
    const commute = activity.commute || false
    const manual = activity.manual || false
    const privateActivity = activity.private || false
    const flagged = activity.flagged || false
    const workoutType = activity.workout_type || null
    const activityName = activity.name || null
    
    console.log("   Parsed values:")
    console.log("   - activityId:", activityId || "MISSING")
    console.log("   - activityType:", activityType)
    console.log("   - startDate:", startDate || "MISSING")
    console.log("   - distanceMeters:", distanceMeters)
    console.log("   - elevationGainMeters:", elevationGainMeters)
    
    if (!activityId) {
      console.error("❌ Missing activity ID")
      return new Response(JSON.stringify({ error: "Missing activity ID" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // 3. Store activity (upsert to handle duplicates)
    console.log("💾 Storing activity in database...")
    
    const { data: storedActivity, error: storeError } = await supabase
      .from('strava_activities')
      .upsert({
        user_id: finalUserId,
        strava_activity_id: parseInt(activityId),
        activity_name: activityName,
        activity_type: activityType,
        sport_type: sportType,
        start_date: startDate,
        start_date_local: startDateLocal,
        elapsed_time: elapsedTime,
        moving_time: movingTime,
        distance_meters: distanceMeters,
        total_elevation_gain_meters: elevationGainMeters,
        average_speed_mps: averageSpeedMps,
        max_speed_mps: maxSpeedMps,
        average_cadence: averageCadence,
        average_heart_rate: averageHeartRate,
        max_heart_rate: maxHeartRate,
        calories: calories,
        device_name: deviceName,
        trainer: trainer,
        commute: commute,
        manual: manual,
        private: privateActivity,
        flagged: flagged,
        workout_type: workoutType,
        raw_summary: activity,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,strava_activity_id'
      })
      .select('id')
      .single()
    
    if (storeError) {
      console.error("❌ Failed to store activity:", storeError)
      throw new Error(`Failed to store activity: ${storeError.message}`)
    }
    
    console.log("✅ Activity stored:", storedActivity.id)
    
    // 4. Fetch and store activity streams (samples) if available
    // Get access token for fetching streams
    const { data: connection, error: connError } = await supabase
      .from('strava_connections')
      .select('access_token, refresh_token, token_expires_at')
      .eq('user_id', finalUserId)
      .single()
    
    if (!connError && connection) {
      console.log("🔄 Fetching activity streams...")
      
      // Check if token needs refresh
      let accessToken = connection.access_token
      const tokenExpiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
      const now = new Date()
      
      if (tokenExpiresAt && tokenExpiresAt <= now) {
        console.log("⚠️ Token expired, would need refresh (skipping streams for now)")
        // Token refresh logic would go here
      } else {
        // Fetch streams
        const streamsUrl = `https://www.strava.com/api/v3/activities/${activityId}/streams?keys=time,distance,latlng,altitude,heartrate,cadence,watts,velocity_smooth,grade_smooth,temp,moving`
        
        try {
          const streamsResponse = await fetch(streamsUrl, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Accept': 'application/json'
            }
          })
          
          if (streamsResponse.ok) {
            const streamsData = await streamsResponse.json()
            console.log("✅ Streams fetched:", streamsData.length, "streams")
            
            // Parse streams into samples
            const timeStream = streamsData.find((s: any) => s.type === 'time')
            const distanceStream = streamsData.find((s: any) => s.type === 'distance')
            const latlngStream = streamsData.find((s: any) => s.type === 'latlng')
            const altitudeStream = streamsData.find((s: any) => s.type === 'altitude')
            const heartrateStream = streamsData.find((s: any) => s.type === 'heartrate')
            const cadenceStream = streamsData.find((s: any) => s.type === 'cadence')
            const velocityStream = streamsData.find((s: any) => s.type === 'velocity_smooth')
            const gradeStream = streamsData.find((s: any) => s.type === 'grade_smooth')
            const tempStream = streamsData.find((s: any) => s.type === 'temp')
            const movingStream = streamsData.find((s: any) => s.type === 'moving')
            
            if (timeStream && timeStream.data) {
              const samples = []
              const timeData = timeStream.data
              const maxLength = timeData.length
              
              for (let i = 0; i < maxLength; i++) {
                const timeOffset = timeData[i]
                const latlng = latlngStream?.data?.[i] || null
                const altitude = altitudeStream?.data?.[i] || null
                const distance = distanceStream?.data?.[i] || null
                const heartrate = heartrateStream?.data?.[i] || null
                const cadence = cadenceStream?.data?.[i] || null
                const velocity = velocityStream?.data?.[i] || null
                const grade = gradeStream?.data?.[i] || null
                const temp = tempStream?.data?.[i] || null
                const moving = movingStream?.data?.[i] || null
                
                samples.push({
                  user_id: finalUserId,
                  activity_id: storedActivity.id, // UUID from strava_activities
                  strava_activity_id: parseInt(activityId), // Strava's activity ID for easy lookups
                  time_offset: timeOffset,
                  latitude: latlng ? latlng[0] : null,
                  longitude: latlng ? latlng[1] : null,
                  altitude_meters: altitude,
                  distance_meters: distance,
                  heart_rate: heartrate ? Math.round(heartrate) : null,
                  cadence: cadence ? Math.round(cadence) : null,
                  velocity_smooth: velocity,
                  grade_smooth: grade,
                  temperature: temp,
                  moving: moving
                })
              }
              
              if (samples.length > 0) {
                console.log("💾 Storing", samples.length, "samples...")
                const { error: samplesError } = await supabase
                  .from('strava_activity_samples')
                  .upsert(samples, {
                    onConflict: 'user_id,activity_id,time_offset'
                  })
                
                if (samplesError) {
                  console.error("⚠️ Failed to store samples:", samplesError)
                } else {
                  console.log("✅ Samples stored")
                }
              }
            }
          } else {
            console.log("⚠️ Could not fetch streams:", streamsResponse.status)
          }
        } catch (streamsError) {
          console.error("⚠️ Error fetching streams:", streamsError)
        }
      }
    }
    
    // 5. Update last_sync_at for connection
    await supabase
      .from('strava_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('user_id', finalUserId)
    
    // 6. Trigger push notification (async, non-blocking)
    const notifyUrl = `${supabaseUrl}/functions/v1/strava-activity-notify`
    const notifyPayload = {
      userId: finalUserId,
      activityId: storedActivity.id,
      stravaActivityId: activityId,
      activityType: activityType,
      distanceMeters: distanceMeters,
      activityName: activityName
    }
    
    fetch(notifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseKey}`
      },
      body: JSON.stringify(notifyPayload)
    }).then(response => {
      if (!response.ok) {
        console.error(`⚠️ Failed to send notification: ${response.status} ${response.statusText}`)
      } else {
        console.log("🔔 Notification request sent successfully")
      }
    }).catch(error => {
      console.error("❌ Error sending notification request:", error)
    })
    
    const duration = Date.now() - startTime
    console.log(`✅ Activity store completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      success: true,
      activityId: storedActivity.id,
      stravaActivityId: activityId,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in store function:", error)
    console.error("   Duration:", `${duration}ms`)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 200, // Return 200 to prevent retries
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

