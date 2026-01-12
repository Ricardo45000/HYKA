# How to Find Your APNs Key

## Step 1: Check What You Currently Have in Supabase

First, let's see what APNs secrets are already configured:

```bash
cd supabase
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
```

This will show:
- `APNS_KEY_ID` - Your key ID
- `APNS_TEAM_ID` - Your Apple Team ID
- `APNS_KEY_CONTENT` - (hidden, but shows if it's set)
- `APNS_BUNDLE_ID` - Your app bundle ID
- `APNS_ENVIRONMENT` - Current environment setting

## Step 2: Find Your APNs Key in Apple Developer Portal

### Option A: If You Already Have a Key

1. **Go to Apple Developer Portal:**
   - Visit: https://developer.apple.com/account/resources/authkeys/list
   - Sign in with your Apple Developer account

2. **Find Your Key:**
   - Look for keys with "Apple Push Notifications service (APNs)" enabled
   - Note the **Key ID** (e.g., `ABC123XYZ`)
   - Note the **Team ID** (shown at top of page, e.g., `DEF456UVW`)

3. **Check Key Type:**
   - Keys can be used for both development and production
   - The environment is determined by the `APNS_ENVIRONMENT` setting, not the key itself

### Option B: If You Need to Create a New Key

1. **Go to Apple Developer Portal:**
   - Visit: https://developer.apple.com/account/resources/authkeys/list
   - Click the **+** button (top right)

2. **Create the Key:**
   - **Key Name:** Enter a name (e.g., "HYKA APNs Key")
   - **Enable:** Check **Apple Push Notifications service (APNs)**
   - Click **Continue** → **Register**

3. **Download the Key:**
   - **⚠️ IMPORTANT:** You can only download the key **once**
   - Click **Download** to get the `.p8` file
   - Save it securely (e.g., `AuthKey_ABC123XYZ.p8`)
   - Note the **Key ID** shown on the page

4. **Get Your Team ID:**
   - Look at the top right of the page
   - Your Team ID is shown there (e.g., `DEF456UVW`)

## Step 3: Get the Key Content

The key content is the contents of the `.p8` file:

```bash
# On Mac/Linux
cat /path/to/AuthKey_ABC123XYZ.p8

# Or open the file and copy its contents
# It should look like:
# -----BEGIN PRIVATE KEY-----
# MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
# ...
# -----END PRIVATE KEY-----
```

## Step 4: Set All APNs Secrets in Supabase

Once you have all the information:

```bash
cd supabase

# Set Key ID (from Apple Developer Portal)
npx supabase secrets set APNS_KEY_ID=YOUR_KEY_ID --project-ref gvfhtiljkybbrbxoyqsq

# Set Team ID (from Apple Developer Portal, top right of page)
npx supabase secrets set APNS_TEAM_ID=YOUR_TEAM_ID --project-ref gvfhtiljkybbrbxoyqsq

# Set Key Content (from the .p8 file)
npx supabase secrets set APNS_KEY_CONTENT="$(cat /path/to/AuthKey_ABC123XYZ.p8)" --project-ref gvfhtiljkybbrbxoyqsq

# Set Bundle ID (your app's bundle ID)
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq

# Set Environment (development for testing, production for release)
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
# OR for production:
# npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
```

## Step 5: Verify Everything is Set

```bash
cd supabase
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
```

You should see all 5 secrets listed.

## Quick Reference

### Where to Find Each Value:

1. **APNS_KEY_ID:**
   - Apple Developer Portal → Keys → Your APNs Key → Key ID

2. **APNS_TEAM_ID:**
   - Apple Developer Portal → Top right corner of any page
   - Or: Xcode → Preferences → Accounts → Your Team → Team ID

3. **APNS_KEY_CONTENT:**
   - Contents of the `.p8` file you downloaded
   - Full file including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`

4. **APNS_BUNDLE_ID:**
   - Your app's bundle ID: `app.hyka.com`
   - Or check in Xcode → Your Target → General → Bundle Identifier

5. **APNS_ENVIRONMENT:**
   - `development` for debug builds/testing
   - `production` for TestFlight/App Store

## If You Lost Your Key

If you lost the `.p8` file:
1. You **cannot** download it again
2. You need to create a **new key** in Apple Developer Portal
3. Delete the old key (optional, but recommended for security)
4. Set the new key in Supabase

## Troubleshooting

### "Key not found"
- Make sure you're signed in to the correct Apple Developer account
- Check that you have the right permissions

### "Key already exists"
- You might already have a key set up
- Check the list of keys in Apple Developer Portal
- Use the existing key's Key ID

### "Invalid key format"
- Make sure you're copying the **entire** `.p8` file content
- Include the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines
- No extra spaces or newlines


