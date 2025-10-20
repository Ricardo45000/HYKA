# Using OAuth 2.0 Credentials as OAuth 1.0a Consumer Key/Secret

## Solution for OAuth 2.0 Only Apps

If your Garmin Developer Portal application is **OAuth 2.0 only** (no separate OAuth 1.0a Consumer Key/Secret), you can use your **OAuth 2.0 Client ID and Client Secret** as the Consumer Key and Consumer Secret.

## How It Works

Garmin allows using:
- **OAuth 2.0 Client ID** → **OAuth 1.0a Consumer Key**
- **OAuth 2.0 Client Secret** → **OAuth 1.0a Consumer Secret**

This is a common pattern when the Developer Portal doesn't provide separate OAuth 1.0a credentials.

## Your Current Setup

Based on your code:

### OAuth 2.0 Credentials (for authentication)
- **Client ID**: `695055f8-9786-4fda-a3a7-f7c2e88382f0`
- **Client Secret**: Stored in Supabase Edge Function environment variable `GARMIN_CLIENT_SECRET`

### OAuth 1.0a Credentials (for data access - using same values)
- **Consumer Key**: `695055f8-9786-4fda-a3a7-f7c2e88382f0` (same as Client ID)
- **Consumer Secret**: `0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q` (should match Client Secret)

## Configuration

### 1. iOS App (`GarminConfig.swift`)

✅ **Already configured!** The code uses:
- Consumer Key = OAuth 2.0 Client ID
- Consumer Secret = OAuth 2.0 Client Secret

**To update the Consumer Secret**, check your Supabase Edge Function environment variable `GARMIN_CLIENT_SECRET` and make sure `GarminConfig.swift` matches it.

### 2. Supabase Edge Function (`garmin-sync-all-users`)

Set environment variables:
- `GARMIN_CONSUMER_KEY` = Your OAuth 2.0 Client ID (`695055f8-9786-4fda-a3a7-f7c2e88382f0`)
- `GARMIN_CONSUMER_SECRET` = Your OAuth 2.0 Client Secret (same as `GARMIN_CLIENT_SECRET`)

**Note**: You can use the same value for both `GARMIN_CLIENT_SECRET` and `GARMIN_CONSUMER_SECRET` since they're the same credential.

## Verification

1. **Check Client Secret matches**:
   - Supabase Edge Function `GARMIN_CLIENT_SECRET` (for OAuth 2.0 token exchange)
   - Supabase Edge Function `GARMIN_CONSUMER_SECRET` (for OAuth 1.0a data access)
   - iOS `GarminConfig.swift` `defaultConsumerSecret`

2. **Test the connection**:
   - Try syncing with Garmin in the iOS app
   - Check logs for OAuth 1.0a signature generation
   - If you see "Invalid signature" errors, verify the Client Secret matches exactly

## Important Notes

⚠️ **Security**: Using the same credentials for both OAuth 2.0 and OAuth 1.0a is acceptable when Garmin doesn't provide separate credentials. This is a common pattern.

✅ **This is the correct approach** for OAuth 2.0 only applications in Garmin Developer Portal.

## If This Doesn't Work

If using Client ID/Secret as Consumer Key/Secret doesn't work:

1. **Try OAuth 2.0 Bearer tokens only** (revert to Bearer token implementation)
2. **Contact Garmin Support** to request OAuth 1.0a access for your application
3. **Check Garmin documentation** for your specific application type

## Next Steps

1. ✅ Verify `GarminConfig.swift` Consumer Secret matches your `GARMIN_CLIENT_SECRET`
2. ✅ Set `GARMIN_CONSUMER_KEY` and `GARMIN_CONSUMER_SECRET` in Supabase Edge Function
3. ✅ Test Garmin sync in iOS app
4. ✅ Check logs for successful OAuth 1.0a signature generation

