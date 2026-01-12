# Fixing BadDeviceToken with Correct Environment

## The Problem

You're getting `BadDeviceToken` even though:
- ✅ APNs environment: `development` (correct)
- ✅ APNs URL: `https://api.sandbox.push.apple.com` (correct)
- ✅ Bundle ID: `com.hyka.HYKA` (matches)
- ✅ Token length: 64 characters (correct format)

**But:** The device token was likely registered when your app was in **production mode**, so it's a **production token** that won't work with the **sandbox environment**.

## Solution: Re-register Device Token

Device tokens are **environment-specific**:
- **Production tokens** → Only work with `APNS_ENVIRONMENT=production`
- **Sandbox tokens** → Only work with `APNS_ENVIRONMENT=development`

### Option 1: Re-register Token (Recommended for Testing)

1. **Delete the old token from database:**
   ```sql
   DELETE FROM user_devices 
   WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
   AND device_token = '1ee8c1007a5cfdfcb623a4e65fb8dd2ba7c03e100f800e31a9f99ea607468310';
   ```

2. **Open the app on your device** (in debug/development mode)
   - The app will automatically register a new **sandbox token**
   - This token will work with `APNS_ENVIRONMENT=development`

3. **Verify new token:**
   ```sql
   SELECT device_token, device_type, push_enabled, created_at
   FROM user_devices 
   WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';
   ```

4. **Test notification again**

### Option 2: Use Production Environment

If you want to keep the existing token:

1. **Switch to production:**
   ```bash
   cd supabase
   npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
   ```

2. **Make sure you have a production APNs key** (not just sandbox)

3. **Test notification again**

## How Device Tokens Work

- **Debug builds** → Generate **sandbox tokens** → Need `development` environment
- **TestFlight/App Store builds** → Generate **production tokens** → Need `production` environment

## Quick Fix Script

```bash
# Option 1: Delete token and re-register (for development testing)
# Run this SQL in Supabase SQL Editor:
DELETE FROM user_devices 
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';

# Then open the app to register a new sandbox token

# Option 2: Switch to production (if using TestFlight/App Store)
cd supabase
npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
```

## Verify Token Type

After re-registering, check the new token:
```sql
SELECT 
  device_token,
  device_type,
  push_enabled,
  created_at
FROM user_devices 
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
ORDER BY created_at DESC;
```

The new token should work with the `development` environment.

## Troubleshooting

### Still getting BadDeviceToken after re-registering?

1. **Check app build type:**
   - Debug build → Should generate sandbox token
   - Release/TestFlight → Generates production token

2. **Verify environment matches build:**
   - Debug build + `development` environment ✅
   - TestFlight build + `production` environment ✅

3. **Check if token is actually being registered:**
   - Look for new entries in `user_devices` table
   - Verify `push_enabled = true`

4. **Try both environments:**
   - If `development` doesn't work, try `production`
   - If `production` doesn't work, try `development`


