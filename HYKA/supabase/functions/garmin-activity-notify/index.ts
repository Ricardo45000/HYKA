// ============================================================================
// Garmin Activity Notification Service
// ============================================================================
//
// Purpose: Sends push notifications to iOS devices when new activities are stored
//
// Flow:
// 1. Called by garmin-activity-store after activity is stored
// 2. Looks up user's device tokens from database
// 3. Sends push notification via Apple Push Notification service (APNs)
// 4. Notification includes deep link to activity and race performance
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// APNs configuration
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') || 'com.hyka.app'
const APNS_KEY_PATH = Deno.env.get('APNS_KEY_PATH') // Path to .p8 key file
const APNS_ENVIRONMENT = Deno.env.get('APNS_ENVIRONMENT') || 'production' // 'development' or 'production'

// APNs endpoints
const APNS_URL = APNS_ENVIRONMENT === 'development' 
  ? 'https://api.sandbox.push.apple.com'
  : 'https://api.push.apple.com'

/**
 * Generate JWT token for APNs authentication
 * 
 * To use this, you need to:
 * 1. Install djwt: Add import at top: import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"
 * 2. Store your .p8 key content in SUPABASE_SECRETS as APNS_KEY_CONTENT (or load from file)
 * 3. Use the key content to sign the JWT
 */
async function generateAPNsToken(): Promise<string> {
  if (!APNS_KEY_ID || !APNS_TEAM_ID) {
    throw new Error("APNS_KEY_ID and APNS_TEAM_ID must be set in environment variables")
  }
  
  // Option 1: Load key from file path (if APNS_KEY_PATH is set)
  let keyContent: string
  if (APNS_KEY_PATH) {
    try {
      keyContent = await Deno.readTextFile(APNS_KEY_PATH)
    } catch (error) {
      throw new Error(`Failed to read APNs key file: ${error.message}`)
    }
  } 
  // Option 2: Load key from environment variable (recommended for Supabase)
  else if (Deno.env.get('APNS_KEY_CONTENT')) {
    keyContent = Deno.env.get('APNS_KEY_CONTENT')!
  } else {
    throw new Error("Either APNS_KEY_PATH or APNS_KEY_CONTENT must be set")
  }
  
  // For now, we'll use a simple approach
  // In production, use djwt library for proper ES256 signing:
  // import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"
  // const header = { alg: "ES256", kid: APNS_KEY_ID }
  // const payload = { iss: APNS_TEAM_ID, iat: getNumericDate(new Date()) }
  // return await create(header, payload, keyContent)
  
  // Temporary implementation - you need to implement proper JWT signing
  // See PUSH_NOTIFICATIONS_SETUP.md for full implementation guide
  throw new Error("APNs JWT signing not yet implemented. Please install djwt and implement proper ES256 signing. See PUSH_NOTIFICATIONS_SETUP.md")
}

/**
 * Send push notification via APNs
 */
async function sendAPNsNotification(
  deviceToken: string,
  title: string,
  body: string,
  data: Record<string, any>
): Promise<boolean> {
  try {
    const token = await generateAPNsToken()
    
    const payload = {
      aps: {
        alert: {
          title: title,
          body: body
        },
        sound: "default",
        badge: 1,
        "content-available": 1
      },
      ...data // Custom data for deep linking
    }
    
    const url = `${APNS_URL}/3/device/${deviceToken}`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'apns-topic': APNS_BUNDLE_ID,
        'apns-priority': '10',
        'apns-push-type': 'alert',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      console.error(`❌ APNs error: ${response.status} - ${errorText}`)
      return false
    }
    
    console.log(`✅ Push notification sent to device: ${deviceToken.substring(0, 8)}...`)
    return true
  } catch (error) {
    console.error("❌ Error sending APNs notification:", error)
    return false
  }
}

serve(async (req) => {
  const startTime = Date.now()
  
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
        'Access-Control-Max-Age': '86400',
      },
    })
  }
  
  try {
    console.log("📱 Garmin Activity Notification Service started")
    
    const body = await req.json()
    const userId = body.user_id || body.userId
    const activityId = body.activity_id || body.activityId
    const activityName = body.activity_name || "Your Run"
    const activityType = body.activity_type || "Running"
    const distanceMeters = body.distance_meters || 0
    const durationSeconds = body.duration_seconds || 0
    
    if (!userId || !activityId) {
      return new Response(JSON.stringify({ 
        error: "Missing user_id or activity_id" 
      }), {
        status: 400,
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
    
    // 1. Get user's device tokens
    console.log("🔍 Looking up device tokens for user:", userId)
    const { data: devices, error: devicesError } = await supabase
      .from('user_devices')
      .select('device_token, device_type')
      .eq('user_id', userId)
      .eq('push_enabled', true)
    
    if (devicesError || !devices || devices.length === 0) {
      console.log("ℹ️ No device tokens found for user (push notifications disabled or no devices registered)")
      return new Response(JSON.stringify({
        success: true,
        message: "No devices registered for push notifications",
        devices_notified: 0
      }), {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    console.log(`📱 Found ${devices.length} device(s) for push notifications`)
    
    // 2. Format activity details for notification
    const distanceKm = (distanceMeters / 1000).toFixed(1)
    const durationMinutes = Math.floor(durationSeconds / 60)
    const durationHours = Math.floor(durationMinutes / 60)
    const durationDisplay = durationHours > 0 
      ? `${durationHours}h ${durationMinutes % 60}m`
      : `${durationMinutes}m`
    
    const title = "🎉 Congrats on Your Run!"
    const body = `Check out your ${distanceKm}km run and see how it influences your upcoming race performance`
    
    // 3. Prepare deep link data
    const deepLinkData = {
      type: "activity_completed",
      activity_id: activityId,
      activity_name: activityName,
      activity_type: activityType,
      distance_km: parseFloat(distanceKm),
      duration_seconds: durationSeconds,
      deep_link: `hyka://activity/${activityId}`
    }
    
    // 4. Send notifications to all devices
    let successCount = 0
    let failCount = 0
    
    for (const device of devices) {
      if (device.device_type === 'ios') {
        const success = await sendAPNsNotification(
          device.device_token,
          title,
          body,
          deepLinkData
        )
        
        if (success) {
          successCount++
        } else {
          failCount++
        }
      } else {
        console.log(`⚠️ Unsupported device type: ${device.device_type}`)
        failCount++
      }
    }
    
    const duration = Date.now() - startTime
    
    return new Response(JSON.stringify({
      success: true,
      message: `Notifications sent to ${successCount} device(s)`,
      devices_notified: successCount,
      devices_failed: failCount,
      total_devices: devices.length,
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
    console.error("❌ Error in notification service:", error)
    
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

