// ============================================================================
// Polar Workout Create - Create workout in Polar Flow
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
    console.log("🏃 Polar Workout Create started")
    
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
    console.log(`   Workout Name: ${workoutData.name || workoutData.workoutName || 'Unknown'}`)
    
    // Validate workout structure
    if (!workoutData.steps || !Array.isArray(workoutData.steps) || workoutData.steps.length === 0) {
      console.error("❌ Invalid workout structure: steps array is missing or empty")
      return new Response(JSON.stringify({ 
        error: "Invalid workout structure",
        details: "Workout must contain a non-empty steps array"
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log(`   Total steps: ${workoutData.steps.length}`)

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch Polar connection
    const { data: connection, error: connError } = await supabase
      .from('polar_connections')
      .select('user_id, polar_user_id, access_token, refresh_token, token_expires_at')
      .eq('user_id', userId)
      .single()

    if (connError || !connection) {
      console.error("❌ No Polar connection found:", connError?.message)
      return new Response(JSON.stringify({ error: "No Polar connection found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`✅ Found Polar connection for user: ${connection.polar_user_id || 'unknown'}`)

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
          const clientId = Deno.env.get('POLAR_CLIENT_ID')
          const clientSecret = Deno.env.get('POLAR_CLIENT_SECRET')
          
          if (!clientId || !clientSecret) {
            console.error("   ❌ Missing POLAR_CLIENT_ID or POLAR_CLIENT_SECRET")
            return new Response(JSON.stringify({ 
              error: "Missing Polar credentials for token refresh",
              hint: "Set POLAR_CLIENT_ID and POLAR_CLIENT_SECRET in Supabase secrets"
            }), {
              status: 500,
              headers: { 'Content-Type': 'application/json' }
            })
          }
          
          console.log("   🔄 Attempting token refresh...")
          const tokenUrl = 'https://polarremote.com/v2/oauth2/token'
          
          let refreshToken = connection.refresh_token
          const refreshResponse = await fetch(tokenUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': `Basic ${btoa(`${clientId}:${clientSecret}`)}`
            },
            body: new URLSearchParams({
              grant_type: 'refresh_token',
              refresh_token: refreshToken
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
              .from('polar_connections')
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

    // Create workout in Polar Flow
    // Note: Polar API endpoint may need adjustment based on actual API documentation
    console.log("📡 Creating workout in Polar Flow...")
    const workoutUrl = 'https://www.polaraccesslink.com/v3/training-programs' // May need adjustment
    
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
        error: "Failed to create workout in Polar Flow",
        status: workoutResponse.status,
        details: errorText
      }), {
        status: workoutResponse.status,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const workoutResult = await workoutResponse.json()
    const workoutId = workoutResult.id || workoutResult.workoutId || workoutResult.workout_id || 'success'
    
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
