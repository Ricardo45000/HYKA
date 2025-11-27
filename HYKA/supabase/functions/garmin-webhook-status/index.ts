// ============================================================================
// Garmin Webhook Status Checker
// ============================================================================
// Purpose: Diagnose why activities aren't automatically syncing
// 
// Checks:
// 1. If webhooks are configured correctly
// 2. If webhooks are being received
// 3. If activities exist in database
// 4. If there are processing errors
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
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
        'Access-Control-Max-Age': '86400',
      },
    })
  }
  
  try {
    console.log("🔍 Garmin Webhook Status Checker started")
    
    const { user_id } = await req.json()
    
    if (!user_id) {
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
    
    // 1. Check Garmin connection
    const { data: connection, error: connectionError } = await supabase
      .from('garmin_connections')
      .select('garmin_user_id, connected_at, last_sync_at, permission_revoked')
      .eq('user_id', user_id)
      .single()
    
    if (connectionError || !connection) {
      return new Response(JSON.stringify({
        success: false,
        error: "No Garmin connection found",
        diagnostics: {
          has_connection: false,
          message: "User needs to connect Garmin account first"
        }
      }), {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    // 2. Check recent activities in database
    const oneDayAgo = Math.floor((Date.now() - 24 * 60 * 60 * 1000) / 1000)
    const { data: recentActivities, error: activitiesError } = await supabase
      .from('garmin_activities')
      .select('id, garmin_activity_id, activity_type, start_time_seconds, created_at')
      .eq('user_id', user_id)
      .gte('start_time_seconds', oneDayAgo)
      .order('start_time_seconds', { ascending: false })
      .limit(10)
    
    // 3. Check recent backfill requests
    const { data: recentBackfills, error: backfillError } = await supabase
      .from('garmin_backfill_requests')
      .select('id, summary_start_time_seconds, summary_end_time_seconds, status, created_at')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(5)
    
    // 4. Check webhook function logs (if accessible)
    // Note: This would require Supabase API access to logs, which may not be available
    // For now, we'll provide diagnostic information
    
    const diagnostics = {
      connection: {
        exists: true,
        garmin_user_id: connection.garmin_user_id,
        connected_at: connection.connected_at,
        last_sync_at: connection.last_sync_at,
        permission_revoked: connection.permission_revoked,
        days_since_connection: connection.connected_at 
          ? Math.floor((Date.now() - new Date(connection.connected_at).getTime()) / (1000 * 60 * 60 * 24))
          : null
      },
      activities: {
        recent_count: recentActivities?.length || 0,
        has_recent_activities: (recentActivities?.length || 0) > 0,
        latest_activity: recentActivities && recentActivities.length > 0
          ? {
              id: recentActivities[0].garmin_activity_id,
              type: recentActivities[0].activity_type,
              start_time: new Date(recentActivities[0].start_time_seconds * 1000).toISOString(),
              created_at: recentActivities[0].created_at
            }
          : null
      },
      backfill_requests: {
        recent_count: recentBackfills?.length || 0,
        pending_count: recentBackfills?.filter(r => r.status === 'pending').length || 0,
        completed_count: recentBackfills?.filter(r => r.status === 'completed').length || 0,
        latest_request: recentBackfills && recentBackfills.length > 0
          ? {
              status: recentBackfills[0].status,
              created_at: recentBackfills[0].created_at,
              age_hours: Math.floor((Date.now() - new Date(recentBackfills[0].created_at).getTime()) / (1000 * 60 * 60))
            }
          : null
      },
      webhook_configuration: {
        ping_url: `${supabaseUrl}/functions/v1/garmin-activity-ping`,
        push_url: `${supabaseUrl}/functions/v1/garmin-activity-push`,
        health_url: `${supabaseUrl}/functions/v1/garmin-health-webhook`,
        note: "Verify these URLs are configured in Garmin Developer Portal → Endpoint Configuration"
      },
      recommendations: [] as string[]
    }
    
    // Generate recommendations
    if (!diagnostics.activities.has_recent_activities) {
      diagnostics.recommendations.push("No recent activities found in database")
      diagnostics.recommendations.push("Check if webhooks are configured in Garmin Developer Portal")
      diagnostics.recommendations.push("Check Supabase Edge Function logs for webhook invocations")
      diagnostics.recommendations.push("Verify activity types match filter (Running/Hiking/Walking only)")
    }
    
    if (connection.permission_revoked) {
      diagnostics.recommendations.push("Garmin permissions have been revoked - user needs to reconnect")
    }
    
    if (diagnostics.backfill_requests.pending_count > 0 && diagnostics.backfill_requests.latest_request) {
      const ageHours = diagnostics.backfill_requests.latest_request.age_hours
      if (ageHours > 24) {
        diagnostics.recommendations.push(`Backfill request pending for ${ageHours} hours - webhooks may not be arriving`)
      }
    }
    
    if (!connection.last_sync_at) {
      diagnostics.recommendations.push("No activities have been synced yet - check webhook configuration")
    }
    
    const duration = Date.now() - startTime
    
    return new Response(JSON.stringify({
      success: true,
      diagnostics,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in webhook status check:", error)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
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

