// OAuth 1.0a Helper for Deno/TypeScript
// Implements HMAC-SHA1 signature generation for Garmin API requests
// Reference: RFC 5849 - The OAuth 1.0 Protocol

// Use Deno's built-in crypto for HMAC-SHA1
async function hmacSha1(key: string, message: string): Promise<string> {
  const keyData = new TextEncoder().encode(key)
  const messageData = new TextEncoder().encode(message)
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  )
  
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, messageData)
  const base64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
  return base64
}

/**
 * Percent-encode a string according to RFC 3986
 * This is stricter than standard URL encoding
 */
function percentEncode(str: string): string {
  return encodeURIComponent(str)
    .replace(/!/g, '%21')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/\*/g, '%2A')
}

/**
 * Generate a random nonce (number used once)
 */
function generateNonce(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

/**
 * Generate OAuth 1.0a signature
 * @param method HTTP method (GET, POST, etc.)
 * @param url Base URL (without query parameters)
 * @param parameters OAuth parameters and request parameters
 * @param consumerSecret OAuth consumer secret
 * @param tokenSecret OAuth token secret (from access_token in OAuth 2.0 flow)
 */
export async function generateOAuth1Signature(
  method: string,
  url: string,
  parameters: Record<string, string>,
  consumerSecret: string,
  tokenSecret: string = ''
): Promise<string> {
  // 1. Normalize parameters: sort by key, then by value
  const sortedParams = Object.entries(parameters)
    .sort(([keyA, valA], [keyB, valB]) => {
      if (keyA !== keyB) return keyA.localeCompare(keyB)
      return valA.localeCompare(valB)
    })
    .map(([key, value]) => `${percentEncode(key)}=${percentEncode(value)}`)
    .join('&')

  // 2. Construct signature base string
  const signatureBaseString = [
    method.toUpperCase(),
    percentEncode(url),
    percentEncode(sortedParams)
  ].join('&')

  // 3. Construct signing key
  const signingKey = `${percentEncode(consumerSecret)}&${percentEncode(tokenSecret)}`

  // 4. Generate HMAC-SHA1 signature
  const signature = await hmacSha1(signingKey, signatureBaseString)

  return signature
}

/**
 * Generate OAuth 1.0a authorization header
 * @param method HTTP method
 * @param url Request URL
 * @param consumerKey OAuth consumer key
 * @param consumerSecret OAuth consumer secret
 * @param token OAuth token (from access_token in OAuth 2.0 flow)
 * @param tokenSecret OAuth token secret (from refresh_token in OAuth 2.0 flow)
 * @param additionalParams Additional OAuth parameters (oauth_callback, etc.)
 */
export async function generateOAuth1Header(
  method: string,
  url: string,
  consumerKey: string,
  consumerSecret: string,
  token: string,
  tokenSecret: string,
  additionalParams: Record<string, string> = {}
): Promise<string> {
  const timestamp = Math.floor(Date.now() / 1000).toString()
  const nonce = generateNonce()

  // Build OAuth parameters
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: consumerKey,
    oauth_token: token,
    oauth_signature_method: 'HMAC-SHA1',
    oauth_timestamp: timestamp,
    oauth_nonce: nonce,
    oauth_version: '1.0',
    ...additionalParams
  }

  // Generate signature (include all parameters in signature base string)
  const signature = await generateOAuth1Signature(
    method,
    url,
    oauthParams,
    consumerSecret,
    tokenSecret
  )

  // Add signature to parameters
  oauthParams.oauth_signature = signature

  // Build authorization header
  const authHeader = 'OAuth ' + Object.entries(oauthParams)
    .map(([key, value]) => `${percentEncode(key)}="${percentEncode(value)}"`)
    .join(', ')

  return authHeader
}

/**
 * Make an OAuth 1.0a signed request
 * @param url Request URL
 * @param method HTTP method
 * @param consumerKey OAuth consumer key
 * @param consumerSecret OAuth consumer secret
 * @param token OAuth token (from access_token)
 * @param tokenSecret OAuth token secret (from refresh_token)
 * @param body Optional request body (for POST requests)
 */
export async function makeOAuth1Request(
  url: string,
  method: string = 'GET',
  consumerKey: string,
  consumerSecret: string,
  token: string,
  tokenSecret: string,
  body?: string
): Promise<Response> {
  const urlObj = new URL(url)
  const baseUrl = `${urlObj.protocol}//${urlObj.host}${urlObj.pathname}`

  // Generate OAuth 1.0a authorization header
  const authHeader = await generateOAuth1Header(
    method,
    baseUrl,
    consumerKey,
    consumerSecret,
    token,
    tokenSecret
  )

  // Make the request
  const headers: Record<string, string> = {
    'Authorization': authHeader,
    'User-Agent': 'HYKA/1.0'
  }

  if (body) {
    headers['Content-Type'] = 'application/x-www-form-urlencoded'
  }

  const response = await fetch(url, {
    method,
    headers,
    body
  })

  return response
}

