// ============================================================================
// Garmin Backfill Status Checker
// ============================================================================
// Purpose: Check and update backfill request statuses based on existing activities
// 
// This function:
// 1. Checks all pending backfill requests
// 2. Looks for activities in those date ranges
// 3. Marks requests as completed if activities exist
// 4. Returns a summary of what was found/updated
//
// Use this when:
// - Backfill requests have been pending for a while
// - You want to check if activities have arrived but requests weren't marked complete
// - You need to manually sync the status
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("🔍 Garmin Backfill Status Checker started")
    
    const { user_id, mark_completed = false } = await req.json()
    
    if (!user_id) {
      return new Response(JSON.stringify({ 
        error: "Missing user_id" 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   User ID:", user_id)
    console.log("   Mark completed:", mark_completed)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Get all pending backfill requests
    const { data: pendingRequests, error: requestsError } = await supabase
      .from('garmin_backfill_requests')
      .select('id, summary_start_time_seconds, summary_end_time_seconds, created_at')
      .eq('user_id', user_id)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
    
    if (requestsError) {
      throw new Error(`Failed to fetch backfill requests: ${requestsError.message}`)
    }
    
    if (!pendingRequests || pendingRequests.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: "No pending backfill requests found",
        pending_count: 0,
        checked: [],
        updated: []
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log(`   Found ${pendingRequests.length} pending backfill requests`)
    
    const results = []
    const updated = []
    
    // Check each pending request
    for (const request of pendingRequests) {
      const bufferSeconds = 24 * 60 * 60 // 1 day buffer
      
      // Check if activities exist in this date range
      const { data: activities, error: activitiesError } = await supabase
        .from('garmin_activities')
        .select('id, garmin_activity_id, activity_type, start_time_seconds')
        .eq('user_id', user_id)
        .gte('start_time_seconds', request.summary_start_time_seconds - bufferSeconds)
        .lte('start_time_seconds', request.summary_end_time_seconds + bufferSeconds)
        .order('start_time_seconds', { ascending: true })
      
      if (activitiesError) {
        console.error(`   ❌ Error checking activities for request ${request.id}:`, activitiesError)
        results.push({
          backfill_id: request.id,
          start: new Date(request.summary_start_time_seconds * 1000).toISOString(),
          end: new Date(request.summary_end_time_seconds * 1000).toISOString(),
          activities_found: 0,
          error: activitiesError.message
        })
        continue
      }
      
      const activityCount = activities?.length || 0
      const requestAge = (Date.now() - new Date(request.created_at).getTime()) / (1000 * 60 * 60 * 24)
      
      console.log(`   Request ${request.id}:`)
      console.log(`     Date range: ${new Date(request.summary_start_time_seconds * 1000).toISOString()} to ${new Date(request.summary_end_time_seconds * 1000).toISOString()}`)
      console.log(`     Age: ${requestAge.toFixed(1)} days`)
      console.log(`     Activities found: ${activityCount}`)
      
      results.push({
        backfill_id: request.id,
        start: new Date(request.summary_start_time_seconds * 1000).toISOString(),
        end: new Date(request.summary_end_time_seconds * 1000).toISOString(),
        age_days: requestAge.toFixed(1),
        activities_found: activityCount,
        activity_ids: activities?.map(a => a.garmin_activity_id) || []
      })
      
      // Mark as completed if activities exist and mark_completed is true
      if (mark_completed && activityCount > 0) {
        const { error: updateError } = await supabase
          .from('garmin_backfill_requests')
          .update({
            status: 'completed',
            completed_at: new Date().toISOString()
          })
          .eq('id', request.id)
        
        if (updateError) {
          console.error(`   ❌ Failed to mark request ${request.id} as completed:`, updateError)
        } else {
          console.log(`   ✅ Marked request ${request.id} as completed`)
          updated.push({
            backfill_id: request.id,
            activities_found: activityCount
          })
        }
      }
    }
    
    const duration = Date.now() - startTime
    console.log(`✅ Status check completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      success: true,
      pending_count: pendingRequests.length,
      checked: results,
      updated: updated,
      updated_count: updated.length,
      note: mark_completed 
        ? "Requests with activities have been marked as completed"
        : "Set mark_completed=true to automatically mark requests with activities as completed",
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in backfill status checker:", error)
    
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

