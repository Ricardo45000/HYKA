// ============================================================================
// Strava Activity Notification Service
// ============================================================================
//
// Purpose: Sends push notifications to iOS devices when new activities are stored
//
// Flow:
// 1. Called by strava-activity-store after activity is stored
// 2. Looks up user's device tokens from database
// 3. Sends push notification via Apple Push Notification service (APNs)
// 4. Notification includes deep link to activity and race performance
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// APNs configuration (same as Garmin)
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') || 'com.hyka.app'
const APNS_KEY_PATH = Deno.env.get('APNS_KEY_PATH')
const APNS_ENVIRONMENT = Deno.env.get('APNS_ENVIRONMENT') || 'production'

// APNs endpoints
const APNS_URL = APNS_ENVIRONMENT === 'development' 
  ? 'https://api.sandbox.push.apple.com'
  : 'https://api.push.apple.com'

/**
 * Generate JWT token for APNs authentication
 */
async function generateAPNsToken(): Promise<string> {
  if (!APNS_KEY_ID || !APNS_TEAM_ID) {
    throw new Error("APNS_KEY_ID and APNS_TEAM_ID must be set in environment variables")
  }
  
  let keyContent: string
  if (APNS_KEY_PATH) {
    try {
      keyContent = await Deno.readTextFile(APNS_KEY_PATH)
    } catch (error) {
      throw new Error(`Failed to read APNs key file: ${error.message}`)
    }
  } else if (Deno.env.get('APNS_KEY_CONTENT')) {
    keyContent = Deno.env.get('APNS_KEY_CONTENT')!
  } else {
    throw new Error("Either APNS_KEY_PATH or APNS_KEY_CONTENT must be set")
  }
  
  // Use djwt for proper ES256 signing
  // See garmin-activity-notify for full implementation
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
      ...data
    }
    
    const url = `${APNS_URL}/3/device/${deviceToken}`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'apns-topic': APNS_BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10'
      },
      body: JSON.stringify(payload)
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      console.error(`❌ APNs error: ${response.status} ${errorText}`)
      return false
    }
    
    return true
  } catch (error) {
    console.error("❌ Error sending APNs notification:", error)
    return false
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }
  
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  }
  
  try {
    const { userId, activityId, stravaActivityId, activityType, distanceMeters, activityName } = await req.json()
    
    if (!userId || !activityId) {
      return new Response(JSON.stringify({ error: "Missing userId or activityId" }), { status: 400, headers })
    }
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // 1. Fetch device tokens for the user
    const { data: devices, error: deviceError } = await supabase
      .from('user_devices')
      .select('device_token')
      .eq('user_id', userId)
      .eq('push_enabled', true)
    
    if (deviceError) {
      console.error("❌ Error fetching device tokens:", deviceError)
      return new Response(JSON.stringify({ error: deviceError.message }), { status: 500, headers })
    }
    
    if (!devices || devices.length === 0) {
      console.log(`ℹ️ No active device tokens found for user ${userId}`)
      return new Response(JSON.stringify({ message: "No device tokens found" }), { status: 200, headers })
    }
    
    // 2. Construct notification message
    const distanceKm = distanceMeters ? (distanceMeters / 1000).toFixed(1) : 'an unknown distance'
    const activityTitle = activityName || `${activityType || 'activity'}`
    const title = `🎉 Congrats on Your ${activityType || 'Activity'}!`
    const body = `Check out your ${distanceKm}km ${activityTitle} and see how it influences your upcoming race performance`
    const deepLink = `hyka://activity/${activityId}`
    
    // 3. Send notifications to all devices
    let successCount = 0
    for (const device of devices) {
      if (device.device_token) {
        const sent = await sendAPNsNotification(device.device_token, title, body, { 
          activity_id: activityId, 
          strava_activity_id: stravaActivityId,
          deep_link: deepLink 
        })
        if (sent) {
          successCount++
        }
      }
    }
    
    console.log(`✅ Sent ${successCount} notifications to user ${userId}`)
    return new Response(JSON.stringify({ message: `Notifications sent to ${successCount} devices` }), { status: 200, headers })
    
  } catch (error) {
    console.error("❌ Error in strava-activity-notify:", error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers })
  }
})

