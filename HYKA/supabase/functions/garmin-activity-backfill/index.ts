// ============================================================================
// Garmin Activity Backfill (Official Endpoint)
// ============================================================================
//
// Purpose: Request historical activity data using official Garmin backfill endpoint
//
// Flow:
// 1. Receive userId and optional date range
// 2. Lookup Garmin access_token from garmin_connections
// 3. Calculate date range (default: last 30 days from connection date)
// 4. Call official backfill endpoint: /rest/backfill/activities
// 5. Garmin responds with 202 Accepted (async processing)
// 6. Garmin sends webhooks as backfill completes
// 7. Return confirmation to caller
//
// Official Endpoint:
// GET https://apis.garmin.com/wellness-api/rest/backfill/activities
// Parameters:
//   - summaryStartTimeInSeconds (required): UTC timestamp (when data was recorded)
//   - summaryEndTimeInSeconds (required): UTC timestamp (when data was recorded)
//
// Important:
// - Maximum 30 days per request
// - Returns 202 Accepted (async)
// - Returns 409 Conflict for duplicate requests
// - Uses summaryStartTimeInSeconds (NOT upload timestamps)
// - No Pull Token needed (uses OAuth 2.0 access token)
//
// Reference: Activity API 1.2.3 - Section 8. Backfill
// https://developerportal.garmin.com/sites/default/files/Activity_API-1.2.3_0.pdf
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("📥 Garmin Activity Backfill started")
    
    const body = await req.json()
    const userId = body.user_id || body.userId
    const summaryStartTimeInSeconds = body.summary_start_time_seconds || body.summaryStartTimeInSeconds
    const summaryEndTimeInSeconds = body.summary_end_time_seconds || body.summaryEndTimeInSeconds
    
    if (!userId) {
      console.error("❌ Missing user_id")
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   User ID:", userId)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Step 1: Lookup Garmin connection
    console.log("🔍 Looking up Garmin connection...")
    
    const { data: connection, error: connectionError } = await supabase
      .from('garmin_connections')
      .select('garmin_user_id, access_token, connected_at, permission_revoked')
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
    
    // Step 2: Calculate date range
    // Default: Last 30 days from connection date (or 1 month from first connection)
    // User rate limit: 1 month since first user connection
    let startTimeSeconds: number
    let endTimeSeconds: number
    
    if (summaryStartTimeInSeconds && summaryEndTimeInSeconds) {
      // Use provided date range
      startTimeSeconds = summaryStartTimeInSeconds
      endTimeSeconds = summaryEndTimeInSeconds
    } else {
      // Calculate default: last 29 days from now (not connection date)
      // According to Garmin docs, backfill can retrieve historic data from before
      // "user's registration with the partner program", so we can request data
      // from before the connection date
      const now = new Date()
      
      // Request last 29 days from now (going backward)
      // This will include data from before connection date if Garmin allows it
      const twentyNineDaysAgo = new Date(now)
      twentyNineDaysAgo.setDate(twentyNineDaysAgo.getDate() - 29)
      
      startTimeSeconds = Math.floor(twentyNineDaysAgo.getTime() / 1000)
      endTimeSeconds = Math.floor(now.getTime() / 1000)
      
      // Log connection date for reference
      if (connection.connected_at) {
        const connectedAt = new Date(connection.connected_at)
        const connectedAtSeconds = Math.floor(connectedAt.getTime() / 1000)
        const daysBeforeConnection = (connectedAtSeconds - startTimeSeconds) / (24 * 60 * 60)
        
        if (startTimeSeconds < connectedAtSeconds) {
          console.log("ℹ️ Requesting backfill from before connection date")
          console.log("   Requested start:", new Date(startTimeSeconds * 1000).toISOString())
          console.log("   Connection date:", connectedAt.toISOString())
          console.log("   Days before connection:", daysBeforeConnection.toFixed(1))
          console.log("   According to Garmin docs, this should be allowed for historic data")
        }
      }
    }
    
    // Validate: Maximum 30 days per request (use 30.0 to account for time components)
    const daysDiff = (endTimeSeconds - startTimeSeconds) / (24 * 60 * 60)
    if (daysDiff > 30.0) {
      console.error("❌ Date range exceeds 30 days:", daysDiff, "days")
      return new Response(JSON.stringify({ 
        error: `Date range exceeds 30 days: ${daysDiff.toFixed(1)} days. Split into multiple requests.` 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    // Note: According to Garmin documentation, backfill CAN retrieve historic data
    // from before "user's registration with the partner program"
    // However, Garmin may still enforce a minimum start time based on their internal rules
    // We'll let Garmin decide - if they reject it, they'll return an error
    const connectedAtSeconds = connection.connected_at 
      ? Math.floor(new Date(connection.connected_at).getTime() / 1000)
      : Math.floor(Date.now() / 1000)
    
    if (startTimeSeconds < connectedAtSeconds) {
      console.log("⚠️ Requesting backfill from before connection date")
      console.log("   Requested start:", new Date(startTimeSeconds * 1000).toISOString())
      console.log("   Connection date:", new Date(connectedAtSeconds * 1000).toISOString())
      console.log("   According to Garmin docs, backfill should support historic data")
      console.log("   Letting Garmin API decide if this is allowed...")
      // Don't reject - let Garmin API decide
    }
    
    console.log("   Date range:", {
      start: new Date(startTimeSeconds * 1000).toISOString(),
      end: new Date(endTimeSeconds * 1000).toISOString(),
      days: daysDiff.toFixed(1)
    })
    
    // Step 3: Check for duplicate backfill request
    console.log("🔍 Checking for duplicate backfill request...")
    
    const { data: existingRequest } = await supabase
      .from('garmin_backfill_requests')
      .select('id, status')
      .eq('user_id', userId)
      .eq('summary_start_time_seconds', startTimeSeconds)
      .eq('summary_end_time_seconds', endTimeSeconds)
      .single()
    
    if (existingRequest) {
      if (existingRequest.status === 'pending' || existingRequest.status === 'completed') {
        console.log("⚠️ Duplicate backfill request detected (status:", existingRequest.status, ")")
        return new Response(JSON.stringify({ 
          success: false,
          error: "Duplicate backfill request",
          message: "This date range has already been requested",
          status: existingRequest.status
        }), {
          status: 409, // Conflict
          headers: { 'Content-Type': 'application/json' }
        })
      }
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
        'Authorization': `Bearer ${connection.access_token}`,
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
      // Conflict: Duplicate request
      console.log("⚠️ Duplicate backfill request (409 Conflict)")
      
      await supabase
        .from('garmin_backfill_requests')
        .update({ status: 'pending' })
        .eq('user_id', userId)
        .eq('summary_start_time_seconds', startTimeSeconds)
        .eq('summary_end_time_seconds', endTimeSeconds)
      
      return new Response(JSON.stringify({
        success: false,
        error: "Duplicate backfill request",
        message: "This date range has already been requested",
        status: 409
      }), {
        status: 409,
        headers: { 'Content-Type': 'application/json' }
      })
      
    } else {
      // Error
      const errorText = await backfillResponse.text()
      console.error("❌ Backfill request failed:", backfillResponse.status, errorText)
      
      await supabase
        .from('garmin_backfill_requests')
        .update({ status: 'failed' })
        .eq('user_id', userId)
        .eq('summary_start_time_seconds', startTimeSeconds)
        .eq('summary_end_time_seconds', endTimeSeconds)
      
      return new Response(JSON.stringify({
        success: false,
        error: "Backfill request failed",
        status: backfillResponse.status,
        details: errorText
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

// ============================================================================
// Configuration Required
// ============================================================================
//
// 1. Deploy this function:
//    supabase functions deploy garmin-activity-backfill
//
// 2. Call from iOS app or other Edge Function:
//    POST /functions/v1/garmin-activity-backfill
//    Body: { user_id, summary_start_time_seconds?, summary_end_time_seconds? }
//
// 3. For multiple 30-day periods, call multiple times:
//    - Request 1: Days 0-30
//    - Request 2: Days 31-60
//    - Request 3: Days 61-90
//    etc.
//
// 4. Garmin will send webhooks as backfill completes
//    - Webhooks go to garmin-activity-ping or garmin-activity-push
//    - Activities are automatically stored via webhook flow
//
// ============================================================================

