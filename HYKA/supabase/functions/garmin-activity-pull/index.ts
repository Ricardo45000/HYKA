// ============================================================================
// Garmin Activity Pull (Correct OAuth 2.0 Flow)
// ============================================================================
//
// Purpose: Fetch activity data from Garmin using callbackUrl
//
// Flow:
// 1. Receive callbackUrl (includes temporary Pull Token)
// 2. Fetch activity summary from callbackUrl
// 3. Fetch activity details from callbackUrl/details
// 4. Forward to garmin-activity-store
//
// Reference: Garmin Connect API OAuth 2.0 DIAUTH specification
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("📥 Garmin Activity Pull started")
    
    const { callbackUrl, garminUserId, summaryId, accessToken } = await req.json()
    
    if (!callbackUrl) {
      console.error("❌ Missing callbackUrl")
      return new Response(JSON.stringify({ error: "Missing callbackUrl" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Validate callbackUrl is from Garmin (prevent test URLs or malicious URLs)
    try {
      const url = new URL(callbackUrl)
      if (!url.hostname.includes('garmin.com') && !url.hostname.includes('apis.garmin.com')) {
        console.error("❌ Invalid callbackUrl domain:", url.hostname)
        return new Response(JSON.stringify({ 
          error: "Invalid callbackUrl: must be from Garmin domain",
          received: url.hostname
        }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        })
      }
    } catch (urlError) {
      console.error("❌ Invalid callbackUrl format:", callbackUrl)
      return new Response(JSON.stringify({ 
        error: "Invalid callbackUrl format",
        details: urlError.message
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   Callback URL:", callbackUrl.substring(0, 100) + "...")
    console.log("   Summary ID:", summaryId || "not provided")
    console.log("   Garmin User ID:", garminUserId || "not provided")
    
    // Get access token if not provided (lookup from database)
    let garminAccessToken = accessToken
    if (!garminAccessToken && garminUserId) {
      console.log("   Looking up Garmin access token from database...")
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      const { data: connection } = await supabase
        .from('garmin_connections')
        .select('access_token')
        .eq('garmin_user_id', garminUserId)
        .single()
      
      if (connection?.access_token) {
        garminAccessToken = connection.access_token
        console.log("   ✅ Found access token in database")
      } else {
        console.log("   ⚠️ No access token found - will try without Authorization header")
      }
    }
    
    // 1. Fetch summary data using callbackUrl
    // Note: callbackUrl includes temporary token in query string, but we also include
    // OAuth access token in Authorization header for additional security
    console.log("🔄 Fetching activity summary...")
    const summaryHeaders: HeadersInit = {
      'Accept': 'application/json'
    }
    
    if (garminAccessToken) {
      summaryHeaders['Authorization'] = `Bearer ${garminAccessToken}`
      console.log("   Using OAuth access token in Authorization header")
    } else {
      console.log("   ⚠️ No access token available - using callbackUrl token only")
    }
    
    const summaryRes = await fetch(callbackUrl, {
      method: 'GET',
      headers: summaryHeaders
    })
    
    if (!summaryRes.ok) {
      const errorText = await summaryRes.text()
      console.error("❌ Summary fetch failed:", summaryRes.status, errorText)
      return new Response(JSON.stringify({ 
        error: "Summary fetch failed",
        status: summaryRes.status,
        details: errorText
      }), {
        status: 200, // Return 200 to prevent retries
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    const summary = await summaryRes.json()
    const activityType = summary.activityType || 'unknown'
    console.log("✅ Summary fetched:", {
      summaryId: summary.summaryId || summary.id,
      activityType: activityType,
      duration: summary.durationInSeconds
    })
    
    // Log activity type to help debug filtering issues
    console.log("   📋 Activity type received:", activityType)
    
    // Check if this is a running/hiking/walking activity (case-insensitive)
    const activityTypeLower = activityType.toLowerCase()
    const isRunningActivity = activityTypeLower.includes('running') || 
                             activityTypeLower.includes('hiking') || 
                             activityTypeLower.includes('walking')
    
    if (!isRunningActivity) {
      console.log("   ⚠️ Activity type is not Running/Hiking/Walking - will still process")
      console.log("   (No filtering in PULL - all activities are forwarded to STORE)")
    }
    
    // 2. Fetch details (samples) from callbackUrl/details
    console.log("🔄 Fetching activity details...")
    const detailsUrl = `${callbackUrl}/details`
    const detailsHeaders: HeadersInit = {
      'Accept': 'application/json'
    }
    
    if (garminAccessToken) {
      detailsHeaders['Authorization'] = `Bearer ${garminAccessToken}`
    }
    
    const detailsRes = await fetch(detailsUrl, {
      method: 'GET',
      headers: detailsHeaders
    })
    
    let details: any = null
    if (detailsRes.ok) {
      details = await detailsRes.json()
      console.log("✅ Details fetched:", {
        samplesCount: (details && details.samples && Array.isArray(details.samples)) ? details.samples.length : 0,
        hasSummary: !!(details && details.summary)
      })
    } else {
      const errorText = await detailsRes.text()
      console.log("⚠️ Details fetch failed (non-critical):", detailsRes.status, errorText)
      // Details are optional, continue without them
      // For ultra-runners (>24h), JSON may be truncated - FIT file will be used instead
    }
    
    // 3. Fetch FIT file (for ultra-runner activities >24 hours)
    // FIT files contain complete data when JSON payloads are truncated
    console.log("🔄 Checking for FIT file...")
    const fitFileUrl = `${callbackUrl}/file`
    const fitFileHeaders: HeadersInit = {
      'Accept': 'application/octet-stream'
    }
    
    if (garminAccessToken) {
      fitFileHeaders['Authorization'] = `Bearer ${garminAccessToken}`
    }
    
    const fitFileRes = await fetch(fitFileUrl, {
      method: 'GET',
      headers: fitFileHeaders
    })
    
    let fitFileData: ArrayBuffer | null = null
    if (fitFileRes.ok && fitFileRes.headers.get('content-type')?.includes('octet-stream')) {
      fitFileData = await fitFileRes.arrayBuffer()
      console.log("✅ FIT file fetched:", {
        size: fitFileData.byteLength,
        sizeMB: (fitFileData.byteLength / 1024 / 1024).toFixed(2)
      })
    } else {
      console.log("ℹ️ No FIT file available (or not needed)")
      // FIT files are optional - only needed for ultra-runner activities
    }
    
    // 3. Forward to store function
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    console.log("🔄 Forwarding to garmin-activity-store...")
    
    const storeResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${supabaseKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ 
        summary,
        details,
        garminUserId,
        callbackUrl,
        fitFileData: fitFileData ? Array.from(new Uint8Array(fitFileData)) : null // Convert ArrayBuffer to array for JSON
      })
    })
    
    if (!storeResponse.ok) {
      const errorText = await storeResponse.text()
      console.error("❌ Store function failed:", storeResponse.status, errorText)
      return new Response(JSON.stringify({ 
        error: "Store failed",
        status: storeResponse.status
      }), {
        status: 200, // Return 200 to prevent retries
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    const storeResult = await storeResponse.json()
    console.log("✅ Store function completed:", storeResult)
    
    // Check if this activity matches a pending backfill request
    // Activities from backfill requests will have summaryStartTimeInSeconds
    const activityStartTime = summary.summaryStartTimeInSeconds || 
                             summary.startTimeInSeconds ||
                             summary.startTimeGMTInSeconds
    
    if (activityStartTime && garminUserId) {
      // Look up HYKA user from garminUserId
      const { data: connection } = await supabase
        .from('garmin_connections')
        .select('user_id')
        .eq('garmin_user_id', garminUserId)
        .single()
      
      if (connection) {
        // Find pending backfill requests where this activity falls within the date range
        // Activity must be: start <= activity <= end
        // Use a wider range check to catch activities that might be slightly outside due to timezone issues
        const bufferSeconds = 24 * 60 * 60 // 1 day buffer for timezone issues
        const { data: matchingBackfills } = await supabase
          .from('garmin_backfill_requests')
          .select('id, summary_start_time_seconds, summary_end_time_seconds, created_at')
          .eq('user_id', connection.user_id)
          .eq('status', 'pending')
          .lte('summary_start_time_seconds', activityStartTime + bufferSeconds) // activity >= start (with buffer)
          .gte('summary_end_time_seconds', activityStartTime - bufferSeconds) // activity <= end (with buffer)
        
        console.log(`   Checking ${matchingBackfills?.length || 0} pending backfill requests for match`)
        if (matchingBackfills && matchingBackfills.length > 0) {
          console.log(`   Activity timestamp: ${activityStartTime} (${new Date(activityStartTime * 1000).toISOString()})`)
          for (const backfill of matchingBackfills) {
            console.log(`   Backfill range: ${backfill.summary_start_time_seconds} to ${backfill.summary_end_time_seconds}`)
            console.log(`   Backfill dates: ${new Date(backfill.summary_start_time_seconds * 1000).toISOString()} to ${new Date(backfill.summary_end_time_seconds * 1000).toISOString()}`)
          }
        }
        
        if (matchingBackfills && matchingBackfills.length > 0) {
          // Mark matching backfill requests as completed
          for (const backfill of matchingBackfills) {
            await supabase
              .from('garmin_backfill_requests')
              .update({ 
                status: 'completed',
                completed_at: new Date().toISOString()
              })
              .eq('id', backfill.id)
            
            console.log(`✅ Marked backfill request ${backfill.id} as completed (activity timestamp: ${activityStartTime})`)
          }
        }
      }
    }
    
    const duration = Date.now() - startTime
    console.log(`✅ Pull completed in ${duration}ms`)
    
    const samplesCount = (details && typeof details === 'object' && 'samples' in details && Array.isArray(details.samples)) 
      ? details.samples.length 
      : 0
    
    return new Response(JSON.stringify({
      success: true,
      summaryId: summary.summaryId || summary.id,
      samplesCount: samplesCount,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in pull function:", error)
    console.error("   Duration:", `${duration}ms`)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 200, // Return 200 to prevent retries
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

