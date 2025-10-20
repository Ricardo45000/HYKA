// Supabase Edge Function for fetching Garmin activity details using OAuth 1.0a
// This function is called from the iOS app or other services to fetch activity details
// when a webhook notification is received or when manually syncing

import { createClient } from 'npm:@supabase/supabase-js@2'
import { crypto } from 'https://deno.land/std@0.168.0/crypto/mod.ts'

// Environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || ''
const GARMIN_CONSUMER_KEY = Deno.env.get('GARMIN_CONSUMER_KEY') || ''
const GARMIN_CONSUMER_SECRET = Deno.env.get('GARMIN_CONSUMER_SECRET') || ''

// Garmin Activity API base URL
const GARMIN_ACTIVITY_API_BASE = 'https://apis.garmin.com/activity-service/activity'

interface ActivityDetail {
  activityId: string
  activityName: string
  description?: string
  activityType?: {
    typeId: number
    typeKey: string
    parentTypeId?: number
  }
  startTimeGMT?: string
  startTimeLocal?: string
  distance?: number
  duration?: number
  elapsedDuration?: number
  movingDuration?: number
  elevationGain?: number
  elevationLoss?: number
  averageSpeed?: number
  maxSpeed?: number
  averageHR?: number
  maxHR?: number
  calories?: number
  [key: string]: any
}

// OAuth 1.0a helper functions (same as webhook function)
function percentEncode(str: string): string {
  return encodeURIComponent(str)
    .replace(/!/g, '%21')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/\*/g, '%2A')
}

function generateNonce(): string {
  const array = new Uint8Array(16)
  crypto.getRandomValues(array)
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('')
}

async function generateOAuth1Signature(
  method: string,
  url: string,
  params: Record<string, string>,
  consumerSecret: string,
  tokenSecret: string = ''
): Promise<string> {
  const sortedParams = Object.keys(params)
    .sort()
    .map(key => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join('&')

  const signatureBase = `${method}&${percentEncode(url)}&${percentEncode(sortedParams)}`
  const signingKey = `${percentEncode(consumerSecret)}&${percentEncode(tokenSecret)}`

  const key = new TextEncoder().encode(signingKey)
  const message = new TextEncoder().encode(signatureBase)
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  )
  
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, message)
  const bytes = new Uint8Array(signature)
  const binary = String.fromCharCode(...bytes)
  return btoa(binary)
}

async function generateOAuth1Header(
  method: string,
  url: string,
  consumerKey: string,
  consumerSecret: string,
  token?: string,
  tokenSecret?: string,
  additionalParams: Record<string, string> = {}
): Promise<string> {
  const nonce = generateNonce()
  const timestamp = Math.floor(Date.now() / 1000).toString()

  const params: Record<string, string> = {
    oauth_consumer_key: consumerKey,
    oauth_nonce: nonce,
    oauth_signature_method: 'HMAC-SHA1',
    oauth_timestamp: timestamp,
    oauth_version: '1.0',
    ...additionalParams,
  }

  if (token) {
    params.oauth_token = token
  }

  const signature = await generateOAuth1Signature(
    method,
    url,
    params,
    consumerSecret,
    tokenSecret || ''
  )

  const headerParams: Record<string, string> = {
    oauth_consumer_key: consumerKey,
    oauth_nonce: nonce,
    oauth_signature_method: 'HMAC-SHA1',
    oauth_timestamp: timestamp,
    oauth_version: '1.0',
    oauth_signature: signature,
  }

  if (token) {
    headerParams.oauth_token = token
  }

  const headerString = Object.keys(headerParams)
    .sort()
    .map(key => `${percentEncode(key)}="${percentEncode(headerParams[key])}"`)
    .join(', ')

  return `OAuth ${headerString}`
}

// Fetch activity details from Garmin Activity API
async function fetchActivityDetails(
  activityId: string,
  accessToken: string,
  tokenSecret: string
): Promise<ActivityDetail | null> {
  const url = `${GARMIN_ACTIVITY_API_BASE}/${activityId}`
  
  try {
    const authHeader = await generateOAuth1Header(
      'GET',
      url,
      GARMIN_CONSUMER_KEY,
      GARMIN_CONSUMER_SECRET,
      accessToken,
      tokenSecret
    )

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': authHeader,
        'Accept': 'application/json',
      },
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`Failed to fetch activity ${activityId}: ${response.status} ${errorText}`)
      return null
    }

    const activityData = await response.json()
    return activityData as ActivityDetail
  } catch (error) {
    console.error(`Error fetching activity ${activityId}:`, error)
    return null
  }
}

// Main handler
Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  try {
    // Verify authentication
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    })

    // Get authenticated user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Parse request body
    const body = await req.json()
    const { activityId } = body

    if (!activityId) {
      return new Response(
        JSON.stringify({ error: 'Missing activityId' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Get user's Garmin OAuth 1.0a credentials from database
    const { data: oauthConnection, error: oauthError } = await supabase
      .from('oauth_connections')
      .select('access_token, token_secret')
      .eq('user_id', user.id)
      .eq('provider', 'garmin')
      .single()

    if (oauthError || !oauthConnection) {
      return new Response(
        JSON.stringify({ error: 'Garmin connection not found' }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Check if we have OAuth 1.0a credentials (token_secret indicates OAuth 1.0a)
    if (!oauthConnection.token_secret) {
      return new Response(
        JSON.stringify({ error: 'OAuth 1.0a credentials not found. Please reconnect Garmin.' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Fetch activity details
    const activityDetails = await fetchActivityDetails(
      activityId,
      oauthConnection.access_token,
      oauthConnection.token_secret
    )

    if (!activityDetails) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch activity details' }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Return activity details
    return new Response(
      JSON.stringify({
        success: true,
        activity: activityDetails,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Error in garmin-oauth1-activity:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})

