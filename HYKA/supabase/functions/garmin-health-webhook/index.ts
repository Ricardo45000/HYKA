// ============================================================================
// Garmin Health Webhook Handler
// ============================================================================
//
// Purpose: Handles Garmin health data webhooks (User Metrics, Health Snapshot, etc.)
// 
// Health Data Includes:
// - Fitness Age
// - VO2 Max
// - Body Composition
// - Blood Pressure
// - Sleep Data
// - Stress
// - HRV Summary
// - And more...
//
// Flow:
// 1. Receive health webhook from Garmin
// 2. If callbackURL provided, fetch actual data from Garmin API
// 3. Parse health data (User Metrics, Health Snapshot, etc.)
// 4. Store in garmin_health_metrics table
// 5. Return 200 OK to Garmin
//
// Reference: Garmin Health API documentation
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
    console.log("🏥 Garmin Health Webhook received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    
    // Parse request body (handle both JSON and form data)
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
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    console.log("   Body keys:", Object.keys(body))
    
    // Extract Garmin user ID from various possible locations
    let garminUserId = body.userId || body.garminUserId || body.user_id
    
    // If not at top level, check inside arrays (dailies, sleeps, epochs, stressDetails, allDayRespiration, userMetrics, etc.)
    if (!garminUserId) {
      const arrayKeys = ['dailies', 'sleeps', 'epochs', 'stressDetails', 'allDayRespiration', 'userMetrics', 'healthSnapshot', 'bodyComposition']
      for (const key of arrayKeys) {
        if (body[key] && Array.isArray(body[key]) && body[key].length > 0) {
          garminUserId = body[key][0].userId || body[key][0].garminUserId || body[key][0].user_id
          if (garminUserId) {
            console.log(`   Found userId in ${key} array`)
            break
          }
        }
      }
    }
    
    if (!garminUserId) {
      console.error("❌ Missing garminUserId in health webhook")
      console.log("   Body sample:", JSON.stringify(body).substring(0, 500))
      return new Response("OK", { status: 200 })
    }
    
    console.log("   Garmin User ID:", garminUserId)
    
    // Initialize Supabase
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
      return new Response("OK", { status: 200 })
    }
    
    console.log("✅ Found HYKA user:", connection.user_id)
    
    // Determine webhook type and extract data
    let metricsDataArray: any[] = []
    let callbackUrl: string | null = null
    let webhookType = 'unknown'
    
    // Handle different health webhook types
    if (body.dailies && Array.isArray(body.dailies)) {
      console.log(`📊 Processing Dailies (${body.dailies.length} items)`)
      webhookType = 'dailies'
      metricsDataArray = body.dailies
    } else if (body.sleeps && Array.isArray(body.sleeps)) {
      console.log(`📊 Processing Sleeps (${body.sleeps.length} items)`)
      webhookType = 'sleeps'
      metricsDataArray = body.sleeps
    } else if (body.epochs && Array.isArray(body.epochs)) {
      console.log(`📊 Processing Epochs (${body.epochs.length} items)`)
      webhookType = 'epochs'
      metricsDataArray = body.epochs
    } else if (body.stressDetails && Array.isArray(body.stressDetails)) {
      console.log(`📊 Processing Stress Details (${body.stressDetails.length} items)`)
      webhookType = 'stressDetails'
      metricsDataArray = body.stressDetails
    } else if (body.allDayRespiration && Array.isArray(body.allDayRespiration)) {
      console.log(`📊 Processing All Day Respiration (${body.allDayRespiration.length} items)`)
      webhookType = 'allDayRespiration'
      metricsDataArray = body.allDayRespiration
    } else if (body.userMetrics) {
      const userMetrics = Array.isArray(body.userMetrics) && body.userMetrics.length > 0 
        ? body.userMetrics[0] 
        : body.userMetrics
      
      console.log("📊 Processing User Metrics")
      webhookType = 'userMetrics'
      callbackUrl = userMetrics.callbackURL || userMetrics.callbackUrl || null
      metricsDataArray = [userMetrics]
    } else if (body.healthSnapshot) {
      const healthSnapshot = Array.isArray(body.healthSnapshot) && body.healthSnapshot.length > 0
        ? body.healthSnapshot[0]
        : body.healthSnapshot
      console.log("📊 Processing Health Snapshot")
      webhookType = 'healthSnapshot'
      callbackUrl = healthSnapshot.callbackURL || healthSnapshot.callbackUrl || null
      metricsDataArray = [healthSnapshot]
    } else if (body.bodyComposition) {
      const bodyComposition = Array.isArray(body.bodyComposition) && body.bodyComposition.length > 0
        ? body.bodyComposition[0]
        : body.bodyComposition
      console.log("📊 Processing Body Composition")
      webhookType = 'bodyComposition'
      callbackUrl = bodyComposition.callbackURL || bodyComposition.callbackUrl || null
      metricsDataArray = [bodyComposition]
    } else {
      metricsDataArray = [body]
      callbackUrl = body.callbackURL || body.callbackUrl || null
      console.log("📊 Processing generic health data")
    }
    
    // Process each item in the metricsDataArray
    let storedCount = 0
    let errorCount = 0
    
    for (let i = 0; i < metricsDataArray.length; i++) {
      let metricsData = metricsDataArray[i]
      
      // If callbackURL is provided, fetch the actual data from Garmin (only for first item if multiple)
      if (callbackUrl && i === 0) {
        console.log("🔄 Fetching health data from callbackURL...")
        console.log("   URL:", callbackUrl.substring(0, 100) + "...")
        
        try {
          // Extract token from callbackURL if present, or use access token
          let fetchHeaders: HeadersInit = {
            'Accept': 'application/json'
          }
          
          // Try to extract token from callbackURL (format: ?token=XXX)
          const urlObj = new URL(callbackUrl)
          const tokenFromUrl = urlObj.searchParams.get('token')
          
          if (tokenFromUrl) {
            fetchHeaders['Authorization'] = `Bearer ${tokenFromUrl}`
            console.log("   Using token from callbackURL")
          } else if (connection.access_token) {
            fetchHeaders['Authorization'] = `Bearer ${connection.access_token}`
            console.log("   Using OAuth access token")
          }
          
          const fetchResponse = await fetch(callbackUrl, {
            method: 'GET',
            headers: fetchHeaders
          })
          
          if (fetchResponse.ok) {
            const fetchedData = await fetchResponse.json()
            console.log("✅ Fetched health data from callbackURL")
            
            // Merge fetched data with existing metricsData
            if (Array.isArray(fetchedData) && fetchedData.length > 0) {
              metricsData = { ...metricsData, ...fetchedData[0] }
            } else if (typeof fetchedData === 'object') {
              metricsData = { ...metricsData, ...fetchedData }
            }
          } else {
            const errorText = await fetchResponse.text()
            console.error("❌ Failed to fetch from callbackURL:", fetchResponse.status, errorText.substring(0, 200))
          }
        } catch (fetchError) {
          console.error("❌ Error fetching from callbackURL:", fetchError)
          // Continue with existing metricsData
        }
      }
      
      // Extract timestamp - try multiple fields based on webhook type
      let timestamp: number | null = null
      let metricDate: string | null = null
      
      if (webhookType === 'dailies') {
        timestamp = metricsData.startTimeInSeconds || metricsData.start_time_in_seconds || null
        metricDate = metricsData.calendarDate || metricsData.calendar_date || null
      } else if (webhookType === 'sleeps') {
        timestamp = metricsData.startTimeInSeconds || metricsData.start_time_in_seconds || null
        metricDate = metricsData.calendarDate || metricsData.calendar_date || null
      } else if (webhookType === 'epochs') {
        timestamp = metricsData.startTimeInSeconds || metricsData.start_time_in_seconds || null
        metricDate = timestamp ? new Date(timestamp * 1000).toISOString().split('T')[0] : null
      } else if (webhookType === 'stressDetails') {
        timestamp = metricsData.startTimeInSeconds || metricsData.start_time_in_seconds || null
        metricDate = metricsData.calendarDate || metricsData.calendar_date || null
      } else if (webhookType === 'allDayRespiration') {
        timestamp = metricsData.startTimeInSeconds || metricsData.start_time_in_seconds || null
        metricDate = timestamp ? new Date(timestamp * 1000).toISOString().split('T')[0] : null
      } else {
        // Generic extraction
        if (metricsData?.timestamp) {
          timestamp = typeof metricsData.timestamp === 'number' 
            ? metricsData.timestamp 
            : new Date(metricsData.timestamp).getTime() / 1000
        } else if (metricsData?.timestampInSeconds) {
          timestamp = metricsData.timestampInSeconds
        } else if (metricsData?.uploadStartTimeInSeconds) {
          timestamp = metricsData.uploadStartTimeInSeconds
        } else {
          timestamp = Math.floor(Date.now() / 1000)
        }
        metricDate = timestamp ? new Date(timestamp * 1000).toISOString().split('T')[0] : null
      }
      
      // Extract key metrics from the data
      const fitnessAge = metricsData?.fitnessAge || metricsData?.fitness_age || null
      const vo2Max = metricsData?.vo2Max || metricsData?.vo2_max || metricsData?.vo2max || null
      
      // Extract webhook-specific fields
      const steps = metricsData?.steps || metricsData?.step_count || null
      const activeCalories = metricsData?.activeKilocalories || metricsData?.active_calories || null
      const totalCalories = metricsData?.bmrKilocalories || metricsData?.total_calories || null
      const restingHeartRate = metricsData?.restingHeartRateInBeatsPerMinute || metricsData?.resting_heart_rate || null
      const avgHeartRate = metricsData?.averageHeartRateInBeatsPerMinute || metricsData?.avg_heart_rate || null
      const maxHeartRate = metricsData?.maxHeartRateInBeatsPerMinute || metricsData?.max_heart_rate || null
      const minHeartRate = metricsData?.minHeartRateInBeatsPerMinute || metricsData?.min_heart_rate || null
      
      // Sleep-specific fields
      const sleepDurationSeconds = metricsData?.durationInSeconds || metricsData?.sleep_duration_seconds || null
      const deepSleepSeconds = metricsData?.deepSleepDurationInSeconds || metricsData?.deep_sleep_seconds || null
      const lightSleepSeconds = metricsData?.lightSleepDurationInSeconds || metricsData?.light_sleep_seconds || null
      const remSleepSeconds = metricsData?.remSleepInSeconds || metricsData?.rem_sleep_seconds || null
      const awakeSeconds = metricsData?.awakeDurationInSeconds || metricsData?.awake_seconds || null
      const sleepStartTime = metricsData?.startTimeInSeconds ? new Date(metricsData.startTimeInSeconds * 1000).toISOString() : null
      const sleepEndTime = metricsData?.startTimeInSeconds && metricsData?.durationInSeconds 
        ? new Date((metricsData.startTimeInSeconds + metricsData.durationInSeconds) * 1000).toISOString() 
        : null
      
      // Stress-specific fields (from stressDetails)
      const stressLevel = metricsData?.timeOffsetStressLevelValues ? 
        Object.values(metricsData.timeOffsetStressLevelValues).reduce((sum: number, val: any) => sum + (Number(val) || 0), 0) / Object.keys(metricsData.timeOffsetStressLevelValues).length 
        : null
      const bodyBattery = metricsData?.timeOffsetBodyBatteryValues ? 
        Object.values(metricsData.timeOffsetBodyBatteryValues).reduce((sum: number, val: any) => sum + (Number(val) || 0), 0) / Object.keys(metricsData.timeOffsetBodyBatteryValues).length 
        : null
      
      // Respiration-specific fields
      const avgRespirationRate = metricsData?.timeOffsetEpochToBreaths ? 
        Object.values(metricsData.timeOffsetEpochToBreaths).reduce((sum: number, val: any) => sum + (Number(val) || 0), 0) / Object.keys(metricsData.timeOffsetEpochToBreaths).length 
        : null
      
      // Build health data object
      const healthData: any = {
        user_id: connection.user_id,
        garmin_user_id: garminUserId,
        timestamp: timestamp ? new Date(timestamp * 1000).toISOString() : new Date().toISOString(),
        metric_date: metricDate || new Date().toISOString().split('T')[0],
        fitness_age: fitnessAge,
        vo2_max: vo2Max,
        steps: steps ? Math.round(steps) : null,
        active_calories: activeCalories ? Math.round(activeCalories) : null,
        total_calories: totalCalories ? Math.round(totalCalories) : null,
        resting_heart_rate: restingHeartRate ? Math.round(restingHeartRate) : null,
        avg_heart_rate: avgHeartRate ? Math.round(avgHeartRate) : null,
        max_heart_rate: maxHeartRate ? Math.round(maxHeartRate) : null,
        min_heart_rate: minHeartRate ? Math.round(minHeartRate) : null,
        sleep_duration_seconds: sleepDurationSeconds ? Math.round(sleepDurationSeconds) : null,
        deep_sleep_seconds: deepSleepSeconds ? Math.round(deepSleepSeconds) : null,
        light_sleep_seconds: lightSleepSeconds ? Math.round(lightSleepSeconds) : null,
        rem_sleep_seconds: remSleepSeconds ? Math.round(remSleepSeconds) : null,
        awake_seconds: awakeSeconds ? Math.round(awakeSeconds) : null,
        sleep_start_time: sleepStartTime,
        sleep_end_time: sleepEndTime,
        stress_level: stressLevel ? Math.round(stressLevel) : null,
        body_battery: bodyBattery ? Math.round(bodyBattery) : null,
        avg_respiration_rate: avgRespirationRate ? Math.round(avgRespirationRate * 100) / 100 : null,
        raw_data: metricsData,
        updated_at: new Date().toISOString()
      }
      
      // Remove null/undefined fields
      Object.keys(healthData).forEach(key => {
        if (healthData[key] === null || healthData[key] === undefined) {
          delete healthData[key]
        }
      })
      
      // Store health metrics
      console.log(`💾 Storing health metrics item ${i + 1}/${metricsDataArray.length}...`)
      
      // Use upsert with correct conflict resolution
      let insertError: any = null
      let insertedData: any = null
      
      const result1 = await supabase
        .from('garmin_health_metrics')
        .upsert(healthData, {
          onConflict: 'garmin_health_metrics_user_id_timestamp_key'
        })
        .select()
      
      if (result1.error) {
        const result2 = await supabase
          .from('garmin_health_metrics')
          .upsert(healthData, {
            onConflict: 'user_id,timestamp'
          })
          .select()
        
        if (result2.error) {
          const result3 = await supabase
            .from('garmin_health_metrics')
            .insert(healthData)
            .select()
          
          insertError = result3.error
          insertedData = result3.data
        } else {
          insertError = result2.error
          insertedData = result2.data
        }
      } else {
        insertError = result1.error
        insertedData = result1.data
      }
      
      if (insertError) {
        console.error(`❌ Error storing health metrics item ${i + 1}:`, insertError.message)
        errorCount++
      } else {
        storedCount++
        if (insertedData && insertedData.length > 0) {
          console.log(`✅ Stored item ${i + 1} (ID: ${insertedData[0].id})`)
        }
      }
    }
    
    console.log(`✅ Health webhook processed: ${storedCount} stored, ${errorCount} errors`)
    
    const duration = Date.now() - startTime
    console.log(`✅ Health webhook processed in ${duration}ms`)
    
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error processing health webhook:", error)
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

