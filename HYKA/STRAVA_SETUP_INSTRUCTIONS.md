# Strava Integration Setup Instructions

## ✅ iOS App Configuration (Already Updated)

The iOS app has been updated with the new Strava credentials:
- **Client ID**: `184009`
- **Redirect URI**: `com.hyka.app://strava-callback`

## 🔧 Supabase Edge Functions Configuration

You need to set the following **Secrets** in your Supabase project for the 4 Strava edge functions:

### Step 1: Navigate to Supabase Dashboard

1. Go to your Supabase project: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq
2. Click on **Edge Functions** in the left sidebar
3. Click on **Secrets** (or go to Settings → Edge Functions → Secrets)

### Step 2: Set Required Secrets

Add/Update the following secrets:

#### 1. `STRAVA_CLIENT_ID`
- **Value**: `184009`
- **Used by**: `strava-auth-callback`
- **Purpose**: Strava OAuth Client ID

#### 2. `STRAVA_CLIENT_SECRET`
- **Value**: `9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45`
- **Used by**: `strava-auth-callback`
- **Purpose**: Strava OAuth Client Secret (used for token exchange)

#### 3. `STRAVA_WEBHOOK_VERIFY_TOKEN` (Optional)
- **Value**: `strava-webhook-verify-token-2025`
- **Used by**: `strava-activity-webhook`
- **Purpose**: Token for verifying webhook subscription requests from Strava
- **Note**: This should match what you configure in Strava Developer Portal

### Step 3: Verify Edge Functions

The following edge functions should already be deployed:
1. ✅ `strava-auth-callback` - Handles OAuth callback
2. ✅ `strava-activity-store` - Stores activity data
3. ✅ `strava-activity-webhook` - Receives webhook notifications
4. ✅ `strava-activity-notify` - Sends push notifications

### Step 4: Configure Strava Developer Portal

1. Go to https://www.strava.com/settings/api
2. Find your application (Client ID: 184009)
3. Click **"Edit Application"** or **"Update Application"**
4. Update the following settings:

#### Authorization Callback Domain:
- **Value**: `gvfhtiljkybbrbxoyqsq.supabase.co`
- **Important**: This must be JUST the domain part (no `https://`, no paths, no trailing slashes)
- This is the domain of your Supabase Edge Function that handles the OAuth redirect
- Strava will redirect to this domain after user authorization

#### OAuth Redirect URI (in iOS app):
- **Current**: The app uses: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback`
- This is a web-based redirect URI (most reliable for Strava)
- Flow: Strava → Edge Function (GET) → App (with code) → Edge Function (POST) → Tokens
- The edge function receives the code from Strava and redirects to the app

#### Webhook Subscription:
- **Webhook URL**: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook`
- **Verify Token**: `strava-webhook-verify-token-2025` (must match `STRAVA_WEBHOOK_VERIFY_TOKEN` in Supabase)
- **Subscription Events**: Select `activity.create` (and optionally `activity.update`, `activity.delete`)

### Step 5: Test the Integration

1. **Test OAuth Flow**:
   - Open the iOS app
   - Go to Profile → Connexion with your wearable
   - Tap on "Strava"
   - Complete the OAuth flow
   - Verify connection is saved

2. **Test Webhook**:
   - Create a test activity in Strava
   - Check Supabase Edge Functions logs to see if webhook was received
   - Verify activity appears in `strava_activities` table

## 📋 Summary of Changes

### iOS App (`Config.swift`)
- ✅ Added `stravaClientID = "184009"`
- ✅ Added `stravaRedirectURI = "com.hyka.app://strava-callback"`
- ✅ Added `stravaAuthCallbackURL` helper

### Supabase Secrets Required
- ✅ `STRAVA_CLIENT_ID` = `184009`
- ✅ `STRAVA_CLIENT_SECRET` = `9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45`
- ✅ `STRAVA_WEBHOOK_VERIFY_TOKEN` = `strava-webhook-verify-token-2025`

### Optional: If You Need to Use Existing Tokens

If you want to use the provided access/refresh tokens directly (for testing or migration):

1. **Access Token**: `72c0bfa1c545c44541b0a4d2738716beaa9b0627`
2. **Refresh Token**: `2c6e3b69cf1301245aec1cb3625d7c1d8daef07e`

You can manually insert these into the `strava_connections` table for a specific user:

```sql
UPDATE strava_connections
SET 
  access_token = '72c0bfa1c545c44541b0a4d2738716beaa9b0627',
  refresh_token = '2c6e3b69cf1301245aec1cb3625d7c1d8daef07e',
  token_expires_at = NOW() + INTERVAL '6 hours', -- Strava tokens expire in 6 hours
  updated_at = NOW()
WHERE user_id = 'YOUR_USER_ID_HERE';
```

**Note**: These tokens will expire, so users should complete the OAuth flow for long-term access.

## 🔍 Troubleshooting

### Edge Function Errors
- Check Edge Functions logs in Supabase Dashboard
- Verify all secrets are set correctly
- Ensure edge functions are deployed

### OAuth Flow Issues

#### "invalid redirect_uri" Error
If you're getting `{"message":"Bad Request","errors":[{"resource":"Application","field":"redirect_uri","code":"invalid"}]}`:

1. **Verify Authorization Callback Domain in Strava:**
   - Go to https://www.strava.com/settings/api
   - Find your app (Client ID: 184009)
   - Click **"Edit Application"**
   - Check the **"Authorization Callback Domain"** field
   - It should be exactly: `gvfhtiljkybbrbxoyqsq.supabase.co`
   - **IMPORTANT**: No `https://`, no paths, no trailing slashes
   - Click **"Save"** and wait 1-2 minutes for changes to propagate

2. **Verify Redirect URI in Code:**
   - The app uses: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback`
   - Check the console logs when connecting to see the exact redirect_uri being sent
   - The domain part (`gvfhtiljkybbrbxoyqsq.supabase.co`) must match the Authorization Callback Domain

3. **Check for Typos:**
   - Make sure there are no extra spaces in the Authorization Callback Domain
   - Verify the domain is exactly: `gvfhtiljkybbrbxoyqsq.supabase.co` (no www, no subdomain variations)

4. **Verify Edge Function is Deployed:**
   - Go to Supabase Dashboard → Edge Functions
   - Ensure `strava-auth-callback` is deployed and active
   - Test the function URL: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback`

5. **Check Console Logs:**
   - When you try to connect, check Xcode console
   - Look for the log: `🔐 Strava Authorization URL: ...`
   - Copy the exact `redirect_uri` value from the query string
   - Compare it with what's configured in Strava

#### Other OAuth Issues
- Check that `strava-auth-callback` function is accessible
- Review function logs for detailed error messages
- Verify all Supabase secrets are set correctly

### Webhook Not Receiving Events
- Verify webhook subscription in Strava Developer Portal
- Check `STRAVA_WEBHOOK_VERIFY_TOKEN` matches in both places
- Test webhook verification endpoint manually (GET request)

## 📝 Next Steps

1. ✅ Set secrets in Supabase Dashboard
2. ✅ Configure Strava Developer Portal
3. ✅ Test OAuth connection in iOS app
4. ✅ Verify webhook receives activity events
5. ✅ Test end-to-end flow: Create activity → Webhook → Store → Notification

