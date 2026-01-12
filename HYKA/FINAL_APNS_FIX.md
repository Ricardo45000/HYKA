# Final APNs Fix - Key Type Mismatch

## Current Situation

You have:
- ❌ **Development/Sandbox APNs key** (from Apple Developer Portal)
- ❌ **Production environment** (`APNS_ENVIRONMENT=production`)
- ✅ **Production device token** (from TestFlight/App Store build)

**Result:** `BadEnvironmentKeyInToken` error because key type doesn't match environment.

## Two Solutions

### Solution 1: Use Production Key (Recommended for Release)

If you're using TestFlight or App Store, you need a **production APNs key**:

1. **Create a Production APNs Key:**
   - Go to: https://developer.apple.com/account/resources/authkeys/list
   - Click **+** to create new key
   - Name: "HYKA APNs Production Key"
   - Enable: **Apple Push Notifications service (APNs)**
   - Click **Continue** → **Register**
   - **Download** the `.p8` file
   - Note the **Key ID**

2. **Update Supabase with Production Key:**
   ```bash
   cd supabase
   
   # Set new production key ID
   npx supabase secrets set APNS_KEY_ID=YOUR_PRODUCTION_KEY_ID --project-ref gvfhtiljkybbrbxoyqsq
   
   # Set production key content
   npx supabase secrets set APNS_KEY_CONTENT="$(cat /path/to/AuthKey_PRODUCTION.p8)" --project-ref gvfhtiljkybbrbxoyqsq
   
   # Keep production environment
   npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
   ```

3. **Test notification** - should work now!

### Solution 2: Use Development Environment (For Testing)

If you're just testing, use development environment:

1. **Set environment to development:**
   ```bash
   cd supabase
   npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
   ```

2. **Delete production device token:**
   ```sql
   DELETE FROM user_devices 
   WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';
   ```

3. **Open app in debug mode** (Xcode debug build)
   - App will register a new **sandbox token**

4. **Test notification** - should work with sandbox token

## Quick Decision Guide

**Use Solution 1 (Production) if:**
- ✅ You're using TestFlight or App Store
- ✅ You want to keep the existing production device token
- ✅ You can create a production APNs key

**Use Solution 2 (Development) if:**
- ✅ You're just testing/developing
- ✅ You're using Xcode debug builds
- ✅ You don't have a production key yet

## Most Likely: You Need a Production Key

Since you have a production device token, you probably need a **production APNs key** to match it.

**Quick check:** Do you have a production APNs key in Apple Developer Portal?
- If **YES** → Use Solution 1, update Supabase with production key
- If **NO** → Create one (Solution 1) or switch to development (Solution 2)

## After Fixing

1. **Verify configuration:**
   ```bash
   cd supabase
   npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
   ```

2. **Test notification** using Supabase Dashboard

3. **Check logs** - should see `✅ Push notification sent to device`


