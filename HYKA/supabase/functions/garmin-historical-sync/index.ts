// ============================================================================
// Garmin Historical Sync (30 Days)
// ============================================================================
//
// Purpose: Request 30 days of historical Garmin activities when user first connects
//
// Flow:
// 1. Called by iOS app after Garmin OAuth connection
// 2. Gets user's Garmin access token (refreshes if needed)
// 3. Requests last 30 days of activities from Garmin
// 4. Garmin processes asynchronously and sends webhooks
//
// Reference: Garmin Wellness API - Backfill Activities
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Token refresh utilities (inline - Supabase doesn't support _shared imports)
function isTokenExpired(expiresAt: string | null | undefined): boolean {
  if (!expiresAt) {
    return true // Assume expired if no expiration time
  }
  
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
    console.log("🔄 Refreshing Garmin access token for user:", userId)
    
    // Get current connection with refresh token
    const { data: connection, error: connectionError } = await supabase
      .from('garmin_connections')
      .select('id, refresh_token, garmin_user_id')
      .eq('user_id', userId)
      .single()
    
    if (connectionError || !connection) {
      console.error("❌ Connection not found:", connectionError)
      return { success: false, error: "Garmin connection not found" }
    }
    
    if (!connection.refresh_token) {
      console.error("❌ No refresh token available")
      return { success: false, error: "No refresh token available. User needs to reconnect Garmin." }
    }
    
    // Get Garmin OAuth credentials
    const clientId = Deno.env.get('GARMIN_CLIENT_ID')
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      console.error("❌ Missing Garmin OAuth credentials")
      return { success: false, error: "Garmin OAuth credentials not configured" }
    }
    
    // Call Garmin token refresh endpoint
    console.log("   Calling Garmin token refresh endpoint...")
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
      const errorText = await tokenResponse.text()
      console.error("❌ Token refresh failed:", tokenResponse.status, errorText)
      
      if (tokenResponse.status === 401 || tokenResponse.status === 400) {
        return { success: false, error: "Refresh token expired or invalid. User needs to reconnect Garmin." }
      }
      
      return { success: false, error: `Token refresh failed: ${tokenResponse.status} - ${errorText}` }
    }
    
    const tokenData = await tokenResponse.json()
    const newAccessToken = tokenData.access_token
    const newRefreshToken = tokenData.refresh_token || connection.refresh_token
    const expiresIn = tokenData.expires_in
    
    console.log("✅ Token refreshed successfully")
    
    // Calculate new expiration time
    const expiresAt = expiresIn 
      ? new Date(Date.now() + (expiresIn - 600) * 1000).toISOString() // Subtract 600s buffer
      : null
    
    // Update connection in database
    const { error: updateError } = await supabase
      .from('garmin_connections')
      .update({
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        token_expires_at: expiresAt,
        updated_at: new Date().toISOString()
      })
      .eq('user_id', userId)
    
    if (updateError) {
      console.error("❌ Failed to update connection:", updateError)
      return { success: false, error: `Failed to update connection: ${updateError.message}` }
    }
    
    return {
      success: true,
      access_token: newAccessToken
    }
    
  } catch (error) {
    console.error("❌ Error refreshing token:", error)
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error"
    }
  }
}

async function getValidAccessToken(
  userId: string,
  supabase: ReturnType<typeof createClient>
): Promise<string | null> {
  // Get connection
  const { data: connection, error } = await supabase
    .from('garmin_connections')
    .select('access_token, token_expires_at, refresh_token')
    .eq('user_id', userId)
    .single()
  
  if (error || !connection) {
    console.error("❌ Connection not found")
    return null
  }
  
  // Check if token is expired
  if (isTokenExpired(connection.token_expires_at)) {
    console.log("⚠️ Access token expired, refreshing...")
    
    const refreshResult = await refreshGarminToken(userId, supabase)
    
    if (!refreshResult.success || !refreshResult.access_token) {
      console.error("❌ Failed to refresh token:", refreshResult.error)
      return null
    }
    
    return refreshResult.access_token
  }
  
  // Token is still valid
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
    console.log("🔄 Garmin Historical Sync (30 days) started")
    
    const body = await req.json()
    const userId = body.user_id || body.userId
    
    if (!userId) {
      return new Response(JSON.stringify({ 
        error: "Missing user_id" 
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
    
    // Get valid access token (refreshes if needed)
    console.log("🔑 Getting valid Garmin access token...")
    const accessToken = await getValidAccessToken(userId, supabase)
    
    if (!accessToken) {
      return new Response(JSON.stringify({ 
        error: "Failed to get Garmin access token. User may need to reconnect Garmin." 
      }), {
        status: 401,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    console.log("✅ Access token obtained")
    
    // Calculate date range: last 30 days
    const now = Date.now()
    const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000) // 30 days in milliseconds
    const MS_PER_SECOND = 1000
    
    const summaryStartTimeInSeconds = Math.floor(thirtyDaysAgo / MS_PER_SECOND)
    const summaryEndTimeInSeconds = Math.floor(now / MS_PER_SECOND)
    
    console.log("📅 Requesting activities from last 30 days")
    console.log(`   Start: ${new Date(summaryStartTimeInSeconds * MS_PER_SECOND).toISOString()}`)
    console.log(`   End: ${new Date(summaryEndTimeInSeconds * MS_PER_SECOND).toISOString()}`)
    
    // Request backfill from Garmin
    const backfillUrl = new URL('https://apis.garmin.com/wellness-api/rest/backfill/activities')
    backfillUrl.searchParams.set('summaryStartTimeInSeconds', summaryStartTimeInSeconds.toString())
    backfillUrl.searchParams.set('summaryEndTimeInSeconds', summaryEndTimeInSeconds.toString())
    
    console.log("📡 Calling Garmin backfill endpoint...")
    const backfillResponse = await fetch(backfillUrl.toString(), {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })
    
    const duration = Date.now() - startTime
    
    if (backfillResponse.status === 202) {
      console.log("✅ Backfill request accepted (202)")
      console.log("   Garmin will process activities asynchronously")
      console.log("   Activities will arrive via webhooks when ready")
      
      // Record the request in database
      await supabase
        .from('garmin_backfill_requests')
        .upsert({
          user_id: userId,
          summary_start_time_seconds: summaryStartTimeInSeconds,
          summary_end_time_seconds: summaryEndTimeInSeconds,
          status: 'pending',
          created_at: new Date().toISOString()
        }, {
          onConflict: 'user_id,summary_start_time_seconds,summary_end_time_seconds'
        })
      
      return new Response(JSON.stringify({
        success: true,
        message: "Historical sync requested successfully",
        date_range: {
          start: new Date(summaryStartTimeInSeconds * MS_PER_SECOND).toISOString(),
          end: new Date(summaryEndTimeInSeconds * MS_PER_SECOND).toISOString(),
          days: 30
        },
        note: "Garmin will process activities asynchronously. Activities will arrive via webhooks when ready (usually within 15-60 minutes).",
        duration: `${duration}ms`
      }), {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    } else if (backfillResponse.status === 409) {
      console.log("⚠️ Backfill request duplicate (409)")
      console.log("   Garmin already remembers this date range")
      console.log("   Activities are likely already being processed or have been processed")
      
      // Update database to reflect duplicate
      await supabase
        .from('garmin_backfill_requests')
        .upsert({
          user_id: userId,
          summary_start_time_seconds: summaryStartTimeInSeconds,
          summary_end_time_seconds: summaryEndTimeInSeconds,
          status: 'pending', // Keep as pending - Garmin is processing
          created_at: new Date().toISOString()
        }, {
          onConflict: 'user_id,summary_start_time_seconds,summary_end_time_seconds'
        })
      
      return new Response(JSON.stringify({
        success: true,
        message: "Historical sync already requested",
        date_range: {
          start: new Date(summaryStartTimeInSeconds * MS_PER_SECOND).toISOString(),
          end: new Date(summaryEndTimeInSeconds * MS_PER_SECOND).toISOString(),
          days: 30
        },
        note: "Garmin remembers this request from before. Activities are being processed or have already been processed. Webhooks will arrive when activities are ready.",
        duration: `${duration}ms`
      }), {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    } else {
      const errorText = await backfillResponse.text()
      console.error("❌ Backfill request failed:", backfillResponse.status, errorText)
      
      return new Response(JSON.stringify({
        success: false,
        error: `Garmin backfill request failed: ${backfillResponse.status}`,
        error_details: errorText.substring(0, 500),
        duration: `${duration}ms`
      }), {
        status: backfillResponse.status,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in historical sync:", error)
    
    return new Response(JSON.stringify({
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
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

