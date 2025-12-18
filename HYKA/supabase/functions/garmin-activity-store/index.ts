// ============================================================================
// Garmin Activity Store (Complete Implementation)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("💾 Garmin Activity Store started")
    
    let requestBody = await req.json()
    console.log("   📥 Request body keys:", Object.keys(requestBody))
    console.log("   📥 Full request body:", JSON.stringify(requestBody, null, 2).substring(0, 1000))
    
    // CRITICAL: Preserve fitFileData from requestBody BEFORE destructuring
    // Large arrays might get lost during destructuring or JSON operations
    const originalFitFileData = requestBody.fitFileData || null
    
    // Also preserve activityId if provided by pull function
    const providedActivityId = requestBody.activityId || null
    
    let { summary, details, garminUserId, userId, callbackUrl, fitFileData, file, activityId: providedActivityIdFromBody } = requestBody
    
    // Use providedActivityId from requestBody if available (from pull function)
    const finalProvidedActivityId = providedActivityIdFromBody || providedActivityId || null
    
    // If fitFileData was lost during destructuring, restore it from original
    if (!fitFileData && originalFitFileData) {
        console.log("   ⚠️ fitFileData was lost during destructuring, restoring from original")
        fitFileData = originalFitFileData
    }
    
    // Log fitFileData immediately after extraction
    console.log("   🔍 fitFileData extraction check:")
    console.log(`      fitFileData in requestBody: ${!!requestBody.fitFileData}`)
    console.log(`      originalFitFileData preserved: ${!!originalFitFileData}`)
    console.log(`      fitFileData extracted: ${!!fitFileData}`)
    console.log(`      fitFileData type: ${fitFileData ? (Array.isArray(fitFileData) ? 'array' : typeof fitFileData) : 'null/undefined'}`)
    console.log(`      fitFileData length: ${fitFileData && Array.isArray(fitFileData) ? fitFileData.length : 'N/A'}`)
    if (fitFileData && Array.isArray(fitFileData) && fitFileData.length > 0) {
        console.log(`      fitFileData first 5 bytes: [${fitFileData.slice(0, 5).join(', ')}]`)
    }
    
    // Store original summary to check if it came from request body
    const originalSummary = summary
    
    // Log what we received for debugging
    console.log("   📥 Received payload types:", {
        hasSummary: !!summary,
        hasFile: !!file,
        hasDetails: !!details,
        hasFitFileData: !!fitFileData,
        hasCallbackUrl: !!callbackUrl
    })
    
    if (summary) {
        console.log("   📋 SUMMARY payload received - keys:", Object.keys(summary).slice(0, 10))
        console.log("   📋 SUMMARY data preview:", {
            activityId: summary.activityId || summary.summaryId || summary.id,
            activityName: summary.activityName || summary.name,
            activityType: summary.activityType || summary.type,
            distance: summary.distanceInMeters || summary.distance,
            duration: summary.durationInSeconds || summary.elapsedDuration
        })
    }
    
    // Handle 'file' payload from PUSH (it contains the callbackUrl and summaryId)
    // IMPORTANT: File payload often contains activity data too (activityType, activityName, etc.)
    // BUT: File payloads don't have distance/duration - we need to wait for the actual summary payload
    if (file && !originalSummary) {
        console.log("   Processing FILE payload (no summary yet)")
        console.log("   ⚠️ FILE payload has no distance/duration - will wait for SUMMARY payload")
        // Create a minimal summary from file payload for ID extraction, but mark it as incomplete
        summary = {
            summaryId: file.summaryId || file.id || file.activityId?.toString(),
            activityId: file.activityId?.toString() || file.summaryId || file.id,
            startTimeInSeconds: file.startTimeInSeconds,
            activityName: file.activityName,
            activityType: file.activityType,
            activityTypeKey: file.activityType,
            deviceName: file.deviceName,
            // Explicitly mark as incomplete - no distance/duration
            distanceInMeters: 0,
            durationInSeconds: 0,
            _isFilePayloadOnly: true // Flag to indicate this came from file payload only
        }
    }

    // Handle 'details' payload only (if summary is missing but details exists)
    if (details && !summary) {
        console.log("   Processing DETAILS payload (no summary yet)")
        summary = {
            summaryId: details.summaryId || details.activityId?.toString(),
            activityId: details.activityId?.toString() || details.summaryId,
            startTimeInSeconds: details.startTimeInSeconds,
            activityName: details.activityName,
            activityType: details.activityType,
            activityTypeKey: details.activityTypeKey
        }
    }
    
    // If we have BOTH file and summary, merge them (summary takes precedence)
    if (file && summary) {
        console.log("   📦 Both file and summary payloads received - merging (summary takes precedence)")
        // Summary already has the data, but ensure we have callbackUrl from file
        if (file.callbackURL || file.callbackUrl) {
            callbackUrl = file.callbackURL || file.callbackUrl || callbackUrl
            console.log("   📎 Using callbackUrl from file payload:", callbackUrl)
        }
    }
    
    // Log summary structure for debugging
    if (summary) {
        console.log("   📋 Summary keys:", Object.keys(summary))
        console.log("   📋 Summary sample:", JSON.stringify({
            summaryId: summary.summaryId || summary.id || summary.activityId,
            activityName: summary.activityName || summary.name,
            activityType: summary.activityType || summary.type || summary.sportType,
            distance: summary.distanceInMeters || summary.distance,
            duration: summary.durationInSeconds || summary.elapsedDuration,
            hasCallbackUrl: !!callbackUrl
        }, null, 2))
    }
    
    // If we have summary but no callbackUrl, try to extract it from summary
    // Note: Garmin uses both callbackUrl and callbackURL (capital)
    if (summary && !callbackUrl) {
        callbackUrl = summary.callbackURL || summary.callbackUrl || summary.file?.callbackURL || summary.file?.callbackUrl || null
        if (callbackUrl) {
            console.log("   📎 Found callbackUrl in summary:", callbackUrl)
        }
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // 1. Find HYKA user & Access Token
    let userAccessToken: string | null = null
    
    if (garminUserId) {
      console.log("🔍 Looking up HYKA user for Garmin user:", garminUserId)
      
      const { data: connection, error: lookupError } = await supabase
        .from('garmin_connections')
        .select('user_id, access_token, refresh_token, token_expires_at')
        .eq('garmin_user_id', garminUserId)
        .maybeSingle() // Use maybeSingle to avoid error if not found
      
      if (lookupError) {
        console.error("❌ Error looking up connection:", lookupError)
        return new Response(JSON.stringify({ 
          success: false, 
          error: "Connection lookup failed",
          details: lookupError.message 
        }), { 
          status: 200, 
          headers: { 'Content-Type': 'application/json' } 
        })
      }
      
      if (!connection) {
        console.error("❌ No Garmin connection found for garmin_user_id:", garminUserId)
        console.error("   User needs to connect Garmin in the app first")
        return new Response(JSON.stringify({ 
          success: false, 
          error: "No Garmin connection found",
          message: "User must connect Garmin in the app before activities can be stored",
          garmin_user_id: garminUserId
        }), { 
          status: 200, 
          headers: { 'Content-Type': 'application/json' } 
        })
      }
      
      userId = connection.user_id
      userAccessToken = connection.access_token
      
      // Check for token expiration and refresh if needed
      if (connection.token_expires_at && connection.refresh_token) {
        const expiresAt = new Date(connection.token_expires_at).getTime()
        const now = Date.now()
        const timeUntilExpiry = expiresAt - now
        const fiveMinutes = 5 * 60 * 1000
        
        console.log(`   Token expires at: ${new Date(expiresAt).toISOString()}`)
        console.log(`   Current time: ${new Date(now).toISOString()}`)
        console.log(`   Time until expiry: ${Math.round(timeUntilExpiry / 1000)}s`)
        
        // Refresh if expired or expiring in the next 5 minutes
        if (now >= expiresAt - fiveMinutes) {
            console.log("   ⚠️ Access token is expired or expiring soon. Refreshing...")
            try {
                // Refresh token logic
                const clientId = Deno.env.get('GARMIN_CLIENT_ID') || Deno.env.get('GARMIN_CONSUMER_KEY')
                const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET') || Deno.env.get('GARMIN_CONSUMER_SECRET')
                
                if (!clientId || !clientSecret) {
                    console.error("   ❌ Missing GARMIN_CLIENT_ID or GARMIN_CLIENT_SECRET in secrets")
                    console.error("   Set them with: npx supabase secrets set GARMIN_CLIENT_ID=... GARMIN_CLIENT_SECRET=...")
                } else {
                    console.log("   🔄 Attempting token refresh...")
                    const tokenUrl = 'https://diauth.garmin.com/di-oauth2-service/oauth/token'
                    
                    // Decode refresh token if it's base64 encoded
                    let refreshToken = connection.refresh_token
                    try {
                        // Check if it's base64 encoded JSON
                        const decoded = atob(refreshToken)
                        const parsed = JSON.parse(decoded)
                        if (parsed.refreshTokenValue) {
                            refreshToken = parsed.refreshTokenValue
                            console.log("   📦 Decoded refresh token from base64 JSON")
                        }
                    } catch (e) {
                        // Not base64 encoded, use as-is
                        console.log("   📦 Using refresh token as-is (not base64)")
                    }
                    
                    const refreshResponse = await fetch(tokenUrl, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/x-www-form-urlencoded',
                        },
                        body: new URLSearchParams({
                            refresh_token: refreshToken,
                            client_id: clientId,
                            client_secret: clientSecret,
                            grant_type: 'refresh_token'
                        })
                    })
                    
                    if (refreshResponse.ok) {
                        const tokens = await refreshResponse.json()
                        console.log("   ✅ Token refreshed successfully")
                        console.log("   📊 New token expires in:", tokens.expires_in || 3600, "seconds")
                        
                        // Update local variable
                        userAccessToken = tokens.access_token
                        
                        // Calculate new expiration
                        const expiresIn = tokens.expires_in || 3600
                        const newExpiresAt = new Date(now + expiresIn * 1000).toISOString()
                        
                        // Update database
                        const { error: updateError } = await supabase
                            .from('garmin_connections')
                            .update({
                                access_token: tokens.access_token,
                                refresh_token: tokens.refresh_token || connection.refresh_token, // Keep old if not provided
                                token_expires_at: newExpiresAt,
                                updated_at: new Date().toISOString()
                            })
                            .eq('user_id', userId)
                            
                        if (updateError) {
                            console.error("   ❌ Failed to update refreshed tokens in database:", updateError)
                        } else {
                            console.log("   💾 Refreshed tokens saved to database")
                            console.log("   ✅ New token will be used for API calls")
                        }
                    } else {
                        const errorText = await refreshResponse.text()
                        console.error(`   ❌ Token refresh failed: ${refreshResponse.status}`)
                        console.error(`   Error response: ${errorText.substring(0, 500)}`)
                        console.error("   ⚠️ Will attempt to use expired token (may fail with 401)")
                    }
                }
            } catch (e) {
                console.error("   ❌ Error refreshing token:", e)
                console.error("   ⚠️ Will attempt to use expired token (may fail with 401)")
            }
        } else {
            console.log("   ✅ Token is still valid")
        }
      } else {
        if (!connection.token_expires_at) {
            console.warn("   ⚠️ No token_expires_at in database - cannot check expiration")
        }
        if (!connection.refresh_token) {
            console.warn("   ⚠️ No refresh_token in database - cannot refresh")
        }
      }
      
      console.log("✅ Found HYKA user:", userId)
      console.log("   Access token present:", !!userAccessToken)
    } else if (!userId) {
      console.error("❌ Missing garminUserId in request")
      return new Response(JSON.stringify({ 
        success: false,
        error: "Missing garminUserId" 
      }), { 
        status: 200, 
        headers: { 'Content-Type': 'application/json' } 
      })
    }

    // 2. Extract and Normalize Activity ID
    // Priority: 1) finalProvidedActivityId (from pull function), 2) summary, 3) callbackUrl (but use summaryId, not id param)
    let rawActivityId: string | null = null
    
    // First, use activityId provided by pull function (most reliable)
    if (finalProvidedActivityId) {
        rawActivityId = finalProvidedActivityId.toString()
        console.log(`   ✅ Using activity ID provided by pull function: ${rawActivityId}`)
    }
    
    // Second, try to get from summary
    if (!rawActivityId && summary) {
        rawActivityId = summary.summaryId?.toString() || summary.id?.toString() || summary.activityId?.toString() || null
    }
    
    // Third, if we have callbackUrl but no summary, try to extract from summaryId in callbackUrl
    // NOTE: Don't use the 'id' parameter in callbackUrl - that's an internal Garmin file ID, not the activity ID
    // The activity ID should come from summaryId parameter passed by push function
    if (!rawActivityId && callbackUrl) {
        // Try to extract summaryId from callbackUrl if it's in the format: ...?summaryId=... or ...&summaryId=...
        const summaryIdMatch = callbackUrl.match(/[?&]summaryId=([^&]+)/)
        if (summaryIdMatch && summaryIdMatch[1]) {
            rawActivityId = summaryIdMatch[1].replace(/-file$/, '').replace(/-detail$/, '')
            console.log(`   ✅ Extracted activity ID from callbackUrl summaryId: ${rawActivityId}`)
        }
    }
    
    // If still no activity ID and we don't have fitFileData, we can't proceed
    if (!rawActivityId && !fitFileData) {
        console.error("❌ Missing summary ID and no callbackUrl/fitFileData to extract ID from")
        return new Response(JSON.stringify({ error: "Missing ID" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }
    
    // If we have fitFileData but no summary, we can still process the FIT file
    // The activity should already exist from a previous summary payload
    if (!summary && fitFileData && rawActivityId) {
        console.log(`   ⚠️ No summary provided, but have FIT file and activity ID: ${rawActivityId}`)
        console.log(`   Will attempt to store FIT file for existing activity`)
    } else if (!rawActivityId) {
        console.error("❌ Missing activity ID")
        return new Response(JSON.stringify({ error: "Missing ID" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }
    
    // Normalize: Remove "-file" or "-detail" suffix if present (e.g., "21193470552-file" -> "21193470552")
    const activityId = rawActivityId.replace(/-file$/, '').replace(/-detail$/, '')
    
    if (rawActivityId !== activityId) {
        console.log(`   Normalized activity ID: ${rawActivityId} -> ${activityId}`)
    }

    // 3. Create minimal summary if we only have fitFileData (from pull function)
    // This allows us to process FIT files even when summary payload hasn't arrived yet
    if (!summary && fitFileData && activityId) {
        console.log("   ⚠️ Creating minimal summary from activity ID for FIT file processing")
        summary = {
            summaryId: activityId,
            activityId: activityId,
            id: activityId
        }
    }
    
    // 3. ALWAYS fetch full activity details if we don't have complete data
    // This ensures we have distance, duration, etc. for notifications
    const hasCompleteData = summary && summary.activityName && 
                           summary.durationInSeconds && 
                           summary.distanceInMeters &&
                           (summary.activityType || summary.type || summary.sportType)
    
    if (!hasCompleteData && userAccessToken) {
        console.log("   📥 Fetching full activity details from Garmin API...")
        console.log("   Current summary has:", {
            name: !!summary.activityName,
            duration: !!summary.durationInSeconds,
            distance: !!summary.distanceInMeters,
            type: !!summary.activityType
        })
        
        try {
            // Use Garmin Activity API endpoints
            // Note: For OAuth2, we use activity-service endpoints
            // The wellness-api endpoints are for the older API and may not work with OAuth2 tokens
            const endpoints = [
                `https://connectapi.garmin.com/activity-service/activity/${activityId}`,
                `https://apis.garmin.com/activity-service/activity/${activityId}`,
                `https://connectapi.garmin.com/activity-service/activity/${activityId}/summary`,
                `https://apis.garmin.com/activity-service/activity/${activityId}/summary`
            ]
            
            let fetched = false
            for (const endpoint of endpoints) {
                if (fetched) break
                
                try {
                    console.log(`   🔄 Trying: ${endpoint}`)
                    const response = await fetch(endpoint, {
                        method: 'GET',
                        headers: {
                            'Authorization': `Bearer ${userAccessToken}`,
                            'Accept': 'application/json',
                            'User-Agent': 'HYKA/1.0'
                        }
                    })
                    
                    if (response.ok) {
                        const fullData = await response.json()
                        console.log(`   ✅ Fetched data from: ${endpoint}`)
                        console.log("   📊 Data keys:", Object.keys(fullData))
                        // Merge with existing summary, prioritizing fetched data
                        summary = { ...summary, ...fullData }
                        fetched = true
                        
                        // Check if data contains FIT file URL or callbackUrl
                        if (fullData.callbackUrl && !callbackUrl) {
                            callbackUrl = fullData.callbackUrl
                            console.log("   📎 Found callbackUrl in data:", callbackUrl)
                        }
                        if (fullData.file?.callbackUrl && !callbackUrl) {
                            callbackUrl = fullData.file.callbackUrl
                            console.log("   📎 Found callbackUrl in data.file:", callbackUrl)
                        }
                    } else {
                        const status = response.status
                        const errorText = await response.text()
                        console.log(`   ⚠️ ${endpoint} returned ${status}: ${errorText.substring(0, 200)}`)
                        
                        // If we get 403 Forbidden, the token likely doesn't have permission for direct API access
                        // This is normal for OAuth2 - data should come via webhooks/callbacks
                        if (status === 403) {
                            console.log("   ℹ️ 403 Forbidden - OAuth token may not have permission for direct API access")
                            console.log("   This is expected for OAuth2. Activity data should come via webhook payloads (summary/details/file)")
                            console.log("   Skipping further API fetch attempts")
                            break // Stop trying other endpoints
                        }
                        
                        // If we get 404, activity might not be ready yet
                        if (status === 404) {
                            console.log("   ℹ️ 404 Not Found - Activity may still be processing")
                        }
                    }
                } catch (endpointErr) {
                    console.log(`   ⚠️ Error with ${endpoint}:`, endpointErr.message)
                }
            }
            
            if (!fetched) {
                console.log("   ℹ️ Could not fetch activity data from API endpoints")
                console.log("   This is normal if:")
                console.log("   1. OAuth token doesn't have direct API access (data comes via webhooks)")
                console.log("   2. Activity is still being processed by Garmin")
                console.log("   3. We'll use the data from webhook payloads (summary/details/file)")
                
                // If we have a FILE payload but no summary, and we can't fetch from API,
                // try to use the pull function if we can construct a base callback URL
                // Note: FILE payloads have callbackURL for FIT file download, not for activity summary
                // So we can't use pull function with FILE payload callbackURLs
                // We need to wait for the summary payload to arrive
                if (file && !summary?.distanceInMeters && !summary?.durationInSeconds) {
                    console.log("   ⚠️ FILE payload received but no summary data available")
                    console.log("   Will wait for summary payload from Garmin webhook")
                    console.log("   Garmin typically sends summary and file payloads separately")
                }
            }
        } catch (err) {
            console.error("   ❌ Error fetching activity data:", err)
        }
    } else if (!userAccessToken) {
        console.log("   ⚠️ No access token available to fetch activity details")
    } else {
        console.log("   ✅ Summary already has complete data, skipping API fetch")
    }

    // 4. Extract all activity data from summary
    const startTimeSeconds = summary.startTimeInSeconds || summary.startTimeGMT || summary.beginTimestamp || summary.summaryStartTimeInSeconds || Math.floor(Date.now()/1000)
    const startTime = new Date(startTimeSeconds * 1000).toISOString()
    
    // Log what we have in summary after API fetch attempt
    console.log("   📊 Summary after fetch attempt:", {
        hasName: !!summary.activityName,
        hasDistance: !!summary.distanceInMeters,
        hasDuration: !!summary.durationInSeconds,
        hasType: !!summary.activityType,
        distanceValue: summary.distanceInMeters || summary.distance || 0,
        durationValue: summary.durationInSeconds || summary.elapsedDuration || 0,
        summaryKeys: Object.keys(summary).slice(0, 20) // First 20 keys
    })
    
    // Extract activity type (handle both string and object formats)
    // Garmin can return activity type in various formats
    let activityType = 'unknown'
    if (typeof summary.activityType === 'string') {
        activityType = summary.activityType
    } else if (summary.activityType?.typeKey) {
        activityType = summary.activityType.typeKey
    } else if (summary.activityType?.key) {
        activityType = summary.activityType.key
    } else if (summary.activityType?.type) {
        activityType = summary.activityType.type
    } else if (summary.type) {
        // Sometimes type is at root level
        activityType = summary.type
    } else if (summary.sportType) {
        // Sometimes it's called sportType
        activityType = summary.sportType
    }
    
    // Normalize activity type to uppercase
    activityType = activityType.toUpperCase()
    
    // If still unknown, try to infer from activity name or other fields
    if (activityType === 'UNKNOWN' || activityType === '') {
        const activityName = (summary.activityName || summary.name || '').toLowerCase()
        if (activityName.includes('run') || activityName.includes('running')) {
            activityType = 'RUNNING'
        } else if (activityName.includes('ride') || activityName.includes('cycling') || activityName.includes('bike')) {
            activityType = 'CYCLING'
        } else if (activityName.includes('walk')) {
            activityType = 'WALKING'
        }
    }
    
    console.log("   🏃 Activity type extracted:", activityType, "from summary keys:", Object.keys(summary).filter(k => k.toLowerCase().includes('type') || k.toLowerCase().includes('sport')))
    
    // Extract comprehensive data from summary/details
    // Garmin API returns data in various formats, so we check multiple possible field names
    const activityData: any = {
      user_id: userId,
      garmin_activity_id: activityId, // Use normalized ID
      activity_name: summary.activityName || summary.name || 'Uncategorized Activity',
      activity_type: activityType,
      start_time: startTime,
      start_time_seconds: startTimeSeconds,
      duration_seconds: summary.durationInSeconds || summary.elapsedDuration || summary.elapsedTime || summary.totalElapsedTime || 0,
      distance_meters: summary.distanceInMeters || summary.distance || summary.totalDistance || 0,
      total_elevation_gain_meters: summary.totalElevationGainInMeters || summary.elevationGainInMeters || summary.totalElevationGain || summary.elevationGain || null,
      total_elevation_loss_meters: summary.totalElevationLossInMeters || summary.elevationLossInMeters || summary.totalElevationLoss || summary.elevationLoss || null,
      // Heart rate must be integer
      average_heart_rate: (() => {
        const hr = summary.averageHeartRateInBeatsPerMinute || summary.avgHeartRate || summary.heartRate?.averageHeartRate || null
        return hr !== null ? Math.round(Number(hr)) : null
      })(),
      max_heart_rate: (() => {
        const hr = summary.maxHeartRateInBeatsPerMinute || summary.maxHeartRate || summary.heartRate?.maxHeartRate || null
        return hr !== null ? Math.round(Number(hr)) : null
      })(),
      average_speed_mps: summary.averageSpeedInMetersPerSecond || summary.avgSpeed || summary.speed?.averageSpeed || null,
      max_speed_mps: summary.maxSpeedInMetersPerSecond || summary.maxSpeed || summary.speed?.maxSpeed || null,
      calories: summary.activeKilocalories || summary.calories || summary.totalKilocalories || summary.kilocalories || null,
      // Steps must be integer
      steps: (() => {
        const steps = summary.steps || summary.totalSteps || null
        return steps !== null ? Math.round(Number(steps)) : null
      })(),
      // Cadence must be integer (round float values)
      average_cadence: (() => {
        const cadence = summary.averageRunCadenceInStepsPerMinute || summary.averageRunningCadenceInStepsPerMinute || summary.avgCadence || summary.cadence?.averageCadence || null
        return cadence !== null ? Math.round(Number(cadence)) : null
      })(),
      max_cadence: (() => {
        const cadence = summary.maxRunCadenceInStepsPerMinute || summary.maxRunningCadenceInStepsPerMinute || summary.maxCadence || summary.cadence?.maxCadence || null
        return cadence !== null ? Math.round(Number(cadence)) : null
      })(),
      device_name: summary.deviceName || summary.device?.displayName || summary.deviceName || null,
      raw_summary: summary, // Store full summary for reference
      updated_at: new Date().toISOString()
    }
    
    console.log("   📊 Extracted data:", {
      distance: activityData.distance_meters,
      duration: activityData.duration_seconds,
      avgHR: activityData.average_heart_rate,
      maxHR: activityData.max_heart_rate,
      avgCadence: activityData.average_cadence,
      elevationGain: activityData.total_elevation_gain_meters,
      activityType: activityData.activity_type,
      activityName: activityData.activity_name
    })
    
    // Check if we have meaningful data
    const hasMeaningfulData = activityData.distance_meters > 0 || 
                              activityData.duration_seconds > 0 ||
                              activityData.average_heart_rate > 0
    
    // Check if this is just a file or details payload with no summary data yet
    // We check the original summary from request body, not the one we might have created from file/details
    const isFilePayloadOnly = file && !originalSummary
    const isDetailsPayloadOnly = details && !originalSummary && !file
    const isMinimalPayload = isFilePayloadOnly || isDetailsPayloadOnly || summary?._isFilePayloadOnly
    
    if (!hasMeaningfulData) {
        if (isMinimalPayload) {
            console.log("   ℹ️ File/Details payload received but no activity data yet")
            console.log("   Waiting for summary payload from Garmin...")
            console.log("   This activity will be updated when summary arrives")
        } else {
            console.warn("   ⚠️ Activity has no meaningful data (distance, duration, HR all zero/null)")
            console.warn("   This may indicate:")
            console.warn("   1. Activity is still being processed by Garmin")
            console.warn("   2. API fetch failed to retrieve data")
            console.warn("   3. Activity was manually created without data")
        }
        console.warn("   Storing anyway - data may be updated when Garmin sends another webhook")
    }
    
    // 5. Check if activity already exists
    const { data: existingActivity, error: existingError } = await supabase
      .from('garmin_activities')
      .select('id, has_fit_file, distance_meters, duration_seconds')
      .eq('user_id', userId)
      .eq('garmin_activity_id', activityId)
      .maybeSingle() // Use maybeSingle() instead of single() to avoid error if not found
    
    const isNewActivity = !existingActivity
    const hasExistingData = existingActivity && (existingActivity.distance_meters > 0 || existingActivity.duration_seconds > 0)
    
    if (existingActivity) {
        console.log(`   ℹ️ Activity already exists: ${existingActivity.id}`)
        if (hasExistingData) {
            console.log(`   ✅ Existing activity has data (distance: ${existingActivity.distance_meters}m, duration: ${existingActivity.duration_seconds}s)`)
        } else {
            console.log(`   ⚠️ Existing activity has no data - will be updated with summary data`)
        }
    }
    
    // CRITICAL: If we have meaningful data (from summary), ALWAYS update
    // If we don't have meaningful data but activity exists with data, preserve existing data
    // This handles the case where file payload arrives after summary
    // BUT: NEVER store a NEW activity with all zeros - wait for summary payload with data
    const shouldUpdate = (isNewActivity && hasMeaningfulData) || // New activity with data - YES
                        (!isNewActivity && hasMeaningfulData) || // Update existing with data - YES
                        (!isNewActivity && !hasExistingData && !isMinimalPayload) || // Update existing empty activity from summary - YES
                        (isNewActivity && !isMinimalPayload && hasMeaningfulData) // New activity from summary with data - YES
                        // All other cases (new activity with no data, minimal payloads) - NO
    
    // Declare activity variable outside the if/else so it's accessible for FIT file processing
    let activity = existingActivity || null
    
    if (!shouldUpdate) {
        if (hasExistingData && !hasMeaningfulData) {
            console.log("   ⚠️ New payload has no data but existing activity has data")
            console.log("   Preserving existing data - this is likely a file/details payload arriving after summary")
        } else if (isNewActivity && !hasMeaningfulData) {
            console.log("   ⏭️ SKIPPING: New activity has no meaningful data (all zeros/NULL)")
            console.log("   Will wait for summary payload with complete data before creating activity")
            console.log("   This prevents storing empty activities like 'Uncategorized Activity' with UNKNOWN type")
        } else {
            console.log("   ⏭️ Skipping activity update")
        }
        console.log("   Will still process FIT file if available")
        // activity is already set to existingActivity above
    } else {
        // 6. Upsert Activity
        console.log(`   💾 ${isNewActivity ? 'Creating' : 'Updating'} activity: ${activityId}`)
        console.log(`   📊 Activity data keys:`, Object.keys(activityData))
        console.log(`   📊 Activity data preview:`, {
            distance_meters: activityData.distance_meters,
            duration_seconds: activityData.duration_seconds,
            average_heart_rate: activityData.average_heart_rate,
            activity_name: activityData.activity_name,
            activity_type: activityData.activity_type
        })
        
        const { data: upsertedActivity, error: activityError } = await supabase
          .from('garmin_activities')
          .upsert(activityData, { onConflict: 'user_id,garmin_activity_id' })
          .select('id, garmin_activity_id, activity_name, distance_meters, duration_seconds')
          .single()
          
        if (activityError) {
            console.error(`❌ Upsert error:`, activityError)
            throw new Error(`Failed to store activity: ${activityError?.message}`)
        }
        
        if (!upsertedActivity) {
            console.error(`❌ Upsert returned no activity data`)
            throw new Error(`Failed to store activity: No data returned`)
        }
        
        activity = upsertedActivity
        console.log(`   ✅ Activity stored: ${activity.id} (${activity.garmin_activity_id})`)
        
        // 6a. Store Health Metrics from Activity
        // Extract health metrics from activity data and save to garmin_health_metrics
        if (shouldUpdate && hasMeaningfulData) {
            console.log("💾 Storing health metrics from activity...")
            
            // Get the date from start_time
            const activityDate = new Date(startTime).toISOString().split('T')[0]
            
            // Prepare health metrics data
            const healthMetricsData: any = {
                user_id: userId,
                metric_date: activityDate,
                updated_at: new Date().toISOString()
            }
            
            // Add activity-specific health metrics if available
            if (activityData.average_heart_rate !== null && activityData.average_heart_rate > 0) {
                healthMetricsData.avg_heart_rate = activityData.average_heart_rate
            }
            if (activityData.max_heart_rate !== null && activityData.max_heart_rate > 0) {
                healthMetricsData.max_heart_rate = activityData.max_heart_rate
            }
            if (activityData.steps !== null && activityData.steps > 0) {
                // For activity steps, we might want to add them to daily steps or store separately
                // For now, store as activity_steps if column exists, or add to steps
                healthMetricsData.steps = activityData.steps
            }
            if (activityData.calories !== null && activityData.calories > 0) {
                // Activity calories are active calories
                healthMetricsData.active_calories = activityData.calories
            }
            
            // Only upsert if we have at least one health metric
            if (healthMetricsData.avg_heart_rate || healthMetricsData.max_heart_rate || healthMetricsData.steps || healthMetricsData.active_calories) {
                const { error: healthError } = await supabase
                    .from('garmin_health_metrics')
                    .upsert(healthMetricsData)
                
                if (healthError) {
                    console.error("❌ Failed to store health metrics:", healthError)
                } else {
                    console.log(`✅ Health metrics stored for ${activityDate}`)
                    console.log(`   Metrics: HR avg=${healthMetricsData.avg_heart_rate || 'N/A'}, max=${healthMetricsData.max_heart_rate || 'N/A'}, steps=${healthMetricsData.steps || 'N/A'}, calories=${healthMetricsData.active_calories || 'N/A'}`)
                }
            } else {
                console.log("⏭️ Skipping health metrics - no health data in activity")
            }
        }
    }
    
    // Get activity ID for FIT file processing (either from upsert or existing)
    // If we updated, activity is already set. If we skipped, use existingActivity or fetch it
    if (!activity) {
        console.log("   ⚠️ Activity is null, attempting to fetch from database...")
        if (existingActivity) {
            activity = existingActivity
            console.log(`   ✅ Using existing activity: ${activity.id}`)
        } else if (activityId && userId) {
            // Re-fetch if we just created it but didn't get it back
            console.log(`   🔄 Fetching activity from database: activityId=${activityId}, userId=${userId}`)
            const { data: fetchedActivity, error: fetchError } = await supabase
              .from('garmin_activities')
              .select('id, garmin_activity_id, has_fit_file, distance_meters, duration_seconds')
              .eq('user_id', userId)
              .eq('garmin_activity_id', activityId)
              .maybeSingle()
            
            if (fetchError) {
                console.error(`   ❌ Error fetching activity:`, fetchError)
            } else if (fetchedActivity) {
                activity = fetchedActivity
                console.log(`   ✅ Fetched activity from database: ${activity.id}`)
            } else {
                console.error(`   ❌ Activity ${activityId} not found in database`)
            }
        } else {
            console.error(`   ❌ Cannot fetch activity - missing activityId (${activityId}) or userId (${userId})`)
        }
    } else {
        console.log(`   ✅ Activity available: ${activity.id} (${activity.garmin_activity_id})`)
    }
    
    // If activity doesn't exist yet but we have a FIT file to store, create a minimal activity record
    // BUT: Only if we have FIT file data already downloaded (from pull function)
    // Don't create activity just because we have a callbackURL - wait for summary payload
    if (!activity && fitFileData && Array.isArray(fitFileData) && fitFileData.length > 0) {
        // We have FIT file data already downloaded (from pull function)
        // Create minimal activity to store it
        console.log("   ⚠️ Activity doesn't exist yet, but we have FIT file data (from pull)")
        console.log("   Creating minimal activity record to store FIT file...")
        
        // Create minimal activity with whatever data we have
        const minimalActivityData = {
            user_id: userId,
            garmin_activity_id: activityId,
            activity_name: activityData.activity_name || 'Activity',
            activity_type: activityData.activity_type || 'UNKNOWN',
            start_time: activityData.start_time || new Date().toISOString(),
            start_time_seconds: activityData.start_time_seconds || Math.floor(Date.now() / 1000),
            distance_meters: activityData.distance_meters || 0,
            duration_seconds: activityData.duration_seconds || 0,
            raw_summary: summary || {},
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        }
        
        const { data: createdActivity, error: createError } = await supabase
            .from('garmin_activities')
            .insert(minimalActivityData)
            .select('id, garmin_activity_id')
            .single()
        
        if (createError || !createdActivity) {
            console.error(`❌ Failed to create minimal activity for FIT file:`, createError)
            console.error("   FIT file will not be stored. Activity may need to be created first with summary data.")
        } else {
            activity = createdActivity
            console.log(`   ✅ Created minimal activity record: ${activity.id} for FIT file storage`)
        }
    } else if (!activity && callbackUrl && !fitFileData) {
        // We have a callbackURL but no FIT file data yet
        // This is likely a FILE payload from push mode - don't create activity yet
        // Wait for SUMMARY payload to arrive with activity data
        console.log("   ℹ️ Activity doesn't exist yet, and we have callbackURL but no FIT file data")
        console.log("   This is likely a FILE payload from push mode")
        console.log("   Will wait for SUMMARY payload to arrive with activity data")
        console.log("   FIT file will be downloaded when SUMMARY payload arrives")
    }
    
    if (!activity) {
        console.error(`❌ Could not get or create activity ID for FIT file processing`)
        console.error(`   FIT file will not be stored. Activity may need to be created first with summary data.`)
        // Don't throw - allow the function to complete without FIT file
        // The activity will be created when summary payload arrives, then FIT file can be stored
    }
    
    // 7. Store FIT File - PULL METHOD ONLY
    // FIT files are ONLY obtained via the garmin-activity-pull function
    // The pull function fetches the FIT file from {callbackUrl}/file and passes it as fitFileData
    // We do NOT attempt to download FIT files directly in this function
    
    // Check if fitFileData is already provided (from pull function - comes as array of numbers)
    if (fitFileData && Array.isArray(fitFileData) && fitFileData.length > 0) {
        console.log("✅ FIT file data provided (from pull function)")
        console.log(`   FIT file size: ${fitFileData.length} bytes`)
        
        // Validate FIT file header
        if (fitFileData[0] === 0x0E) {
            console.log("   ✅ Valid FIT file header verified (0x0E)")
        } else {
            console.warn(`   ⚠️ FIT file header may be invalid (expected 0x0E, got: 0x${fitFileData[0]?.toString(16) || 'unknown'})`)
            console.warn("   Storing anyway - may be valid FIT file with different header format")
        }
    } else if (!fitFileData) {
        console.log("ℹ️ No FIT file data provided - FIT files must be obtained via garmin-activity-pull function")
    }
    
    // 8. Store FIT File if we have it
    // fitFileData comes from pull function as an array of numbers
    // CRITICAL: Use preserved originalFitFileData if fitFileData was lost
    if (!fitFileData && originalFitFileData) {
        console.log("   ⚠️ Restoring fitFileData from preserved original")
        fitFileData = originalFitFileData
    }
    
    console.log("💾 FIT file storage check:")
    console.log(`   fitFileData exists: ${!!fitFileData}`)
    console.log(`   originalFitFileData exists: ${!!originalFitFileData}`)
    console.log(`   fitFileData type: ${fitFileData ? (Array.isArray(fitFileData) ? 'array' : typeof fitFileData) : 'null'}`)
    console.log(`   fitFileData length: ${fitFileData && Array.isArray(fitFileData) ? fitFileData.length : 'N/A'}`)
    console.log(`   activity exists: ${!!activity}`)
    console.log(`   activity ID: ${activity?.id || 'N/A'}`)
    console.log(`   activityId: ${activityId || 'N/A'}`)
    console.log(`   userId: ${userId || 'N/A'}`)
    
    if (fitFileData && Array.isArray(fitFileData) && fitFileData.length > 0) {
        if (!activity) {
            console.error("❌ Cannot store FIT file: No activity record available")
            console.error("   Attempting to fetch activity from database...")
            
            // Try to fetch activity one more time using activityId
            if (activityId && userId) {
                const { data: fetchedActivity, error: fetchError } = await supabase
                    .from('garmin_activities')
                    .select('id, garmin_activity_id, has_fit_file')
                    .eq('user_id', userId)
                    .eq('garmin_activity_id', activityId)
                    .maybeSingle()
                
                if (fetchError) {
                    console.error(`   ❌ Error fetching activity:`, fetchError)
                } else if (fetchedActivity) {
                    activity = fetchedActivity
                    console.log(`   ✅ Found activity in database: ${activity.id}`)
                } else {
                    console.error(`   ❌ Activity ${activityId} not found in database for user ${userId}`)
                    console.error("   FIT file will not be stored - activity must exist first")
                }
            } else {
                console.error(`   ❌ Missing activityId (${activityId}) or userId (${userId}) - cannot fetch activity`)
            }
        }
        
        if (activity) {
            console.log("💾 Storing FIT file to database...")
            console.log(`   Activity ID: ${activity.id}, FIT file size: ${fitFileData.length} bytes`)
            
            // Verify FIT file header before storing
            if (fitFileData.length > 0 && fitFileData[0] === 0x0E) {
                console.log("   ✅ Valid FIT file header verified (0x0E)")
            } else {
                console.warn(`   ⚠️ FIT file header may be invalid (expected 0x0E, got: 0x${fitFileData[0]?.toString(16) || 'unknown'})`)
                console.warn("   Storing anyway - may be valid FIT file with different header format")
            }
            
            const { error: fitError } = await supabase
                .from('garmin_fit_files')
                .upsert({
                    activity_id: activity.id,
                    file_data: fitFileData,
                    file_size: fitFileData.length,
                    created_at: new Date().toISOString()
                }, { onConflict: 'activity_id' })
                
            if (fitError) {
                console.error("❌ FIT store error:", fitError)
            } else {
                console.log("✅ FIT file stored successfully")
                console.log(`   Stored ${fitFileData.length} bytes for activity ${activity.id}`)
                
                // Update activity to mark FIT file as stored (processor will also update this, but do it here too)
                await supabase
                    .from('garmin_activities')
                    .update({ has_fit_file: true })
                    .eq('id', activity.id)
                
                // 9. Trigger FIT processor
                console.log("🔄 Triggering FIT processor...")
                console.log(`   Activity ID: ${activity.id}`)
                console.log(`   FIT file size: ${fitFileData.length} bytes`)
                const processorUrl = `${supabaseUrl}/functions/v1/garmin-fit-processor`
                fetch(processorUrl, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${supabaseKey}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        activity_id: activity.id,
                        fit_file_data: fitFileData
                    })
                }).then(async (res) => {
                    if (res.ok) {
                        const result = await res.json().catch(() => ({}))
                        console.log(`✅ FIT processor triggered: ${res.status}`)
                        console.log(`   Processor result:`, {
                            samplesExtracted: result.samples_extracted || 0,
                            samplesInserted: result.samples_inserted || 0,
                            fitFileSize: result.fit_file_size || 0
                        })
                    } else {
                        const text = await res.text()
                        console.error(`❌ FIT processor failed: ${res.status} - ${text}`)
                    }
                }).catch(err => {
                    console.error("❌ Error calling FIT processor:", err)
                    console.error("   Error details:", err.message)
                })
            }
        }
    }

    // 10. Trigger Notification
    // Send notification if:
    // 1. Activity was created/updated (activity exists)
    // 2. Activity has meaningful data (distance and duration > 0)
    // 3. It's a new activity OR it's an update that added data to an activity that previously had none
    const hasActivityData = activityData.distance_meters > 0 && activityData.duration_seconds > 0
    const isNewActivityWithData = isNewActivity && hasActivityData && shouldUpdate
    const isUpdateWithNewData = !isNewActivity && hasActivityData && shouldUpdate && !hasExistingData
    
    const shouldNotify = activity && hasActivityData && (isNewActivityWithData || isUpdateWithNewData)
    
    if (shouldNotify) {
        console.log("🔔 Triggering notification for activity...")
        console.log(`   📊 Notification data: ${activityData.distance_meters}m, ${activityData.duration_seconds}s`)
        console.log(`   📊 Activity type: ${isNewActivityWithData ? 'new' : 'updated (was empty, now has data)'}`)
        
        const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
        const notifyPayload = {
            user_id: userId,
            activity_id: activity.id,
            activity_name: activityData.activity_name,
            activity_type: activityData.activity_type,
            distance_meters: activityData.distance_meters,
            duration_seconds: activityData.duration_seconds
        }

        fetch(notifyUrl, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(notifyPayload)
        }).then(async (res) => {
            if (res.ok) {
                console.log(`✅ Notification triggered: ${res.status}`)
            } else {
                const text = await res.text()
                console.error(`❌ Notification failed: ${res.status} - ${text}`)
            }
        }).catch(err => {
            console.error("❌ Error calling notification:", err)
        })
    } else {
        if (!activity) {
            console.log("⏭️ Skipping notification - activity was not created/updated")
        } else if (!hasActivityData) {
            console.log("⏭️ Skipping notification - missing distance or duration data")
            console.log(`   Distance: ${activityData.distance_meters}m, Duration: ${activityData.duration_seconds}s`)
        } else if (!isNewActivityWithData && !isUpdateWithNewData) {
            console.log("⏭️ Skipping notification - activity already exists with data")
        }
    }

    const duration = Date.now() - startTime
    return new Response(JSON.stringify({ 
      success: true, 
      activityId: activity?.id || null,
      isNew: isNewActivity,
      hasFitFile: !!fitFileData,
      duration: `${duration}ms`
    }), { 
      status: 200, 
      headers: { 'Content-Type': 'application/json' } 
    })

  } catch (error) {
    console.error("❌ Critical Error:", error)
    return new Response(JSON.stringify({ success: false, error: error.message }), { 
      status: 200, 
      headers: { 'Content-Type': 'application/json' } 
    })
  }
})
