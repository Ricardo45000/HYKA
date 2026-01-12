# Quick Fix for APNs Environment Error

## The Problem

Your logs show:
- ❌ `BadEnvironmentKeyInToken` error
- Current environment: `production`
- Your APNs key is a **Development/Sandbox** key

## The Fix

Run these commands:

```bash
cd supabase

# Set environment to development (for sandbox key)
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq

# Also fix the bundle ID (should be app.hyka.com)
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

## Or Use the Script

```bash
chmod +x fix_apns_environment.sh
./fix_apns_environment.sh
```

## After Fixing

1. **Test notification again** using Supabase Dashboard
2. **Check logs** - should see `✅ Push notification sent to device`
3. **If still errors**, check logs for new error messages

## Why This Happens

- **Development/Sandbox keys** → Must use `APNS_ENVIRONMENT=development`
- **Production keys** → Must use `APNS_ENVIRONMENT=production`

Your key is development, but environment was set to production, causing the mismatch.


