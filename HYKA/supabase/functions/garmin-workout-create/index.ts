// ============================================================================
// Garmin Workout Create - Create workout in Garmin Connect
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
    console.log("🏃 Garmin Workout Create started")
    
    // Parse request body
    const body = await req.json()
    const userId = body.user_id
    const workoutData = body.workout // The workout JSON structure

    if (!userId) {
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    if (!workoutData) {
      return new Response(JSON.stringify({ error: "Missing workout data" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`   User ID: ${userId}`)
    console.log(`   Workout Name: ${workoutData.workoutName || 'Unknown'}`)
    
    // Validate workout structure
    if (!workoutData.segments || !Array.isArray(workoutData.segments) || workoutData.segments.length === 0) {
      console.error("❌ Invalid workout structure: segments array is missing or empty")
      return new Response(JSON.stringify({ 
        error: "Invalid workout structure",
        details: "Workout must contain a non-empty segments array"
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log(`   Segments: ${workoutData.segments.length}`)
    console.log(`   Total steps: ${workoutData.segments.reduce((sum: number, seg: any) => sum + (seg.steps?.length || 0), 0)}`)

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
      
      console.log(`   Token expires at: ${new Date(expiresAt).toISOString()}`)
      console.log(`   Time until expiry: ${Math.floor(timeUntilExpiry / 1000)}s`)
      
      // Refresh if expired or expiring in the next 5 minutes
      if (now >= expiresAt - fiveMinutes) {
        console.log("   ⚠️ Access token is expired or expiring soon. Refreshing...")
        try {
          const clientId = Deno.env.get('GARMIN_CLIENT_ID') || Deno.env.get('GARMIN_CONSUMER_KEY')
          const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET') || Deno.env.get('GARMIN_CONSUMER_SECRET')
          
          if (!clientId || !clientSecret) {
            console.error("   ❌ Missing GARMIN_CLIENT_ID or GARMIN_CLIENT_SECRET")
            return new Response(JSON.stringify({ 
              error: "Missing Garmin credentials for token refresh",
              hint: "Set GARMIN_CLIENT_ID and GARMIN_CLIENT_SECRET in Supabase secrets"
            }), {
              status: 500,
              headers: { 'Content-Type': 'application/json' }
            })
          }
          
          console.log("   🔄 Attempting token refresh...")
          const tokenUrl = 'https://diauth.garmin.com/di-oauth2-service/oauth/token'
          
          let refreshToken = connection.refresh_token
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
            
            accessToken = tokens.access_token
            
            // Calculate new expiration
            const expiresIn = tokens.expires_in || 3600
            const newExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString()
            
            // Update database
            const { error: updateError } = await supabase
              .from('garmin_connections')
              .update({
                access_token: tokens.access_token,
                refresh_token: tokens.refresh_token || connection.refresh_token,
                token_expires_at: newExpiresAt,
                updated_at: new Date().toISOString()
              })
              .eq('user_id', userId)
            
            if (updateError) {
              console.error("   ⚠️ Failed to update token in database:", updateError)
            } else {
              console.log("   💾 Refreshed tokens saved to database")
            }
          } else {
            const errorText = await refreshResponse.text()
            console.error(`   ❌ Token refresh failed: ${refreshResponse.status} - ${errorText}`)
            return new Response(JSON.stringify({ 
              error: "Token refresh failed - Refresh token is invalid or expired",
              details: errorText
            }), {
              status: 401,
              headers: { 'Content-Type': 'application/json' }
            })
          }
        } catch (e) {
          console.error("   ❌ Error refreshing token:", e)
          return new Response(JSON.stringify({ 
            error: "Token refresh error",
            details: e.message
          }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          })
        }
      }
    }

    // Create workout in Garmin Connect
    console.log("📡 Creating workout in Garmin Connect...")
    console.log("   Endpoint: https://apis.garmin.com/workoutportal/workout/v2")
    console.log("   Workout structure:", JSON.stringify({
      workoutName: workoutData.workoutName,
      sport: workoutData.sport,
      segmentsCount: workoutData.segments?.length || 0
    }))
    
    const workoutUrl = 'https://apis.garmin.com/workoutportal/workout/v2'
    
    const workoutResponse = await fetch(workoutUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(workoutData)
    })

    if (!workoutResponse.ok) {
      const errorText = await workoutResponse.text()
      console.error(`❌ Workout creation failed: ${workoutResponse.status} - ${errorText}`)
      
      return new Response(JSON.stringify({ 
        error: "Failed to create workout in Garmin Connect",
        status: workoutResponse.status,
        details: errorText
      }), {
        status: workoutResponse.status,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const workoutResult = await workoutResponse.json()
    const workoutId = workoutResult.workoutId || workoutResult.id || workoutResult.workout_id || 'success'
    
    console.log(`✅ Workout created successfully: ${workoutId}`)
    
    const duration = Date.now() - startTime
    console.log(`⏱️  Total time: ${duration}ms`)

    return new Response(JSON.stringify({ 
      success: true,
      workoutId: workoutId,
      workout: workoutResult
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error("❌ Error creating workout:", error)
    return new Response(JSON.stringify({ 
      error: "Internal server error",
      details: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
