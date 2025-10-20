// ============================================================================
// Garmin Auth Callback (OAuth 2.0 PKCE)
// ============================================================================
//
// Purpose: Receives OAuth2 redirect from iOS app, exchanges code for tokens,
//          fetches Garmin user ID, stores connection, and registers webhooks
//
// Flow:
// 1. Receive OAuth2 code from iOS app (after user authorizes)
// 2. Exchange code for access_token + refresh_token
// 3. Fetch Garmin user ID from /rest/user/id
// 4. Store tokens and user mapping in garmin_connections
// 5. Register webhook URLs with Garmin (if needed)
// 6. Return success to iOS app
//
// Reference: Garmin OAuth 2.0 PKCE Specification
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Handle CORS preflight
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
    console.log("🔐 Garmin Auth Callback started")
    console.log("   Method:", req.method)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Parse request
    const body = await req.json()
    const code = body.code
    const codeVerifier = body.code_verifier || body.codeVerifier
    const redirectUri = body.redirect_uri || body.redirectUri
    const userId = body.user_id // HYKA user ID from iOS app
    
    if (!code || !codeVerifier || !redirectUri || !userId) {
      console.error("❌ Missing required parameters")
      return new Response(JSON.stringify({ 
        error: "Missing required parameters: code, code_verifier, redirect_uri, user_id" 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   User ID:", userId)
    console.log("   Code:", code.substring(0, 20) + "...")
    console.log("   Redirect URI:", redirectUri)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Get client credentials
    const clientId = "695055f8-9786-4fda-a3a7-f7c2e88382f0"
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    if (!clientSecret) {
      console.error("❌ GARMIN_CLIENT_SECRET environment variable is required")
      return new Response(JSON.stringify({ 
        error: "Server configuration error: GARMIN_CLIENT_SECRET not set" 
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
    const tokenUrl = "https://diauth.garmin.com/di-oauth2-service/oauth/token"
    
    const params = new URLSearchParams({
      grant_type: "authorization_code",
      code: code,
      code_verifier: codeVerifier,
      redirect_uri: redirectUri,
      client_id: clientId,
      client_secret: clientSecret
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
    const expiresIn = tokenData.expires_in
    
    console.log("✅ Tokens received")
    console.log("   Access token:", accessToken.substring(0, 20) + "...")
    console.log("   Expires in:", expiresIn, "seconds")
    
    // Step 2: Fetch Garmin user ID
    console.log("🔄 Fetching Garmin user ID...")
    const userIdUrl = "https://apis.garmin.com/wellness-api/rest/user/id"
    
    const userIdResponse = await fetch(userIdUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })
    
    if (!userIdResponse.ok) {
      const errorText = await userIdResponse.text()
      console.error("❌ User ID fetch failed:", userIdResponse.status, errorText)
      throw new Error(`User ID fetch failed: ${userIdResponse.status} - ${errorText}`)
    }
    
    const userIdData = await userIdResponse.json()
    const garminUserId = userIdData.userId
    
    if (!garminUserId) {
      throw new Error("Garmin user ID not found in response")
    }
    
    console.log("✅ Garmin user ID:", garminUserId)
    
    // Step 3: Calculate token expiration
    const expiresAt = expiresIn 
      ? new Date(Date.now() + (expiresIn - 600) * 1000).toISOString() // Subtract 600s buffer
      : null
    
    // Step 4: Store connection in database
    console.log("💾 Storing connection in database...")
    
    const { data: connection, error: connectionError } = await supabase
      .from('garmin_connections')
      .upsert({
        user_id: userId,
        garmin_user_id: garminUserId,
        access_token: accessToken,
        refresh_token: refreshToken,
        token_expires_at: expiresAt,
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
    
    // Step 5: Register webhook URLs with Garmin (if required)
    // Note: Webhook registration is typically done via Developer Portal
    // However, some implementations may require API registration
    // Check Garmin documentation for webhook registration endpoint
    
    // Webhook URLs that should be configured in Garmin Developer Portal:
    // - Activity PING: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
    // - Activity PUSH: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push
    // - Permission Webhook: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook
    
    console.log("ℹ️ Webhook URLs should be configured in Garmin Developer Portal:")
    console.log("   - PING: /functions/v1/garmin-activity-ping")
    console.log("   - PUSH: /functions/v1/garmin-activity-push")
    console.log("   - Permission: /functions/v1/garmin-permission-webhook")
    
    // Step 6: Trigger automatic backfill from connection date forward
    // Note: Garmin only allows backfilling from connection date forward, not backward
    // For very recent connections, this will be a small range (which is expected)
    console.log("🔄 Triggering automatic backfill from connection date...")
    try {
      const connectedAt = new Date()
      
      // Start from connection date (Garmin requirement: cannot backfill before connection)
      const backfillStartSeconds = Math.floor(connectedAt.getTime() / 1000)
      // End: connection date + 29 days, or now (whichever is earlier)
      const endDate = new Date(connectedAt)
      endDate.setDate(endDate.getDate() + 29)
      const actualEndDate = endDate < new Date() ? endDate : new Date()
      const backfillEndSeconds = Math.floor(actualEndDate.getTime() / 1000)
      
      // Call backfill function internally (don't await - fire and forget)
      const backfillUrl = `${supabaseUrl}/functions/v1/garmin-activity-backfill`
      fetch(backfillUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseKey}`,
          'apikey': supabaseKey
        },
        body: JSON.stringify({
          user_id: userId,
          summary_start_time_seconds: backfillStartSeconds,
          summary_end_time_seconds: backfillEndSeconds
        })
      }).catch(err => {
        console.log("⚠️ Backfill trigger failed (non-critical):", err.message)
        // Non-critical - user can trigger manually via sync button
      })
      
      console.log("✅ Automatic backfill triggered (last 30 days)")
    } catch (backfillError) {
      console.log("⚠️ Could not trigger automatic backfill:", backfillError)
      // Non-critical - user can trigger manually via sync button
    }
    
    const duration = Date.now() - startTime
    console.log(`✅ Auth callback completed in ${duration}ms`)
    
    // Return tokens in format expected by iOS app
    // iOS app expects: access_token, refresh_token, expires_in, token_type
    return new Response(JSON.stringify({
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: expiresIn,
      token_type: "Bearer",
      // Additional info for debugging
      garmin_user_id: garminUserId,
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

// ============================================================================
// Configuration Required
// ============================================================================
//
// 1. Set GARMIN_CLIENT_SECRET environment variable:
//    supabase secrets set GARMIN_CLIENT_SECRET=your_secret_here
//
// 2. Deploy this function:
//    supabase functions deploy garmin-auth-callback
//
// 3. iOS app should call this after OAuth2 authorization:
//    POST /functions/v1/garmin-auth-callback
//    Body: { code, code_verifier, redirect_uri, user_id }
//
// ============================================================================

