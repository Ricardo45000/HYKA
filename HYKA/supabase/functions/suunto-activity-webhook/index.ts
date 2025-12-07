import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Suunto Activity & Health Webhook
 * 
 * Receives webhook notifications from Suunto for:
 * - Workouts (activities)
 * - 247 Daily Activity (steps, energy, HR)
 * - 247 Sleep data
 * - 247 Recovery data
 * 
 * Webhook URL: https://<project>.supabase.co/functions/v1/suunto-activity-webhook
 * Reference: https://apizone.suunto.com/api-details#api=new-247-api
 */

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, ocp-apim-subscription-key'
      }
    })
  }

  const startTime = Date.now()

  try {
    console.log("📥 Suunto Webhook started")
    console.log("   Method:", req.method)
    
    // Suunto webhook verification (GET request)
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const challenge = url.searchParams.get('challenge')
      
      if (challenge) {
        console.log("✅ Suunto webhook verification request")
        return new Response(JSON.stringify({ challenge }), {
          status: 200,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        })
      }

      return new Response(JSON.stringify({
        status: "ok",
        message: "Suunto webhook endpoint is active"
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }

    // Handle webhook event (POST request)
    const body = await req.json()
    console.log("📨 Webhook payload:", JSON.stringify(body).substring(0, 1000))

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get subscription key for Suunto API
    const subscriptionKey = Deno.env.get('SUUNTO_SUBSCRIPTION_KEY') || '8e6bcafebd494d7c94df5cf7d5154fde'

    // Determine notification type based on payload
    const notificationType = detectNotificationType(body)
    console.log("📋 Notification type:", notificationType)

    // Extract user ID
    const suuntoUserId = body.username || body.user_id || body.suunto_user_id || body.userId
    
    if (!suuntoUserId) {
      console.error("❌ Missing user ID in webhook payload")
      return new Response(JSON.stringify({ success: false, error: "Missing user ID" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }

    // Find user connection
    const { data: connection, error: connError } = await supabase
      .from('suunto_connections')
      .select('user_id, access_token, refresh_token, token_expires_at')
      .eq('suunto_user_id', suuntoUserId)
      .single()

    if (connError || !connection) {
      console.error("❌ Suunto connection not found for user:", suuntoUserId)
      return new Response(JSON.stringify({ success: false, error: "Connection not found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }

    console.log("✅ Found connection for user:", connection.user_id)

    // Process based on notification type
    let result
    switch (notificationType) {
      case 'workout':
        result = await handleWorkoutNotification(supabase, connection, body, subscriptionKey)
        break
      case '247_daily':
        result = await handle247DailyNotification(supabase, connection, body, subscriptionKey)
        break
      case '247_sleep':
        result = await handle247SleepNotification(supabase, connection, body, subscriptionKey)
        break
      case '247_recovery':
        result = await handle247RecoveryNotification(supabase, connection, body, subscriptionKey)
        break
      default:
        console.log("⚠️ Unknown notification type, storing raw data")
        result = await storeRawNotification(supabase, connection, body, notificationType)
    }

    const duration = Date.now() - startTime
    console.log(`✅ Webhook processed: ${notificationType} (${duration}ms)`)

    return new Response(JSON.stringify({
      success: true,
      type: notificationType,
      ...result,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    })

  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in Suunto webhook:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    })
  }
})

// Detect notification type from payload
function detectNotificationType(body: any): string {
  // Check for explicit type field
  if (body.type) {
    if (body.type.includes('sleep')) return '247_sleep'
    if (body.type.includes('recovery')) return '247_recovery'
    if (body.type.includes('247') || body.type.includes('daily')) return '247_daily'
    if (body.type.includes('workout')) return 'workout'
  }
  
  // Check for workout-specific fields
  if (body.workoutid || body.workout_id) return 'workout'
  
  // Check for 247 data fields
  if (body.sleepData || body.sleep || body.sleepScore) return '247_sleep'
  if (body.recoveryData || body.recovery || body.recoveryScore) return '247_recovery'
  if (body.steps || body.dailyData || body.activeCalories) return '247_daily'
  
  // Check event field
  const event = body.event || ''
  if (event.includes('sleep')) return '247_sleep'
  if (event.includes('recovery')) return '247_recovery'
  if (event.includes('247') || event.includes('daily')) return '247_daily'
  
  return 'workout' // Default to workout
}

// Handle workout notification
async function handleWorkoutNotification(supabase: any, connection: any, body: any, subscriptionKey: string) {
  const workoutId = body.workoutid || body.workout_id || body.id
  
  if (!workoutId) {
    throw new Error("Missing workout ID")
  }

  console.log("➡️ Forwarding workout to suunto-activity-store:", workoutId)
  
  // Forward to suunto-activity-store which handles:
  // 1. Fetching workout details
  // 2. Storing activity
  // 3. Fetching/Storing FIT file
  // 4. Sending Notification
  
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Use service key for internal call
  
  const response = await fetch(`${supabaseUrl}/functions/v1/suunto-activity-store`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      user_id: connection.user_id,
      activity_id: workoutId
    })
  })
  
  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Failed to forward to store: ${response.status} - ${errorText}`)
  }
  
  const result = await response.json()
  console.log("✅ Forwarded successfully:", result)
  
  return { workout_id: workoutId, forwarded: true }
}

// Handle 247 daily activity notification
async function handle247DailyNotification(supabase: any, connection: any, body: any, subscriptionKey: string) {
  const date = body.date || new Date().toISOString().split('T')[0]
  
  console.log("📤 Processing 247 daily data for:", date)

  // Data might be in the webhook payload directly, or we need to fetch it
  let dailyData = body.data || body.dailyData || body
  
  // If not in payload, fetch from API
  if (!dailyData.steps && !dailyData.activeCalories) {
    const response = await fetch(`https://cloudapi.suunto.com/v2/247/daily/${date}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${connection.access_token}`,
        'Accept': 'application/json',
        'Ocp-Apim-Subscription-Key': subscriptionKey
      }
    })
    
    if (response.ok) {
      dailyData = await response.json()
    }
  }

  // Store in suunto_health_metrics table (raw data)
  // Trigger will auto-sync to unified health_metrics table
  const { error } = await supabase
    .from('suunto_health_metrics')
    .upsert({
      user_id: connection.user_id,
      metric_date: date,
      steps: dailyData.steps || dailyData.totalSteps,
      active_calories: dailyData.activeCalories || dailyData.calories,
      total_calories: dailyData.totalCalories,
      resting_heart_rate: dailyData.restingHr || dailyData.restingHeartRate,
      avg_heart_rate: dailyData.avgHr || dailyData.averageHeartRate,
      max_heart_rate: dailyData.maxHr || dailyData.maxHeartRate,
      min_heart_rate: dailyData.minHr || dailyData.minHeartRate,
      raw_daily_data: dailyData,
      updated_at: new Date().toISOString()
    }, { onConflict: 'user_id,metric_date' })

  if (error) {
    console.error("⚠️ Failed to store 247 daily data:", error.message)
  } else {
    console.log("✅ 247 daily data stored in suunto_health_metrics")
  }
  
  return { date, type: '247_daily' }
}

// Handle 247 sleep notification
async function handle247SleepNotification(supabase: any, connection: any, body: any, subscriptionKey: string) {
  const date = body.date || new Date().toISOString().split('T')[0]
  
  console.log("📤 Processing 247 sleep data for:", date)

  let sleepData = body.data || body.sleepData || body
  
  // If not in payload, fetch from API
  if (!sleepData.duration && !sleepData.sleepScore) {
    const response = await fetch(`https://cloudapi.suunto.com/v2/247/sleep/${date}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${connection.access_token}`,
        'Accept': 'application/json',
        'Ocp-Apim-Subscription-Key': subscriptionKey
      }
    })
    
    if (response.ok) {
      sleepData = await response.json()
    }
  }

  // Store in suunto_health_metrics table (raw data)
  // Trigger will auto-sync to unified health_metrics table
  const { error } = await supabase
    .from('suunto_health_metrics')
    .upsert({
      user_id: connection.user_id,
      metric_date: date,
      sleep_duration_seconds: sleepData.duration || sleepData.sleepDuration,
      sleep_score: sleepData.sleepScore || sleepData.quality,
      deep_sleep_seconds: sleepData.deepSleep || sleepData.deepSleepDuration,
      light_sleep_seconds: sleepData.lightSleep || sleepData.lightSleepDuration,
      rem_sleep_seconds: sleepData.remSleep || sleepData.remSleepDuration,
      awake_seconds: sleepData.awake || sleepData.awakeDuration,
      sleep_start_time: sleepData.startTime || sleepData.sleepStartTime,
      sleep_end_time: sleepData.endTime || sleepData.sleepEndTime,
      raw_sleep_data: sleepData,
      updated_at: new Date().toISOString()
    }, { onConflict: 'user_id,metric_date' })

  if (error) {
    console.error("⚠️ Failed to store 247 sleep data:", error.message)
  } else {
    console.log("✅ 247 sleep data stored in suunto_health_metrics")
  }
  
  return { date, type: '247_sleep' }
}

// Handle 247 recovery notification
async function handle247RecoveryNotification(supabase: any, connection: any, body: any, subscriptionKey: string) {
  const date = body.date || new Date().toISOString().split('T')[0]
  
  console.log("📤 Processing 247 recovery data for:", date)

  let recoveryData = body.data || body.recoveryData || body
  
  // If not in payload, fetch from API
  if (!recoveryData.recovery && !recoveryData.recoveryScore) {
    const response = await fetch(`https://cloudapi.suunto.com/v2/247/recovery/${date}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${connection.access_token}`,
        'Accept': 'application/json',
        'Ocp-Apim-Subscription-Key': subscriptionKey
      }
    })
    
    if (response.ok) {
      recoveryData = await response.json()
    }
  }

  // Store in suunto_health_metrics table (raw data)
  // Trigger will auto-sync to unified health_metrics table
  const { error } = await supabase
    .from('suunto_health_metrics')
    .upsert({
      user_id: connection.user_id,
      metric_date: date,
      recovery_score: recoveryData.recovery || recoveryData.recoveryScore,
      recovery_time_hours: recoveryData.recoveryTime || recoveryData.timeToRecovery,
      stress_level: recoveryData.stress || recoveryData.stressLevel,
      body_resources: recoveryData.bodyResources || recoveryData.resources,
      vo2_max: recoveryData.vo2Max || recoveryData.estimatedVo2Max,
      raw_recovery_data: recoveryData,
      updated_at: new Date().toISOString()
    }, { onConflict: 'user_id,metric_date' })

  if (error) {
    console.error("⚠️ Failed to store 247 recovery data:", error.message)
  } else {
    console.log("✅ 247 recovery data stored in suunto_health_metrics")
  }
  
  return { date, type: '247_recovery' }
}

// Store raw notification for unknown types
async function storeRawNotification(supabase: any, connection: any, body: any, type: string) {
  console.log("📦 Storing raw notification data for type:", type)
  // Just log it - don't try to store in health_metrics as schema might not match
  console.log("   Raw payload:", JSON.stringify(body).substring(0, 500))
  return { type: 'raw', logged: true }
}
