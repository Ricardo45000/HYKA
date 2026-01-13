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
  
  // Handle GET requests (webhook verification/test from Garmin)
  if (req.method === 'GET') {
    console.log("🔍 GET request received - likely webhook verification/test from Garmin")
    console.log("   URL:", req.url)
    console.log("   Query params:", new URL(req.url).searchParams.toString())
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
  }
  
  try {
    // Log ALL incoming requests - even empty ones
    console.log("🏥 Garmin Health Webhook received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Timestamp:", new Date().toISOString())
    console.log("   User-Agent:", req.headers.get('user-agent') || 'N/A')
    console.log("   Content-Type:", req.headers.get('content-type') || 'N/A')
    console.log("   Content-Length:", req.headers.get('content-length') || 'N/A')
    
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
      // Note: Can't read body again after it's been consumed, so we log what we can
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    console.log("   Body keys:", Object.keys(body))
    console.log("   Body size:", JSON.stringify(body).length, "bytes")
    
    // Log if body is empty or has no data
    if (!body || Object.keys(body).length === 0) {
      console.log("⚠️ Empty webhook body received - Garmin may be testing the endpoint")
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
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
      console.log("   Lookup error:", lookupError?.message || 'No error (connection not found)')
      console.log("   This means:")
      console.log("   1. The Garmin user ID in the webhook doesn't match any garmin_user_id in garmin_connections")
      console.log("   2. OR the user hasn't connected their Garmin account in the app")
      console.log("   3. OR the garmin_user_id wasn't saved during OAuth connection")
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
      console.log("   ⚠️ Unknown webhook format - body structure:", JSON.stringify(body).substring(0, 500))
    }
    
    // Log if no data was found
    if (metricsDataArray.length === 0 || (metricsDataArray.length === 1 && Object.keys(metricsDataArray[0] || {}).length === 0)) {
      console.log("⚠️ No health data found in webhook payload")
      console.log("   This could mean:")
      console.log("   1. Garmin sent a test/verification webhook (empty body)")
      console.log("   2. The webhook format changed")
      console.log("   3. Health data is sent via a different webhook endpoint")
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
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
      // Note: fitnessAge and vo2Max only come from userMetrics/healthSnapshot webhooks,
      // not from sleeps/epochs/dailies webhooks
      let fitnessAge = metricsData?.fitnessAge || metricsData?.fitness_age || null
      let vo2Max = metricsData?.vo2Max || metricsData?.vo2_max || metricsData?.vo2max || null
      
      // If not found in current webhook data, look up the latest values from previous userMetrics
      // This ensures fitness_age and vo2_max are available for all health metrics records
      if ((!fitnessAge || !vo2Max) && webhookType !== 'userMetrics' && webhookType !== 'healthSnapshot') {
        try {
          const { data: latestMetrics } = await supabase
            .from('garmin_health_metrics')
            .select('fitness_age, vo2_max')
            .eq('user_id', connection.user_id)
            .eq('garmin_user_id', garminUserId)
            .not('fitness_age', 'is', null)
            .not('vo2_max', 'is', null)
            .order('metric_date', { ascending: false })
            .limit(1)
            .single()
          
          if (latestMetrics) {
            if (!fitnessAge && latestMetrics.fitness_age) {
              fitnessAge = latestMetrics.fitness_age
            }
            if (!vo2Max && latestMetrics.vo2_max) {
              vo2Max = latestMetrics.vo2_max
            }
          }
        } catch (lookupError) {
          // Silently fail - it's okay if we can't find previous values
          // This is just a convenience lookup, not critical
        }
      }
      
      // Extract webhook-specific fields
      let steps = metricsData?.steps || metricsData?.step_count || null
      let activeCalories = metricsData?.activeKilocalories || metricsData?.active_calories || null
      let totalCalories = metricsData?.bmrKilocalories || metricsData?.total_calories || null
      let restingHeartRate = metricsData?.restingHeartRateInBeatsPerMinute || metricsData?.resting_heart_rate || null
      let avgHeartRate = metricsData?.averageHeartRateInBeatsPerMinute || metricsData?.avg_heart_rate || null
      let maxHeartRate = metricsData?.maxHeartRateInBeatsPerMinute || metricsData?.max_heart_rate || null
      let minHeartRate = metricsData?.minHeartRateInBeatsPerMinute || metricsData?.min_heart_rate || null
      
      // For userMetrics/healthSnapshot webhooks, look up dailies data for the same date
      // to fill in missing daily activity fields (steps, calories, heart rate, etc.)
      if ((webhookType === 'userMetrics' || webhookType === 'healthSnapshot') && metricDate) {
        try {
          const { data: dailiesData } = await supabase
            .from('garmin_health_metrics')
            .select('steps, active_calories, total_calories, resting_heart_rate, avg_heart_rate, max_heart_rate, min_heart_rate, stress_level, body_battery')
            .eq('user_id', connection.user_id)
            .eq('garmin_user_id', garminUserId)
            .eq('metric_date', metricDate)
            .not('steps', 'is', null)  // Only get records that have daily activity data
            .order('updated_at', { ascending: false })
            .limit(1)
            .single()
          
          if (dailiesData) {
            // Fill in missing fields from dailies data
            if (!steps && dailiesData.steps) steps = dailiesData.steps
            if (!activeCalories && dailiesData.active_calories) activeCalories = dailiesData.active_calories
            if (!totalCalories && dailiesData.total_calories) totalCalories = dailiesData.total_calories
            if (!restingHeartRate && dailiesData.resting_heart_rate) restingHeartRate = dailiesData.resting_heart_rate
            if (!avgHeartRate && dailiesData.avg_heart_rate) avgHeartRate = dailiesData.avg_heart_rate
            if (!maxHeartRate && dailiesData.max_heart_rate) maxHeartRate = dailiesData.max_heart_rate
            if (!minHeartRate && dailiesData.min_heart_rate) minHeartRate = dailiesData.min_heart_rate
          }
        } catch (lookupError) {
          // Silently fail - it's okay if we can't find dailies data
        }
      }
      
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
      
      // For non-dailies webhooks, look up existing dailies data for the same date to merge
      // This ensures all records have complete data (steps, calories, heart rate, etc.)
      if (webhookType !== 'dailies' && metricDate) {
        try {
          const { data: existingDailies } = await supabase
            .from('garmin_health_metrics')
            .select('steps, active_calories, total_calories, resting_heart_rate, avg_heart_rate, max_heart_rate, min_heart_rate, stress_level, body_battery')
            .eq('user_id', connection.user_id)
            .eq('garmin_user_id', garminUserId)
            .eq('metric_date', metricDate)
            .not('steps', 'is', null)  // Only get records that have daily activity data
            .order('updated_at', { ascending: false })
            .limit(1)
            .single()
          
          if (existingDailies) {
            // Merge missing fields from existing dailies data
            if (!steps && existingDailies.steps) steps = existingDailies.steps
            if (!activeCalories && existingDailies.active_calories) activeCalories = existingDailies.active_calories
            if (!totalCalories && existingDailies.total_calories) totalCalories = existingDailies.total_calories
            if (!restingHeartRate && existingDailies.resting_heart_rate) restingHeartRate = existingDailies.resting_heart_rate
            if (!avgHeartRate && existingDailies.avg_heart_rate) avgHeartRate = existingDailies.avg_heart_rate
            if (!maxHeartRate && existingDailies.max_heart_rate) maxHeartRate = existingDailies.max_heart_rate
            if (!minHeartRate && existingDailies.min_heart_rate) minHeartRate = existingDailies.min_heart_rate
          }
        } catch (lookupError) {
          // Silently fail - it's okay if we can't find dailies data
        }
      }
      
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
      
      // First, try to get existing record for this date to merge data
      const { data: existingRecord } = await supabase
        .from('garmin_health_metrics')
        .select('*')
        .eq('user_id', connection.user_id)
        .eq('garmin_user_id', garminUserId)
        .eq('metric_date', metricDate || new Date().toISOString().split('T')[0])
        .maybeSingle()
      
      // Merge data: use existing values if new values are null
      if (existingRecord) {
        healthData.fitness_age = healthData.fitness_age ?? existingRecord.fitness_age
        healthData.vo2_max = healthData.vo2_max ?? existingRecord.vo2_max
        healthData.steps = healthData.steps ?? existingRecord.steps
        healthData.active_calories = healthData.active_calories ?? existingRecord.active_calories
        healthData.total_calories = healthData.total_calories ?? existingRecord.total_calories
        healthData.resting_heart_rate = healthData.resting_heart_rate ?? existingRecord.resting_heart_rate
        healthData.avg_heart_rate = healthData.avg_heart_rate ?? existingRecord.avg_heart_rate
        healthData.max_heart_rate = healthData.max_heart_rate ?? existingRecord.max_heart_rate
        healthData.min_heart_rate = healthData.min_heart_rate ?? existingRecord.min_heart_rate
        healthData.sleep_duration_seconds = healthData.sleep_duration_seconds ?? existingRecord.sleep_duration_seconds
        healthData.sleep_score = healthData.sleep_score ?? existingRecord.sleep_score
        healthData.deep_sleep_seconds = healthData.deep_sleep_seconds ?? existingRecord.deep_sleep_seconds
        healthData.light_sleep_seconds = healthData.light_sleep_seconds ?? existingRecord.light_sleep_seconds
        healthData.rem_sleep_seconds = healthData.rem_sleep_seconds ?? existingRecord.rem_sleep_seconds
        healthData.awake_seconds = healthData.awake_seconds ?? existingRecord.awake_seconds
        healthData.sleep_start_time = healthData.sleep_start_time ?? existingRecord.sleep_start_time
        healthData.sleep_end_time = healthData.sleep_end_time ?? existingRecord.sleep_end_time
        healthData.stress_level = healthData.stress_level ?? existingRecord.stress_level
        healthData.body_battery = healthData.body_battery ?? existingRecord.body_battery
        healthData.avg_respiration_rate = healthData.avg_respiration_rate ?? existingRecord.avg_respiration_rate
        // Keep the most recent raw_data if it's more complete
        if (existingRecord.raw_data && !healthData.raw_data) {
          healthData.raw_data = existingRecord.raw_data
        }
        // Use the earliest timestamp
        if (existingRecord.timestamp && healthData.timestamp) {
          const existingTs = new Date(existingRecord.timestamp).getTime()
          const newTs = new Date(healthData.timestamp).getTime()
          if (existingTs < newTs) {
            healthData.timestamp = existingRecord.timestamp
          }
        }
      }
      
      // Remove null/undefined fields again after merging
      Object.keys(healthData).forEach(key => {
        if (healthData[key] === null || healthData[key] === undefined) {
          delete healthData[key]
        }
      })
      
      // Use upsert with daily summary constraint (user_id, garmin_user_id, metric_date)
      // Try column-based conflict first (works even without the constraint)
      // Then try named constraint (works after migration)
      let insertError: any = null
      let insertedData: any = null
      
      // First, try column-based conflict (works without constraint)
      const result1 = await supabase
        .from('garmin_health_metrics')
        .upsert(healthData, {
          onConflict: 'user_id,garmin_user_id,metric_date'
        })
        .select()
      
      insertError = result1.error
      insertedData = result1.data
      
      // If column-based conflict fails, try named constraint (after migration)
      if (insertError && (insertError.message?.includes('does not exist') || insertError.code === '42704' || insertError.code === '42P01')) {
        console.log(`   Trying named constraint instead...`)
        const result2 = await supabase
          .from('garmin_health_metrics')
          .upsert(healthData, {
            onConflict: 'garmin_health_metrics_user_date_unique'
          })
          .select()
        
        insertError = result2.error
        insertedData = result2.data
      }
      
      // Final fallback: if both fail, try old constraint (before migration)
      if (insertError) {
        console.log(`   Trying old timestamp constraint as fallback...`)
        const result3 = await supabase
          .from('garmin_health_metrics')
          .upsert(healthData, {
            onConflict: 'user_id,timestamp'
          })
          .select()
        
        insertError = result3.error
        insertedData = result3.data
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

