// ============================================================================
// Garmin Activity Pull (Correct OAuth 2.0 Flow)
// ============================================================================
//
// Purpose: Fetch activity data from Garmin using callbackUrl
//
// Flow:
// 1. Receive callbackUrl (includes temporary Pull Token)
// 2. Fetch activity summary from callbackUrl
// 3. Fetch activity details from callbackUrl/details
// 4. Forward to garmin-activity-store
//
// Reference: Garmin Connect API OAuth 2.0 DIAUTH specification
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("📥 Garmin Activity Pull started")
    
    const { callbackUrl, garminUserId, summaryId } = await req.json()
    
    if (!callbackUrl) {
      console.error("❌ Missing callbackUrl")
      return new Response(JSON.stringify({ error: "Missing callbackUrl" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log("   Callback URL:", callbackUrl.substring(0, 100) + "...")
    console.log("   Summary ID:", summaryId || "not provided")
    console.log("   Garmin User ID:", garminUserId || "not provided")
    
    // 1. Fetch summary data using callbackUrl
    console.log("🔄 Fetching activity summary...")
    const summaryRes = await fetch(callbackUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    })
    
    if (!summaryRes.ok) {
      const errorText = await summaryRes.text()
      console.error("❌ Summary fetch failed:", summaryRes.status, errorText)
      return new Response(JSON.stringify({ 
        error: "Summary fetch failed",
        status: summaryRes.status,
        details: errorText
      }), {
        status: 200, // Return 200 to prevent retries
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    const summary = await summaryRes.json()
    console.log("✅ Summary fetched:", {
      summaryId: summary.summaryId || summary.id,
      activityType: summary.activityType,
      duration: summary.durationInSeconds
    })
    
    // 2. Fetch details (samples) from callbackUrl/details
    console.log("🔄 Fetching activity details...")
    const detailsUrl = `${callbackUrl}/details`
    const detailsRes = await fetch(detailsUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    })
    
    let details = null
    if (detailsRes.ok) {
      details = await detailsRes.json()
      console.log("✅ Details fetched:", {
        samplesCount: details.samples?.length || 0,
        hasSummary: !!details.summary
      })
    } else {
      const errorText = await detailsRes.text()
      console.log("⚠️ Details fetch failed (non-critical):", detailsRes.status, errorText)
      // Details are optional, continue without them
      // For ultra-runners (>24h), JSON may be truncated - FIT file will be used instead
    }
    
    // 3. Fetch FIT file (for ultra-runner activities >24 hours)
    // FIT files contain complete data when JSON payloads are truncated
    console.log("🔄 Checking for FIT file...")
    const fitFileUrl = `${callbackUrl}/file`
    const fitFileRes = await fetch(fitFileUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/octet-stream'
      }
    })
    
    let fitFileData: ArrayBuffer | null = null
    if (fitFileRes.ok && fitFileRes.headers.get('content-type')?.includes('octet-stream')) {
      fitFileData = await fitFileRes.arrayBuffer()
      console.log("✅ FIT file fetched:", {
        size: fitFileData.byteLength,
        sizeMB: (fitFileData.byteLength / 1024 / 1024).toFixed(2)
      })
    } else {
      console.log("ℹ️ No FIT file available (or not needed)")
      // FIT files are optional - only needed for ultra-runner activities
    }
    
    // 3. Forward to store function
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    console.log("🔄 Forwarding to garmin-activity-store...")
    
    const storeResponse = await fetch(`${supabaseUrl}/functions/v1/garmin-activity-store`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${supabaseKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ 
        summary,
        details,
        garminUserId,
        callbackUrl,
        fitFileData: fitFileData ? Array.from(new Uint8Array(fitFileData)) : null // Convert ArrayBuffer to array for JSON
      })
    })
    
    if (!storeResponse.ok) {
      const errorText = await storeResponse.text()
      console.error("❌ Store function failed:", storeResponse.status, errorText)
      return new Response(JSON.stringify({ 
        error: "Store failed",
        status: storeResponse.status
      }), {
        status: 200, // Return 200 to prevent retries
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    const storeResult = await storeResponse.json()
    console.log("✅ Store function completed:", storeResult)
    
    const duration = Date.now() - startTime
    console.log(`✅ Pull completed in ${duration}ms`)
    
    const samplesCount = details && Array.isArray(details.samples) ? details.samples.length : 0
    
    return new Response(JSON.stringify({
      success: true,
      summaryId: summary.summaryId || summary.id,
      samplesCount: samplesCount,
      duration: `${duration}ms`
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error in pull function:", error)
    console.error("   Duration:", `${duration}ms`)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      duration: `${duration}ms`
    }), {
      status: 200, // Return 200 to prevent retries
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

