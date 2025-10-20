// ============================================================================
// Garmin Permission Webhook (Certification Required)
// ============================================================================
//
// Purpose: Handles Garmin webhooks for user registration, permission changes,
//          and deregistration (required for certification)
//
// Webhook Types:
// 1. Registration: User connects Garmin account
// 2. Permission Revoked: User removes permissions but doesn't disconnect
// 3. Deregistration: User disconnects Garmin account
//
// Flow:
// 1. Receive webhook from Garmin
// 2. Parse webhook type and garminUserId
// 3. Update garmin_connections table accordingly
// 4. Return 200 OK to Garmin
//
// Reference: Garmin Developer Program Certification Requirements
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = Date.now()
  
  try {
    console.log("🔔 Garmin Permission Webhook received")
    console.log("   Method:", req.method)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Verify request is from Garmin
    const userAgent = req.headers.get('user-agent') || ''
    if (!userAgent.includes('Garmin')) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
      // Still return 200 to prevent retries
    }
    
    // Parse request body
    const body = await req.json()
    console.log("   Body:", JSON.stringify(body, null, 2))
    
    // Extract webhook type and user ID
    const webhookType = body.type || body.eventType || body.webhookType
    const garminUserId = body.userId || body.garminUserId || body.user_id
    
    if (!garminUserId) {
      console.error("❌ Missing garminUserId in webhook")
      return new Response("OK", { status: 200 })
    }
    
    console.log("   Webhook Type:", webhookType || "unknown")
    console.log("   Garmin User ID:", garminUserId)
    
    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Handle different webhook types
    switch (webhookType?.toLowerCase()) {
      case 'registration':
      case 'register':
        console.log("✅ Registration webhook - user connected")
        // Connection already stored in garmin-auth-callback
        // Just log it here
        await supabase
          .from('garmin_connections')
          .update({ 
            permission_revoked: false,
            updated_at: new Date().toISOString()
          })
          .eq('garmin_user_id', garminUserId)
        break
        
      case 'permission_revoked':
      case 'permissionrevoked':
        console.log("⚠️ Permission revoked webhook - user removed permissions")
        // User removed permissions but didn't disconnect
        // Set flag for certification compliance
        await supabase
          .from('garmin_connections')
          .update({ 
            permission_revoked: true,
            updated_at: new Date().toISOString()
          })
          .eq('garmin_user_id', garminUserId)
        break
        
      case 'deregistration':
      case 'unregister':
        console.log("🗑️ Deregistration webhook - user disconnected")
        // User disconnected - delete connection
        // Note: This should also trigger unregistration endpoint call
        await supabase
          .from('garmin_connections')
          .delete()
          .eq('garmin_user_id', garminUserId)
        break
        
      default:
        console.log("ℹ️ Unknown webhook type:", webhookType)
        // Still return 200 OK
    }
    
    const duration = Date.now() - startTime
    console.log(`✅ Permission webhook processed in ${duration}ms`)
    
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
    
  } catch (error) {
    const duration = Date.now() - startTime
    console.error("❌ Error processing permission webhook:", error)
    console.error("   Duration:", `${duration}ms`)
    
    // Always return 200 to Garmin (even on error) to prevent retries
    return new Response("OK", { 
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    })
  }
})

// ============================================================================
// Configuration Required
// ============================================================================
//
// 1. Configure webhook in Garmin Developer Portal:
//    - URL: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook
//    - Method: POST
//    - Events: Registration, Permission Changes, Deregistration
//
// 2. This webhook is required for certification
//
// ============================================================================

