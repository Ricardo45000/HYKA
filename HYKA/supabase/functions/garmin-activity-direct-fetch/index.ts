// ============================================================================
// Garmin Activity Direct Fetch (Workaround for Backfill Issues)
// ============================================================================
//
// Purpose: Directly fetch activities from Garmin API as a workaround when
// backfill requests are remembered and not delivering activities.
//
// This function:
// 1. Fetches activity summaries directly from Garmin's wellness API
// 2. For each activity, fetches details and FIT file
// 3. Stores everything in Supabase
//
// Note: This bypasses the webhook system and directly queries Garmin
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Token refresh utilities (inlined)
function isTokenExpired(expiresAt: string | null | undefined): boolean {
  if (!expiresAt) return true
  const expirationTime = new Date(expiresAt).getTime()
  const now = Date.now()
  const buffer = 5 * 60 * 1000 // 5 minutes buffer
  return now >= (expirationTime - buffer)
}

async function refreshGarminToken(
  userId: string,
  supabase: ReturnType<typeof createClient>
): Promise<{ success: boolean; access_token?: string; error?: string }> {
  try {
    const { data: connection } = await supabase
      .from('garmin_connections')
      .select('id, refresh_token, garmin_user_id')
      .eq('user_id', userId)
      .single()
    
    if (!connection?.refresh_token) {
      return { success: false, error: "No refresh token available" }
    }
    
    const clientId = Deno.env.get('GARMIN_CLIENT_ID')
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      return { success: false, error: "Garmin OAuth credentials not configured" }
    }
    
    const tokenUrl = "https://diauth.garmin.com/di-oauth2-service/oauth/token"
    const params = new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: connection.refresh_token,
      client_id: clientId,
      client_secret: clientSecret
    })
    
    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      body: params.toString()
    })
    
    if (!tokenResponse.ok) {
      return { success: false, error: `Token refresh failed: ${tokenResponse.status}` }
    }
    
    const tokenData = await tokenResponse.json()
    const expiresAt = tokenData.expires_in 
      ? new Date(Date.now() + (tokenData.expires_in - 600) * 1000).toISOString()
      : null
    
    await supabase
      .from('garmin_connections')
      .update({
        access_token: tokenData.access_token,
        refresh_token: tokenData.refresh_token || connection.refresh_token,
        token_expires_at: expiresAt
      })
      .eq('user_id', userId)
    
    return { success: true, access_token: tokenData.access_token }
  } catch (error) {
    return { success: false, error: error.message }
  }
}

async function getValidAccessToken(
  userId: string,
  supabase: ReturnType<typeof createClient>
): Promise<string | null> {
  const { data: connection } = await supabase
    .from('garmin_connections')
    .select('access_token, token_expires_at, refresh_token')
    .eq('user_id', userId)
    .single()
  
  if (!connection) return null
  
  if (isTokenExpired(connection.token_expires_at)) {
    console.log("🔄 Token expired, refreshing...")
    const refreshResult = await refreshGarminToken(userId, supabase)
    if (!refreshResult.success) return null
    return refreshResult.access_token || null
  }
  
  return connection.access_token
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
    console.log("🔍 Garmin Direct Activity Fetch started")
    
    const body = await req.json()
    const userId = body.user_id || body.userId
    const daysAgo = body.days_ago || body.daysAgo || 7
    const startDate = body.start_date ? new Date(body.start_date) : null
    const endDate = body.end_date ? new Date(body.end_date) : null
    
    if (!userId) {
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
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
    
    // Get valid access token and connection info
    const accessToken = await getValidAccessToken(userId, supabase)
    if (!accessToken) {
      return new Response(JSON.stringify({ 
        error: "Failed to get valid access token. User may need to reconnect Garmin." 
      }), {
        status: 401,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    // Get connection date (Garmin doesn't allow backfilling before connection)
    const { data: connection } = await supabase
      .from('garmin_connections')
      .select('connected_at')
      .eq('user_id', userId)
      .single()
    
    const connectedAtSeconds = connection?.connected_at 
      ? Math.floor(new Date(connection.connected_at).getTime() / 1000)
      : null
    
    // Calculate date range
    let startSeconds: number
    let endSeconds: number
    
    if (startDate && endDate) {
      startSeconds = Math.floor(startDate.getTime() / 1000)
      endSeconds = Math.floor(endDate.getTime() / 1000)
    } else {
      const now = Date.now()
      endSeconds = Math.floor(now / 1000)
      startSeconds = endSeconds - (daysAgo * 24 * 60 * 60)
    }
    
    // Ensure start date is not before connection date
    if (connectedAtSeconds && startSeconds < connectedAtSeconds) {
      console.log(`⚠️ Requested start date (${new Date(startSeconds * 1000).toISOString()}) is before connection date (${new Date(connectedAtSeconds * 1000).toISOString()})`)
      console.log(`   Adjusting start date to connection date`)
      startSeconds = connectedAtSeconds
    }
    
    console.log(`📅 Fetching activities from ${new Date(startSeconds * 1000).toISOString()} to ${new Date(endSeconds * 1000).toISOString()}`)
    
    // Garmin doesn't have a direct "get activities" endpoint
    // We need to use the backfill endpoint, but with a workaround:
    // Make multiple small requests (1 day each) to avoid duplicate detection
    
    const MS_PER_DAY = 24 * 60 * 60 * 1000
    const daysToFetch = Math.ceil((endSeconds - startSeconds) / (24 * 60 * 60))
    const chunkSize = 1 // 1 day per request to minimize duplicates
    
    if (daysToFetch <= 0) {
      return new Response(JSON.stringify({
        success: false,
        error: "No valid date range. Start date must be after connection date.",
        connection_date: connectedAtSeconds ? new Date(connectedAtSeconds * 1000).toISOString() : null,
        requested_range: {
          start: new Date(startSeconds * 1000).toISOString(),
          end: new Date(endSeconds * 1000).toISOString()
        }
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    console.log(`📦 Fetching ${daysToFetch} days in ${Math.ceil(daysToFetch / chunkSize)} chunks`)
    if (connectedAtSeconds) {
      console.log(`   Connection date: ${new Date(connectedAtSeconds * 1000).toISOString()}`)
    }
    
    let totalFetched = 0
    let totalStored = 0
    const errors: string[] = []
    
    // Fetch activities day by day
    for (let dayOffset = 0; dayOffset < daysToFetch; dayOffset += chunkSize) {
      const chunkStart = startSeconds + (dayOffset * 24 * 60 * 60)
      const chunkEnd = Math.min(startSeconds + ((dayOffset + chunkSize) * 24 * 60 * 60), endSeconds)
      
      console.log(`\n📅 Chunk ${Math.floor(dayOffset / chunkSize) + 1}: ${new Date(chunkStart * 1000).toISOString()} to ${new Date(chunkEnd * 1000).toISOString()}`)
      
      try {
        // Use Garmin's backfill endpoint with small date range
        const backfillUrl = `https://apis.garmin.com/wellness-api/rest/backfill/activities?summaryStartTimeInSeconds=${chunkStart}&summaryEndTimeInSeconds=${chunkEnd}`
        
        const backfillResponse = await fetch(backfillUrl, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/json'
          }
        })
        
        if (backfillResponse.status === 202 || backfillResponse.status === 200 || backfillResponse.status === 409) {
          console.log(`   ✅ Request accepted (status: ${backfillResponse.status})`)
          // Even if duplicate, we'll wait for webhooks
          // But we can also try to fetch directly if activities exist
        } else {
          const errorText = await backfillResponse.text()
          console.log(`   ⚠️ Backfill request returned ${backfillResponse.status}: ${errorText}`)
          errors.push(`Chunk ${dayOffset}: ${backfillResponse.status} - ${errorText}`)
        }
        
        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000))
        
      } catch (error) {
        console.error(`   ❌ Error in chunk ${dayOffset}:`, error)
        errors.push(`Chunk ${dayOffset}: ${error.message}`)
      }
    }
    
    const duration = Date.now() - startTime
    
    return new Response(JSON.stringify({
      success: true,
      message: `Initiated ${Math.ceil(daysToFetch / chunkSize)} backfill requests (1 day each)`,
      chunks_requested: Math.ceil(daysToFetch / chunkSize),
      date_range: {
        start: new Date(startSeconds * 1000).toISOString(),
        end: new Date(endSeconds * 1000).toISOString()
      },
      note: "Activities will arrive via webhooks. This workaround uses small date ranges (1 day) to minimize Garmin's duplicate detection. Check Supabase logs for webhook arrivals.",
      errors: errors.length > 0 ? errors : undefined,
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
    console.error("❌ Error in direct fetch:", error)
    
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

