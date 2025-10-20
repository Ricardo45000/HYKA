# Garmin Token Exchange Edge Function

This Supabase Edge Function securely exchanges Garmin OAuth 2.0 PKCE authorization codes for access tokens.

## Setup

1. **Set Environment Variables in Supabase Dashboard:**
   - Go to: Project Settings → Edge Functions → Secrets
   - Add the following secrets:
     - `GARMIN_CLIENT_ID`: Your Garmin OAuth client ID
     - `GARMIN_CLIENT_SECRET`: Your Garmin OAuth client secret
     - `GARMIN_REDIRECT_URI`: Your Garmin redirect URI (default: `https://hyka.app/garmin/callback`)

2. **Deploy the Function:**
   ```bash
   supabase functions deploy garmin-token-exchange
   ```

## Usage

**Endpoint:** `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-token-exchange`

**Method:** POST

**Headers:**
- `Authorization: Bearer <supabase_anon_key>` (or user's access token)
- `Content-Type: application/json`

**Request Body:**
```json
{
  "code": "authorization_code_from_garmin",
  "code_verifier": "pkce_code_verifier",
  "redirect_uri": "https://hyka.app/garmin/callback" // optional, uses env var if not provided
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "refresh_token": "refresh_token_here",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

## Security

- Client secret is stored securely in Supabase environment variables
- Function requires authentication (Authorization header)
- CORS is enabled for cross-origin requests

