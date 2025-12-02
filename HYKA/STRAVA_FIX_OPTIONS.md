# Strava Redirect URI Fix - Multiple Options to Try

## Current Issue
Strava is rejecting the redirect_uri with error: `{"message":"Bad Request","errors":[{"resource":"Application","field":"redirect_uri","code":"invalid"}]}`

## Your Current Strava Configuration
- **Authorization Callback Domain**: `com.hyka.app` ✅ (This is correct)

## Try These Solutions in Order

### Option 1: Use Full URL Scheme (Current)
**In `ios/Config/Config.swift`:**
```swift
static let stravaRedirectURI = "com.hyka.app://"
```

**In Strava:**
- Authorization Callback Domain: `com.hyka.app`

**Status**: Currently configured - if this doesn't work, try Option 2

---

### Option 2: Use Domain Only (No ://)
**In `ios/Config/Config.swift`:**
```swift
static let stravaRedirectURI = "com.hyka.app"
```

**In Strava:**
- Authorization Callback Domain: `com.hyka.app`

**Note**: This might work if Strava does strict matching. However, iOS might not handle the callback properly.

---

### Option 3: Use Web Format with Edge Function Redirect
**In `ios/Config/Config.swift`:**
```swift
static let stravaRedirectURI = "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback/redirect"
```

**In Strava:**
- Authorization Callback Domain: `gvfhtiljkybbrbxoyqsq.supabase.co`

**Implementation**: Create a redirect endpoint in the edge function that redirects to `com.hyka.app://?code=xxx`

**Pros**: More reliable, works with most OAuth providers
**Cons**: Requires additional edge function endpoint

---

### Option 4: Use Simpler URL Scheme
**In `ios/Config/Config.swift`:**
```swift
static let stravaRedirectURI = "hyka://"
```

**In Strava:**
- Authorization Callback Domain: `hyka`

**In `Info.plist`**: Already has `hyka` registered ✅

**Pros**: Simpler, no dots that might confuse validation
**Cons**: Less standard than reverse domain format

---

## Recommended Next Steps

1. **First, check the console logs** when you try to connect:
   - Look for: `Redirect URI (original):` and `Redirect URI (for Strava):`
   - This shows exactly what's being sent to Strava

2. **Try Option 4 (Simpler scheme)** - This is most likely to work:
   - Update `Config.swift` to use `hyka://`
   - Update Strava Authorization Callback Domain to: `hyka`
   - Rebuild and test

3. **If Option 4 works**, you can keep it or migrate back to `com.hyka.app` later

4. **If none work**, we may need to implement Option 3 (web redirect)

## Debugging

When testing, check Xcode console for:
```
🔄 Strava OAuth 2.0 Flow
   Client ID: 184009
   Redirect URI (original): com.hyka.app://
   Redirect URI (encoded): com.hyka.app%3A%2F%2F
   Redirect URI (for Strava): com.hyka.app%3A%2F%2F
   Full auth URL: https://www.strava.com/oauth/authorize?client_id=184009&redirect_uri=...
```

This will show exactly what Strava is receiving.

