// ============================================================================
// Garmin Token Refresh Utility
// ============================================================================
//
// Purpose: Refresh expired Garmin OAuth 2.0 access tokens
//
// Usage:
//   import { refreshGarminToken } from './_shared/garmin-token-refresh.ts'
//   const refreshedToken = await refreshGarminToken(userId, supabase)
//
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export interface TokenRefreshResult {
  success: boolean
  access_token?: string
  refresh_token?: string
  token_expires_at?: string
  error?: string
}

/**
 * Refreshes a Garmin OAuth 2.0 access token using the refresh token
 */
export async function refreshGarminToken(
  userId: string,
  supabase: ReturnType<typeof createClient>
): Promise<TokenRefreshResult> {
  try {
    console.log("🔄 Refreshing Garmin access token for user:", userId)
    
    // Step 1: Get current connection with refresh token
    const { data: connection, error: connectionError } = await supabase
      .from('garmin_connections')
      .select('id, refresh_token, garmin_user_id')
      .eq('user_id', userId)
      .single()
    
    if (connectionError || !connection) {
      console.error("❌ Connection not found:", connectionError)
      return {
        success: false,
        error: "Garmin connection not found"
      }
    }
    
    if (!connection.refresh_token) {
      console.error("❌ No refresh token available")
      return {
        success: false,
        error: "No refresh token available. User needs to reconnect Garmin."
      }
    }
    
    // Step 2: Get Garmin OAuth credentials
    const clientId = Deno.env.get('GARMIN_CLIENT_ID')
    const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
    
    if (!clientId || !clientSecret) {
      console.error("❌ Missing Garmin OAuth credentials")
      return {
        success: false,
        error: "Garmin OAuth credentials not configured"
      }
    }
    
    // Step 3: Call Garmin token refresh endpoint
    console.log("   Calling Garmin token refresh endpoint...")
    const tokenUrl = "https://diauth.garmin.com/di-oauth2-service/oauth/token"
    
    const params = new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: connection.refresh_token,
      client_id: clientId,
      client_secret: clientSecret
    })
    
    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      body: params.toString()
    })
    
    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error("❌ Token refresh failed:", tokenResponse.status, errorText)
      
      // If refresh token is invalid, user needs to reconnect
      if (tokenResponse.status === 401 || tokenResponse.status === 400) {
        return {
          success: false,
          error: "Refresh token expired or invalid. User needs to reconnect Garmin."
        }
      }
      
      return {
        success: false,
        error: `Token refresh failed: ${tokenResponse.status} - ${errorText}`
      }
    }
    
    const tokenData = await tokenResponse.json()
    const newAccessToken = tokenData.access_token
    const newRefreshToken = tokenData.refresh_token || connection.refresh_token // Keep old if not provided
    const expiresIn = tokenData.expires_in
    
    console.log("✅ Token refreshed successfully")
    console.log("   New access token:", newAccessToken.substring(0, 20) + "...")
    console.log("   Expires in:", expiresIn, "seconds")
    
    // Step 4: Calculate new expiration time
    const expiresAt = expiresIn 
      ? new Date(Date.now() + (expiresIn - 600) * 1000).toISOString() // Subtract 600s buffer
      : null
    
    // Step 5: Update connection in database
    console.log("💾 Updating connection with new token...")
    
    const { error: updateError } = await supabase
      .from('garmin_connections')
      .update({
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        token_expires_at: expiresAt,
        updated_at: new Date().toISOString()
      })
      .eq('user_id', userId)
    
    if (updateError) {
      console.error("❌ Failed to update connection:", updateError)
      return {
        success: false,
        error: `Failed to update connection: ${updateError.message}`
      }
    }
    
    console.log("✅ Connection updated with new token")
    
    return {
      success: true,
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
      token_expires_at: expiresAt || undefined
    }
    
  } catch (error) {
    console.error("❌ Error refreshing token:", error)
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error"
    }
  }
}

/**
 * Checks if a token is expired or about to expire (within 5 minutes)
 */
export function isTokenExpired(expiresAt: string | null | undefined): boolean {
  if (!expiresAt) {
    return true // Assume expired if no expiration time
  }
  
  const expirationTime = new Date(expiresAt).getTime()
  const now = Date.now()
  const buffer = 5 * 60 * 1000 // 5 minutes buffer
  
  return now >= (expirationTime - buffer)
}

/**
 * Gets a valid access token, refreshing if necessary
 */
export async function getValidAccessToken(
  userId: string,
  supabase: ReturnType<typeof createClient>
): Promise<string | null> {
  // Get connection
  const { data: connection, error } = await supabase
    .from('garmin_connections')
    .select('access_token, token_expires_at, refresh_token')
    .eq('user_id', userId)
    .single()
  
  if (error || !connection) {
    console.error("❌ Connection not found")
    return null
  }
  
  // Check if token is expired
  if (isTokenExpired(connection.token_expires_at)) {
    console.log("⚠️ Access token expired, refreshing...")
    
    const refreshResult = await refreshGarminToken(userId, supabase)
    
    if (!refreshResult.success || !refreshResult.access_token) {
      console.error("❌ Failed to refresh token:", refreshResult.error)
      return null
    }
    
    return refreshResult.access_token
  }
  
  // Token is still valid
  return connection.access_token
}

