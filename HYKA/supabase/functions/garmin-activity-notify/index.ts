// ============================================================================
// Garmin Activity Notification Service (With JWT Signing)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"

// APNs configuration
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') || 'app.hyka.com' // Updated to match bundle ID
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
  
  // Load key content from environment variable
  const keyContent = Deno.env.get('APNS_KEY_CONTENT')
  
  if (!keyContent) {
    throw new Error("APNS_KEY_CONTENT must be set in environment variables")
  }

  console.log("🔑 Processing APNs Key Content...")
  
  // Parse the PEM key content to a CryptoKey
  // We need to remove the header/footer and newlines for importKey
  let pemContents = keyContent
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "") // Remove all whitespace (newlines, spaces)

  console.log(`   Sanitized key length: ${pemContents.length}`)
  
  try {
    // Decode base64
    const binaryDerString = atob(pemContents)
    const binaryDer = new Uint8Array(binaryDerString.length)
    for (let i = 0; i < binaryDerString.length; i++) {
      binaryDer[i] = binaryDerString.charCodeAt(i)
    }
    
    console.log("   Key decoded successfully")

    const key = await crypto.subtle.importKey(
      "pkcs8",
      binaryDer,
      {
        name: "ECDSA",
        namedCurve: "P-256",
      },
      false,
      ["sign"]
    )
    
    console.log("   Key imported successfully")
    
    const header = { alg: "ES256", kid: APNS_KEY_ID }
    const payload = { 
      iss: APNS_TEAM_ID, 
      iat: getNumericDate(new Date()) 
    }
    
    // Sign with djwt
    const token = await create(header, payload, key)
    console.log("   JWT generated successfully")
    return token

  } catch (e) {
    console.error("❌ Error processing APNs key:", e)
    throw new Error(`Failed to process APNs key: ${e.message}`)
  }
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
      let errorData: any = {}
      try {
        errorData = JSON.parse(errorText)
      } catch (e) {
        // Not JSON, use raw text
      }
      
      console.error(`❌ APNs error: ${response.status} - ${errorText}`)
      console.error(`   Device token: ${deviceToken.substring(0, 8)}...${deviceToken.substring(deviceToken.length - 8)}`)
      console.error(`   APNs environment: ${APNS_ENVIRONMENT}`)
      console.error(`   Bundle ID: ${APNS_BUNDLE_ID}`)
      console.error(`   APNs URL: ${APNS_URL}`)
      
      // Handle specific APNs errors
      if (response.status === 410) {
        console.log(`ℹ️ Device token ${deviceToken.substring(0, 8)}... is no longer valid (uninstalled)`)
        // Ideally remove from database here
      } else if (response.status === 400 && errorData.reason === 'DeviceTokenNotForTopic') {
        console.error(`❌ DeviceTokenNotForTopic - Device token was registered with a different bundle ID:`)
        console.error(`   Current bundle ID: ${APNS_BUNDLE_ID}`)
        console.error(`   Device token: ${deviceToken.substring(0, 8)}...`)
        console.error(`   Fix: This token was registered with the old bundle ID. Delete it and re-register:`)
        console.error(`   1. Delete old tokens: DELETE FROM user_devices WHERE device_token = '${deviceToken}';`)
        console.error(`   2. User opens app → new token auto-registers with bundle ID ${APNS_BUNDLE_ID}`)
        // Mark token for deletion (we'll remove it from database)
        try {
          await supabase
            .from('user_devices')
            .delete()
            .eq('device_token', deviceToken)
          console.log(`   ✅ Removed invalid device token from database`)
        } catch (e) {
          console.error(`   ⚠️ Could not remove token from database: ${e.message}`)
        }
      } else if (response.status === 400 && errorData.reason === 'BadDeviceToken') {
        console.error(`❌ BadDeviceToken - Possible causes:`)
        console.error(`   1. Device token is invalid or expired`)
        console.error(`   2. Environment mismatch: Token is for ${APNS_ENVIRONMENT === 'development' ? 'sandbox' : 'production'}, but app might be using ${APNS_ENVIRONMENT === 'development' ? 'production' : 'sandbox'}`)
        console.error(`   3. Bundle ID mismatch: Expected ${APNS_BUNDLE_ID}`)
        console.error(`   4. Token format is incorrect (should be 64 hex characters)`)
        console.error(`   Token length: ${deviceToken.length} characters`)
      } else if (response.status === 403 && errorData.reason === 'BadEnvironmentKeyInToken') {
        console.error(`❌ BadEnvironmentKeyInToken - Key type doesn't match environment:`)
        console.error(`   Current environment: ${APNS_ENVIRONMENT}`)
        console.error(`   Current APNs URL: ${APNS_URL}`)
        console.error(`   Fix: Set APNS_ENVIRONMENT to match your key type:`)
        console.error(`   - Development/Sandbox key → APNS_ENVIRONMENT=development`)
        console.error(`   - Production key → APNS_ENVIRONMENT=production`)
        console.error(`   Run: npx supabase secrets set APNS_ENVIRONMENT=<development|production> --project-ref gvfhtiljkybbrbxoyqsq`)
      }
      
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
    let activityName = body.activity_name || "Your Run"
    let activityType = body.activity_type || "Running"
    let distanceMeters = body.distance_meters || 0
    let durationSeconds = body.duration_seconds || 0
    
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
    
    // If distance/duration are missing or zero, fetch from database
    if (distanceMeters === 0 || durationSeconds === 0) {
        console.log("⚠️ Missing distance/duration in payload, fetching from database...")
        const { data: activity, error: activityError } = await supabase
            .from('garmin_activities')
            .select('distance_meters, duration_seconds, activity_name, activity_type')
            .eq('id', activityId)
            .single()
        
        if (!activityError && activity) {
            if (distanceMeters === 0 && activity.distance_meters) {
                distanceMeters = activity.distance_meters
                console.log(`   ✅ Fetched distance: ${distanceMeters}m`)
            }
            if (durationSeconds === 0 && activity.duration_seconds) {
                durationSeconds = activity.duration_seconds
                console.log(`   ✅ Fetched duration: ${durationSeconds}s`)
            }
            if (activity.activity_name) activityName = activity.activity_name
            if (activity.activity_type) activityType = activity.activity_type
        } else {
            console.error("   ❌ Could not fetch activity from database:", activityError)
        }
    }
    
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
    
    // Calculate Pace (min/km)
    let paceString = "-:--"
    if (distanceMeters > 0 && durationSeconds > 0) {
        const distanceKmValue = distanceMeters / 1000
        const durationMinutesValue = durationSeconds / 60
        const paceDecimal = durationMinutesValue / distanceKmValue
        
        const paceMinutes = Math.floor(paceDecimal)
        const paceSeconds = Math.round((paceDecimal - paceMinutes) * 60)
        
        const paceSecondsString = paceSeconds < 10 ? `0${paceSeconds}` : `${paceSeconds}`
        paceString = `${paceMinutes}:${paceSecondsString}`
    }
    
    const title = `Distance: ${distanceKm} km - Pace: ${paceString} m/km`
    const bodyText = "Check your HYKA digital twin for your upcoming event"
    
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
    
    // 4. Check if APNs is configured
    const isAPNsConfigured = !!(APNS_KEY_ID && APNS_TEAM_ID && Deno.env.get('APNS_KEY_CONTENT'))
    
    if (!isAPNsConfigured) {
      console.log("ℹ️ APNs not configured - skipping push notifications")
      console.log("   To enable push notifications, configure APNS_KEY_ID, APNS_TEAM_ID, and APNS_KEY_CONTENT")
      return new Response(JSON.stringify({
        success: true,
        message: "APNs not configured - push notifications disabled",
        devices_notified: 0
      }), { status: 200, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
    }
    
    // 5. Send notifications to all devices
    let successCount = 0
    let failCount = 0
    
    for (const device of devices) {
      if (device.device_type === 'ios') {
        try {
          const success = await sendAPNsNotification(
            device.device_token,
            title,
            bodyText,
            deepLinkData
          )
          
          if (success) {
            successCount++
          } else {
            failCount++
          }
        } catch (error) {
          console.error(`❌ Error sending notification to device ${device.device_token.substring(0, 8)}...:`, error)
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
      status: 200, // Return 200 to prevent 503s
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
})

