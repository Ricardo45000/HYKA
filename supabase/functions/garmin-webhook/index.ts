// Supabase Edge Function for receiving Garmin Push Notifications (Webhooks)
// This function receives activity notifications from Garmin and fetches activity details
// Updated to use OAuth 2.0 PKCE Bearer tokens (no OAuth 1.0a required)

import { createClient } from 'npm:@supabase/supabase-js@2'

// Environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

// Garmin API base URLs (OAuth 2.0)
const GARMIN_CONNECT_API_BASE = 'https://connectapi.garmin.com/activity-service/activity'
const GARMIN_WELLNESS_API_BASE = 'https://apis.garmin.com/wellness-api/rest'

interface GarminWebhookPayload {
  activityId?: string
  activityName?: string
  userId?: string // Garmin user ID
  eventType?: string
  timestamp?: string
  // OAuth 2.0: We'll get the token from database, not from webhook payload
}

interface ActivityDetail {
  activityId: string
  activityName: string
  description?: string
  activityType?: {
    typeId: number
    typeKey: string
    parentTypeId?: number
  }
  startTimeGMT?: string
  startTimeLocal?: string
  distance?: number
  duration?: number
  elapsedDuration?: number
  movingDuration?: number
  elevationGain?: number
  elevationLoss?: number
  averageSpeed?: number
  maxSpeed?: number
  averageHR?: number
  maxHR?: number
  calories?: number
  [key: string]: any
}

// Fetch activity details from Garmin using OAuth 2.0 Bearer token
async function fetchActivityDetails(
  activityId: string,
  accessToken: string
): Promise<ActivityDetail | null> {
  // Try Connect API first
  const connectUrl = `${GARMIN_CONNECT_API_BASE}/${activityId}`
  
  try {
    const response = await fetch(connectUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json',
      },
    })

    if (response.ok) {
      const activityData = await response.json()
      console.log(`✅ Fetched activity ${activityId} from Connect API`)
      return activityData as ActivityDetail
    } else {
      const errorText = await response.text()
      console.error(`⚠️ Connect API failed for ${activityId}: ${response.status} ${errorText}`)
    }
  } catch (error) {
    console.error(`❌ Error fetching from Connect API for ${activityId}:`, error)
  }
  
  // Try Wellness API as fallback
  try {
    // First get Garmin user ID
    const userIdResponse = await fetch(`${GARMIN_WELLNESS_API_BASE}/user/id`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    })
    
    if (userIdResponse.ok) {
      const userIdData = await userIdResponse.json()
      const garminUserId = userIdData.userId || userIdData.user_id
      
      // Try to get activity details from Wellness API
      // Note: Wellness API might not have individual activity endpoint
      // We might need to fetch from activities list and filter
      const activitiesUrl = `${GARMIN_WELLNESS_API_BASE}/activities`
      const params = new URLSearchParams()
      params.append('limit', '100')
      params.append('start', '0')
      
      const activitiesResponse = await fetch(`${activitiesUrl}?${params.toString()}`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
        },
      })
      
      if (activitiesResponse.ok) {
        const activitiesData = await activitiesResponse.json()
        const activities = Array.isArray(activitiesData) ? activitiesData : activitiesData.activities || []
        
        // Find the specific activity
        const activity = activities.find((a: any) => 
          a.activityId === activityId || 
          a.activityId?.toString() === activityId ||
          a.id === activityId ||
          a.id?.toString() === activityId
        )
        
        if (activity) {
          console.log(`✅ Found activity ${activityId} in Wellness API`)
          return activity as ActivityDetail
        }
      }
    }
  } catch (error) {
    console.error(`❌ Error fetching from Wellness API for ${activityId}:`, error)
  }
  
  return null
}

// Store activity in Supabase
async function storeActivity(
  supabase: any,
  userId: string,
  activity: ActivityDetail
): Promise<void> {
  try {
    // Filter to only running, hiking, walking
    const activityType = activity.activityType?.typeKey?.toLowerCase() || ''
    const allowedTypes = ['running', 'hiking', 'walking', 'indoor_running', 'trail_running', 'treadmill_running']
    
    if (!allowedTypes.some(type => activityType.includes(type))) {
      console.log(`⏭️ Skipping activity ${activity.activityId} - type: ${activityType} (not running/hiking/walking)`)
      return
    }
    
    // Map Garmin activity to your workout schema
    const workoutData = {
      user_id: userId,
      provider: 'garmin',
      provider_activity_id: activity.activityId,
      name: activity.activityName || 'Untitled Activity',
      distance_m: activity.distance || null,
      elapsed_seconds: activity.elapsedDuration || activity.duration || null,
      activity_type_code: activityType || null,
      start_time: activity.startTimeGMT ? new Date(activity.startTimeGMT) : null,
      start_timezone_offset_minutes: null, // Calculate from startTimeLocal if available
      average_heart_rate: activity.averageHR || null,
      max_heart_rate: activity.maxHR || null,
      calories: activity.calories || null,
      elevation_gain_m: activity.elevationGain || null,
      elevation_loss_m: activity.elevationLoss || null,
      average_speed_mps: activity.averageSpeed || null,
      max_speed_mps: activity.maxSpeed || null,
    }

    // Upsert workout (insert or update if exists)
    const { error } = await supabase
      .from('workouts')
      .upsert(workoutData, {
        onConflict: 'user_id,provider,provider_activity_id',
      })

    if (error) {
      console.error('Error storing activity:', error)
      throw error
    }

    console.log(`✅ Stored activity ${activity.activityId} for user ${userId}`)
  } catch (error) {
    console.error('Error in storeActivity:', error)
    throw error
  }
}

// Main webhook handler
Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  try {
    // Parse webhook payload
    const payload: GarminWebhookPayload = await req.json()
    
    console.log('📥 Received Garmin webhook:', JSON.stringify(payload, null, 2))

    const { activityId, userId: garminUserId, eventType } = payload

    if (!activityId) {
      return new Response(
        JSON.stringify({ error: 'Missing activityId' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Initialize Supabase client with service role key (bypasses RLS)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Find user by Garmin user ID or activity ID
    // Option 1: If webhook provides Garmin user ID, we need to map it to our user_id
    // Option 2: Get all Garmin connections and try each one (less efficient but works)
    
    let targetUserId: string | null = null
    let accessToken: string | null = null

    // Try to find user by Garmin user ID if provided
    if (garminUserId) {
      // Note: You might need to store Garmin user ID in oauth_connections table
      // For now, we'll try to find by checking all connections
      const { data: connections } = await supabase
        .from('oauth_connections')
        .select('user_id, access_token')
        .eq('provider', 'garmin')
        .is('token_secret', null) // OAuth 2.0 doesn't have token_secret
      
      if (connections && connections.length > 0) {
        // Try the first connection (in production, you'd want to store Garmin user ID mapping)
        targetUserId = connections[0].user_id
        accessToken = connections[0].access_token
      }
    } else {
      // If no Garmin user ID, get all Garmin connections and try each one
      const { data: connections } = await supabase
        .from('oauth_connections')
        .select('user_id, access_token')
        .eq('provider', 'garmin')
        .is('token_secret', null) // OAuth 2.0 only
      
      if (connections && connections.length > 0) {
        // Try each connection until we find the activity
        for (const connection of connections) {
          if (connection.access_token) {
            const activity = await fetchActivityDetails(activityId, connection.access_token)
            if (activity) {
              targetUserId = connection.user_id
              accessToken = connection.access_token
              break
            }
          }
        }
      }
    }

    if (!targetUserId || !accessToken) {
      return new Response(
        JSON.stringify({ error: 'User not found or no valid OAuth 2.0 token' }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Fetch activity details from Garmin using OAuth 2.0
    console.log(`🔄 Fetching activity details for ${activityId} using OAuth 2.0...`)
    const activityDetails = await fetchActivityDetails(activityId, accessToken)

    if (!activityDetails) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch activity details' }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Store activity in Supabase
    await storeActivity(supabase, targetUserId, activityDetails)

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        activityId: activityDetails.activityId,
        message: 'Activity processed successfully',
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Error processing webhook:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
