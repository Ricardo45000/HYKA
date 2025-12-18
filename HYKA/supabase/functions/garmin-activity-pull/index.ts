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
// 4. Fetch FIT file from callbackUrl/file
// 5. Forward to garmin-activity-store
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
    
    // Check if callbackUrl is a direct FIT file URL (activityFile endpoint)
    // If so, we can't fetch summary from API (403 Forbidden with OAuth2)
    // Instead, we'll get summary from database or skip it (summary should already be stored from activities payload)
    let fitFileUrl = callbackUrl
    let shouldFetchSummary = true
    let shouldFetchDetails = true
    
    if (callbackUrl.includes('activityFile') || callbackUrl.includes('wellness-api/rest/activityFile')) {
      console.log("   ⚠️ CallbackUrl is a direct FIT file URL (activityFile endpoint)")
      console.log("   OAuth2 tokens cannot access activity-service endpoints (403 Forbidden)")
      console.log("   Summary should already be stored from activities payload")
      console.log("   Will only fetch FIT file and get summary from database if needed")
      
      fitFileUrl = callbackUrl // Use the original callbackUrl for FIT file (has token)
      shouldFetchSummary = false // Skip summary fetch (will fail with 403)
      shouldFetchDetails = false // Skip details fetch (will fail with 403)
    } else {
      // Base callbackUrl - can fetch summary, details, and file
      fitFileUrl = `${callbackUrl}/file`
    }
    
    // 1. Try to get summary from database first (if activity was already stored from activities payload)
    let summary: any = null
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    if (summaryId && garminUserId) {
      // Normalize activity ID (remove -file or -detail suffix)
      const normalizedActivityId = summaryId.replace(/-file$/, '').replace(/-detail$/, '')
      
      console.log("🔄 Looking up activity summary from database...")
      console.log(`   Normalized activity ID: ${normalizedActivityId}`)
      
      // Look up HYKA user from garminUserId
      const { data: connection } = await supabase
        .from('garmin_connections')
        .select('user_id')
        .eq('garmin_user_id', garminUserId)
        .single()
      
      if (connection) {
        // Get activity from database
        const { data: activity } = await supabase
          .from('garmin_activities')
          .select('*')
          .eq('user_id', connection.user_id)
          .eq('garmin_activity_id', normalizedActivityId)
          .single()
        
        if (activity && activity.raw_summary) {
          // Parse raw_summary JSON if it's a string
          if (typeof activity.raw_summary === 'string') {
            try {
              summary = JSON.parse(activity.raw_summary)
              console.log("✅ Found summary in database (parsed from JSON string)")
              console.log("   Summary keys:", Object.keys(summary).slice(0, 10))
              console.log("   Has distance:", !!(summary.distanceInMeters || summary.distance))
              console.log("   Has duration:", !!(summary.durationInSeconds || summary.elapsedDuration))
            } catch (e) {
              console.log("⚠️ Could not parse raw_summary from database:", e.message)
            }
          } else {
            summary = activity.raw_summary
            console.log("✅ Found summary in database (already object)")
            console.log("   Summary keys:", Object.keys(summary).slice(0, 10))
            console.log("   Has distance:", !!(summary.distanceInMeters || summary.distance))
            console.log("   Has duration:", !!(summary.durationInSeconds || summary.elapsedDuration))
          }
        } else {
          console.log("ℹ️ Activity not found in database yet (may arrive later from activities payload)")
        }
      }
    }
    
    // 2. If summary not in database and we have a base callbackUrl, try to fetch it
    if (!summary && shouldFetchSummary) {
      console.log("🔄 Fetching activity summary from callbackUrl...")
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
      
      if (summaryRes.ok) {
        summary = await summaryRes.json()
        const activityType = summary.activityType || 'unknown'
        console.log("✅ Summary fetched from callbackUrl:", {
          summaryId: summary.summaryId || summary.id,
          activityType: activityType,
          duration: summary.durationInSeconds
        })
      } else {
        const errorText = await summaryRes.text()
        console.log("⚠️ Summary fetch failed (non-critical):", summaryRes.status, errorText.substring(0, 200))
        // Continue without summary - it may be stored later from activities payload
      }
    }
    
    const activityType = summary?.activityType || 'unknown'
    
    // Log activity type if we have summary
    if (summary) {
      console.log("   📋 Activity type:", activityType)
    }
    
    // 2. Fetch details (samples) - only if we have a base callbackUrl (not activityFile URL)
    let details: any = null
    if (shouldFetchDetails && callbackUrl && !callbackUrl.includes('activityFile')) {
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
      
      if (detailsRes.ok) {
        details = await detailsRes.json()
        console.log("✅ Details fetched:", {
          samplesCount: (details && details.samples && Array.isArray(details.samples)) ? details.samples.length : 0,
          hasSummary: !!(details && details.summary)
        })
      } else {
        const errorText = await detailsRes.text()
        console.log("⚠️ Details fetch failed (non-critical):", detailsRes.status, errorText.substring(0, 200))
        // Details are optional, continue without them
        // For ultra-runners (>24h), JSON may be truncated - FIT file will be used instead
      }
    } else {
      console.log("ℹ️ Skipping details fetch (activityFile URL or not available)")
    }
    
    // 3. Fetch FIT file from fitFileUrl
    // FIT files contain complete data when JSON payloads are truncated
    console.log("🔄 Fetching FIT file...")
    const fitFileHeaders: HeadersInit = {
      'Accept': 'application/octet-stream'
    }
    
    if (garminAccessToken) {
      fitFileHeaders['Authorization'] = `Bearer ${garminAccessToken}`
    }
    
    let fitFileData: number[] | null = null
    try {
      const fitFileRes = await fetch(fitFileUrl, {
        method: 'GET',
        headers: fitFileHeaders
      })
      
      if (fitFileRes.ok) {
        const contentType = fitFileRes.headers.get('content-type') || ''
        console.log("   Content-Type:", contentType)
        
        if (contentType.includes('octet-stream') || contentType.includes('application/octet-stream') || contentType.includes('binary')) {
          const arrayBuffer = await fitFileRes.arrayBuffer()
          fitFileData = Array.from(new Uint8Array(arrayBuffer))
          
          console.log("✅ FIT file fetched:", {
            size: fitFileData.length,
            sizeMB: (fitFileData.length / 1024 / 1024).toFixed(2)
          })
          
          // Validate FIT file header (should start with 0x0E)
          if (fitFileData.length > 0 && fitFileData[0] === 0x0E) {
            console.log("   ✅ Valid FIT file header verified (0x0E)")
          } else {
            console.warn(`   ⚠️ FIT file header may be invalid (expected 0x0E, got: 0x${fitFileData[0]?.toString(16) || 'unknown'})`)
            console.warn("   Storing anyway - may be valid FIT file with different header format")
          }
        } else {
          console.log("   ℹ️ Response is not a binary file (Content-Type:", contentType, ")")
          console.log("   This might be an error response or the FIT file isn't available yet")
        }
      } else {
        const errorText = await fitFileRes.text()
        console.log("⚠️ FIT file fetch failed (non-critical):", fitFileRes.status)
        console.log("   Error:", errorText.substring(0, 200))
        // FIT files are optional - activity can be stored without them
      }
    } catch (fitFileErr) {
      console.error("❌ Error fetching FIT file:", fitFileErr)
      // Continue without FIT file - it's optional
    }
    
    // 4. Forward to store function
    // CRITICAL: Use summaryId (normalized) as the activity ID, not the ID from callbackUrl
    // The callbackUrl has an internal Garmin file ID (id=513229032532), not the activity ID
    // The activity ID should come from summaryId (e.g., "21272304081-file" -> "21272304081")
    let normalizedActivityIdForStore = summaryId
    if (normalizedActivityIdForStore) {
        // Remove -file or -detail suffix if present
        normalizedActivityIdForStore = normalizedActivityIdForStore.replace(/-file$/, '').replace(/-detail$/, '')
    } else if (summary?.summaryId || summary?.activityId || summary?.id) {
        // Fallback to summary ID if summaryId parameter not provided
        normalizedActivityIdForStore = (summary.summaryId || summary.activityId || summary.id)?.toString().replace(/-file$/, '').replace(/-detail$/, '') || null
    }
    
    console.log("🔄 Forwarding to garmin-activity-store...")
    console.log("   Summary:", !!summary, summary ? `(from ${summary.summaryId || summary.id || 'database'})` : 'not available')
    console.log("   Details:", !!details)
    console.log("   FIT file:", !!fitFileData, fitFileData ? `(${fitFileData.length} bytes)` : '')
    console.log("   Activity ID for store:", normalizedActivityIdForStore || 'will extract from callbackUrl')
    
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
        fitFileData: fitFileData, // Array of numbers (converted from ArrayBuffer)
        activityId: normalizedActivityIdForStore // Pass the correct activity ID
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
    const activityStartTime = summary?.summaryStartTimeInSeconds || 
                             summary?.startTimeInSeconds ||
                             summary?.startTimeGMTInSeconds ||
                             null
    
    if (activityStartTime && garminUserId && summary) {
      // Look up HYKA user from garminUserId
      const supabase = createClient(supabaseUrl, supabaseKey)
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
      summaryId: summary?.summaryId || summary?.id || summaryId || null,
      samplesCount: samplesCount,
      hasFitFile: !!fitFileData,
      fitFileSize: fitFileData ? fitFileData.length : 0,
      hasSummary: !!summary,
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

