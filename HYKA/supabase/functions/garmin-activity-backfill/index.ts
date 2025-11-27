import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function isTokenExpired(expiresAt: string | null | undefined): boolean {
  if (!expiresAt) {
    return true // Assume expired if no expiration time
  }
  
  const expirationTime = new Date(expiresAt).getTime()
  const now = Date.now()
  const buffer = 5 * 60 * 1000 // 5 minutes buffer
  
  return now >= (expirationTime - buffer)
}

/**
 * Refreshes a Garmin OAuth 2.0 access token using the refresh token
 */
async function refreshGarminToken(
  userId: string,
  supabase: ReturnType<typeof createClient>
): Promise<{ success: boolean; access_token?: string; error?: string }> {
  try {
    console.log("🔄 Refreshing Garmin access token for user:", userId)
    
    // Step 1: Get current connection with refresh token
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
    
    // Step 2: Get Garmin OAuth credentials
    const clientId = Deno.env.get('GARMIN_CLIENT_ID')
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      console.error("❌ Missing Garmin OAuth credentials")
      return { success: false, error: "Garmin OAuth credentials not configured" }
    }
    
    // Step 3: Call Garmin token refresh endpoint
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
      
      // If refresh token is invalid, user needs to reconnect
      if (tokenResponse.status === 401 || tokenResponse.status === 400) {
        return { success: false, error: "Refresh token expired or invalid. User needs to reconnect Garmin." }
      }
      
      return { success: false, error: `Token refresh failed: ${tokenResponse.status} - ${errorText}` }
    }
    
    const tokenData = await tokenResponse.json()
    const newAccessToken = tokenData.access_token
    const newRefreshToken = tokenData.refresh_token || connection.refresh_token // Keep old if not provided
    const expiresIn = tokenData.expires_in
    
    console.log("✅ Token refreshed successfully")
    console.log("   New access token:", newAccessToken.substring(0, 20) + "...")
    console.log("   Expires in:", expiresIn, "seconds")
    
    // Step 4: Calculate new expiration time
    const expiresAt = expiresIn 
      ? new Date(Date.now() + (expiresIn - 600) * 1000).toISOString() // Subtract 600s buffer
      : null
    
    // Step 5: Update connection in database
    console.log("💾 Updating connection with new token...")
    
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
    
    console.log("✅ Connection updated with new token")
    
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

/**
 * Gets a valid access token, refreshing if necessary
 */
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
  
  try {
    console.log("📥 Garmin Activity Backfill started")
    
    const body = await req.json()
    const userId = body.user_id || body.userId
    const summaryStartTimeInSeconds = body.summary_start_time_seconds || body.summaryStartTimeInSeconds
    const summaryEndTimeInSeconds = body.summary_end_time_seconds || body.summaryEndTimeInSeconds
    const requestLast90Days = body.request_last_90_days || body.requestLast90Days || false
    const ignoreConnectionDate = body.ignore_connection_date || body.ignoreConnectionDate || false
    
    if (!userId) {
      console.error("❌ Missing user_id")
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   User ID:", userId)
    console.log("   Request last 90 days:", requestLast90Days)
    console.log("   Ignore connection date constraint:", ignoreConnectionDate)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Step 1: Lookup Garmin connection
    console.log("🔍 Looking up Garmin connection...")
    
    const { data: connection, error: connectionError } = await supabase
      .from('garmin_connections')
      .select('garmin_user_id, access_token, token_expires_at, connected_at, permission_revoked')
      .eq('user_id', userId)
      .single()
    
    if (connectionError || !connection) {
      console.error("❌ Connection not found:", connectionError)
      return new Response(JSON.stringify({ 
        error: "Garmin connection not found for user" 
      }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    if (connection.permission_revoked) {
      console.error("❌ Permissions revoked for user")
      return new Response(JSON.stringify({ 
        error: "Garmin permissions have been revoked" 
      }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("✅ Found connection for Garmin user:", connection.garmin_user_id)
    
    // Step 1.5: Check and refresh token if expired
    let accessToken = connection.access_token
    
    if (isTokenExpired(connection.token_expires_at)) {
      console.log("⚠️ Access token expired, refreshing...")
      
      const refreshedToken = await getValidAccessToken(userId, supabase)
      
      if (!refreshedToken) {
        console.error("❌ Failed to refresh token")
        return new Response(JSON.stringify({ 
          error: "Failed to refresh Garmin access token. Please reconnect Garmin." 
        }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      accessToken = refreshedToken
      console.log("✅ Token refreshed successfully")
    } else {
      console.log("✅ Access token is still valid")
    }
    
    // Step 2: Calculate date range
    // According to Garmin Activity API 1.2.3 documentation:
    // - Backfill CAN retrieve "historic data" = data uploaded BEFORE user's registration
    // - "User Connection Timing is NOT a Barrier" - even if user connected 2 days ago,
    //   you can still request data from before that connection
    // - Maximum 30 days per request
    // - User rate limit: 1 month since first user connection (frequency limit, not history depth)
    // - Garmin API will accept or reject based on actual data availability
    let startTimeSeconds: number
    let endTimeSeconds: number
    
    const MS_PER_SECOND = 1000;
    const MS_PER_DAY = 24 * 60 * 60 * MS_PER_SECOND;
    // Get connection date (for logging/info only - NOT a barrier for historic data requests)
    const connectedAtSeconds = connection.connected_at 
      ? Math.floor(new Date(connection.connected_at).getTime() / MS_PER_SECOND)
      : Math.floor(Date.now() / MS_PER_SECOND)
    
    const now = new Date()
    const nowSeconds = Math.floor(now.getTime() / MS_PER_SECOND)
    
    // Check if user wants to request last 90 days (split into 3 chunks)
    if (requestLast90Days) {
      console.log("📅 Requesting last 90 days in 3 chunks of 30 days each")
      console.log("   According to Garmin docs: 'Historic data' = data uploaded before user registration")
      console.log("   Connection date is NOT a barrier - we can request data from before connection")
      
      const results: Array<{
        chunk: number
        status: string
        message?: string
        start?: string
        end?: string
        error?: string
      }> = []
      
      // FIX: Use milliseconds arithmetic to correctly calculate 90 days ago in UTC,
      // avoiding issues with new Date().setDate() across time zones/months.
      const ninetyDaysInMs = 90 * MS_PER_DAY
      const start90DaysAgoRaw = Math.floor((now.getTime() - ninetyDaysInMs) / MS_PER_SECOND)
      
      // *** CRITICAL FIX: Use the later of 90 days ago or the connection time ***
      // Garmin enforces a "min start time" which is typically the connection date.
      // While Garmin docs say historic data can be requested, in practice they reject
      // requests that start before the connection date. Starting at the connection date
      // ensures compliance and prevents 400 Bad Request errors.
      const start90DaysAgo = Math.max(start90DaysAgoRaw, connectedAtSeconds)
      
      console.log("   Current time (now):", now.toISOString())
      console.log("   Raw 90 days ago:", new Date(start90DaysAgoRaw * MS_PER_SECOND).toISOString())
      console.log("   Connection date:", new Date(connectedAtSeconds * MS_PER_SECOND).toISOString())
      console.log("   Actual start (max of 90d ago or connection):", new Date(start90DaysAgo * MS_PER_SECOND).toISOString())
      console.log("   Time difference:", ((nowSeconds - start90DaysAgo) / (24 * 60 * 60)).toFixed(1), "days")
      
      if (start90DaysAgoRaw < connectedAtSeconds) {
        console.log("   ⚠️ 90 days ago is before connection date - using connection date as start")
        console.log("   This ensures compliance with Garmin's min start time requirement")
      } else {
        console.log("   ✅ Requesting from 90 days ago (connection date is earlier)")
      }
      
      // Make 3 requests: 90-60 days ago (oldest), 60-30 days ago (middle), 30-0 days ago (newest)
      // Request order: Start with oldest (chunk 0) to newest (chunk 2)
      const secondsPerDay = MS_PER_DAY / MS_PER_SECOND;
      for (let chunk = 0; chunk < 3; chunk++) {
        // Calculate chunk boundaries in seconds
        const chunkStart = start90DaysAgo + (chunk * 30 * secondsPerDay)
        const chunkEnd = Math.min(
          start90DaysAgo + ((chunk + 1) * 30 * secondsPerDay),
          nowSeconds
        )
        
        // Skip if chunk end is before start or too small
        if (chunkEnd <= chunkStart || (chunkEnd - chunkStart) < 60) {
          console.log(`   Skipping chunk ${chunk + 1} (too small)`)
          continue
        }
        
        console.log(`   Chunk ${chunk + 1}/3: ${new Date(chunkStart * MS_PER_SECOND).toISOString()} to ${new Date(chunkEnd * MS_PER_SECOND).toISOString()}`)
        
        // Check for existing request (informational only - don't block)
        const { data: existingRequest } = await supabase
          .from('garmin_backfill_requests')
          .select('id, status, created_at')
          .eq('user_id', userId)
          .eq('summary_start_time_seconds', chunkStart)
          .eq('summary_end_time_seconds', chunkEnd)
          .single()
        
        if (existingRequest) {
          const requestAge = existingRequest.created_at 
            ? (Date.now() - new Date(existingRequest.created_at).getTime()) / (1000 * 60 * 60 * 24) // Age in days
            : 0
          
          console.log(`   ℹ️ Chunk ${chunk + 1} was requested before (status: ${existingRequest.status}, age: ${requestAge.toFixed(1)} days)`)
          console.log(`   Proceeding anyway - you can call backfill whenever you want`)
        }
        
        // Record request
        await supabase
          .from('garmin_backfill_requests')
          .upsert({
            user_id: userId,
            summary_start_time_seconds: chunkStart,
            summary_end_time_seconds: chunkEnd,
            status: 'pending',
            created_at: new Date().toISOString()
          }, {
            onConflict: 'user_id,summary_start_time_seconds,summary_end_time_seconds'
          })
        
        // Make backfill request to Garmin
        const backfillUrl = new URL('https://apis.garmin.com/wellness-api/rest/backfill/activities')
        backfillUrl.searchParams.set('summaryStartTimeInSeconds', chunkStart.toString())
        backfillUrl.searchParams.set('summaryEndTimeInSeconds', chunkEnd.toString())
        
        const backfillResponse = await fetch(backfillUrl.toString(), {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/json'
          }
        })
        
        if (backfillResponse.status === 202) {
          console.log(`   ✅ Chunk ${chunk + 1} accepted (202)`)
          results.push({
            chunk: chunk + 1,
            status: 'accepted',
            start: new Date(chunkStart * MS_PER_SECOND).toISOString(),
            end: new Date(chunkEnd * MS_PER_SECOND).toISOString()
          })
        } else if (backfillResponse.status === 409) {
          console.log(`   ⚠️ Chunk ${chunk + 1} duplicate (409) - Garmin remembers this request`)
          console.log(`   Garmin's server remembers this date range from a previous request`)
          console.log(`   This is normal - Garmin remembers requests for weeks/months`)
          console.log(`   Garmin is likely still processing or has already processed this request`)
          console.log(`   Webhooks will arrive when activities are ready`)
          
          // Update our database to reflect that Garmin knows about this request
          await supabase
            .from('garmin_backfill_requests')
            .update({ 
              status: 'pending' // Keep as pending - Garmin is processing it
            })
            .eq('user_id', userId)
            .eq('summary_start_time_seconds', chunkStart)
            .eq('summary_end_time_seconds', chunkEnd)
          
          results.push({
            chunk: chunk + 1,
            status: 'duplicate',
            message: 'Garmin remembers this request - already being processed',
            note: 'Webhooks will arrive when activities are ready'
          })
        } else {
          const errorText = await backfillResponse.text()
          console.error(`   ❌ Chunk ${chunk + 1} failed:`, backfillResponse.status, errorText)
          results.push({
            chunk: chunk + 1,
            status: 'failed',
            error: errorText.substring(0, 200)
          })
        }
        
        // Small delay between requests to avoid rate limiting
        if (chunk < 2) {
          await new Promise(resolve => setTimeout(resolve, 1000)) // 1 second delay
        }
      }
      
      const duration = Date.now() - startTime
      const acceptedCount = results.filter(r => r.status === 'accepted').length
      const duplicateCount = results.filter(r => r.status === 'duplicate').length
      
      let message = `Requested 90 days in 3 chunks. ${acceptedCount}/3 chunks accepted.`
      if (duplicateCount > 0) {
        message += ` ${duplicateCount} chunk(s) were duplicates (Garmin already processing).`
      }
      
      return new Response(JSON.stringify({
        success: acceptedCount > 0 || duplicateCount > 0, // Success if accepted OR duplicate (Garmin is processing)
        message: message,
        chunks: results,
        total_chunks: 3,
        accepted_chunks: acceptedCount,
        duplicate_chunks: duplicateCount,
        duration: `${duration}ms`,
        note: duplicateCount > 0 
          ? "Some chunks were duplicates - Garmin is already processing these date ranges. Webhooks will arrive when activities are ready."
          : "Garmin will process each chunk asynchronously. Webhooks will be sent as activities are processed."
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Single request logic (existing behavior)
    if (summaryStartTimeInSeconds && summaryEndTimeInSeconds) {
      // Use provided date range as-is
      // Garmin allows requesting "historic data" from before connection date
      // The API will accept or reject based on actual data availability
      startTimeSeconds = summaryStartTimeInSeconds
      endTimeSeconds = summaryEndTimeInSeconds
      
      if (summaryStartTimeInSeconds < connectedAtSeconds) {
        console.log("   ℹ️ Requesting historic data from BEFORE connection date")
        console.log("   This is allowed by Garmin for data uploaded before user registration")
      }
    } else {
      // Calculate default: last 29 days from now
      // FIX: Use milliseconds arithmetic to correctly calculate 29 days ago in UTC.
      const twentyNineDaysInMs = 29 * MS_PER_DAY
      startTimeSeconds = Math.floor((now.getTime() - twentyNineDaysInMs) / MS_PER_SECOND)
      endTimeSeconds = nowSeconds
      
      // Log if we're requesting historic data
      if (startTimeSeconds < connectedAtSeconds) {
        console.log("   ℹ️ Default range includes historic data from before connection date")
      }
    }
    
    // Ensure end time is not in the future and is after start time
    endTimeSeconds = Math.min(endTimeSeconds, nowSeconds)
    const SECONDS_PER_DAY = MS_PER_DAY / MS_PER_SECOND;
    if (endTimeSeconds <= startTimeSeconds) {
      console.error("❌ Invalid date range: end time must be after start time")
      return new Response(JSON.stringify({ 
        error: "Invalid date range: end time must be after start time" 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Validate: Maximum 30 days per request (use 30.0 to account for time components)
    const daysDiff = (endTimeSeconds - startTimeSeconds) / SECONDS_PER_DAY
    if (daysDiff > 30.0) {
      console.error("❌ Date range exceeds 30 days:", daysDiff, "days")
      return new Response(JSON.stringify({ 
        error: `Date range exceeds 30 days: ${daysDiff.toFixed(1)} days. Split into multiple requests.` 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Validate: Maximum 3 hours per request (to avoid Garmin duplicate detection)
    const hoursDiff = (endTimeSeconds - startTimeSeconds) / 3600
    if (hoursDiff > 3.0) {
      console.error("❌ Date range exceeds 3 hours:", hoursDiff.toFixed(1), "hours")
      return new Response(JSON.stringify({ 
        error: `Date range exceeds 3 hours: ${hoursDiff.toFixed(1)} hours. Maximum is 3 hours to avoid duplicate requests.` 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // If range is too small (less than 1 minute), skip it
    // Note: Reduced from 1 hour to allow testing with recent connections
    // Garmin API will still decide if it accepts the request
    if (daysDiff < 1/(24 * 60)) {
      console.log("⚠️ Date range is too small (< 1 minute) - skipping backfill")
      return new Response(JSON.stringify({ 
        success: false,
        message: "Date range is too small (< 1 minute). Need at least 1 minute of data.",
        days_since_connection: ((nowSeconds - connectedAtSeconds) / SECONDS_PER_DAY).toFixed(2),
        range_seconds: endTimeSeconds - startTimeSeconds
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   Date range:", {
      start: new Date(startTimeSeconds * MS_PER_SECOND).toISOString(),
      end: new Date(endTimeSeconds * MS_PER_SECOND).toISOString(),
      connection: new Date(connectedAtSeconds * MS_PER_SECOND).toISOString(),
      days: daysDiff.toFixed(1),
      days_since_connection: ((nowSeconds - connectedAtSeconds) / SECONDS_PER_DAY).toFixed(1)
    })
    
    // Step 3: Check for existing backfill request (informational only - don't block)
    console.log("🔍 Checking for existing backfill request (informational)...")
    
    const { data: existingRequest } = await supabase
      .from('garmin_backfill_requests')
      .select('id, status, created_at')
      .eq('user_id', userId)
      .eq('summary_start_time_seconds', startTimeSeconds)
      .eq('summary_end_time_seconds', endTimeSeconds)
      .single()
    
    if (existingRequest) {
      const requestAge = existingRequest.created_at 
        ? (Date.now() - new Date(existingRequest.created_at).getTime()) / (1000 * 60 * 60 * 24) // Age in days
        : 0
      
      console.log(`   ℹ️ Found existing request: status=${existingRequest.status}, age=${requestAge.toFixed(1)} days`)
      console.log(`   Proceeding anyway - you can call backfill whenever you want`)
      console.log(`   If Garmin returns 409, they remember the request but will still process it`)
    } else {
      console.log(`   ℹ️ No existing request found - this is a new request`)
    }
    
    // Step 4: Record backfill request (for deduplication)
    await supabase
      .from('garmin_backfill_requests')
      .upsert({
        user_id: userId,
        summary_start_time_seconds: startTimeSeconds,
        summary_end_time_seconds: endTimeSeconds,
        status: 'pending',
        created_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,summary_start_time_seconds,summary_end_time_seconds'
      })
    
    // Step 5: Call official Garmin backfill endpoint
    console.log("🔄 Calling Garmin backfill endpoint...")
    
    const backfillUrl = new URL('https://apis.garmin.com/wellness-api/rest/backfill/activities')
    backfillUrl.searchParams.set('summaryStartTimeInSeconds', startTimeSeconds.toString())
    backfillUrl.searchParams.set('summaryEndTimeInSeconds', endTimeSeconds.toString())
    
    console.log("   URL:", backfillUrl.toString())
    
    const backfillResponse = await fetch(backfillUrl.toString(), {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })
    
    console.log("   Response status:", backfillResponse.status)
    
    // Step 6: Handle response
    if (backfillResponse.status === 202) {
      // Success: 202 Accepted (async processing)
      console.log("✅ Backfill request accepted (202)")
      console.log("   Garmin will process this asynchronously")
      console.log("   Webhooks will be sent as activities are processed")
      
      // Update backfill request status
      await supabase
        .from('garmin_backfill_requests')
        .update({ 
          status: 'pending',
          completed_at: null
        })
        .eq('user_id', userId)
        .eq('summary_start_time_seconds', startTimeSeconds)
        .eq('summary_end_time_seconds', endTimeSeconds)
      
      const duration = Date.now() - startTime
      
      return new Response(JSON.stringify({
        success: true,
        message: "Backfill request accepted",
        status: "pending",
        summary_start_time_seconds: startTimeSeconds,
        summary_end_time_seconds: endTimeSeconds,
        days: daysDiff.toFixed(1),
        note: "Garmin will process this asynchronously. Webhooks will be sent as activities are processed.",
        duration: `${duration}ms`
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
      
    } else if (backfillResponse.status === 409) {
      // Conflict: Duplicate request - Garmin remembers this request
      console.log("⚠️ Duplicate backfill request (409 Conflict)")
      console.log("   Garmin's server remembers this request from before")
      console.log("   This is normal - Garmin remembers requests for a long time (weeks/months)")
      console.log("   Garmin is likely still processing or has already processed this request")
      console.log("   Webhooks should arrive when activities are ready")
      
      // Check when this was last requested
      const { data: lastRequest } = await supabase
        .from('garmin_backfill_requests')
        .select('created_at')
        .eq('user_id', userId)
        .eq('summary_start_time_seconds', startTimeSeconds)
        .eq('summary_end_time_seconds', endTimeSeconds)
        .single()
      
      const lastRequestAge = lastRequest?.created_at 
        ? (Date.now() - new Date(lastRequest.created_at).getTime()) / (1000 * 60 * 60 * 24)
        : null
      
      await supabase
        .from('garmin_backfill_requests')
        .update({ status: 'pending' })
        .eq('user_id', userId)
        .eq('summary_start_time_seconds', startTimeSeconds)
        .eq('summary_end_time_seconds', endTimeSeconds)
      
      return new Response(JSON.stringify({
        success: true, // Treat as success - Garmin is processing it
        message: "Garmin remembers this request - it's already being processed",
        status: "pending",
        garmin_status: "duplicate_remembered",
        last_requested_days_ago: lastRequestAge ? lastRequestAge.toFixed(1) : null,
        note: "Garmin remembers backfill requests for a long time. This request is already in their system and will be processed. Webhooks will arrive when activities are ready. If you need to force a new request, wait 30+ days or contact Garmin support.",
        summary_start_time_seconds: startTimeSeconds,
        summary_end_time_seconds: endTimeSeconds
      }), {
        status: 200, // Return 200 instead of 409 - this is not really an error
        headers: { 'Content-Type': 'application/json' }
      })
      
    } else {
      // Error - Garmin API rejected the request
      const errorText = await backfillResponse.text()
      console.error("❌ Backfill request failed:", backfillResponse.status, errorText)
      
      // Parse Garmin's error message to extract minimum start time if provided
      let minStartTimeFromGarmin: number | null = null
      let errorMessage = "Backfill request failed"
      
      if (backfillResponse.status === 400) {
        // Try to parse "min start time" from error message
        // Format: "start 2025-09-20T15:42:26Z before min start time of 2025-10-19T16:42:30.333571500Z"
        const minStartTimeMatch = errorText.match(/min start time of ([0-9TZ.:-]+)/i)
        if (minStartTimeMatch) {
          try {
            const minStartTimeStr = minStartTimeMatch[1]
            minStartTimeFromGarmin = Math.floor(new Date(minStartTimeStr).getTime() / MS_PER_SECOND)
            console.log("   ℹ️ Garmin's minimum start time:", new Date(minStartTimeFromGarmin * MS_PER_SECOND).toISOString())
            console.log("   Connection date:", new Date(connectedAtSeconds * MS_PER_SECOND).toISOString())
            
            if (minStartTimeFromGarmin < connectedAtSeconds) {
              console.log("   ⚠️ Garmin allows data from BEFORE connection date")
              console.log("   This suggests 'user registration with partner program' happened earlier")
            } else if (minStartTimeFromGarmin > connectedAtSeconds) {
              console.log("   ⚠️ Garmin requires data from AFTER connection date")
            }
          } catch (e) {
            console.log("   Could not parse min start time from error:", e)
          }
        }
        
        errorMessage = "Invalid date range - start time is before Garmin's minimum allowed start time"
        if (minStartTimeFromGarmin) {
          errorMessage += ` (minimum: ${new Date(minStartTimeFromGarmin * MS_PER_SECOND).toISOString()})`
        }
      }
      
      await supabase
        .from('garmin_backfill_requests')
        .update({ 
          status: 'failed'
        })
        .eq('user_id', userId)
        .eq('summary_start_time_seconds', startTimeSeconds)
        .eq('summary_end_time_seconds', endTimeSeconds)
      
      return new Response(JSON.stringify({
        success: false,
        error: errorMessage,
        status: backfillResponse.status,
        details: errorText,
        requested_start: new Date(startTimeSeconds * MS_PER_SECOND).toISOString(),
        connection_date: new Date(connectedAtSeconds * MS_PER_SECOND).toISOString(),
        garmin_min_start_time: minStartTimeFromGarmin ? new Date(minStartTimeFromGarmin * MS_PER_SECOND).toISOString() : null
      }), {
        status: backfillResponse.status,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in backfill function:", error)
    console.error("   Duration:", `${duration}ms`)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
