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
  
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, User-Agent',
        'Access-Control-Max-Age': '86400',
      },
    })
  }
  
  try {
    console.log("🔔 Garmin Permission Webhook received")
    console.log("   Method:", req.method)
    console.log("   URL:", req.url)
    console.log("   Headers:", Object.fromEntries(req.headers.entries()))
    
    // Extract webhook secret from URL path
    // Expected format: /functions/v1/garmin-permission-webhook/SECRET_TOKEN
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(p => p)
    const functionNameIndex = pathParts.findIndex(p => p === 'garmin-permission-webhook')
    const secretFromPath = functionNameIndex >= 0 && pathParts[functionNameIndex + 1] 
      ? pathParts[functionNameIndex + 1] 
      : null
    
    // Get expected webhook secret from environment (optional)
    const expectedSecret = Deno.env.get('GARMIN_WEBHOOK_SECRET') || 'garmin-webhook-secret-2024'
    
    // Verify secret if provided in path
    if (secretFromPath) {
      if (secretFromPath === expectedSecret) {
        console.log("✅ Valid webhook secret verified")
      } else {
        console.log("⚠️ Invalid webhook secret provided")
      }
    } else {
      console.log("ℹ️ No webhook secret in URL path")
    }
    
    // Verify request is from Garmin (but don't reject - just log)
    const userAgent = req.headers.get('user-agent') || ''
    if (!userAgent.includes('Garmin')) {
      console.log("⚠️ Request not from Garmin (user-agent:", userAgent, ")")
      // Still process - might be from testing or other sources
    } else {
      console.log("✅ Verified Garmin User-Agent")
    }
    
    // Parse request body (handle both JSON and form data)
    let body: any
    try {
      const contentType = req.headers.get('content-type') || ''
      if (contentType.includes('application/json')) {
        body = await req.json()
      } else {
        // Try to parse as JSON anyway (Garmin usually sends JSON)
        const text = await req.text()
        body = text ? JSON.parse(text) : {}
      }
    } catch (parseError) {
      console.error("❌ Error parsing request body:", parseError)
      // Return 200 to prevent Garmin from retrying
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
    }
    
    console.log("   Body:", JSON.stringify(body, null, 2))
    console.log("   Body keys:", Object.keys(body))
    
    // Extract webhook type and user ID
    // Garmin may send userId in various formats depending on webhook type
    const webhookType = body.type || body.eventType || body.webhookType || body.event_type
    const garminUserId = body.userId || body.garminUserId || body.user_id || body.garmin_user_id || 
                         body.userAccessToken || body.user?.id || body.user?.garminUserId
    
    if (!garminUserId) {
      console.error("❌ Missing garminUserId in webhook")
      console.error("   Body structure:", JSON.stringify(body, null, 2))
      console.error("   Available keys:", Object.keys(body))
      console.error("   Webhook type:", webhookType || "unknown")
      
      // Some webhook types might not require garminUserId (e.g., global events)
      // Still return 200 OK to prevent Garmin from retrying
      return new Response("OK", { 
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain'
        }
      })
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
// IMPORTANT: This function must be configured to allow anonymous access
// in Supabase Dashboard, otherwise Garmin webhooks will receive 401 errors.
//
// To make this function public:
// 1. Go to Supabase Dashboard → Edge Functions → garmin-permission-webhook
// 2. Configure the function to allow unauthenticated requests
//    OR use the anon key in the webhook URL (not recommended for security)
//
// 1. Configure webhook in Garmin Developer Portal:
//    - URL: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook
//    - Method: POST
//    - Events: Registration, Permission Changes, Deregistration
//
// 2. This webhook is required for certification
//
// 3. Make function public in Supabase Dashboard (required for webhooks)
//
// ============================================================================

