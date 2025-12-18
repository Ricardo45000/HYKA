// ============================================================================
// Garmin Health Sync - Pull Historical Health Data
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
    console.log("🏥 Garmin Health Sync started")
    
    // Parse request body
    const body = await req.json()
    const userId = body.user_id
    const daysBack = body.days_back || 30
    
    if (!userId) {
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`   User ID: ${userId}`)
    console.log(`   Days back: ${daysBack}`)

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
          // Try the diauth endpoint (OAuth2 PKCE)
          const tokenUrl = 'https://diauth.garmin.com/di-oauth2-service/oauth/token'
          
          // Decode refresh token if it's base64 encoded
          let refreshToken = connection.refresh_token
          try {
            const decoded = atob(refreshToken)
            const parsed = JSON.parse(decoded)
            if (parsed.refreshTokenValue) {
              refreshToken = parsed.refreshTokenValue
              console.log("   📦 Decoded refresh token from base64 JSON")
            }
          } catch (e) {
            console.log("   📦 Using refresh token as-is (not base64)")
          }
          
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
            
            // Update local variable
            accessToken = tokens.access_token
            
            // Update database
            const newExpiresAt = new Date(Date.now() + (tokens.expires_in || 3600) * 1000).toISOString()
            
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
              console.error("   ❌ Failed to update tokens in database:", updateError)
            } else {
              console.log("   💾 Refreshed tokens saved to database")
            }
          } else {
            const errorText = await refreshResponse.text()
            console.error(`   ❌ Token refresh failed: ${refreshResponse.status}`)
            console.error(`   Error: ${errorText.substring(0, 200)}`)
            return new Response(JSON.stringify({ 
              error: "Token refresh failed",
              status: refreshResponse.status,
              hint: "Try reconnecting Garmin in the app"
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
      } else {
        console.log("   ✅ Token is still valid")
      }
    } else {
      if (!connection.token_expires_at) {
        console.warn("   ⚠️ No token_expires_at in database")
      }
      if (!connection.refresh_token) {
        console.warn("   ⚠️ No refresh_token in database - cannot refresh")
      }
    }

    // Calculate date range
    const nowSeconds = Math.floor(Date.now() / 1000)
    const startDate = nowSeconds - (daysBack * 24 * 60 * 60)
    const endDate = nowSeconds

    console.log(`📅 Date range: ${new Date(startDate * 1000).toISOString()} to ${new Date(endDate * 1000).toISOString()}`)

    // Make backfill requests with delays
    const domain = "https://apis.garmin.com"
    const results: Record<string, { status: number; message: string }> = {}
    
    const endpoints = [
      { name: 'dailies', path: 'dailies' },
      { name: 'sleeps', path: 'sleeps' },
      { name: 'stress', path: 'stressDetails' },
      { name: 'bodyComps', path: 'bodyComps' },
      { name: 'pulseOx', path: 'pulseOx' },
      { name: 'respiration', path: 'respiration' },
    ]

    for (const endpoint of endpoints) {
      const url = `${domain}/wellness-api/rest/backfill/${endpoint.path}?summaryStartTimeInSeconds=${startDate}&summaryEndTimeInSeconds=${endDate}`
      console.log(`🔄 Fetching ${endpoint.name}...`)
      
      try {
        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/json'
          }
        })

        results[endpoint.name] = {
          status: response.status,
          message: response.status === 202 ? 'Backfill accepted' : 
                   response.status === 409 ? 'Already requested' :
                   response.status === 401 ? 'Token expired/invalid' :
                   response.status === 429 ? 'Rate limited' :
                   response.ok ? 'Success' : 'Failed'
        }
        console.log(`   ${endpoint.name}: ${response.status} - ${results[endpoint.name].message}`)
      } catch (err) {
        results[endpoint.name] = { status: 0, message: `Error: ${err.message}` }
        console.error(`   ${endpoint.name}: Error - ${err.message}`)
      }

      // Delay between requests to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000))
    }

    const duration = Date.now() - startTime
    console.log(`✅ Health sync completed in ${duration}ms`)

    return new Response(JSON.stringify({
      success: true,
      user_id: userId,
      days_back: daysBack,
      results,
      duration: `${duration}ms`,
      note: "Backfill returns 202 - data arrives via webhooks"
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error("❌ Error:", error)
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
