import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    console.log("📦 Polar Historical Sync (Manual Transaction Trigger) started")
    const { user_id } = await req.json()
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: connection, error: connError } = await supabase
      .from('polar_connections')
      .select('*')
      .eq('user_id', user_id)
      .single()

    if (connError || !connection) throw new Error("Polar connection not found")

    // Trigger the existing transaction logic by calling the webhook function (or duplicating logic)
    // It's cleaner to call the webhook function if possible, or just replicate the transaction code.
    // Let's replicate the transaction code to be safe and independent.
    
    const userId = connection.polar_user_id
    const accessToken = connection.access_token
    
    // 1. Create Transaction
    console.log("🔄 Creating Polar transaction...")
    const txRes = await fetch(`https://www.polaraccesslink.com/v3/users/${userId}/exercise-transactions`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/json'
        }
    })

    if (txRes.status === 204) {
        console.log("ℹ️ No new data (204 No Content)")
        return new Response(JSON.stringify({ success: true, message: "No new data found", count: 0 }), { headers: { 'Content-Type': 'application/json' } })
    }

    if (!txRes.ok) {
        // If 409, valid transaction exists?
        throw new Error(`Failed to create transaction: ${txRes.status}`)
    }

    const txData = await txRes.json()
    const transactionId = txData.transaction_id
    const resourceUrl = txData["resource-uri"]
    
    console.log(`✅ Transaction created: ${transactionId}`)

    // 2. List Exercises
    const listRes = await fetch(resourceUrl, {
        headers: { 'Authorization': `Bearer ${accessToken}` }
    })
    
    if (!listRes.ok) throw new Error("Failed to list exercises")
    
    const { exercises } = await listRes.json()
    console.log(`✅ Found ${exercises?.length || 0} exercises`)

    // 3. Process & Commit
    let processed = 0
    if (exercises) {
        for (const exerciseUrl of exercises) {
            // Extract ID from URL
            // URL format: .../exercises/{id}
            const activityId = exerciseUrl.split('/').pop()
            
            // Call store
            const payload = {
                exerciseId: activityId, // passed to store
                polarUserId: userId,
                url: exerciseUrl,
                manual_sync: true
            }

            await fetch(`${supabaseUrl}/functions/v1/polar-activity-store`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${supabaseKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            })
            processed++
        }
    }

    // Commit Transaction
    await fetch(`https://www.polaraccesslink.com/v3/users/${userId}/exercise-transactions/${transactionId}`, {
        method: 'PUT',
        headers: { 'Authorization': `Bearer ${accessToken}` }
    })
    
    console.log("✅ Transaction committed")

    return new Response(JSON.stringify({ success: true, count: processed }), { headers: { 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error("❌ Error:", error)
    return new Response(JSON.stringify({ success: false, error: error.message }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
})

