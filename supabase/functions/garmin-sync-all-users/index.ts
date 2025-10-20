// Supabase Edge Function for syncing Garmin activities for all connected users
// This function runs periodically (via cron) to fetch new activities from Garmin
// 
// Garmin's Hybrid Approach:
// - OAuth 2.0 + PKCE for authentication (already done in garmin-token-exchange)
// - OAuth 1.0a HMAC-SHA1 for data access (this function)
// 
// Token mapping:
// - OAuth 2.0 access_token → OAuth 1.0a oauth_token
// - OAuth 2.0 refresh_token → OAuth 1.0a oauth_token_secret

import { createClient } from 'npm:@supabase/supabase-js@2'
import { makeOAuth1Request } from './oauth1.ts'

// Environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
const GARMIN_CONSUMER_KEY = Deno.env.get('GARMIN_CONSUMER_KEY') || ''
const GARMIN_CONSUMER_SECRET = Deno.env.get('GARMIN_CONSUMER_SECRET') || ''

// Garmin API endpoints (OAuth 1.0a for data access)
// Reference: Activity_API-1.2.3_0.pdf Section 7.1 - Activity Summaries
// Using the documented Wellness API endpoint: https://apis.garmin.com/wellness-api/rest/activities
const GARMIN_WELLNESS_API_ENDPOINT = 'https://apis.garmin.com/wellness-api/rest/activities'

interface GarminActivity {
  activityId: string
  activityName?: string
  activityType?: {
    typeId: number
    typeKey: string
  }
  startTimeGMT?: string
  startTimeLocal?: string
  distance?: number
  duration?: number
  elapsedDuration?: number
  averageHR?: number
  maxHR?: number
  calories?: number
  elevationGain?: number
  elevationLoss?: number
  averageSpeed?: number
  maxSpeed?: number
  [key: string]: any
}

// Fetch activities from Garmin using OAuth 1.0a HMAC-SHA1 signature
// Reference: Activity_API-1.2.3_0.pdf Section 7.1 - Activity Summaries
// Endpoint: GET https://apis.garmin.com/wellness-api/rest/activities
// Parameters: uploadStartTimeInSeconds, uploadEndTimeInSeconds (in SECONDS, not milliseconds!)
// 
// Token mapping:
// - accessToken (OAuth 2.0) → oauth_token (OAuth 1.0a)
// - refreshToken (OAuth 2.0) → oauth_token_secret (OAuth 1.0a)
async function fetchGarminActivities(
  accessToken: string, // OAuth 2.0 access_token → OAuth 1.0a oauth_token
  refreshToken: string, // OAuth 2.0 refresh_token → OAuth 1.0a oauth_token_secret
  userId: string,
  userName: string,
  afterDate?: Date
): Promise<GarminActivity[]> {
  const activities: GarminActivity[] = []
  
  try {
    // Use the documented Wellness API endpoint
    const url = GARMIN_WELLNESS_API_ENDPOINT
    
    // Calculate date range (SECONDS for Wellness API, not milliseconds!)
    const startDateSeconds = afterDate 
      ? Math.floor(afterDate.getTime() / 1000)
      : Math.floor((Date.now() - 90 * 24 * 60 * 60 * 1000) / 1000) // 90 days ago if no afterDate
    const endDateSeconds = Math.floor(Date.now() / 1000)
    
    console.log(`📅 Date range: ${new Date(startDateSeconds * 1000).toISOString()} to ${new Date(endDateSeconds * 1000).toISOString()}`)
    console.log(`📅 Date range (seconds): ${startDateSeconds} to ${endDateSeconds}`)
    
    // Check if date range exceeds 24 hours (Wellness API limit)
    const dateRangeSeconds = endDateSeconds - startDateSeconds
    if (dateRangeSeconds > 86400) {
      console.log(`⚠️ Date range (${dateRangeSeconds}s) exceeds 24h limit. Will chunk requests for ${userName}`)
      // Chunk into 24-hour periods
      return await fetchGarminActivitiesChunked(accessToken, refreshToken, userId, userName, afterDate)
    }
    
    // Build URL with query parameters (GET request as per documentation)
    const params = new URLSearchParams()
    params.append('uploadStartTimeInSeconds', String(startDateSeconds))
    params.append('uploadEndTimeInSeconds', String(endDateSeconds))
    params.append('limit', '100')
    params.append('start', '0')
    
    const fullUrl = `${url}?${params.toString()}`
    
    // Use OAuth 1.0a HMAC-SHA1 signature for data access
    // accessToken (OAuth 2.0) → oauth_token (OAuth 1.0a)
    // refreshToken (OAuth 2.0) → oauth_token_secret (OAuth 1.0a)
    if (!GARMIN_CONSUMER_KEY || !GARMIN_CONSUMER_SECRET) {
      throw new Error('GARMIN_CONSUMER_KEY and GARMIN_CONSUMER_SECRET must be set in environment variables')
    }
    
    const response = await makeOAuth1Request(
      fullUrl,
      'GET',
      GARMIN_CONSUMER_KEY,
      GARMIN_CONSUMER_SECRET,
      accessToken, // OAuth 2.0 access_token → OAuth 1.0a oauth_token
      refreshToken // OAuth 2.0 refresh_token → OAuth 1.0a oauth_token_secret
    )
    
    if (response.ok) {
      const responseText = await response.text()
      
      // Check if response is empty
      if (!responseText || responseText.trim() === '' || responseText === '{}') {
        console.log(`ℹ️ Wellness API returned empty response for ${userName}`)
        return []
      }
      
      try {
        const data = JSON.parse(responseText)
        
        // Handle different response formats (Wellness API typically returns array directly)
        if (Array.isArray(data)) {
          activities.push(...data)
        } else if (data.activities) {
          activities.push(...(Array.isArray(data.activities) ? data.activities : []))
        } else if (data.activityList) {
          activities.push(...(Array.isArray(data.activityList) ? data.activityList : []))
        } else if (data.data) {
          activities.push(...(Array.isArray(data.data) ? data.data : []))
        } else if (data.results) {
          activities.push(...(Array.isArray(data.results) ? data.results : []))
        } else if (data.items) {
          activities.push(...(Array.isArray(data.items) ? data.items : []))
        } else if (data.list) {
          activities.push(...(Array.isArray(data.list) ? data.list : []))
        }
        
        console.log(`✅ Fetched ${activities.length} activities from Wellness API for ${userName}`)
        if (activities.length > 0) {
          console.log(`   Sample activity IDs: ${activities.slice(0, 3).map(a => a.activityId).join(', ')}`)
        }
      } catch (parseError) {
        console.error(`⚠️ Failed to parse response for ${userName}:`, parseError)
        console.error(`Response text (first 500 chars): ${responseText.substring(0, 500)}`)
      }
    } else {
      const errorText = await response.text()
      console.error(`⚠️ Wellness API failed for ${userName}: ${response.status}`)
      console.error(`   Error response: ${errorText.substring(0, 1000)}`)
      
      // Check for specific error messages from Activity_API-1.2.3_0.pdf Appendix B
      try {
        const errorJson = JSON.parse(errorText)
        if (errorJson.errorMessage) {
          console.error(`❌ Error message: ${errorJson.errorMessage}`)
        }
      } catch {
        // Ignore parse errors
      }
    }
  } catch (error) {
    console.error(`❌ Error fetching from Wellness API for ${userName}:`, error)
    console.error(`   Error details: ${error instanceof Error ? error.message : String(error)}`)
  }
  
  console.log(`📊 Total activities fetched for ${userName}: ${activities.length}`)
  return activities
}

// Fetch activities in chunks when date range exceeds 24 hours (Wellness API limit)
async function fetchGarminActivitiesChunked(
  accessToken: string, // OAuth 2.0 access_token → OAuth 1.0a oauth_token
  refreshToken: string, // OAuth 2.0 refresh_token → OAuth 1.0a oauth_token_secret
  userId: string,
  userName: string,
  afterDate?: Date
): Promise<GarminActivity[]> {
  const allActivities: GarminActivity[] = []
  const chunkDuration = 86400 // 24 hours in seconds
  
  let currentStart = afterDate 
    ? Math.floor(afterDate.getTime() / 1000)
    : Math.floor((Date.now() - 365 * 24 * 60 * 60 * 1000) / 1000)
  const endDateSeconds = Math.floor(Date.now() / 1000)
  
  console.log(`📦 Chunking date range into 24-hour periods for ${userName}...`)
  
  while (currentStart < endDateSeconds) {
    const chunkEnd = Math.min(currentStart + chunkDuration, endDateSeconds)
    
    console.log(`📅 Fetching chunk for ${userName}: ${new Date(currentStart * 1000).toISOString()} to ${new Date(chunkEnd * 1000).toISOString()}`)
    
    try {
      const params = new URLSearchParams()
      params.append('uploadStartTimeInSeconds', String(currentStart))
      params.append('uploadEndTimeInSeconds', String(chunkEnd))
      params.append('limit', '100')
      params.append('start', '0')
      
      const fullUrl = `${GARMIN_WELLNESS_API_ENDPOINT}?${params.toString()}`
      
      // Use OAuth 1.0a HMAC-SHA1 signature for data access
      const response = await makeOAuth1Request(
        fullUrl,
        'GET',
        GARMIN_CONSUMER_KEY,
        GARMIN_CONSUMER_SECRET,
        accessToken, // OAuth 2.0 access_token → OAuth 1.0a oauth_token
        refreshToken // OAuth 2.0 refresh_token → OAuth 1.0a oauth_token_secret
      )
      
      if (response.ok) {
        const data = await response.json()
        
        if (Array.isArray(data)) {
          allActivities.push(...data)
        } else if (data.activities) {
          allActivities.push(...(Array.isArray(data.activities) ? data.activities : []))
        }
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500))
    } catch (error) {
      console.error(`⚠️ Error fetching chunk for ${userName}:`, error)
    }
    
    currentStart = chunkEnd
  }
  
  // Deduplicate by activity ID
  const uniqueActivities = Array.from(
    new Map(allActivities.map(activity => [activity.activityId, activity])).values()
  )
  
  console.log(`✅ Fetched ${allActivities.length} total activities, ${uniqueActivities.length} unique for ${userName}`)
  return uniqueActivities
}

// Store activities in Supabase
async function storeActivities(
  supabase: any,
  userId: string,
  activities: GarminActivity[]
): Promise<number> {
  let storedCount = 0
  let filteredCount = 0
  
  console.log(`📦 Processing ${activities.length} activities for storage...`)
  
  for (const activity of activities) {
    try {
      // Filter to only running, hiking, walking (matching iOS client filter)
      // Activity type must contain "Running", "Walking", or "Hiking" (case-insensitive)
      const activityType = activity.activityType?.typeKey?.toLowerCase() || ''
      const activityName = (activity.activityName || '').toLowerCase()
      
      // Target keywords to match (case-insensitive)
      const targetKeywords = ['running', 'walking', 'hiking']
      
      // Check if activity type contains any of the target keywords
      const typeMatches = targetKeywords.some(keyword => activityType.includes(keyword))
      
      // Check activity name as fallback
      const nameMatches = activityName && targetKeywords.some(keyword => activityName.includes(keyword))
      
      if (!typeMatches && !nameMatches) {
        filteredCount++
        continue
      }
      
      const workoutData = {
        user_id: userId,
        provider: 'garmin',
        provider_activity_id: activity.activityId,
        name: activity.activityName || 'Untitled Activity',
        distance_m: activity.distance || null,
        elapsed_seconds: activity.elapsedDuration || activity.duration || null,
        activity_type_code: activity.activityType?.typeKey || null,
        start_time: activity.startTimeGMT ? new Date(activity.startTimeGMT) : null,
        average_heart_rate: activity.averageHR || null,
        max_heart_rate: activity.maxHR || null,
        calories: activity.calories || null,
        elevation_gain_m: activity.elevationGain || null,
        elevation_loss_m: activity.elevationLoss || null,
        average_speed_mps: activity.averageSpeed || null,
        max_speed_mps: activity.maxSpeed || null,
      }
      
      const { error } = await supabase
        .from('workouts')
        .upsert(workoutData, {
          onConflict: 'user_id,provider,provider_activity_id',
        })
      
      if (error) {
        console.error(`   ❌ Error storing activity ${activity.activityId}:`, error)
      } else {
        storedCount++
        if (storedCount <= 5) {
          console.log(`   ✅ Stored activity: ${activity.activityId} (${activity.activityName || 'Untitled'})`)
        }
      }
    } catch (error) {
      console.error(`   ❌ Error processing activity ${activity.activityId}:`, error)
    }
  }
  
  console.log(`📊 Storage summary: ${storedCount} stored, ${filteredCount} filtered out, ${activities.length - storedCount - filteredCount} errors`)
  return storedCount
}

// Refresh OAuth 2.0 token if needed
async function refreshTokenIfNeeded(
  supabase: any,
  userId: string,
  accessToken: string,
  refreshToken: string | null
): Promise<string | null> {
  if (!refreshToken) {
    return accessToken // Can't refresh without refresh token
  }
  
  // Check if token is expired (you might want to check expires_at field)
  // For now, we'll try to use the current token and refresh if it fails
  
  // TODO: Implement token refresh logic using Garmin's token refresh endpoint
  // This requires Garmin's token refresh endpoint URL and client credentials
  
  return accessToken
}

// Main handler
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
    // Initialize Supabase client with service role key
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
      // Get all users with Garmin OAuth 2.0 connections
      // OAuth 2.0 connections store access_token and refresh_token
      // These will be used as oauth_token and oauth_token_secret for OAuth 1.0a data access
      const { data: connections, error: connectionsError } = await supabase
        .from('oauth_connections')
        .select('user_id, access_token, refresh_token, expires_at')
        .eq('provider', 'garmin')
        .not('access_token', 'is', null)
        .not('refresh_token', 'is', null)
    
    if (connectionsError) {
      console.error('Error fetching connections:', connectionsError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch connections' }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }
    
    if (!connections || connections.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No Garmin connections found', synced: 0 }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }
    
    console.log(`\n🔄 Starting sync for ${connections.length} user(s)`)
    console.log(`═══════════════════════════════════════`)
    
    let totalSynced = 0
    const results: Array<{ userId: string; success: boolean; count: number; error?: string }> = []
    
    // Sync activities for each user
    for (const connection of connections) {
      const userId = connection.user_id
      const accessToken = connection.access_token
      const refreshToken = connection.refresh_token
      
      // Fetch user profile to get name
      let userName = userId // Default to user ID if name not found
      try {
        const { data: profile } = await supabase
          .from('profiles')
          .select('first_name, last_name, email')
          .eq('id', userId)
          .single()
        
        if (profile) {
          if (profile.first_name || profile.last_name) {
            userName = `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || profile.email || userId
          } else if (profile.email) {
            userName = profile.email
          }
        }
      } catch (error) {
        // If profiles table doesn't exist or query fails, just use userId
        console.log(`   ⚠️ Could not fetch user profile, using user ID`)
      }
      
      if (!accessToken || !refreshToken) {
        console.error(`⚠️ No access token or refresh token for user ${userName} (${userId})`)
        results.push({ userId, success: false, count: 0, error: 'No access token or refresh token' })
        continue
      }
      
      try {
        console.log(`\n👤 Syncing activities for user: ${userName} (${userId})`)
        console.log(`   Using OAuth 1.0a HMAC-SHA1 for data access`)
        console.log(`   OAuth 2.0 access_token → OAuth 1.0a oauth_token`)
        console.log(`   OAuth 2.0 refresh_token → OAuth 1.0a oauth_token_secret`)
        
        // Get last sync timestamp (most recent workout)
        const { data: lastWorkout } = await supabase
          .from('workouts')
          .select('start_time')
          .eq('user_id', userId)
          .eq('provider', 'garmin')
          .order('start_time', { ascending: false })
          .limit(1)
          .single()
        
        // Fetch last 90 days if no previous workouts, otherwise fetch since last workout
        const afterDate = lastWorkout?.start_time 
          ? new Date(lastWorkout.start_time)
          : new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) // Last 90 days if no previous workouts
        
        console.log(`📅 Fetching activities for ${userName}`)
        console.log(`   Last workout: ${lastWorkout?.start_time || 'none'}`)
        console.log(`   Fetching from: ${afterDate.toISOString()}`)
        
        // Fetch activities from Garmin using OAuth 1.0a
        console.log(`🔄 Calling fetchGarminActivities for ${userName}...`)
        const activities = await fetchGarminActivities(accessToken, refreshToken, userId, userName, afterDate)
        console.log(`📥 Received ${activities.length} activities from Garmin API for ${userName}`)
        
        if (activities.length > 0) {
          console.log(`💾 Storing ${activities.length} activities for ${userName}...`)
          // Store activities
          const storedCount = await storeActivities(supabase, userId, activities)
          totalSynced += storedCount
          results.push({ userId, success: true, count: storedCount })
          console.log(`✅ Synced ${storedCount} activities for ${userName} (out of ${activities.length} fetched)`)
          
          if (storedCount < activities.length) {
            console.log(`⚠️ Only ${storedCount} out of ${activities.length} activities were stored for ${userName} (some may have been filtered or already exist)`)
          }
        } else {
          results.push({ userId, success: true, count: 0 })
          console.log(`ℹ️ No activities returned from Garmin API for ${userName}`)
          console.log(`   This could mean:`)
          console.log(`   - No activities in the last 90 days`)
          console.log(`   - Garmin API returned empty`)
          console.log(`   - OAuth token issue`)
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error)
        console.error(`❌ Error syncing user ${userName} (${userId}):`, errorMessage)
        results.push({ userId, success: false, count: 0, error: errorMessage })
      }
      
      // Add small delay between users to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000))
    }
    
    console.log(`\n═══════════════════════════════════════`)
    console.log(`✅ Sync complete: ${totalSynced} activities synced for ${connections.length} user(s)`)
    
    return new Response(
      JSON.stringify({
        success: true,
        totalUsers: connections.length,
        totalSynced,
        results,
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
    console.error('Error in garmin-sync-all-users:', error)
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

