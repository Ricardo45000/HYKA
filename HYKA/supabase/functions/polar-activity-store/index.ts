import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Polar Activity Store
 * 
 * Fetches a specific exercise from Polar AccessLink API and stores it in Supabase.
 * Can be called manually or triggered by webhooks.
 * 
 * POST body:
 * {
 *   "user_id": "uuid",           // Supabase user ID
 *   "activity_id": "string",     // Polar exercise ID
 *   "access_token": "string"     // Optional: Provide token directly if available
 * }
 */

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
    console.log("📥 Polar Activity Store started")
    
    const body = await req.json()
    const userId = body.user_id
    const activityId = body.activity_id
    
    if (!userId || !activityId) {
      return new Response(JSON.stringify({
        error: "Missing user_id or activity_id"
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      })
    }

    console.log("📋 Request:", { userId, activityId })

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    let accessToken = body.access_token
    let refreshToken: string | null = null

    // If no token provided, fetch from DB
    if (!accessToken) {
        const { data: connection, error: connError } = await supabase
        .from('polar_connections')
        .select('access_token, refresh_token, token_expires_at')
        .eq('user_id', userId)
        .single()

        if (connError || !connection) {
        throw new Error(`Polar connection not found: ${connError?.message}`)
        }
        accessToken = connection.access_token
        refreshToken = connection.refresh_token
        
        // Check if token needs refresh
        const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
        const needsRefresh = expiresAt && (expiresAt <= new Date(Date.now() + 5 * 60 * 1000))
        
        if (needsRefresh && refreshToken) {
          console.log("🔄 Refreshing Polar token (expires at:", expiresAt?.toISOString(), ")...")
          
          try {
            const clientId = Deno.env.get('POLAR_CLIENT_ID')
            const clientSecret = Deno.env.get('POLAR_CLIENT_SECRET')
            
            if (!clientId || !clientSecret) {
              console.error("❌ POLAR_CLIENT_ID or POLAR_CLIENT_SECRET not set")
            } else {
              const basicAuth = btoa(`${clientId}:${clientSecret}`)
              
              const refreshResponse = await fetch("https://polarremote.com/v2/oauth2/token", {
                method: 'POST',
                headers: {
                  'Authorization': `Basic ${basicAuth}`,
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Accept': 'application/json'
                },
                body: new URLSearchParams({
                  grant_type: 'refresh_token',
                  refresh_token: refreshToken
                }).toString()
              })
              
              if (refreshResponse.ok) {
                const refreshData = await refreshResponse.json()
                accessToken = refreshData.access_token
                refreshToken = refreshData.refresh_token || refreshToken
                const newExpiresAt = refreshData.expires_in 
                  ? new Date(Date.now() + refreshData.expires_in * 1000).toISOString()
                  : null
                
                console.log("✅ Polar token refreshed successfully")
                
                // Update connection in database
                await supabase
                  .from('polar_connections')
                  .update({
                    access_token: accessToken,
                    refresh_token: refreshToken,
                    token_expires_at: newExpiresAt,
                    updated_at: new Date().toISOString()
                  })
                  .eq('user_id', userId)
              } else {
                const errorText = await refreshResponse.text()
                console.error("❌ Polar token refresh failed:", refreshResponse.status, errorText)
              }
            }
          } catch (refreshError) {
            console.error("❌ Error refreshing Polar token:", refreshError)
          }
        }
    }
    
    if (!accessToken) {
      throw new Error("Polar access token is missing or null")
    }

    console.log("🔑 Using access token:", accessToken.substring(0, 20) + "...")

    // Fetch activity from Polar API
    // Endpoint: https://www.polaraccesslink.com/v3/exercises/{exerciseId}
    const polarResponse = await fetch(`https://www.polaraccesslink.com/v3/exercises/${activityId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })
    
    console.log("📤 Polar API request:", {
      url: `https://www.polaraccesslink.com/v3/exercises/${activityId}`,
      status: polarResponse.status
    })

    if (!polarResponse.ok) {
      const errorText = await polarResponse.text()
      console.error("❌ Polar API error:", polarResponse.status, errorText)
      throw new Error(`Polar API error: ${polarResponse.status} - ${errorText}`)
    }

    const exercise = await polarResponse.json()
    console.log("✅ Fetched exercise:", exercise.id)

    // Map Polar exercise to database schema
    const activityData = {
        user_id: userId,
        polar_activity_id: exercise.id.toString(),
        activity_name: "Polar Exercise", // Polar doesn't always provide a name
        activity_type: exercise.detailed_sport_info || "UNKNOWN",
        sport_type: exercise.sport,
        start_date: exercise.start_time,
        elapsed_time: exercise.duration ? Math.round(parseFloat(exercise.duration.replace('PT', '').replace('S', ''))) : 0, // ISO8601 duration parsing simplified
        distance_meters: exercise.distance,
        total_elevation_gain_meters: exercise.ascent,
        total_elevation_loss_meters: exercise.descent,
        average_heart_rate: exercise.heart_rate?.average,
        max_heart_rate: exercise.heart_rate?.maximum,
        calories: exercise.calories,
        device_name: exercise.device?.name,
        has_route: exercise.has_route,
        raw_summary: exercise,
        updated_at: new Date().toISOString()
    }

    // Better duration parsing if needed (ISO 8601 duration)
    // For now trusting the simple replace/parse or assuming seconds if number
    // Actually Polar duration is ISO 8601 (PT1H30M...)
    // We can't easily parse that in simplified JS without library, 
    // but let's try to see if it's already seconds in some responses?
    // Documentation says: "PT1H2M3S". 
    // Simple parser:
    if (typeof exercise.duration === 'string' && exercise.duration.startsWith('PT')) {
        const durationRegex = /PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?/;
        const matches = exercise.duration.match(durationRegex);
        if (matches) {
            const hours = parseInt(matches[1] || '0');
            const minutes = parseInt(matches[2] || '0');
            const seconds = parseFloat(matches[3] || '0');
            activityData.elapsed_time = Math.round(hours * 3600 + minutes * 60 + seconds);
        }
    }

    // Store activity in database
    const { data: storedActivity, error: storeError } = await supabase
      .from('polar_activities')
      .upsert(activityData, {
        onConflict: 'user_id,polar_activity_id'
      })
      .select('id')
      .single()

    if (storeError || !storedActivity) {
      throw new Error(`Failed to store activity: ${storeError?.message}`)
    }

    // ------------------------------------------------------------------------
    // Fetch & Store TCX/GPX File (Polar doesn't provide FIT)
    // ------------------------------------------------------------------------
    try {
        console.log("📥 Fetching TCX file from Polar...")
        // Try TCX first as it has more data
        const fileUrl = `https://www.polaraccesslink.com/v3/exercises/${activityId}/tcx`
        
        const fileResponse = await fetch(fileUrl, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Accept': 'application/vnd.garmin.tcx+xml' // Or */*
            }
        })
        
        if (fileResponse.ok) {
            const arrayBuffer = await fileResponse.arrayBuffer()
            const fileData = Array.from(new Uint8Array(arrayBuffer))
            
            if (fileData.length > 0) {
                console.log(`✅ Downloaded TCX file: ${fileData.length} bytes`)
                
                const { error: fileError } = await supabase
                    .from('polar_fit_files')
                    .upsert({
                        activity_id: storedActivity.id,
                        file_data: fileData,
                        file_format: 'tcx',
                        file_size: fileData.length,
                        created_at: new Date().toISOString()
                    }, { onConflict: 'activity_id' })
                    
                if (fileError) {
                    console.error("❌ Failed to store TCX file:", fileError)
                } else {
                    console.log("💾 TCX file stored in polar_fit_files")
                    
                    // Trigger TCX processor
                    console.log("🔄 Triggering TCX processor...")
                    const processorUrl = `${supabaseUrl}/functions/v1/polar-file-processor`
                    fetch(processorUrl, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${supabaseKey}`,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            activity_id: storedActivity.id,
                            file_data: fileData,
                            file_format: 'tcx'
                        })
                    }).then(async (res) => {
                        if (res.ok) {
                            console.log(`✅ TCX processor triggered: ${res.status}`)
                        } else {
                            const text = await res.text()
                            console.error(`❌ TCX processor failed: ${res.status} - ${text}`)
                        }
                    }).catch(err => {
                        console.error("❌ Error calling TCX processor:", err)
                    })
                }
            }
        } else {
            console.warn(`⚠️ Failed to download TCX file: ${fileResponse.status}`)
            // Fallback to GPX? Maybe later.
        }
    } catch (fileErr) {
        console.error("❌ Error fetching/storing Polar file:", fileErr)
    }

    const duration = Date.now() - startTime
    console.log(`✅ Activity stored: ${activityId} (${duration}ms)`)

    // Trigger Notification
    console.log("🔔 Triggering notification...")
    const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
    const notifyPayload = {
        user_id: userId,
        activity_id: activityId.toString(),
        activity_name: activityData.activity_name,
        activity_type: activityData.activity_type,
        distance_meters: activityData.distance_meters,
        duration_seconds: activityData.elapsed_time
    }

    fetch(notifyUrl, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(notifyPayload)
    }).then(async (res) => {
        if (res.ok) {
            console.log(`✅ Notification triggered successfully: ${res.status}`)
        } else {
            const text = await res.text()
            console.error(`❌ Notification trigger failed: ${res.status} - ${text}`)
        }
    }).catch(err => {
        console.error("❌ Error calling notification function:", err)
    })

    return new Response(JSON.stringify({
      success: true,
      activity_id: activityId,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in Polar activity store:", error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
})

