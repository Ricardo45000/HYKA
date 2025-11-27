// ============================================================================
// Strava Auth Callback (OAuth 2.0)
// ============================================================================
//
// Purpose: Receives OAuth2 redirect from iOS app, exchanges code for tokens,
//          fetches Strava athlete ID, stores connection, and registers webhooks
//
// Flow:
// 1. Receive OAuth2 code from iOS app (after user authorizes)
// 2. Exchange code for access_token + refresh_token
// 3. Fetch Strava athlete ID from /api/v3/athlete
// 4. Store tokens and user mapping in strava_connections
// 5. Register webhook subscription with Strava (if needed)
// 6. Return success to iOS app
//
// Reference: Strava API v3 OAuth 2.0
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
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }
  
  const startTime = Date.now()
  
  try {
    console.log("🔐 Strava Auth Callback started")
    console.log("   Method:", req.method)
    
    // Parse request
    const body = await req.json()
    const code = body.code
    const redirectUri = body.redirect_uri || body.redirectUri
    const userId = body.user_id // HYKA user ID from iOS app
    
    if (!code || !redirectUri || !userId) {
      console.error("❌ Missing required parameters")
      return new Response(JSON.stringify({ 
        error: "Missing required parameters: code, redirect_uri, user_id" 
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
        }
      })
    }
    
    console.log("   User ID:", userId)
    console.log("   Code:", code.substring(0, 20) + "...")
    console.log("   Redirect URI:", redirectUri)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Get client credentials from environment
    const clientId = Deno.env.get('STRAVA_CLIENT_ID')
    const clientSecret = Deno.env.get('STRAVA_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      console.error("❌ STRAVA_CLIENT_ID or STRAVA_CLIENT_SECRET not set")
      return new Response(JSON.stringify({ 
        error: "Server configuration error: Strava credentials not set" 
      }), {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
        }
      })
    }
    
    // Step 1: Exchange code for tokens
    console.log("🔄 Exchanging authorization code for tokens...")
    const tokenUrl = "https://www.strava.com/oauth/token"
    
    const params = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: code,
      grant_type: "authorization_code",
      redirect_uri: redirectUri
    })
    
    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      body: params.toString()
    })
    
    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error("❌ Token exchange failed:", tokenResponse.status, errorText)
      throw new Error(`Token exchange failed: ${tokenResponse.status} - ${errorText}`)
    }
    
    const tokenData = await tokenResponse.json()
    const accessToken = tokenData.access_token
    const refreshToken = tokenData.refresh_token
    const expiresAt = tokenData.expires_at // Unix timestamp
    const athlete = tokenData.athlete
    
    if (!accessToken || !athlete || !athlete.id) {
      throw new Error("Invalid token response from Strava")
    }
    
    console.log("✅ Tokens received")
    console.log("   Access token:", accessToken.substring(0, 20) + "...")
    console.log("   Expires at:", new Date(expiresAt * 1000).toISOString())
    console.log("   Athlete ID:", athlete.id)
    
    // Step 2: Calculate token expiration
    const expiresAtDate = expiresAt 
      ? new Date(expiresAt * 1000).toISOString()
      : null
    
    // Step 3: Store connection in database
    console.log("💾 Storing connection in database...")
    
    const { data: connection, error: connectionError } = await supabase
      .from('strava_connections')
      .upsert({
        user_id: userId,
        strava_athlete_id: athlete.id,
        access_token: accessToken,
        refresh_token: refreshToken,
        token_expires_at: expiresAtDate,
        connected_at: new Date().toISOString(),
        permission_revoked: false,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id'
      })
      .select('id')
      .single()
    
    if (connectionError || !connection) {
      console.error("❌ Failed to store connection:", connectionError)
      throw new Error(`Failed to store connection: ${connectionError?.message}`)
    }
    
    console.log("✅ Connection stored:", connection.id)
    
    // Step 4: Register webhook subscription with Strava
    // Note: Webhook subscription is typically done via Strava Developer Portal
    // However, we can also register programmatically
    console.log("ℹ️ Webhook URL should be configured in Strava Developer Portal:")
    console.log("   - Activity Webhook: /functions/v1/strava-activity-webhook")
    
    const duration = Date.now() - startTime
    console.log(`✅ Auth callback completed in ${duration}ms`)
    
    // Return tokens in format expected by iOS app
    return new Response(JSON.stringify({
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_at: expiresAt,
      token_type: "Bearer",
      athlete: {
        id: athlete.id,
        firstname: athlete.firstname,
        lastname: athlete.lastname
      },
      connection_id: connection.id
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in auth callback:", error)
    console.error("   Duration:", `${duration}ms`)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }
})

