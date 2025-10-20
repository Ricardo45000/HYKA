// ============================================================================
// Garmin Token Exchange (DEPRECATED)
// ============================================================================
//
// ⚠️ THIS FUNCTION IS DEPRECATED
//
// This function has been replaced by `garmin-auth-callback` which:
// 1. Exchanges code for tokens
// 2. Fetches Garmin user ID
// 3. Stores connection in garmin_connections table
//
// Please use `garmin-auth-callback` instead.
//
// This function returns 410 Gone to prevent accidental usage.
//
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  return new Response(JSON.stringify({
    error: "This function is deprecated",
    message: "Please use garmin-auth-callback instead",
    replacement: "/functions/v1/garmin-auth-callback"
  }), {
    status: 410, // Gone
    headers: { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  })
  
  // OLD CODE BELOW (kept for reference, never executed)
  /*
  const startTime = Date.now()
  
  try {
    console.log("🔐 Garmin Token Exchange started")
    
    // Parse request (iOS sends snake_case parameters)
    const body = await req.json()
    const code = body.code
    const codeVerifier = body.code_verifier || body.codeVerifier
    const redirectUri = body.redirect_uri || body.redirectUri
    
    console.log("   Request body keys:", Object.keys(body))
    
    if (!code || !codeVerifier || !redirectUri) {
      console.error("   Missing parameters. Received:", body)
      throw new Error("Missing required parameters: code, code_verifier/codeVerifier, redirect_uri/redirectUri")
    }
    
    console.log("   Code:", code.substring(0, 20) + "...")
    console.log("   Code Verifier:", codeVerifier.substring(0, 20) + "...")
    console.log("   Redirect URI:", redirectUri)
    
    // Get client credentials from environment
    const clientId = "695055f8-9786-4fda-a3a7-f7c2e88382f0"
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET') || "0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q"
    
    console.log("   Client ID:", clientId)
    console.log("   Client Secret:", clientSecret ? "✅ Set" : "❌ Missing")
    
    // Garmin token endpoint (OAuth 2.0 PKCE)
    const tokenUrl = "https://diauth.garmin.com/di-oauth2-service/oauth/token"
    
    // Build request body (application/x-www-form-urlencoded)
    const params = new URLSearchParams({
      grant_type: "authorization_code",
      code: code,
      code_verifier: codeVerifier,
      redirect_uri: redirectUri,
      client_id: clientId,
      client_secret: clientSecret
    })
    
    console.log("   Token URL:", tokenUrl)
    console.log("   Params:", params.toString().replace(clientSecret, 'SECRET_HIDDEN'))
    
    // Exchange code for tokens
    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      body: params.toString()
    })
    
    console.log("   Token response status:", tokenResponse.status)
    
    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error("   Token exchange failed:", errorText)
      throw new Error(`Garmin token exchange failed: ${tokenResponse.status} - ${errorText}`)
    }
    
    const tokenData = await tokenResponse.json()
    
    console.log("   Access token:", tokenData.access_token ? tokenData.access_token.substring(0, 20) + "..." : "❌ Missing")
    console.log("   Refresh token:", tokenData.refresh_token ? tokenData.refresh_token.substring(0, 20) + "..." : "❌ Missing")
    console.log("   Expires in:", tokenData.expires_in, "seconds")
    
    // Return tokens to iOS app
    const duration = Date.now() - startTime
    console.log(`✅ Token exchange completed in ${duration}ms`)
    
    return new Response(JSON.stringify({
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
      expires_in: tokenData.expires_in,
      token_type: tokenData.token_type || "Bearer"
    }), {
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Token exchange error:", error)
    console.error("   Duration:", `${duration}ms`)
    
    return new Response(JSON.stringify({
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

// Handle CORS preflight
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }
})

  */
})

// ============================================================================
// DEPRECATED - Use garmin-auth-callback instead
// ============================================================================

