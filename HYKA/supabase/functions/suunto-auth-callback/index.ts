// ============================================================================
// Suunto Auth Callback (OAuth 2.0)
// ============================================================================
//
// Purpose: Receives OAuth2 redirect from iOS app, exchanges code for tokens,
//          fetches Suunto user ID, stores connection, and registers webhooks
//
// Flow:
// 1. Receive OAuth2 code from iOS app (after user authorizes)
// 2. Exchange code for access_token + refresh_token
// 3. Fetch Suunto user ID from /v2/user
// 4. Store tokens and user mapping in suunto_connections
// 5. Register webhook subscription with Suunto (if needed)
// 6. Return success to iOS app
//
// Reference: Suunto API OAuth 2.0
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
    console.log("🔐 Suunto Auth Callback started")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    
    // Handle GET requests (web redirect from Suunto OAuth)
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const code = url.searchParams.get('code')
      const state = url.searchParams.get('state')
      const error = url.searchParams.get('error')
      
      if (error) {
        console.error("❌ Suunto OAuth error:", error)
        // Redirect to app with error
        const appRedirectURL = `app.hyka.com://?error=${encodeURIComponent(error)}`
        return new Response(null, {
          status: 302,
          headers: {
            'Location': appRedirectURL,
            'Access-Control-Allow-Origin': '*'
          }
        })
      }
      
      if (!code) {
        console.error("❌ No code in GET request")
        const appRedirectURL = `app.hyka.com://?error=no_code`
        return new Response(null, {
          status: 302,
          headers: {
            'Location': appRedirectURL,
            'Access-Control-Allow-Origin': '*'
          }
        })
      }
      
      console.log("✅ Received code from Suunto redirect")
      console.log("   Code:", code.substring(0, 20) + "...")
      console.log("   State:", state)
      
      // Redirect to app with code - app will handle token exchange
      const appRedirectURL = `app.hyka.com://?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state || 'suunto_oauth')}`
      console.log("🌐 Redirecting to app:", appRedirectURL)
      
      return new Response(null, {
        status: 302,
        headers: {
          'Location': appRedirectURL,
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    // Handle POST requests (from iOS app for token exchange)
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
    const clientId = Deno.env.get('SUUNTO_CLIENT_ID')
    const clientSecret = Deno.env.get('SUUNTO_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      console.error("❌ SUUNTO_CLIENT_ID or SUUNTO_CLIENT_SECRET not set")
      return new Response(JSON.stringify({ 
        error: "Server configuration error: Suunto credentials not set" 
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
    // Get subscription key (required for Suunto API including token exchange)
    const subscriptionKey = Deno.env.get('SUUNTO_SUBSCRIPTION_KEY') || '8e6bcafebd494d7c94df5cf7d5154fde'
    
    // Token endpoint - try cloudapi-oauth domain (same as authorize)
    // Path should be /oauth/token (no /v2 prefix)
    console.log("🔄 Exchanging authorization code for tokens...")
    const tokenUrl = "https://cloudapi-oauth.suunto.com/oauth/token"
    
    // Token exchange params - standard OAuth2 format
    const params = new URLSearchParams({
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirectUri,
      client_id: clientId,
      client_secret: clientSecret
    })
    
    console.log("📤 Token exchange request to:", tokenUrl)
    console.log("   Client ID:", clientId)
    console.log("   Params:", params.toString())
    
    // Try standard OAuth2 token exchange (credentials in body)
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
      console.error("❌ Token exchange failed:", tokenResponse.status)
      console.error("   Response:", errorText)
      console.error("   Client ID:", clientId)
      throw new Error(`Token exchange failed: ${tokenResponse.status} - ${errorText}`)
    }
    
    const tokenData = await tokenResponse.json()
    const accessToken = tokenData.access_token
    const refreshToken = tokenData.refresh_token
    const expiresIn = tokenData.expires_in // Seconds until expiration
    const tokenType = tokenData.token_type || "Bearer"
    
    if (!accessToken) {
      throw new Error("Invalid token response from Suunto")
    }
    
    console.log("✅ Tokens received")
    console.log("   Access token:", accessToken.substring(0, 20) + "...")
    console.log("   Expires in:", expiresIn, "seconds")
    
    // Step 2: Fetch Suunto user ID
    console.log("👤 Fetching Suunto user information...")
    const userUrl = "https://cloudapi.suunto.com/v2/user"
    
    // Subscription key already declared above - reusing for API calls
    console.log("🔑 Using subscription key for user fetch")
    
    // Build headers - Suunto API requires Ocp-Apim-Subscription-Key header
    const userHeaders: HeadersInit = {
      'Authorization': `${tokenType} ${accessToken}`,
      'Accept': 'application/json',
      'Ocp-Apim-Subscription-Key': subscriptionKey  // Required header for Suunto API
    }
    
    console.log("📤 Request headers:", {
      'Authorization': `${tokenType} ${accessToken.substring(0, 20)}...`,
      'Ocp-Apim-Subscription-Key': subscriptionKey ? `${subscriptionKey.substring(0, 10)}...` : 'MISSING'
    })
    
    const userResponse = await fetch(userUrl, {
      method: 'GET',
      headers: userHeaders
    })
    
    let suuntoUserId: string | null = null
    if (userResponse.ok) {
      const userData = await userResponse.json()
      suuntoUserId = userData.id?.toString() || userData.userId?.toString() || null
      console.log("✅ Suunto user ID:", suuntoUserId)
    } else {
      console.log("⚠️ Could not fetch user ID (non-critical):", userResponse.status)
    }
    
    // Step 3: Calculate token expiration
    const expiresAtDate = expiresIn 
      ? new Date(Date.now() + expiresIn * 1000).toISOString()
      : null
    
    // Step 4: Store connection in database
    console.log("💾 Storing connection in database...")
    
    const { data: connection, error: connectionError } = await supabase
      .from('suunto_connections')
      .upsert({
        user_id: userId,
        suunto_user_id: suuntoUserId,
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
    
    // Step 5: Register webhook subscription with Suunto
    // Note: Webhook subscription is typically done via Suunto Developer Portal
    // However, we can also register programmatically if API supports it
    console.log("ℹ️ Webhook URL should be configured in Suunto Developer Portal:")
    console.log("   - Activity Webhook: /functions/v1/suunto-activity-webhook")
    
    const duration = Date.now() - startTime
    console.log(`✅ Auth callback completed in ${duration}ms`)
    
    // Return tokens in format expected by iOS app
    return new Response(JSON.stringify({
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: expiresIn,
      token_type: tokenType,
      suunto_user_id: suuntoUserId,
      connection_id: connection.id
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }
})

