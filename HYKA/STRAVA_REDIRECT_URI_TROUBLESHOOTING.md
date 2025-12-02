# Strava Redirect URI Troubleshooting

## Current Error
```
{"message":"Bad Request","errors":[{"resource":"Application","field":"redirect_uri","code":"invalid"}]}
```

## Quick Fix Steps

### Step 1: Verify Strava Configuration
1. Go to https://www.strava.com/settings/api
2. Find your application (Client ID: 184009)
3. Check the **Authorization Callback Domain** field
4. It should be exactly: `com.hyka.app` (no `://`, no paths, no protocols)
5. Click **Update** to save if you made changes

### Step 2: Check What the App is Sending
When you try to connect Strava, check the Xcode console logs. You should see:
```
🔄 Strava OAuth 2.0 Flow
   Client ID: 184009
   Redirect URI: com.hyka.app://
   Redirect URI (encoded): com.hyka.app%3A%2F%2F
   Full auth URL: https://www.strava.com/oauth/authorize?client_id=184009&redirect_uri=com.hyka.app%3A%2F%2F&...
```

### Step 3: Try Alternative Configuration

If the error persists, try this alternative:

**Option A: Without `://` (Current - Recommended)**
- Authorization Callback Domain: `com.hyka.app`
- Redirect URI in code: `com.hyka.app://`
- **Status**: Currently configured

**Option B: Without `://` (Alternative)**
If Option A doesn't work:

1. Update `ios/Config/Config.swift`:
   ```swift
   static let stravaRedirectURI = "com.hyka.app"
   ```

2. Update Strava Authorization Callback Domain to: `com.hyka.app` (same as before)

3. Rebuild the app and try again

**Option C: With Path (If needed)**
If both above fail:

1. Update `ios/Config/Config.swift`:
   ```swift
   static let stravaRedirectURI = "com.hyka.app://callback"
   ```

2. Update Strava Authorization Callback Domain to: `com.hyka.app`

3. Rebuild the app and try again

## Common Issues

### Issue 1: Authorization Callback Domain Not Set
- **Symptom**: "invalid redirect_uri" error
- **Fix**: Make sure the Authorization Callback Domain field in Strava is set to `com.hyka.app`

### Issue 2: URL Encoding Problems
- **Symptom**: Redirect URI doesn't match
- **Fix**: The code automatically URL-encodes the redirect_uri. Check console logs to see the encoded value.

### Issue 3: Cached Configuration
- **Symptom**: Changes in Strava don't take effect
- **Fix**: 
  1. Save changes in Strava Developer Portal
  2. Wait 1-2 minutes for changes to propagate
  3. Try again

## Verification Checklist

- [ ] Authorization Callback Domain in Strava is set to: `com.hyka.app`
- [ ] No extra spaces, slashes, or protocols in the domain field
- [ ] Changes saved in Strava Developer Portal
- [ ] App is using the correct redirect URI (check console logs)
- [ ] URL scheme `com.hyka.app` is registered in Info.plist (already done)
- [ ] Rebuilt the app after any code changes

## Testing

1. Open the app
2. Go to Profile → Connexion with your wearable
3. Tap "Strava"
4. Check Xcode console for the exact redirect_uri being sent
5. Compare with what's configured in Strava

## Still Not Working?

If none of the above work, please provide:
1. The exact redirect_uri from the console logs
2. A screenshot of your Strava API settings showing the Authorization Callback Domain
3. The full error message from Strava

This will help identify if there's a specific format requirement we're missing.

