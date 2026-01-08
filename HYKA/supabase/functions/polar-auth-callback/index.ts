// ============================================================================
// Polar Auth Callback (OAuth 2.0)
// ============================================================================
//
// Purpose: Receives OAuth2 redirect from iOS app, exchanges code for tokens,
//          registers user with Polar AccessLink, and stores connection.
//
// Flow:
// 1. Receive OAuth2 code from iOS app (after user authorizes)
// 2. Exchange code for access_token + refresh_token
// 3. Register user with Polar AccessLink (required for data access)
// 4. Store tokens and user mapping in polar_connections
// 5. Return success to iOS app
//
// Reference: Polar AccessLink API v3
// ============================================================================

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
  
  const startTime = Date.now()
  
  try {
    console.log("🔐 Polar Auth Callback started")
    
    // Handle GET requests (web redirect)
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const code = url.searchParams.get('code')
      const state = url.searchParams.get('state')
      const error = url.searchParams.get('error')
      
      if (error) {
        console.error("❌ Polar OAuth error:", error)
        const appRedirectURL = `app.hyka.com://?error=${encodeURIComponent(error)}`
        return new Response(null, {
          status: 302,
          headers: { 'Location': appRedirectURL, 'Access-Control-Allow-Origin': '*' }
        })
      }
      
      if (!code) {
        console.error("❌ No code in GET request")
        const appRedirectURL = `app.hyka.com://?error=no_code`
        return new Response(null, {
          status: 302,
          headers: { 'Location': appRedirectURL, 'Access-Control-Allow-Origin': '*' }
        })
      }
      
      console.log("✅ Received code from Polar redirect")
      
      // Redirect to app with code
      const appRedirectURL = `app.hyka.com://?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state || 'polar_oauth')}`
      console.log("🌐 Redirecting to app:", appRedirectURL)
      
      return new Response(null, {
        status: 302,
        headers: { 'Location': appRedirectURL, 'Access-Control-Allow-Origin': '*' }
      })
    }
    
    // Handle POST requests (token exchange)
    const body = await req.json()
    const code = body.code
    const redirectUri = body.redirect_uri || body.redirectUri
    const userId = body.user_id
    
    if (!code || !redirectUri || !userId) {
      return new Response(JSON.stringify({ 
        error: "Missing required parameters: code, redirect_uri, user_id" 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }
    
    console.log("   User ID:", userId)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Get credentials
    const clientId = Deno.env.get('POLAR_CLIENT_ID')
    const clientSecret = Deno.env.get('POLAR_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      throw new Error("Server configuration error: Polar credentials not set")
    }
    
    // Step 1: Exchange code for tokens
    console.log("🔄 Exchanging authorization code for tokens...")
    const tokenUrl = "https://polarremote.com/v2/oauth2/token"
    
    // Basic Auth header
    const authString = btoa(`${clientId}:${clientSecret}`)
    
    const params = new URLSearchParams({
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirectUri
    })
    
    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${authString}`,
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
    const refreshToken = tokenData.refresh_token // Polar creates refresh token but expiration is long
    const expiresIn = tokenData.expires_in
    const polarUserId = tokenData.x_user_id?.toString()
    
    console.log("✅ Tokens received")
    if (polarUserId) console.log("   Polar User ID:", polarUserId)
    
    // Step 2: Register User with Polar AccessLink
    // Required to access data
    console.log("👤 Registering Polar user...")
    const registerUrl = "https://www.polaraccesslink.com/v3/users"
    
    const registerResponse = await fetch(registerUrl, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        body: JSON.stringify({ "member-id": userId }) // Use Supabase UUID as member-id
    })
    
    if (registerResponse.status === 200) {
        console.log("✅ User already registered")
    } else if (registerResponse.status === 201) {
        console.log("✅ User registered successfully")
    } else {
        console.warn("⚠️ Registration warning:", registerResponse.status, await registerResponse.text())
        // Proceed anyway, as failure might mean "already registered" in some edge cases or other non-critical issue
    }
    
    // Step 3: Store connection
    const expiresAtDate = expiresIn 
      ? new Date(Date.now() + expiresIn * 1000).toISOString()
      : null
      
    console.log("💾 Storing connection in database...")
    
    const { data: connection, error: connectionError } = await supabase
      .from('polar_connections')
      .upsert({
        user_id: userId,
        polar_user_id: polarUserId, // Store if available from token response
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
    
    if (connectionError) {
      console.error("❌ Failed to store connection:", connectionError)
      throw new Error(`Failed to store connection: ${connectionError.message}`)
    }
    
    console.log("✅ Connection stored:", connection.id)
    
    const duration = Date.now() - startTime
    
    return new Response(JSON.stringify({
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: expiresIn,
      polar_user_id: polarUserId,
      connection_id: connection.id
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
    
  } catch (error) {
    console.error("❌ Error in auth callback:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    })
  }
})


