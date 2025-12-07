// ============================================================================
// Garmin Activity Store (OAuth 2.0 Aware)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("💾 Garmin Activity Store started")
    
    const requestBody = await req.json()
    console.log("   📥 Request body keys:", Object.keys(requestBody))
    
    let { summary, details, garminUserId, callbackUrl, fitFileData, file } = requestBody
    
    // Handle 'file' payload from PUSH (it contains the callbackUrl and summaryId)
    if (file && !summary) {
        console.log("   Processing FILE payload (no summary yet)")
        callbackUrl = file.callbackUrl
        // Create a minimal summary so we can proceed with ID
        summary = {
            summaryId: file.summaryId || file.id,
            activityId: file.summaryId || file.id,
            startTimeInSeconds: file.startTimeInSeconds // Might be missing in file payload
        }
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // 1. Find HYKA user & Access Token
    let userId: string | null = null
    let userAccessToken: string | null = null
    
    if (garminUserId) {
      console.log("🔍 Looking up HYKA user for Garmin user:", garminUserId)
      
      const { data: connection, error: lookupError } = await supabase
        .from('garmin_connections')
        .select('user_id, access_token')
        .eq('garmin_user_id', garminUserId)
        .single()
      
      if (lookupError || !connection) {
        console.log("⚠️ No connection found")
        return new Response(JSON.stringify({ success: false, message: "No connection found" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
      }
      
      userId = connection.user_id
      userAccessToken = connection.access_token
      console.log("✅ Found HYKA user:", userId)
    } else {
        // ... error handling ...
        return new Response(JSON.stringify({ error: "No garminUserId" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }

    // 2. Download FIT File if needed (using OAuth 2.0)
    if (callbackUrl && !fitFileData) {
        console.log("📥 Downloading FIT file from:", callbackUrl)
        
        try {
            const fileResponse = await fetch(callbackUrl, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${userAccessToken}`
                }
            })
            
            if (fileResponse.ok) {
                const arrayBuffer = await fileResponse.arrayBuffer()
                fitFileData = Array.from(new Uint8Array(arrayBuffer))
                console.log(`✅ Downloaded FIT file: ${fitFileData.length} bytes`)
            } else {
                console.error(`❌ Failed to download file: ${fileResponse.status}`)
                // Log response text for debugging (might imply OAuth 1.0a requirement)
                console.error("   Error:", await fileResponse.text())
            }
        } catch (err) {
            console.error("❌ Error downloading file:", err)
        }
    }

    // ... Rest of the logic (store activity, store FIT file) ...
    // I will paste the rest of your provided code here, integrated with the new file fetching
    
    // [Rest of the function implementation follows...]
    
    // 2. Parse activity data
    // (Robust check for summary existence)
    if (!summary || (!summary.summaryId && !summary.activityId)) {
         // If we only got a file push and couldn't download/parse it yet, we might stop here
         // But if we downloaded it, we might be able to extract ID from filename or metadata later (complex)
         // For now, require summary ID
         console.error("❌ Missing summary ID")
         return new Response(JSON.stringify({ error: "Missing ID" }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }

    const activityId = summary.summaryId?.toString() || summary.id?.toString() || summary.activityId?.toString()
    const startTimeSeconds = summary.startTimeInSeconds || summary.startTimeGMT || summary.beginTimestamp || summary.summaryStartTimeInSeconds || Math.floor(Date.now()/1000) // Fallback for file-only pushes
    
    // Convert start time
    const startTime = new Date(startTimeSeconds * 1000).toISOString()
    
    // ... (Standard storing logic from your code) ...
    // I'll include the DB operations for garmin_activities and garmin_fit_files
    
    const activityData = {
      user_id: userId,
      garmin_activity_id: activityId,
      // ... map other fields ...
      activity_name: summary.activityName || 'Uncategorized Activity',
      activity_type: summary.activityType || 'unknown',
      start_time: startTime,
      start_time_seconds: startTimeSeconds,
      duration_seconds: summary.durationInSeconds || 0,
      distance_meters: summary.distanceInMeters || 0,
      updated_at: new Date().toISOString()
    }
    
    // Upsert Activity
    const { data: activity, error: activityError } = await supabase
      .from('garmin_activities')
      .upsert(activityData, { onConflict: 'user_id,garmin_activity_id' })
      .select('id')
      .single()
      
    if (activityError || !activity) {
        throw new Error(`Failed to store activity: ${activityError?.message}`)
    }
    
    // Store FIT File
    if (fitFileData) {
        console.log("💾 Storing FIT file to database...")
        const { error: fitError } = await supabase
            .from('garmin_fit_files')
            .upsert({
                activity_id: activity.id,
                file_data: fitFileData,
                file_size: fitFileData.length,
                created_at: new Date().toISOString()
            }, { onConflict: 'activity_id' })
            
        if (fitError) console.error("❌ FIT store error:", fitError)
        else console.log("✅ FIT file stored")
    }

    // Trigger Notification
    console.log("🔔 Triggering notification...")
    const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
    const notifyPayload = {
        user_id: userId,
        activity_id: activity.id,
        activity_name: activity.activity_name,
        activity_type: activity.activity_type,
        distance_meters: activity.distance_meters,
        duration_seconds: activity.duration_seconds
    }

    // We use fetch without await to not block the response, but we log the result
    fetch(notifyUrl, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(notifyPayload)
    }).then(async (res) => {
        if (res.ok) {
            console.log(`✅ Notification triggered successfully: ${res.status}`)
        } else {
            const text = await res.text()
            console.error(`❌ Notification trigger failed: ${res.status} - ${text}`)
        }
    }).catch(err => {
        console.error("❌ Error calling notification function:", err)
    })

    return new Response(JSON.stringify({ success: true, activityId: activity.id }), { status: 200, headers: { 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error("❌ Critical Error:", error)
    return new Response(JSON.stringify({ success: false, error: error.message }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  }
})

