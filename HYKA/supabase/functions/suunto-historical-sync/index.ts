import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    console.log("📦 Suunto Historical Sync started")
    const { user_id } = await req.json()
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: connection, error: connError } = await supabase
      .from('suunto_connections')
      .select('*')
      .eq('user_id', user_id)
      .single()

    if (connError || !connection) throw new Error("Suunto connection not found")

    // Refresh Token Logic
    let accessToken = connection.access_token
    if (isTokenExpired(connection.expires_at)) { // expires_at might be number or string? standard is often seconds since epoch or ISO
        console.log("🔄 Refreshing Suunto token...")
        const tokens = await refreshSuuntoToken(connection.refresh_token)
        accessToken = tokens.access_token
        
        // Calculate expires_at
        const expiresAt = Math.floor(Date.now() / 1000) + tokens.expires_in

        await supabase.from('suunto_connections').update({
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_at: expiresAt, 
            updated_at: new Date().toISOString()
        }).eq('user_id', user_id)
    }

    const subscriptionKey = Deno.env.get('SUUNTO_SUBSCRIPTION_KEY')
    if (!subscriptionKey) throw new Error("Missing SUUNTO_SUBSCRIPTION_KEY")

    // 30 Days Ago (ISO String)
    const thirtyDaysAgo = new Date(Date.now() - (30 * 24 * 60 * 60 * 1000)).toISOString()
    
    console.log(`📅 Fetching Suunto workouts since: ${thirtyDaysAgo}`)

    const response = await fetch(`https://cloudapi.suunto.com/v2/workouts?since=${thirtyDaysAgo}&limit=100`, {
        headers: { 
            'Authorization': `Bearer ${accessToken}`,
            'Ocp-Apim-Subscription-Key': subscriptionKey
        }
    })

    if (!response.ok) {
        throw new Error(`Suunto API error: ${response.status} - ${await response.text()}`)
    }

    const data = await response.json()
    const workouts = data.payload || [] // Suunto often wraps in payload
    console.log(`✅ Found ${workouts.length} workouts`)

    let processed = 0
    for (const workout of workouts) {
        // Call suunto-activity-store
        // suunto-activity-store typically handles webhook: { workoutId: "..." }
        const payload = {
            workoutId: workout.workoutId,
            username: connection.suunto_username, // passing context if needed
            manual_sync: true
        }

        await fetch(`${supabaseUrl}/functions/v1/suunto-activity-store`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        })
        processed++
    }

    return new Response(JSON.stringify({ success: true, count: processed }), { headers: { 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error("❌ Error:", error)
    return new Response(JSON.stringify({ success: false, error: error.message }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
})

function isTokenExpired(expiresAt: number): boolean {
    return (Date.now() / 1000) > (expiresAt - 300)
}

async function refreshSuuntoToken(refreshToken: string) {
    const clientId = Deno.env.get('SUUNTO_CLIENT_ID')
    const clientSecret = Deno.env.get('SUUNTO_CLIENT_SECRET')
    
    // Basic Auth for refresh
    const auth = btoa(`${clientId}:${clientSecret}`)
    
    const res = await fetch("https://cloudapi.suunto.com/oauth/token", {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${auth}`
        },
        body: new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: refreshToken
        })
    })
    
    if (!res.ok) throw new Error("Failed to refresh Suunto token")
    return await res.json()
}

