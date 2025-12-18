import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }

  try {
    console.log("📥 Strava Activity Webhook started")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    
    // Strava webhook verification (GET request)
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const mode = url.searchParams.get('hub.mode')
      const token = url.searchParams.get('hub.verify_token')
      const challenge = url.searchParams.get('hub.challenge')

      const verifyToken = Deno.env.get('STRAVA_WEBHOOK_VERIFY_TOKEN') || 'strava-webhook-verify-token-2025'

      if (mode === 'subscribe' && token === verifyToken) {
        console.log("✅ Strava webhook verified")
        return new Response(JSON.stringify({
          'hub.challenge': challenge
        }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        })
      } else {
        console.error("❌ Strava webhook verification failed")
        return new Response(JSON.stringify({
          error: "Verification failed"
        }), {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        })
      }
    }

    // Handle webhook event (POST request)
    const body = await req.json()
    console.log("📨 Webhook payload:", JSON.stringify(body, null, 2))
    
    const objectType = body.object_type
    const objectId = body.object_id
    const aspectType = body.aspect_type
    const ownerId = body.owner_id

    console.log("📋 Parsed webhook event:", {
      object_type: objectType,
      object_id: objectId,
      aspect_type: aspectType,
      owner_id: ownerId
    })

    // Only process activity creation/updates
    if (objectType !== 'activity' || (aspectType !== 'create' && aspectType !== 'update')) {
      console.log("⏭️ Skipping event (not activity create/update):", { objectType, aspectType })
      return new Response(JSON.stringify({
        success: true,
        message: "Event skipped"
      }), {
        status: 200,
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

    // Find user by Strava athlete ID
    // ownerId from Strava webhook is a number, strava_athlete_id in DB is integer
    // Convert to number to ensure proper type matching
    const athleteId = typeof ownerId === 'number' ? ownerId : parseInt(ownerId.toString(), 10)
    
    console.log("🔍 Looking up connection for athlete_id:", athleteId)
    console.log("   Type:", typeof athleteId, "Value:", athleteId)
    
    const { data: connection, error: connError } = await supabase
      .from('strava_connections')
      .select('user_id, strava_athlete_id, access_token, refresh_token, token_expires_at')
      .eq('strava_athlete_id', athleteId)
      .single()

    if (connError || !connection) {
      console.error("❌ Strava connection not found for athlete:", athleteId)
      console.error("   Error details:", connError)
      
      // Debug: Check what connections exist
      const { data: allConnections } = await supabase
        .from('strava_connections')
        .select('user_id, strava_athlete_id')
        .limit(5)
      console.log("   Available connections:", allConnections)
      
      return new Response(JSON.stringify({
        success: false,
        error: "Connection not found",
        athlete_id: athleteId,
        error_details: connError?.message
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    console.log("✅ Found connection:", {
      user_id: connection.user_id,
      strava_athlete_id: connection.strava_athlete_id
    })

    // Deduplication: Check if we've recently processed this activity
    // Strava can send multiple webhooks for the same activity (create, update, retries)
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString()
    
    const { data: existingActivity, error: checkError } = await supabase
      .from('strava_activities')
      .select('id, updated_at, strava_activity_id')
      .eq('user_id', connection.user_id)
      .eq('strava_activity_id', objectId.toString())
      .single()
    
    if (existingActivity) {
      const lastUpdated = new Date(existingActivity.updated_at).getTime()
      const now = Date.now()
      const timeSinceUpdate = now - lastUpdated
      const fiveMinutes = 5 * 60 * 1000
      
      console.log(`🔍 Activity ${objectId} already exists in database`)
      console.log(`   Last updated: ${existingActivity.updated_at}`)
      console.log(`   Time since update: ${Math.round(timeSinceUpdate / 1000)}s`)
      
      // If activity was updated within the last 5 minutes, skip to prevent duplicate processing
      if (timeSinceUpdate < fiveMinutes) {
        console.log(`⏭️ SKIPPING: Activity ${objectId} was recently processed (${Math.round(timeSinceUpdate / 1000)}s ago)`)
        console.log(`   This is likely a duplicate webhook from Strava`)
        return new Response(JSON.stringify({
          success: true,
          message: "Activity recently processed, skipping duplicate",
          activity_id: objectId,
          last_updated: existingActivity.updated_at
        }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        })
      } else {
        console.log(`✅ Activity exists but was last updated ${Math.round(timeSinceUpdate / 1000)}s ago`)
        console.log(`   Processing ${aspectType} event to refresh data`)
      }
    } else {
      console.log(`🆕 New activity detected: ${objectId}`)
    }

    console.log("➡️ Forwarding activity to strava-activity-store:", objectId)
    
    // Forward to strava-activity-store which handles:
    // 1. Fetching activity details from Strava API
    // 2. Storing activity in database
    // 3. Sending Notification
    // This ensures consistency and centralizes all logic
    
    const storeUrl = `${supabaseUrl}/functions/v1/strava-activity-store`
    
    const storeResponse = await fetch(storeUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        user_id: connection.user_id,
        activity_id: objectId.toString()
      })
    })
    
    if (!storeResponse.ok) {
      const errorText = await storeResponse.text()
      console.error(`❌ Failed to forward to store: ${storeResponse.status} - ${errorText}`)
      throw new Error(`Failed to forward to store: ${storeResponse.status} - ${errorText}`)
    }
    
    const storeResult = await storeResponse.json()
    console.log("✅ Forwarded successfully:", storeResult)

    return new Response(JSON.stringify({
      success: true,
      activity_id: objectId
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error("❌ Error in Strava webhook:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
})


