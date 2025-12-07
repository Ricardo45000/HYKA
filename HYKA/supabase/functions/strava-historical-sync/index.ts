import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    console.log("📦 Strava Historical Sync started")
    const { user_id } = await req.json()
    
    if (!user_id) throw new Error("Missing user_id")

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get Strava Connection
    const { data: connection, error: connError } = await supabase
      .from('strava_connections')
      .select('*')
      .eq('user_id', user_id)
      .single()

    if (connError || !connection) throw new Error("Strava connection not found")

    // Refresh Token Logic
    let accessToken = connection.access_token
    if (isTokenExpired(connection.expires_at)) {
        console.log("🔄 Refreshing Strava token...")
        const tokens = await refreshStravaToken(connection.refresh_token)
        accessToken = tokens.access_token
        
        await supabase.from('strava_connections').update({
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_at: tokens.expires_at,
            updated_at: new Date().toISOString()
        }).eq('user_id', user_id)
    }

    // 30 Days Ago
    const thirtyDaysAgo = Math.floor((Date.now() - (30 * 24 * 60 * 60 * 1000)) / 1000)
    
    console.log(`📅 Fetching Strava activities after epoch: ${thirtyDaysAgo}`)

    // Fetch Activities
    const response = await fetch(`https://www.strava.com/api/v3/athlete/activities?after=${thirtyDaysAgo}&per_page=100`, {
        headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    if (!response.ok) {
        throw new Error(`Strava API error: ${response.status} - ${await response.text()}`)
    }

    const activities = await response.json()
    console.log(`✅ Found ${activities.length} activities`)

    // Process each activity
    let processed = 0
    for (const activity of activities) {
        // Call strava-activity-store
        // Note: strava-activity-store normally handles webhook events (object_id), 
        // but we can adapt it or call it with a manufactured payload if it supports it.
        // Actually, strava-activity-store expects: { object_id, owner_id, ... }
        // Or we can just call the logic directly if we want, but calling the function is cleaner if adaptable.
        
        // Let's invoke strava-activity-store with a simulated webhook payload or extended payload
        const payload = {
            object_id: activity.id,
            owner_id: activity.athlete.id,
            aspect_type: 'create', // Simulate creation
            object_type: 'activity',
            manual_sync: true // Flag to indicate manual sync
        }

        await fetch(`${supabaseUrl}/functions/v1/strava-activity-store`, {
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
    // Buffer of 5 minutes
    return (Date.now() / 1000) > (expiresAt - 300)
}

async function refreshStravaToken(refreshToken: string) {
    const clientId = Deno.env.get('STRAVA_CLIENT_ID')
    const clientSecret = Deno.env.get('STRAVA_CLIENT_SECRET')
    
    const res = await fetch("https://www.strava.com/oauth/token", {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            client_id: clientId,
            client_secret: clientSecret,
            refresh_token: refreshToken,
            grant_type: 'refresh_token'
        })
    })
    
    if (!res.ok) throw new Error("Failed to refresh Strava token")
    return await res.json()
}

