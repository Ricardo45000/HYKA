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
        'Access-Control-Allow-Headers': 'Content-Type, User-Agent',
        'Access-Control-Max-Age': '86400',
      },
    })
  }

  try {
    console.log("📦 Garmin PUSH received")
    
    // Verify User-Agent
    const userAgent = req.headers.get('user-agent') || ''
    if (!userAgent.includes('Garmin')) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
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
    for (const key of dataKeys) {
      if (body[key] && Array.isArray(body[key]) && body[key].length > 0) {
        primaryData = body[key]
        dataType = key
        // Extract User ID from the first item
        garminUserId = body[key][0].userId || body[key][0].garminUserId || body[key][0].userAccessToken
        if (garminUserId) break
      }
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

      for (const item of primaryData) {
        try {
          // Normalize ID and Name
          const activityId = item.summaryId || item.activityId || item.id
          
          // Filter by activity type (only for 'activities' summaries where type is guaranteed)
          // For files/details, type might not be present, so we proceed (or you could fetch summary to check)
          if (dataType === 'activities') {
            const activityType = (item.activityType || '').toLowerCase()
            const isAllowed = allowedActivityTypeKeywords.some(k => activityType.includes(k))
            
            if (!isAllowed) {
              console.log(`⏭️ Skipping activity type: ${item.activityType} (not Running/Hiking/Walking)`)
              continue
            }
          }

          // For files/details, we might not have activityType, accept everything
          const activityType = item.activityType || 'unknown'
          
          if (!activityId) {
            console.log("⚠️ Item missing ID, skipping")
            continue
          }

          console.log(`📦 Processing ${dataType}: ${activityId} (${activityType})`)

          // Prepare payload for store function
          // We map everything to a common structure expected by store function
          const payloadToStore = {
            garminUserId: garminUserId,
            userId: connection.user_id, // Pass HYKA user ID directly
            
            // Pass raw data based on what we received
            summary: dataType === 'activities' ? item : null,
            file: dataType === 'activityFiles' ? item : null,
            details: dataType === 'activityDetails' ? item : null,
            
            // If we received a file/details push, we might need to fetch the full summary if we don't have it
            // But for now, just passing what we have is a good start
            
            callbackUrl: item.callbackUrl // Important for files/details
          }

          // Call garmin-activity-store
          // Note: You might need to update garmin-activity-store to handle 'file' and 'details' payloads directly
          // For now, we'll assume it can handle it or we just log the receipt
          
          // If it's just a file/detail push without summary, we might want to trigger a fetch
          // But let's try to forward it first
          
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
            console.log(`✅ ${dataType} forwarded for ${activityId}`)
          } else {
            const err = await storeResponse.text()
            console.error(`❌ Store failed: ${storeResponse.status} - ${err}`)
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

