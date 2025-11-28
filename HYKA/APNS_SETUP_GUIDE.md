# APNs Setup Guide for HYKA

This guide explains how to get your Apple Push Notification Service (APNs) credentials and configure them in Supabase.

## Step 1: Get Your APNs Authentication Key

1. Go to [Apple Developer Account → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/authkeys/list)
2. Click the **"+"** button to create a new key
3. Enter a **Key Name** (e.g., "HYKA APNs Key")
4. Check the box for **"Apple Push Notifications service (APNs)"**
5. Click **"Continue"** then **"Register"**
6. **Download the .p8 key file** - ⚠️ **IMPORTANT: You can only download this once!** Save it securely.
7. **Note the Key ID** shown on the page (e.g., "ABC123DEF4")

## Step 2: Get Your Team ID

1. Go to [Apple Developer Account](https://developer.apple.com/account)
2. Your **Team ID** is shown in the top right corner (e.g., "ABC123DEF4")
3. Copy this value

## Step 3: Get Your Bundle ID

1. Open your Xcode project
2. Select your app target → **General** tab
3. The **Bundle Identifier** is shown (e.g., "com.hyka.app")
4. Copy this value

## Step 4: Prepare Your APNs Key for Supabase

You need to base64-encode your .p8 key file content:

### On macOS/Linux:
```bash
# Base64-encode the entire .p8 file (including BEGIN/END markers)
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

### On Windows (PowerShell):
```powershell
# Base64-encode the entire .p8 file
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))
```

This will output a long base64 string. Copy this entire string.

## Step 5: Configure in Supabase

1. Go to your **Supabase Dashboard**
2. Navigate to **Project Settings** → **Edge Functions** → **Secrets**
3. Add the following secrets:

| Secret Name | Value | Example |
|------------|-------|---------|
| `APNS_KEY_ID` | The Key ID from Step 1 | `ABC123DEF4` |
| `APNS_TEAM_ID` | Your Team ID from Step 2 | `XYZ987ABC6` |
| `APNS_BUNDLE_ID` | Your app's bundle identifier | `com.hyka.app` |
| `APNS_KEY_CONTENT` | The base64-encoded .p8 file content | `LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...` |
| `APNS_ENVIRONMENT` | `development` or `production` | `development` (for testing) or `production` (for App Store) |

## Step 6: Test Your Setup

After deploying the edge function, test it by:

1. Triggering a Garmin activity sync
2. Check the edge function logs in Supabase Dashboard
3. Verify that notifications are received on your iOS device

## Troubleshooting

### "APNs credentials not configured"
- Make sure all 5 secrets are set in Supabase
- Check that secret names match exactly (case-sensitive)

### "Invalid APNs key format"
- Make sure you base64-encoded the **entire** .p8 file content
- The key should include the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` markers

### "APNs error: 403"
- Check that your Key ID and Team ID are correct
- Verify the bundle ID matches your app's bundle identifier
- Make sure you're using the correct environment (development vs production)

### "APNs error: 400"
- Check that device tokens are valid
- Verify the notification payload structure

## Environment Notes

- **Development**: Use `APNS_ENVIRONMENT=development` for testing with development builds
- **Production**: Use `APNS_ENVIRONMENT=production` for App Store builds and TestFlight

The development and production environments use different APNs endpoints and require different device tokens.

## Security Best Practices

1. **Never commit** your .p8 key file to version control
2. **Store secrets** only in Supabase's secret management (not in code)
3. **Rotate keys** periodically for security
4. **Use different keys** for development and production if possible

