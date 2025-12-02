# Strava Redirect URI Debugging Steps

## Current Error
```
{"message":"Bad Request","errors":[{"resource":"Application","field":"redirect_uri","code":"invalid"}]}
```

## Step 1: Check What's Being Sent

When you try to connect Strava, check the Xcode console. You should see:
```
🔄 Strava OAuth 2.0 Flow
   Client ID: 184009
   Redirect URI: com.hyka.app://
   Full query string: client_id=184009&redirect_uri=com.hyka.app%3A%2F%2F&...
   redirect_uri in query: redirect_uri=com.hyka.app%3A%2F%2F
```

**Copy the exact `redirect_uri` value from the console** - this shows what Strava is receiving.

## Step 2: Verify Strava Settings

1. Go to https://www.strava.com/settings/api
2. Click "Edit Application"
3. Check the **Authorization Callback Domain** field
4. Take a screenshot or note the exact value

## Step 3: Try These Solutions

### Solution A: Match Exactly (No ://)
If the console shows `redirect_uri=com.hyka.app%3A%2F%2F` (encoded `://`):

1. Update `ios/Config/Config.swift`:
   ```swift
   static let stravaRedirectURI = "com.hyka.app"
   ```

2. In Strava, set Authorization Callback Domain to: `com.hyka.app`

3. Rebuild and test

### Solution B: Use Web Redirect (Most Reliable)
If custom URL schemes don't work:

1. Update `ios/Config/Config.swift`:
   ```swift
   static let stravaRedirectURI = "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback"
   ```

2. In Strava, set Authorization Callback Domain to: `gvfhtiljkybbrbxoyqsq.supabase.co`

3. The edge function will redirect to the app after receiving the code

4. Rebuild and test

### Solution C: Check for Typos
- Make sure there are no extra spaces in Strava's Authorization Callback Domain
- Make sure you clicked "Save" after making changes
- Wait 2-3 minutes for changes to propagate

## Step 4: Test and Report

After trying a solution:
1. Check the console logs for the exact redirect_uri being sent
2. Note what error you get (if any)
3. Share:
   - The console log showing the redirect_uri
   - What you set in Strava's Authorization Callback Domain
   - The exact error message (if any)

## Most Likely Issue

Based on the error pattern, Strava might not support custom URL schemes with reverse domain notation (`com.hyka.app`). 

**Recommended**: Try **Solution B (Web Redirect)** - this is the most reliable approach and works with all OAuth providers.

