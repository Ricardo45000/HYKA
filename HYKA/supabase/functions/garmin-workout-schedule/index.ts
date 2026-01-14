// ============================================================================
// Garmin Workout Schedule - Schedule workout in Garmin Connect
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  const startTime = Date.now()

  try {
    console.log("📅 Garmin Workout Schedule started")
    
    // Parse request body
    const body = await req.json()
    const userId = body.user_id
    const workoutId = body.workout_id
    const date = body.date // Format: YYYY-mm-dd

    if (!userId) {
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    if (!workoutId) {
      return new Response(JSON.stringify({ error: "Missing workout_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    if (!date) {
      return new Response(JSON.stringify({ error: "Missing date" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`   User ID: ${userId}`)
    console.log(`   Workout ID: ${workoutId}`)
    console.log(`   Date: ${date}`)

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch Garmin connection
    const { data: connection, error: connError } = await supabase
      .from('garmin_connections')
      .select('user_id, garmin_user_id, access_token, refresh_token, token_expires_at')
      .eq('user_id', userId)
      .single()

    if (connError || !connection) {
      console.error("❌ No Garmin connection found:", connError?.message)
      return new Response(JSON.stringify({ error: "No Garmin connection found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`✅ Found Garmin connection for user: ${connection.garmin_user_id}`)

    let accessToken = connection.access_token
    if (!accessToken) {
      return new Response(JSON.stringify({ error: "No access token" }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Check for token expiration and refresh if needed
    if (connection.token_expires_at && connection.refresh_token) {
      const expiresAt = new Date(connection.token_expires_at).getTime()
      const now = Date.now()
      const timeUntilExpiry = expiresAt - now
      const fiveMinutes = 5 * 60 * 1000
      
      if (now >= expiresAt - fiveMinutes) {
        console.log("   ⚠️ Access token is expired or expiring soon. Refreshing...")
        try {
          const clientId = Deno.env.get('GARMIN_CLIENT_ID') || Deno.env.get('GARMIN_CONSUMER_KEY')
          const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET') || Deno.env.get('GARMIN_CONSUMER_SECRET')
          
          if (!clientId || !clientSecret) {
            return new Response(JSON.stringify({ 
              error: "Missing Garmin credentials for token refresh"
            }), {
              status: 500,
              headers: { 'Content-Type': 'application/json' }
            })
          }
          
          const tokenUrl = 'https://diauth.garmin.com/di-oauth2-service/oauth/token'
          const refreshResponse = await fetch(tokenUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
              refresh_token: connection.refresh_token,
              client_id: clientId,
              client_secret: clientSecret,
              grant_type: 'refresh_token'
            })
          })

          if (refreshResponse.ok) {
            const tokens = await refreshResponse.json()
            accessToken = tokens.access_token
            
            const expiresIn = tokens.expires_in || 3600
            const newExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString()
            
            await supabase
              .from('garmin_connections')
              .update({
                access_token: tokens.access_token,
                refresh_token: tokens.refresh_token || connection.refresh_token,
                token_expires_at: newExpiresAt,
                updated_at: new Date().toISOString()
              })
              .eq('user_id', userId)
          }
        } catch (e) {
          console.error("   ❌ Error refreshing token:", e)
        }
      }
    }

    // Schedule workout in Garmin Connect
    console.log("📡 Scheduling workout in Garmin Connect...")
    const scheduleUrl = 'https://apis.garmin.com/training-api/schedule/'
    
    // Convert workoutId to number if it's a string
    const workoutIdNum = typeof workoutId === 'string' ? parseInt(workoutId, 10) : workoutId
    
    const scheduleData = {
      workoutId: workoutIdNum,
      date: date
    }
    
    console.log("   Schedule data:", JSON.stringify(scheduleData))
    
    const scheduleResponse = await fetch(scheduleUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(scheduleData)
    })

    if (!scheduleResponse.ok) {
      const errorText = await scheduleResponse.text()
      console.error(`❌ Workout scheduling failed: ${scheduleResponse.status} - ${errorText}`)
      
      return new Response(JSON.stringify({ 
        error: "Failed to schedule workout in Garmin Connect",
        status: scheduleResponse.status,
        details: errorText
      }), {
        status: scheduleResponse.status,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const scheduleResult = await scheduleResponse.json()
    const scheduleId = scheduleResult.scheduleId || scheduleResult.id || 'success'
    
    console.log(`✅ Workout scheduled successfully: ${scheduleId}`)
    
    const duration = Date.now() - startTime
    console.log(`⏱️  Total time: ${duration}ms`)

    return new Response(JSON.stringify({ 
      success: true,
      scheduleId: scheduleId,
      schedule: scheduleResult
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error("❌ Error scheduling workout:", error)
    return new Response(JSON.stringify({ 
      error: "Internal server error",
      details: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
