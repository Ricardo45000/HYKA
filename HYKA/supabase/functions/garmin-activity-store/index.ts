// ============================================================================
// Garmin Activity Store (Correct OAuth 2.0 Flow)
// ============================================================================
//
// Purpose: Store activity data in Supabase database
//
// Flow:
// 1. Receive summary and details from pull function
// 2. Find HYKA user from garminUserId
// 3. Store activity in garmin_activities table
// 4. Store samples in garmin_activity_samples table
// 5. Handle duplicates (upsert)
//
// Reference: Garmin Connect API OAuth 2.0 DIAUTH specification
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("💾 Garmin Activity Store started")
    
    const requestBody = await req.json()
    console.log("   📥 Request body keys:", Object.keys(requestBody))
    console.log("   📥 Full request body:", JSON.stringify(requestBody, null, 2))
    
    const { summary, details, garminUserId, callbackUrl, fitFileData } = requestBody
    
    if (!summary) {
      console.error("❌ Missing summary data")
      console.error("   Request body:", JSON.stringify(requestBody, null, 2))
      return new Response(JSON.stringify({ error: "Missing summary" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   ✅ Summary received")
    console.log("   Summary keys:", Object.keys(summary))
    console.log("   Summary ID:", summary.summaryId || summary.id || summary.activityId || "NOT FOUND")
    console.log("   Activity Type:", summary.activityType || "NOT FOUND")
    console.log("   Garmin User ID:", garminUserId || "not provided")
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // 1. Find HYKA user from garminUserId
    let userId: string | null = null
    
    if (garminUserId) {
      console.log("🔍 Looking up HYKA user for Garmin user:", garminUserId)
      
      const { data: connection, error: lookupError } = await supabase
        .from('garmin_connections')
        .select('user_id')
        .eq('garmin_user_id', garminUserId)
        .single()
      
      if (lookupError || !connection) {
        console.log("⚠️ No HYKA user found for Garmin user:", garminUserId)
        console.log("   This could mean:")
        console.log("   - User disconnected their Garmin")
        console.log("   - Connection not yet established")
        console.log("   - garmin_user_id not stored during OAuth")
        
        // Still return 200 (don't want to retry)
        return new Response(JSON.stringify({
          success: false,
          message: "No connection found for user"
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      userId = connection.user_id
      console.log("✅ Found HYKA user:", userId)
    } else {
      console.log("⚠️ No garminUserId provided - cannot link to user")
      return new Response(JSON.stringify({
        success: false,
        message: "No garminUserId provided"
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // 2. Parse activity data
    console.log("   🔍 Parsing activity data...")
    console.log("   Available summary fields:", Object.keys(summary))
    
    const activityId = summary.summaryId?.toString() || summary.id?.toString() || summary.activityId?.toString()
    const activityType = summary.activityType || summary.activityTypeKey || 'unknown'
    const startTimeSeconds = summary.startTimeInSeconds || summary.startTimeGMT || summary.beginTimestamp || summary.summaryStartTimeInSeconds
    const durationSeconds = summary.durationInSeconds || summary.elapsedDuration || 0
    const distanceMeters = summary.distanceInMeters || summary.distance || 0
    const elevationGainMeters = summary.totalElevationGainInMeters || summary.elevationGain || 0
    const avgHR = summary.averageHeartRateInBeatsPerMinute || summary.avgHeartRate || null
    const maxHR = summary.maxHeartRateInBeatsPerMinute || summary.maxHeartRate || null
    const activityName = summary.activityName || summary.name || null
    const deviceName = summary.deviceName || summary.device || null
    
    console.log("   Parsed values:")
    console.log("   - activityId:", activityId || "MISSING")
    console.log("   - activityType:", activityType)
    console.log("   - startTimeSeconds:", startTimeSeconds || "MISSING")
    console.log("   - durationSeconds:", durationSeconds)
    console.log("   - distanceMeters:", distanceMeters)
    
    if (!activityId) {
      console.error("❌ Missing activity ID in summary")
      return new Response(JSON.stringify({ error: "Missing activity ID" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    if (!startTimeSeconds) {
      console.error("❌ Missing startTimeInSeconds in summary")
      return new Response(JSON.stringify({ error: "Missing startTimeInSeconds" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Convert start time to ISO string
    const startTime = new Date(startTimeSeconds * 1000).toISOString()
    
    console.log("   Parsed activity:", {
      activityId,
      activityType,
      startTime,
      startTimeSeconds,
      durationSeconds,
      distanceMeters,
      elevationGainMeters,
      deviceName
    })
    
    // 3. Compute elevation gain/loss from samples (more accurate than summary)
    // For ultra-runners, summary elevation may be inaccurate - compute from samples
    let computedElevationGain = elevationGainMeters
    let computedElevationLoss = 0
    
    if (details?.samples && Array.isArray(details.samples) && details.samples.length > 1) {
      console.log("📊 Computing elevation from samples...")
      let previousElevation: number | null = null
      let gain = 0
      let loss = 0
      
      for (const sample of details.samples) {
        const elevation = sample.elevationInMeters || sample.elevation
        if (elevation !== null && elevation !== undefined && previousElevation !== null) {
          const diff = elevation - previousElevation
          if (diff > 0) {
            gain += diff
          } else if (diff < 0) {
            loss += Math.abs(diff)
          }
        }
        if (elevation !== null && elevation !== undefined) {
          previousElevation = elevation
        }
      }
      
      computedElevationGain = gain
      computedElevationLoss = loss
      console.log("   Computed elevation:", {
        gain: computedElevationGain.toFixed(1),
        loss: computedElevationLoss.toFixed(1),
        fromSummary: elevationGainMeters
      })
    }
    
    // Round elevation values to integers (database expects integers)
    const elevationGainRounded = Math.round(computedElevationGain)
    const elevationLossRounded = Math.round(computedElevationLoss)
    
    // Round cadence values to integers if present
    const avgCadence = summary.averageRunCadenceInStepsPerMinute || summary.averageCadence
    const maxCadence = summary.maxRunCadenceInStepsPerMinute || summary.maxCadence
    const avgCadenceRounded = avgCadence ? Math.round(avgCadence) : null
    const maxCadenceRounded = maxCadence ? Math.round(maxCadence) : null
    
    // Round steps to integer if present
    const stepsRounded = summary.steps ? Math.round(summary.steps) : null
    
    // Round calories to integer if present
    const caloriesRounded = summary.activeKilocalories || summary.calories
    const caloriesInt = caloriesRounded ? Math.round(caloriesRounded) : null
    
    // 4. Store activity (upsert to handle duplicates)
    console.log("💾 Storing activity in database...")
    console.log("   Table: garmin_activities")
    console.log("   User ID:", userId)
    console.log("   Garmin Activity ID:", activityId)
    
    const activityData = {
      user_id: userId,
      garmin_activity_id: activityId,
      activity_name: activityName,
      activity_type: activityType,
      start_time: startTime,
      start_time_seconds: startTimeSeconds,
      duration_seconds: durationSeconds,
      distance_meters: distanceMeters,
      total_elevation_gain_meters: elevationGainRounded, // Rounded to integer
      total_elevation_loss_meters: elevationLossRounded, // Rounded to integer
      average_heart_rate: avgHR ? Math.round(avgHR) : null,
      max_heart_rate: maxHR ? Math.round(maxHR) : null,
      average_speed_mps: summary.averageSpeedInMetersPerSecond || null,
      max_speed_mps: summary.maxSpeedInMetersPerSecond || null,
      calories: caloriesInt,
      steps: stepsRounded,
      average_cadence: avgCadenceRounded,
      max_cadence: maxCadenceRounded,
      device_name: deviceName,
      raw_summary: summary, // Changed from raw_data to raw_summary
      has_fit_file: !!fitFileData,
      updated_at: new Date().toISOString()
    }
    
    console.log("   Activity data to insert:", JSON.stringify(activityData, null, 2))
    
    const { data: activity, error: activityError } = await supabase
      .from('garmin_activities')
      .upsert(activityData, {
        onConflict: 'user_id,garmin_activity_id'
      })
      .select('id')
      .single()
    
    if (activityError || !activity) {
      console.error("❌ Failed to store activity in database")
      console.error("   Error:", activityError)
      console.error("   Error message:", activityError?.message)
      console.error("   Error details:", JSON.stringify(activityError, null, 2))
      console.error("   Activity data that failed:", JSON.stringify(activityData, null, 2))
      throw new Error(`Failed to store activity: ${activityError?.message}`)
    }
    
    console.log("✅ Activity stored successfully in database")
    console.log("   Database activity ID:", activity.id)
    console.log("   Garmin activity ID:", activityId)
    
    // 4.5. Send push notification (async, don't wait for response)
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
      
      console.log("📱 Triggering push notification...")
      
      // Fire and forget - don't wait for response
      fetch(notifyUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseKey}`,
          'apikey': supabaseKey
        },
        body: JSON.stringify({
          user_id: userId,
          activity_id: activity.id,
          activity_name: activityName,
          activity_type: activityType,
          distance_meters: distanceMeters,
          duration_seconds: durationSeconds
        })
      }).then(response => {
        if (response.ok) {
          console.log("✅ Push notification triggered successfully")
        } else {
          console.error("⚠️ Push notification failed:", response.status)
        }
      }).catch(err => {
        console.error("⚠️ Failed to trigger notification (non-critical):", err)
        // Don't fail the whole operation if notification fails
      })
    } catch (error) {
      console.error("⚠️ Error triggering notification (non-critical):", error)
      // Don't fail the whole operation if notification fails
    }
    
    // 5. Store FIT file if available (for ultra-runner activities)
    let fitFileStored = false
    if (fitFileData && Array.isArray(fitFileData) && fitFileData.length > 0) {
      console.log("💾 Storing FIT file...")
      
      // Convert array back to Uint8Array and then to Buffer/Blob
      const fitFileBytes = new Uint8Array(fitFileData)
      const fitFileSize = fitFileBytes.length
      
      console.log("   FIT file size:", fitFileSize, "bytes (", (fitFileSize / 1024 / 1024).toFixed(2), "MB)")
      
      // Store FIT file in database
      const { error: fitFileError } = await supabase
        .from('garmin_fit_files')
        .upsert({
          activity_id: activity.id,
          file_data: Array.from(fitFileBytes), // Store as BYTEA
          file_size: fitFileSize,
          device_name: deviceName,
          file_version: null, // Will be extracted by FIT processor
          created_at: new Date().toISOString()
        }, {
          onConflict: 'activity_id'
        })
      
      if (fitFileError) {
        console.error("⚠️ Failed to store FIT file (non-critical):", fitFileError)
        // Don't fail the whole operation if FIT file storage fails
      } else {
        fitFileStored = true
        console.log("✅ FIT file stored")
        
        // Trigger FIT file processing (async)
        // Note: FIT processing will extract samples and update elevation
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        
        // Call FIT processor asynchronously (don't wait)
        fetch(`${supabaseUrl}/functions/v1/garmin-fit-processor`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${supabaseKey}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({ 
            activity_id: activity.id,
            fit_file_data: fitFileData
          })
        }).catch(err => {
          console.log("⚠️ FIT processor call failed (will retry later):", err)
        })
      }
    } else {
      console.log("ℹ️ No FIT file to store")
    }
    
    // 6. Store samples if available (from JSON details)
    // Note: For ultra-runners, samples may come from FIT file instead
    let samplesCount = 0
    if (details?.samples && Array.isArray(details.samples) && details.samples.length > 0) {
      console.log("💾 Storing", details.samples.length, "samples from JSON...")
      
      const samples = details.samples.map((s: any) => {
        const timestamp = s.startTimeInSeconds || s.timestamp || 0
        const sampleTime = timestamp > 0 ? new Date(timestamp * 1000).toISOString() : null
        
        return {
          activity_id: activity.id,
          timestamp_seconds: timestamp,
          sample_time: sampleTime,
          latitude: s.latitudeInDegree || s.latitude || null,
          longitude: s.longitudeInDegree || s.longitude || null,
          elevation_meters: s.elevationInMeters || s.elevation || null,
          heart_rate: s.heartRate || null,
          speed_mps: s.speedMetersPerSecond || s.speed || null,
          steps_per_minute: s.stepsPerMinute || null,
          air_temperature_celsius: s.airTemperatureCelcius || s.temperature || null
        }
      })
      
      const { error: samplesError } = await supabase
        .from('garmin_activity_samples')
        .upsert(samples, {
          onConflict: 'activity_id,timestamp_seconds'
        })
      
      if (samplesError) {
        console.error("⚠️ Failed to store some samples (non-critical):", samplesError)
        // Don't fail the whole operation if samples fail
      } else {
        samplesCount = samples.length
        console.log("✅ Stored", samplesCount, "samples from JSON")
      }
    } else {
      console.log("ℹ️ No samples from JSON (may come from FIT file)")
    }
    
    // 7. Update last_sync_at timestamp
    await supabase
      .from('garmin_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('user_id', userId)
    
    const duration = Date.now() - startTime
    console.log(`✅ Store completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      success: true,
      activityId: activity.id,
      garminActivityId: activityId,
      samplesCount: samplesCount,
      fitFileStored: fitFileStored,
      elevationGain: computedElevationGain,
      elevationLoss: computedElevationLoss,
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

