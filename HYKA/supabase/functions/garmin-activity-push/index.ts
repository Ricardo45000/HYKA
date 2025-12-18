// ============================================================================
// Garmin Activity PUSH Webhook (Fixed & Robust)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, User-Agent, Authorization, apikey',
        'Access-Control-Max-Age': '86400',
      },
    })
  }

  try {
    console.log("📦 Garmin PUSH received")
    
    // Verify User-Agent (Garmin webhooks should have "Garmin" in User-Agent)
    const userAgent = req.headers.get('user-agent') || ''
    const isFromGarmin = userAgent.includes('Garmin') || userAgent.includes('garmin')
    
    if (!isFromGarmin) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
      // Still process, but log warning
    } else {
      console.log("✅ Verified Garmin User-Agent:", userAgent)
    }

    // Parse body
    let body: any
    try {
      const contentType = req.headers.get('content-type') || ''
      if (contentType.includes('application/json')) {
        body = await req.json()
      } else {
        const text = await req.text()
        body = text ? JSON.parse(text) : {}
      }
    } catch (parseError) {
      console.error("❌ Error parsing request body:", parseError)
      return new Response(JSON.stringify({ success: false, error: "Invalid request body" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }

    console.log("   Body keys:", Object.keys(body))

    // ------------------------------------------------------------------------
    // 1. Extract Data & User ID (Robust Method)
    // ------------------------------------------------------------------------
    
    // Garmin sends different keys for different data types
    const dataKeys = [
      'activities',       // Activity Summaries
      'activityFiles',    // FIT Files
      'activityDetails',  // Activity Details (Samples)
      'dailies',          // Daily Health Data
      'epochs',           // Intraday Steps/HR
      'sleeps',           // Sleep Data
      'bodyComps',        // Body Composition
      'thirdPartyDailies',
      'stressDetails',
      'userMetrics',
      'moveIQActivities',
      'pulseOx'
    ]

    let garminUserId: string | null = null
    let primaryData: any[] = []
    let dataType = 'unknown'

    // Find the first key that contains data
    // IMPORTANT: In push mode, Garmin may send multiple webhooks (activities, activityFiles, activityDetails)
    // We process each one separately, but prioritize 'activities' if it exists
    const foundKeys: string[] = []
    for (const key of dataKeys) {
      if (body[key] && Array.isArray(body[key]) && body[key].length > 0) {
        foundKeys.push(key)
        // Prioritize 'activities' (summary) if it exists, as it has the full data
        if (key === 'activities' && !primaryData.length) {
          primaryData = body[key]
          dataType = key
          garminUserId = body[key][0].userId || body[key][0].garminUserId || body[key][0].userAccessToken
        } else if (!primaryData.length) {
          // Use first available if activities not found
          primaryData = body[key]
          dataType = key
          garminUserId = body[key][0].userId || body[key][0].garminUserId || body[key][0].userAccessToken
        }
      }
    }
    
    console.log(`   📋 Found data keys in webhook: ${foundKeys.join(', ')}`)
    if (foundKeys.includes('activities')) {
      console.log(`   ✅ SUMMARY payload (activities) found - this should have full activity data`)
    }

    // Fallback: Check top-level userId
    if (!garminUserId) {
      garminUserId = body.userId || body.garminUserId || body.userAccessToken
    }

    if (!garminUserId) {
      console.error("❌ Missing garminUserId in PUSH")
      // Log full body for debugging if we still can't find it
      console.log("   Full Body:", JSON.stringify(body).substring(0, 1000))
      return new Response(JSON.stringify({ success: false, error: "Missing garminUserId" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }

    console.log(`   DataType: ${dataType}`)
    console.log(`   Garmin User ID: ${garminUserId}`)
    console.log(`   Items count: ${primaryData.length}`)

    // ------------------------------------------------------------------------
    // 2. Lookup HYKA User
    // ------------------------------------------------------------------------
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: connection, error: lookupError } = await supabase
      .from('garmin_connections')
      .select('user_id, access_token')
      .eq('garmin_user_id', garminUserId)
      .single()

    if (lookupError || !connection) {
      console.log("⚠️ No HYKA user found for Garmin user:", garminUserId)
      return new Response(JSON.stringify({ success: true, message: "No connection found" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }

    console.log("✅ Found HYKA user:", connection.user_id)

    // ------------------------------------------------------------------------
    // 3. Process Data Based on Type
    // ------------------------------------------------------------------------

    let processedCount = 0

    // A. Handle ACTIVITIES (Summaries, Files, Details)
    if (['activities', 'activityFiles', 'activityDetails'].includes(dataType)) {
      
      // Filter keywords (case-insensitive)
      const allowedActivityTypeKeywords = ['running', 'hiking', 'walking']
      
      console.log(`   📦 Processing ${dataType} payload with ${primaryData.length} item(s)`)
      console.log(`   📦 First item keys:`, primaryData[0] ? Object.keys(primaryData[0]).slice(0, 20) : 'no items')

      for (const item of primaryData) {
        try {
          // Normalize ID - check multiple possible fields
          const activityId = item.summaryId || item.activityId || item.id || item.summary?.summaryId || item.summary?.activityId
          
          // Extract activity type from multiple possible locations
          let activityType = item.activityType || item.type || item.sportType || item.activityTypeKey
          // If it's an object, extract the key
          if (activityType && typeof activityType === 'object') {
            activityType = activityType.typeKey || activityType.key || activityType.type
          }
          
          // Filter by activity type (only for 'activities' summaries where type should be present)
          // For files/details, type might not be present, so we proceed
          // IMPORTANT: Always forward 'activities' payloads to store function - let store function decide if it has meaningful data
          if (dataType === 'activities') {
            const activityTypeLower = (activityType || '').toLowerCase()
            const isAllowed = activityTypeLower ? allowedActivityTypeKeywords.some(k => activityTypeLower.includes(k)) : false
            
            // Log what we're checking
            console.log(`   📋 Checking activity type: "${activityType}" (lowercase: "${activityTypeLower}")`)
            console.log(`   📋 Allowed keywords: ${allowedActivityTypeKeywords.join(', ')}`)
            console.log(`   📋 Is allowed: ${isAllowed}`)
            console.log(`   📋 Activity data preview:`, {
              activityId: activityId,
              activityName: item.activityName || item.name,
              distance: item.distanceInMeters || item.distance,
              duration: item.durationInSeconds || item.elapsedDuration,
              activityType: activityType
            })
            
            // Only skip if we have a specific activity type that's NOT allowed
            // If activityType is undefined/null/empty, forward it anyway - store function will handle it
            if (!isAllowed && activityType && activityType !== 'unknown') {
              console.log(`⏭️ Skipping activity type: ${activityType} (not Running/Hiking/Walking)`)
              continue
            } else {
              if (!activityType) {
                console.log(`⚠️ Activity type is undefined/missing, but forwarding anyway (store function will decide)`)
              } else {
                console.log(`✅ Activity type "${activityType}" is allowed - forwarding to store`)
              }
              // Forward to store function - it will check for meaningful data
            }
          }

          // For files/details, we might not have activityType, accept everything
          const finalActivityType = activityType || 'unknown'
          
          if (!activityId) {
            console.log("⚠️ Item missing ID, skipping")
            console.log("   Item keys:", Object.keys(item))
            continue
          }

          console.log(`📦 Processing ${dataType}: ${activityId} (${finalActivityType})`)

          // Extract callbackUrl if available
          const callbackUrl = item.callbackUrl || item.callbackURL
          
          // If we have a callbackUrl, we need to use the PULL function to fetch FIT file
          // The PULL function will fetch summary, details, and FIT file from the callbackUrl
          if (callbackUrl && (dataType === 'activityFiles' || dataType === 'activityDetails')) {
            console.log(`   🔄 Found callbackUrl for ${dataType} - calling PULL function...`)
            console.log(`   Callback URL: ${callbackUrl.substring(0, 100)}...`)
            
            // Call the PULL function which will:
            // 1. Fetch summary from callbackUrl
            // 2. Fetch details from callbackUrl/details
            // 3. Fetch FIT file from callbackUrl/file
            // 4. Forward everything to STORE function
            const pullUrl = `${supabaseUrl}/functions/v1/garmin-activity-pull`
            const pullResponse = await fetch(pullUrl, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                callbackUrl: callbackUrl,
                garminUserId: garminUserId,
                summaryId: activityId
              })
            })
            
            if (pullResponse.ok) {
              const pullResult = await pullResponse.json()
              console.log(`   ✅ PULL function completed successfully`)
              console.log(`   Summary ID: ${pullResult.summaryId}, Samples: ${pullResult.samplesCount || 0}`)
              processedCount++
            } else {
              const pullErrorText = await pullResponse.text()
              console.error(`   ❌ PULL function failed: ${pullResponse.status} - ${pullErrorText}`)
              // Fallback: Still forward to store function with what we have
              console.log(`   ⚠️ Falling back to direct store (without FIT file)`)
              
              const payloadToStore = {
                garminUserId: garminUserId,
                userId: connection.user_id,
                summary: dataType === 'activities' ? item : null,
                file: dataType === 'activityFiles' ? item : null,
                details: dataType === 'activityDetails' ? item : null,
                callbackUrl: callbackUrl
              }
              
              const storeResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
                method: "POST",
                headers: {
                  "Authorization": `Bearer ${supabaseKey}`,
                  "Content-Type": "application/json"
                },
                body: JSON.stringify(payloadToStore)
              })
              
              if (storeResponse.ok) {
                processedCount++
                console.log(`✅ ${dataType} forwarded to store (fallback)`)
              } else {
                const err = await storeResponse.text()
                console.error(`❌ Store failed (fallback): ${storeResponse.status} - ${err}`)
              }
            }
          } else {
            // No callbackUrl or it's a summary payload - forward directly to store
            // Prepare payload for store function
            const payloadToStore = {
              garminUserId: garminUserId,
              userId: connection.user_id, // Pass HYKA user ID directly
              
              // Pass raw data based on what we received
              summary: dataType === 'activities' ? item : null,
              file: dataType === 'activityFiles' ? item : null,
              details: dataType === 'activityDetails' ? item : null,
              
              callbackUrl: callbackUrl // May be null for summary payloads
            }
            
            // Log what we're sending to store function
            if (dataType === 'activities') {
              console.log(`   📤 SUMMARY payload - forwarding to store with data:`, {
                activityId: activityId,
                activityName: item.activityName || item.name,
                distance: item.distanceInMeters || item.distance || 'missing',
                duration: item.durationInSeconds || item.elapsedDuration || 'missing',
                activityType: activityType || 'missing',
                hasDistance: !!(item.distanceInMeters || item.distance),
                hasDuration: !!(item.durationInSeconds || item.elapsedDuration)
              })
            }

            // Call garmin-activity-store
            const storeResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${supabaseKey}`,
                "Content-Type": "application/json"
              },
              body: JSON.stringify(payloadToStore)
            })

            if (storeResponse.ok) {
              processedCount++
              const storeResult = await storeResponse.json().catch(() => ({}))
              console.log(`✅ ${dataType} forwarded for ${activityId}`)
              if (dataType === 'activities') {
                console.log(`   Store result:`, storeResult)
              }
            } else {
              const err = await storeResponse.text()
              console.error(`❌ Store failed: ${storeResponse.status} - ${err}`)
            }
          }

        } catch (err) {
          console.error("❌ Error processing item:", err)
        }
      }
    }
    
    // B. Handle HEALTH DATA (Dailies, Sleeps, etc.)
    else if (['dailies', 'sleeps', 'epochs', 'bodyComps'].includes(dataType)) {
      console.log(`🏥 Processing Health Data: ${dataType}`)
      
      // Process health data directly here or forward to a health-store function
      // For simplicity, let's store directly to garmin_health_metrics table
      
      for (const item of primaryData) {
        try {
          const date = item.calendarDate || item.startTimeInSeconds ? new Date(item.startTimeInSeconds * 1000).toISOString().split('T')[0] : null
          
          if (!date) {
            console.log("⚠️ Health item missing date, skipping")
            continue
          }

          // Map fields based on data type
          // This is a simplified mapping - expand as needed based on Garmin schema
          const healthData: any = {
            user_id: connection.user_id,
            metric_date: date,
            updated_at: new Date().toISOString()
          }

          if (dataType === 'dailies') {
            healthData.steps = item.steps
            healthData.active_calories = item.activeKilocalories
            healthData.total_calories = item.bmrKilocalories + item.activeKilocalories
            healthData.resting_heart_rate = item.restingHeartRateInBeatsPerMinute
            healthData.max_heart_rate = item.maxHeartRateInBeatsPerMinute
            healthData.min_heart_rate = item.minHeartRateInBeatsPerMinute
            healthData.avg_heart_rate = item.averageHeartRateInBeatsPerMinute
            healthData.stress_level = item.averageStressLevel
            // raw_daily_data: item // Can store raw JSON if column exists
          }
          else if (dataType === 'sleeps') {
            healthData.sleep_duration_seconds = item.durationInSeconds
            healthData.sleep_score = item.overallSleepScore?.value
            healthData.sleep_start_time = new Date(item.startTimeInSeconds * 1000).toISOString()
            // Map phases if available
          }
          else if (dataType === 'bodyComps') {
             healthData.weight_kg = item.weightInGrams / 1000
          }

          // Upsert into database
          // Note: This requires the updated garmin_health_metrics table we created!
          const { error } = await supabase
            .from('garmin_health_metrics')
            .upsert(healthData, { onConflict: 'user_id,metric_date' })

          if (error) {
            console.error(`❌ Failed to store health data: ${error.message}`)
          } else {
            processedCount++
            console.log(`✅ Health data stored for ${date}`)
          }

        } catch (err) {
          console.error("❌ Error processing health item:", err)
        }
      }
    }
    else {
      console.log(`ℹ️ Unknown data type: ${dataType} - skipping processing`)
    }

    // Update last_sync_at
    await supabase
      .from('garmin_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('user_id', connection.user_id)

    const duration = Date.now() - startTime
    return new Response(JSON.stringify({ 
      success: true,
      processed: processedCount,
      type: dataType,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error("❌ Critical Error:", error)
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 200, // Return 200 to satisfy Garmin
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

