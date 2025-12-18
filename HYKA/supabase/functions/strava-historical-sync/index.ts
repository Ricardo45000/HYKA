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
    const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
    const expiresAtTimestamp = expiresAt ? Math.floor(expiresAt.getTime() / 1000) : null
    
    if (expiresAtTimestamp && isTokenExpired(expiresAtTimestamp)) {
        console.log("🔄 Refreshing Strava token...")
        const tokens = await refreshStravaToken(connection.refresh_token)
        accessToken = tokens.access_token
        
        // Convert expires_at from Unix timestamp to ISO string
        const newExpiresAt = tokens.expires_at 
          ? new Date(tokens.expires_at * 1000).toISOString() 
          : null
        
        await supabase.from('strava_connections').update({
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            token_expires_at: newExpiresAt,
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
    let errors = 0
    for (const activity of activities) {
        try {
            // Call strava-activity-store with direct format (user_id + activity_id)
            // The function now supports both webhook format and direct format
            const payload = {
                user_id: user_id, // Direct format - we already have user_id
                activity_id: activity.id.toString() // Direct format
            }

            const storeResponse = await fetch(`${supabaseUrl}/functions/v1/strava-activity-store`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${supabaseKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            })

            if (!storeResponse.ok) {
                const errorText = await storeResponse.text()
                console.error(`❌ Failed to store activity ${activity.id}: ${storeResponse.status} - ${errorText}`)
                errors++
            } else {
                console.log(`✅ Stored activity ${activity.id}`)
                processed++
            }
        } catch (error) {
            console.error(`❌ Error processing activity ${activity.id}:`, error)
            errors++
        }
    }
    
    console.log(`📊 Sync complete: ${processed} stored, ${errors} errors`)

    return new Response(JSON.stringify({ 
      success: true, 
      count: processed,
      errors: errors,
      total: activities.length
    }), { headers: { 'Content-Type': 'application/json' } })

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

