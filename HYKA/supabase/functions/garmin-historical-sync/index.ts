import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  const startTime = Date.now()

  try {
    console.log("📦 Garmin Historical Sync started")
    
    // Parse request body
    let body: any = {}
    try {
        body = await req.json()
    } catch (e) {
        console.error("❌ Failed to parse JSON body:", e)
        return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400, headers: { 'Content-Type': 'application/json' } })
    }

    console.log("   Body:", JSON.stringify(body))

    const userId = body.user_id
    
    if (!userId) {
      console.error("❌ Missing user_id in request")
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch Garmin connection
    const { data: connection, error: connError } = await supabase
      .from('garmin_connections')
      .select('user_id, garmin_user_id, access_token, refresh_token, token_expires_at')
      .eq('user_id', userId)
      .single()

    if (connError || !connection) {
      console.error("❌ Garmin connection not found for user:", userId)
      return new Response(JSON.stringify({ error: "Garmin connection not found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log("✅ Found Garmin connection for user:", userId)

    // Refresh token if needed
    let accessToken = connection.access_token
    if (isTokenExpired(connection.token_expires_at)) {
        console.log("🔄 Token expired, refreshing...")
        try {
            const tokens = await refreshGarminToken(connection.refresh_token)
            accessToken = tokens.access_token
            
            // Update DB
            await supabase.from('garmin_connections').update({
                access_token: tokens.access_token,
                refresh_token: tokens.refresh_token, // Might be same or new
                token_expires_at: new Date(Date.now() + (tokens.expires_in * 1000)).toISOString(),
                updated_at: new Date().toISOString()
            }).eq('user_id', userId)
            
            console.log("✅ Token refreshed and saved")
        } catch (e) {
            console.error("❌ Token refresh failed:", e)
            return new Response(JSON.stringify({ error: "Failed to refresh Garmin token" }), { status: 401, headers: { 'Content-Type': 'application/json' } })
        }
    }

    // Calculate time range (Last 30 days)
    const endDate = Math.floor(Date.now() / 1000)
    const startDate = endDate - (30 * 24 * 60 * 60) // 30 days ago

    console.log(`📅 Requesting historical activities from ${startDate} to ${endDate} (30 days)`)

    // Standard Backfill URL (Health API)
    // Documentation says: https://apis.garmin.com/wellness-api/rest/backfill/activities
    // We previously tried POST which failed with 502.
    // Appendix B in documentation shows GET requests with query params.
    // Let's try GET to the backfill endpoint.
    
    const domain = "https://apis.garmin.com"
    // Note: Some docs suggest /wellness-api/rest/backfill/activities
    // Others might imply /wellness-api/rest/activities with params triggers backfill?
    // Let's try the explicit backfill endpoint first with GET.
    
    let backfillUrl = `${domain}/wellness-api/rest/backfill/activities?summaryStartTimeInSeconds=${startDate}&summaryEndTimeInSeconds=${endDate}`
    console.log(`🚀 Attempting Backfill API (GET): ${backfillUrl}`)
        
    try {
        let response = await fetch(backfillUrl, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Accept': 'application/json'
            }
        })
        
        // Retry logic for 409 (Duplicate Backfill)
        if (response.status === 409) {
            console.warn("⚠️ Backfill conflict (409). Attempting smart retry...")
            
            let shiftedStart = startDate - 3600
            
            try {
                // Extract the "processed at" end date from error message
                // Format: duplicate backfill processed at ... [Start to End]
                // We need the "End" date from the range to start just after it
                const errorText = await response.text()
                console.log("   Conflict Details:", errorText)
                
                // Regex to find the range end date in ISO format inside brackets
                // Looks for: to YYYY-MM-DDTHH:mm:ssZ]
                const match = errorText.match(/to\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\]/)
                
                if (match && match[1]) {
                    const previousEndDate = new Date(match[1])
                    // Start 1 second after the previous backfill ended
                    shiftedStart = Math.floor(previousEndDate.getTime() / 1000) + 1
                    console.log(`   Found previous end date: ${match[1]}. New start time: ${shiftedStart}`)
                } else {
                    console.log("   Could not parse date from error, using fallback 1h shift")
                }
            } catch (e) {
                console.log("   Error parsing conflict message:", e)
            }
            
            // Ensure start is not after end
            if (shiftedStart >= endDate) {
                console.warn("   New start time is in the future relative to end time. Using 1h shift.")
                shiftedStart = endDate - 3600 // Just try last hour
            }

            backfillUrl = `${domain}/wellness-api/rest/backfill/activities?summaryStartTimeInSeconds=${shiftedStart}&summaryEndTimeInSeconds=${endDate}`
            console.log(`🚀 Retrying Backfill with smart start time: ${backfillUrl}`)
            
            response = await fetch(backfillUrl, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Accept': 'application/json'
                }
            })
        }
        
        // If 404/405 (Method Not Allowed), try the generic /activities endpoint which is often used for manual fetch/backfill
        if (!response.ok && (response.status === 404 || response.status === 405)) {
             console.warn(`⚠️ Backfill endpoint failed (${response.status}). Retrying with generic /activities endpoint...`)
             backfillUrl = `${domain}/wellness-api/rest/activities?uploadStartTimeInSeconds=${startDate}&uploadEndTimeInSeconds=${endDate}`
             console.log(`🚀 Attempting Generic Activity API (GET): ${backfillUrl}`)
             
             response = await fetch(backfillUrl, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Accept': 'application/json'
                }
            })
        }
        
        if (response.ok) {
            // If it returns 200, it might be a list of activities (Direct Fetch succeeded!) OR a backfill confirmation
            // Check content type or body
            const responseText = await response.text()
            console.log("✅ Request successful. Response preview:", responseText.substring(0, 200))
            
            let parsed: any = {}
            try { parsed = JSON.parse(responseText) } catch (e) {}
            
            // If it's an array, we got activities! Process them.
            if (Array.isArray(parsed)) {
                console.log(`🎉 Received ${parsed.length} activities directly!`)
                // Process activities manually
                let processed = 0
                for (const activity of parsed) {
                    try {
                        const storePayload = {
                            summary: activity,
                            garminUserId: connection.garmin_user_id
                        }
                        await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
                            method: 'POST',
                            headers: { 'Authorization': `Bearer ${supabaseKey}`, 'Content-Type': 'application/json' },
                            body: JSON.stringify(storePayload)
                        })
                        processed++
                    } catch (err) { console.error("   Error processing activity:", err) }
                }
                return new Response(JSON.stringify({ success: true, message: "Activities fetched directly", count: processed }), { status: 200, headers: { 'Content-Type': 'application/json' } })
            }
            
            // If it's not an array, assume backfill triggered
            await supabase.from('garmin_backfill_requests').insert({
                user_id: userId,
                summary_start_time_seconds: startDate,
                summary_end_time_seconds: endDate,
                status: 'pending',
                domain_used: domain
            })
            
            return new Response(JSON.stringify({ 
                success: true, 
                message: "Backfill requested successfully.",
                range_days: 30
            }), { status: 200, headers: { 'Content-Type': 'application/json' } })
            
        } else {
            console.warn(`⚠️ Request failed: ${response.status}`)
            const text = await response.text()
            console.log("   Error:", text)
            return new Response(JSON.stringify({ 
                success: false, 
                error: `Garmin API failed: ${response.status}`,
                details: text
            }), { status: 200, headers: { 'Content-Type': 'application/json' } })
        }
    } catch (e) {
        console.error(`❌ Exception:`, e)
        return new Response(JSON.stringify({ 
            success: false, 
            error: e.message
        }), { status: 500, headers: { 'Content-Type': 'application/json' } })
    }

  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in Garmin Historical Sync:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

// --- Helper Functions ---

function isTokenExpired(expiresAt: string | null): boolean {
    if (!expiresAt) return true
    return new Date(expiresAt).getTime() < Date.now()
}

async function refreshGarminToken(refreshToken: string) {
    const clientId = Deno.env.get('GARMIN_CLIENT_ID')
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) throw new Error("Missing Garmin credentials")
    
    const url = "https://connectapi.garmin.com/oauth-service/oauth/exchange/refresh_token"
    
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({
            refresh_token: refreshToken,
            client_id: clientId,
            client_secret: clientSecret
        })
    })
    
    if (!response.ok) {
        throw new Error(`Refresh failed: ${response.status}`)
    }
    
    return await response.json()
}
