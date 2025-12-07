import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Polar Activity Webhook
 * 
 * Handles webhooks from Polar AccessLink.
 * Polar sends a "PING" notification when data is available.
 * We must then:
 * 1. Initiate a transaction
 * 2. List available data (exercises)
 * 3. Fetch each item
 * 4. Commit the transaction
 * 
 * Webhook Payload Example:
 * {
 *   "type": "EXERCISE",
 *   "url": "https://www.polaraccesslink.com/v3/users/123456/exercise-transactions/123456",
 *   "user_id": 123456,
 *   "event": "EXERCISE"
 * }
 */

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
        'Access-Control-Allow-Headers': 'content-type'
      }
    })
  }

  // Handle verification PING from Polar (GET request)
  // Polar sends a GET request to verify the endpoint
  if (req.method === 'GET') {
      return new Response(JSON.stringify({ status: "ok" }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
      })
  }

  const startTime = Date.now()

  try {
    console.log("📦 Polar Webhook received")
    const body = await req.json()
    console.log("   Body:", JSON.stringify(body))

    const polarUserId = body.user_id
    const eventType = body.type || body.event // "EXERCISE", "ACTIVITY", "SLEEP"

    if (!polarUserId) {
        console.warn("⚠️ Missing user_id in webhook")
        return new Response(JSON.stringify({ message: "Missing user_id" }), { status: 200 }) // Return 200 to stop retries
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. Lookup User Connection
    const { data: connection, error: connError } = await supabase
        .from('polar_connections')
        .select('user_id, access_token, id')
        .eq('polar_user_id', polarUserId.toString())
        .single()

    if (connError || !connection) {
        console.error(`❌ Connection not found for Polar user ${polarUserId}`)
        // Return 200 to acknowledge receipt and stop Polar from retrying
        return new Response(JSON.stringify({ message: "Connection not found" }), { status: 200 })
    }

    console.log(`✅ Found connection for user: ${connection.user_id}`)

    // 2. Process based on Event Type
    // We currently only automate EXERCISE (Activities + FIT/TCX)
    if (eventType === 'EXERCISE') {
        await processExerciseTransaction(connection, supabase)
    } else {
        console.log(`ℹ️ Skipping event type: ${eventType} (Not implemented yet)`)
    }

    return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error("❌ Error processing Polar webhook:", error)
    return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
    })
  }
})

async function processExerciseTransaction(connection: any, supabase: any) {
    const accessToken = connection.access_token
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // A. Create Transaction
    console.log("🔄 Creating Exercise Transaction...")
    const createTxRes = await fetch(`https://www.polaraccesslink.com/v3/users/${connection.polar_user_id}/exercise-transactions`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/json'
        }
    })

    if (createTxRes.status === 204) {
        console.log("ℹ️ No new exercises available")
        return
    }

    if (!createTxRes.ok) {
        const text = await createTxRes.text()
        console.error("❌ Failed to create transaction:", createTxRes.status, text)
        return
    }

    const transaction = await createTxRes.json()
    const transactionId = transaction.transaction_id
    const resourceUrl = transaction.resource_uri // List of exercises URL
    
    console.log(`✅ Transaction created: ${transactionId}`)

    // B. List Exercises
    console.log("📋 Listing exercises...")
    const listRes = await fetch(resourceUrl, {
        headers: { 'Authorization': `Bearer ${accessToken}`, 'Accept': 'application/json' }
    })

    if (!listRes.ok) {
        console.error("❌ Failed to list exercises")
        return
    }

    const exerciseList = await listRes.json()
    const exercises = exerciseList.exercises || []
    console.log(`   Found ${exercises.length} exercises`)

    // C. Process Each Exercise
    for (const exerciseUrl of exercises) {
        // exerciseUrl example: "https://www.polaraccesslink.com/v3/exercises/123456"
        const parts = exerciseUrl.split('/')
        const exerciseId = parts[parts.length - 1]

        console.log(`➡️ Forwarding Exercise ${exerciseId} to polar-activity-store...`)

        // Call polar-activity-store to handle fetch, storage, TCX download, and notification
        await fetch(`${supabaseUrl}/functions/v1/polar-activity-store`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                user_id: connection.user_id,
                activity_id: exerciseId,
                access_token: accessToken // Pass token to save a DB lookup
            })
        }).catch(err => console.error(`   ❌ Failed to forward exercise ${exerciseId}:`, err))
    }

    // D. Commit Transaction
    // IMPORTANT: Only commit if we processed at least something, or always to clear the queue?
    // Always commit to acknowledge we received them.
    console.log(`🔒 Committing transaction ${transactionId}...`)
    const commitRes = await fetch(`https://www.polaraccesslink.com/v3/users/${connection.polar_user_id}/exercise-transactions/${transactionId}`, {
        method: 'PUT',
        headers: { 'Authorization': `Bearer ${accessToken}` }
    })

    if (commitRes.ok) {
        console.log("✅ Transaction committed")
    } else {
        console.error("⚠️ Failed to commit transaction:", commitRes.status)
    }
}
