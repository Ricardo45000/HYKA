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
    console.log("🔐 Strava Auth Callback started")
    
    // Handle GET requests (web redirect from Strava OAuth)
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const code = url.searchParams.get('code')
      const state = url.searchParams.get('state')
      const error = url.searchParams.get('error')

      if (error) {
        console.error("❌ Strava OAuth error:", error)
        const appRedirectURL = `com.hyka.app://?error=${encodeURIComponent(error)}&state=${encodeURIComponent(state || '')}`
        return new Response(null, {
          status: 302,
          headers: {
            'Location': appRedirectURL,
            'Access-Control-Allow-Origin': '*'
          }
        })
      }

      if (!code) {
        console.error("❌ Missing 'code' parameter in GET request")
        const appRedirectURL = `com.hyka.app://?error=${encodeURIComponent("Missing authorization code")}&state=${encodeURIComponent(state || '')}`
        return new Response(null, {
          status: 302,
          headers: {
            'Location': appRedirectURL,
            'Access-Control-Allow-Origin': '*'
          }
        })
      }

      console.log("🌐 Received GET request from Strava OAuth. Redirecting to app...")
      const appRedirectURL = `com.hyka.app://?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state || '')}`

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
    const userId = body.user_id

    if (!code || !redirectUri || !userId) {
      return new Response(JSON.stringify({
        error: "Missing required parameters: code, redirect_uri, user_id"
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
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
          'Access-Control-Allow-Origin': '*'
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
      grant_type: "authorization_code"
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

    if (!accessToken) {
      throw new Error("Invalid token response from Strava")
    }

    console.log("✅ Tokens received")
    console.log("   Access token:", accessToken.substring(0, 20) + "...")
    console.log("   Expires at:", expiresAt ? new Date(expiresAt * 1000).toISOString() : "Not provided")

    // Step 2: Fetch athlete info (optional, but good to have)
    // ⚠️ CRITICAL: Must include Authorization header!
    let athleteId: number | null = null
    if (athlete?.id) {
      athleteId = athlete.id
    } else {
      try {
        const athleteResponse = await fetch("https://www.strava.com/api/v3/athlete", {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${accessToken}`,  // ✅ REQUIRED!
            'Accept': 'application/json'
          }
        })

        if (athleteResponse.ok) {
          const athleteData = await athleteResponse.json()
          athleteId = athleteData.id
          console.log("✅ Fetched athlete ID:", athleteId)
        } else {
          console.log("⚠️ Could not fetch athlete info (non-critical):", athleteResponse.status)
        }
      } catch (error) {
        console.log("⚠️ Error fetching athlete info (non-critical):", error)
      }
    }

    // Step 3: Calculate token expiration
    const expiresAtDate = expiresAt
      ? new Date(expiresAt * 1000).toISOString()
      : null

    // Step 4: Store connection in database
    console.log("💾 Storing connection in database...")

    const { data: connection, error: connectionError } = await supabase
      .from('strava_connections')
      .upsert({
        user_id: userId,
        strava_athlete_id: athleteId?.toString() || null,
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

    // Return tokens in format expected by iOS app
    return new Response(JSON.stringify({
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_at: expiresAt,
      token_type: "Bearer",
      athlete_id: athleteId,
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
    console.error("❌ Error in Strava auth callback:", error)
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


