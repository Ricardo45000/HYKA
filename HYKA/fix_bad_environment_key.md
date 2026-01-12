# Fixing "BadEnvironmentKeyInToken" Error

## The Problem

`BadEnvironmentKeyInToken` means your APNs key type doesn't match the environment you're using:
- **Development key** → Must use `APNS_ENVIRONMENT=development` (sandbox)
- **Production key** → Must use `APNS_ENVIRONMENT=production`

## Solution

### Step 1: Determine Your Key Type

APNs keys can be either:
1. **Development/Sandbox Key** - For debug builds, development testing
2. **Production Key** - For TestFlight, App Store, production builds

**How to check:**
- Go to **Apple Developer Portal** → **Certificates, Identifiers & Profiles** → **Keys**
- Find your APNs key
- Check if it says "Development" or "Production" (or both)

**Note:** Some keys support both, but the environment setting must still match.

### Step 2: Set Correct Environment

**If you have a DEVELOPMENT key:**
```bash
cd supabase
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
```

**If you have a PRODUCTION key:**
```bash
cd supabase
npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
```

### Step 3: Verify Current Setting

```bash
cd supabase
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS_ENVIRONMENT
```

If nothing is set, it defaults to `production`.

## Most Common Scenarios

### Scenario 1: Testing with Debug Build
- **Key type:** Development/Sandbox
- **Set:** `APNS_ENVIRONMENT=development`

### Scenario 2: Testing with TestFlight/App Store
- **Key type:** Production
- **Set:** `APNS_ENVIRONMENT=production`

### Scenario 3: Key Supports Both
- Try `development` first for testing
- Use `production` for release

## If You Need a Different Key Type

### Create a New APNs Key:

1. Go to **Apple Developer Portal** → **Certificates, Identifiers & Profiles** → **Keys**
2. Click **+** to create a new key
3. Name it (e.g., "HYKA APNs Production Key")
4. Check **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. **Download the key** (`.p8` file) - you can only download it once!
7. Note the **Key ID** (shown on the key page)

### Update Supabase Secrets:

```bash
cd supabase

# Set the key content (replace with path to your .p8 file)
npx supabase secrets set APNS_KEY_CONTENT="$(cat /path/to/AuthKey_XXXXX.p8)" --project-ref gvfhtiljkybbrbxoyqsq

# Set the key ID (from Apple Developer Portal)
npx supabase secrets set APNS_KEY_ID=YOUR_KEY_ID --project-ref gvfhtiljkybbrbxoyqsq

# Set the team ID (from Apple Developer Portal)
npx supabase secrets set APNS_TEAM_ID=YOUR_TEAM_ID --project-ref gvfhtiljkybbrbxoyqsq

# Set the environment to match your key
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
# OR
npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
```

## Quick Fix (Try This First)

For development/testing, try:

```bash
cd supabase
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
```

Then test the notification again. If it still fails, you likely need a development key, or your current key is production-only.

## Verify All Secrets Are Set

```bash
cd supabase
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
```

You should see:
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_KEY_CONTENT`
- `APNS_BUNDLE_ID` (optional)
- `APNS_ENVIRONMENT` (should match your key type)

## After Fixing

1. **Test notification again** using Supabase Dashboard
2. **Check logs** - should see `✅ Push notification sent to device` instead of the error
3. **If still failing**, check logs for the new error message (will be more specific)


