
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { code, code_verifier, redirect_uri, user_id } = await req.json()

    if (!code || !redirect_uri || !user_id) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400 })
    }

    const clientId = Deno.env.get('GARMIN_CLIENT_ID')
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    if (!clientId || !clientSecret) {
        throw new Error("Garmin credentials not configured")
    }

    console.log(`🔄 Exchanging code for Garmin tokens (User: ${user_id})`)

    // 1. Exchange Code for Tokens
    // https://developerportal.garmin.com/connect-api/oauth-2-0
    const tokenUrl = "https://connectapi.garmin.com/oauth-service/oauth/exchange/user/access_token"
    
    const body = new URLSearchParams({
        grant_type: 'authorization_code',
        code: code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirect_uri,
    })

    if (code_verifier) {
        body.append('code_verifier', code_verifier)
    }

    const tokenResponse = await fetch(tokenUrl, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body
    })

    if (!tokenResponse.ok) {
        const errText = await tokenResponse.text()
        console.error("❌ Token exchange failed:", errText)
        return new Response(JSON.stringify({ error: "Token exchange failed", details: errText }), { status: 400 })
    }

    const tokens = await tokenResponse.json()
    // tokens: { access_token, refresh_token, expires_in, scope, ... }

    console.log("✅ Tokens received")

    // 2. Fetch Garmin User ID
    // We need this to map webhooks (which only send garmin_user_id) back to our user_id
    const userIdUrl = "https://apis.garmin.com/wellness-api/rest/user/id"
    const userResponse = await fetch(userIdUrl, {
        headers: {
            'Authorization': `Bearer ${tokens.access_token}`
        }
    })

    let garminUserId = null
    if (userResponse.ok) {
        const userData = await userResponse.json()
        garminUserId = userData.userId
        console.log("✅ Fetched Garmin User ID:", garminUserId)
    } else {
        console.warn("⚠️ Failed to fetch Garmin User ID:", await userResponse.text())
        // Proceeding without garminUserId is risky for webhooks, but we can still save the tokens
    }

    // 3. Store in Supabase
    const supabase = createClient(supabaseUrl, supabaseKey)

    const connectionData = {
        user_id: user_id,
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        token_expires_at: new Date(Date.now() + (tokens.expires_in * 1000)).toISOString(),
        updated_at: new Date().toISOString()
    }

    // Only update garmin_user_id if we successfully fetched it
    // If it's already there, we don't want to null it out (if fetch failed)
    if (garminUserId) {
        Object.assign(connectionData, { garmin_user_id: garminUserId })
    }

    const { error: upsertError } = await supabase
        .from('garmin_connections')
        .upsert(connectionData, { onConflict: 'user_id' })

    if (upsertError) {
        console.error("❌ Database upsert failed:", upsertError)
        throw new Error("Failed to store connection")
    }

    console.log("✅ Connection stored successfully")

    // 4. Return tokens to client
    return new Response(JSON.stringify(tokens), {
        headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error("❌ Error:", error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
})

