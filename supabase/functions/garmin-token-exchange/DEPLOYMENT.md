# Garmin Token Exchange - Deployment Guide

## Prerequisites

1. Supabase CLI installed and authenticated
2. Access to your Supabase project

## Step 1: Set Environment Variables

In your Supabase Dashboard:

1. Go to **Project Settings** → **Edge Functions** → **Secrets**
2. Add the following secrets:

```
GARMIN_CLIENT_ID=695055f8-9786-4fda-a3a7-f7c2e88382f0
GARMIN_CLIENT_SECRET=0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q
GARMIN_REDIRECT_URI=https://hyka.app/garmin/callback
```

**OR** use Supabase CLI:

```bash
supabase secrets set GARMIN_CLIENT_ID=695055f8-9786-4fda-a3a7-f7c2e88382f0
supabase secrets set GARMIN_CLIENT_SECRET=0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q
supabase secrets set GARMIN_REDIRECT_URI=https://hyka.app/garmin/callback
```

## Step 2: Deploy the Function

From the project root directory:

```bash
cd supabase
supabase functions deploy garmin-token-exchange
```

## Step 3: Verify Deployment

Test the function:

```bash
curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-token-exchange \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "test_code",
    "code_verifier": "test_verifier",
    "redirect_uri": "https://hyka.app/garmin/callback"
  }'
```

## Step 4: Update iOS App

The iOS code has already been updated to use the Edge Function. No additional changes needed.

## Security Notes

- ✅ Client secret is now stored securely in Supabase (not in iOS app)
- ✅ Function requires authentication (Authorization header)
- ✅ CORS is enabled for cross-origin requests
- ⚠️ Make sure to keep your Supabase anon key secure (it's used for authentication)

## Troubleshooting

### Function returns 401
- Check that you're sending the `Authorization` header with your Supabase anon key
- Verify the anon key is correct

### Function returns 500
- Check that all environment variables are set correctly
- Review Supabase function logs for detailed error messages

### Token exchange fails
- Verify Garmin credentials are correct
- Check that the redirect URI matches what's configured in Garmin Developer Portal
- Ensure the authorization code hasn't expired (they expire quickly)

