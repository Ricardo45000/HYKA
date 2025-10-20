// Supabase Edge Function for Garmin OAuth 2.0 PKCE Token Exchange
// This function securely exchanges the authorization code for access tokens
// Reference: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf

import { createClient } from 'npm:@supabase/supabase-js@2'

// Secrets and config from environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || ''
const GARMIN_CLIENT_ID = Deno.env.get('GARMIN_CLIENT_ID') || ''
const GARMIN_CLIENT_SECRET = Deno.env.get('GARMIN_CLIENT_SECRET') || ''
const GARMIN_REDIRECT_URI = Deno.env.get('GARMIN_REDIRECT_URI') || 'https://hyka.app/garmin/callback'

// The Edge Function request handler
Deno.serve(async (req) => {
  // CORS preflight handling
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  try {
    // 1. Parse the request body for the authorization code and PKCE verifier
    let body: { code?: string; code_verifier?: string; redirect_uri?: string }
    
    try {
      body = await req.json()
    } catch {
      // Fallback: try query parameters if body parsing fails
      const url = new URL(req.url)
      body = {
        code: url.searchParams.get('code') || undefined,
        code_verifier: url.searchParams.get('code_verifier') || undefined,
        redirect_uri: url.searchParams.get('redirect_uri') || undefined,
      }
    }

    const code = body.code
    const codeVerifier = body.code_verifier
    const redirectUri = body.redirect_uri || GARMIN_REDIRECT_URI

    if (!code) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization code' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    if (!codeVerifier) {
      return new Response(
        JSON.stringify({ error: 'Missing code_verifier (PKCE)' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Verify environment variables are set
    if (!GARMIN_CLIENT_ID || !GARMIN_CLIENT_SECRET) {
      console.error('GARMIN_CLIENT_ID or GARMIN_CLIENT_SECRET not configured')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // 2. Exchange the authorization code for tokens by POSTing to Garmin's token URL
    // Try both token endpoints (Garmin has multiple)
    const tokenEndpoints = [
      'https://diauth.garmin.com/di-oauth2-service/oauth/token', // OAuth 2.0 PKCE endpoint
      'https://apis.garmin.com/oauth-service/oauth/token', // Alternative endpoint
    ]

    let tokenData: any = null
    let tokenError: string | null = null

    for (const tokenURL of tokenEndpoints) {
      try {
        const tokenRequestBody = new URLSearchParams({
          grant_type: 'authorization_code',
          redirect_uri: redirectUri,
          code: code,
          code_verifier: codeVerifier,
          client_id: GARMIN_CLIENT_ID,
          client_secret: GARMIN_CLIENT_SECRET,
        })

        console.log('Exchanging Garmin authorization code for tokens...')
        console.log('Token URL:', tokenURL)
        console.log('Client ID:', GARMIN_CLIENT_ID.substring(0, 20) + '...')
        console.log('Redirect URI:', redirectUri)

        const tokenResponse = await fetch(tokenURL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: tokenRequestBody.toString(),
        })

        if (tokenResponse.ok) {
          tokenData = await tokenResponse.json()
          console.log('✅ Successfully exchanged code for tokens')
          console.log('Token type:', tokenData.token_type)
          console.log('Expires in:', tokenData.expires_in, 'seconds')
          break
        } else {
          const errorText = await tokenResponse.text()
          console.error(`Token exchange failed at ${tokenURL}:`, tokenResponse.status, errorText)
          tokenError = errorText
        }
      } catch (error) {
        console.error(`Error with token endpoint ${tokenURL}:`, error)
        tokenError = error instanceof Error ? error.message : String(error)
      }
    }

    if (!tokenData) {
      return new Response(
        JSON.stringify({
          error: 'Token exchange failed',
          details: tokenError,
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const accessToken = tokenData.access_token
    const refreshToken = tokenData.refresh_token
    const expiresIn = tokenData.expires_in // seconds until expiration

    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: 'No access token in response' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // 3. Use the access token to retrieve the Garmin user's stable ID
    const userIdResponse = await fetch('https://apis.garmin.com/wellness-api/rest/user/id', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    })

    let garminUserId: string | null = null
    if (userIdResponse.ok) {
      const userIdData = await userIdResponse.json()
      garminUserId = userIdData.userId || userIdData.user_id || null
      console.log('✅ Got Garmin user ID:', garminUserId)
    } else {
      console.warn('⚠️ Failed to fetch Garmin user ID (non-critical):', await userIdResponse.text())
    }

    // 4. Initialize Supabase client with Auth context to identify the logged-in user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    })

    // Get the authenticated user
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      console.error('Auth error:', authError)
      return new Response(
        JSON.stringify({ error: 'Unauthorized user context', details: authError?.message }),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // 5. Store tokens in oauth_connections table (existing schema)
    // Compute an absolute timestamp for access token expiry
    const expiresAt = expiresIn
      ? new Date(Date.now() + expiresIn * 1000 - 600 * 1000).toISOString() // Subtract 10 minutes as buffer
      : null

    const { error: dbError } = await supabaseClient
      .from('oauth_connections')
      .upsert(
        {
          user_id: user.id,
          provider: 'garmin',
          access_token: accessToken,
          refresh_token: refreshToken,
          expires_at: expiresAt,
          // Store Garmin user ID in a JSON field or separate column if available
          // For now, we'll store it in the connection metadata if the schema supports it
        },
        {
          onConflict: 'user_id,provider',
        }
      )

    if (dbError) {
      console.error('DB insert error:', dbError)
      return new Response(
        JSON.stringify({
          error: 'Failed to save tokens to database',
          details: dbError.message,
        }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Success – return tokens to client (iOS app needs them)
    return new Response(
      JSON.stringify({
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: expiresIn,
        token_type: tokenData.token_type || 'Bearer',
        garmin_user_id: garminUserId,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (e) {
    console.error('Unexpected error:', e)
    return new Response(
      JSON.stringify({
        error: 'Internal Server Error',
        message: e instanceof Error ? e.message : String(e),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
