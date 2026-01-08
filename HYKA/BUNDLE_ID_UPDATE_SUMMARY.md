# Bundle ID Update Summary: `com.hyka.app` → `app.hyka.com`

## ✅ Completed Updates

All references to the bundle ID have been updated from `com.hyka.app` to `app.hyka.com` across the entire codebase:

### Code Files Updated:
- ✅ `Info.plist` - URL schemes updated
- ✅ `supabase/functions/garmin-activity-notify/index.ts` - Default bundle ID
- ✅ `supabase/functions/strava-auth-callback/index.ts` - OAuth redirect URLs
- ✅ `supabase/functions/polar-auth-callback/index.ts` - OAuth redirect URLs
- ✅ `supabase/functions/suunto-auth-callback/index.ts` - OAuth redirect URLs
- ✅ `ios/Integrations/DeviceOAuthManager.swift` - OAuth callback schemes
- ✅ `ios/Auth/AuthView.swift` - URL scheme handling
- ✅ `ios/App/MainApp.swift` - URL scheme handling
- ✅ `ios/Auth/SessionManager.swift` - OAuth redirect URLs
- ✅ `ios/Config/Config.example.swift` - Garmin redirect URI

### Documentation & Scripts Updated:
- ✅ `ORGANIZATIONAL_ACCOUNT_MIGRATION.md`
- ✅ `XCODE_TEAM_UPDATE.md`
- ✅ `update_apns_organizational.sh`
- ✅ `verify_bundle_id.sh`
- ✅ `find_apns_key.md`
- ✅ `fix_bad_device_token.md`
- ✅ `check_notification_status.md`
- ✅ `send_notification_manual.md`
- ✅ `debug_notification.sh`
- ✅ `QUICK_FIX_APNS.md`

---

## 🔴 Critical Next Steps

### 1. Register Bundle ID in Apple Developer Portal

**IMPORTANT:** You must register `app.hyka.com` under your **organizational account**:

1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Sign in with your **organizational account**
3. Click **+** to create new App ID
4. **Bundle ID:** `app.hyka.com`
5. **Enable:** Push Notifications capability
6. Click **Continue** → **Register**

### 2. Update Supabase Secrets

Update the bundle ID in Supabase:

```bash
cd supabase
npx supabase login  # If not already logged in
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

Or use the verification script:
```bash
./verify_bundle_id.sh
```

### 3. Update Xcode Project Settings

1. Open your project in Xcode
2. Select project → Target → **Signing & Capabilities**
3. **Bundle Identifier:** Change to `app.hyka.com`
4. **Team:** Select your organizational team
5. Clean build folder (Shift+Cmd+K) and rebuild (Cmd+B)

### 4. Update OAuth Provider Settings

Update the callback URLs in your OAuth provider configurations:

- **Garmin:** Update redirect URI to `app.hyka.com://callback`
- **Strava:** Update Authorization Callback Domain to `app.hyka.com`
- **Polar:** Update redirect URI to `app.hyka.com://callback`
- **Suunto:** Update redirect URI to `app.hyka.com://callback`

### 5. Re-register Device Tokens

After changing the bundle ID, existing device tokens may need to be re-registered:

1. Build and run the app on your device
2. The app will automatically register a new device token with the new bundle ID
3. Old tokens with `com.hyka.app` will no longer work

---

## ⚠️ Important Notes

1. **Bundle ID Format:** `app.hyka.com` uses a reverse domain format (domain-style), which is valid for iOS bundle IDs.

2. **URL Scheme:** The URL scheme is now `app.hyka.com://` instead of `com.hyka.app://`

3. **OAuth Callbacks:** All OAuth providers must be updated with the new callback URL format.

4. **Device Tokens:** All existing device tokens registered with the old bundle ID will stop working. Users will need to re-register.

5. **TestFlight/App Store:** If you have existing builds, you'll need to create a new app entry with the new bundle ID, or update the existing one if possible.

---

## Verification Checklist

- [ ] Bundle ID `app.hyka.com` registered in Apple Developer Portal (organizational account)
- [ ] Push Notifications capability enabled for the bundle ID
- [ ] Supabase `APNS_BUNDLE_ID` secret updated to `app.hyka.com`
- [ ] Xcode Bundle Identifier set to `app.hyka.com`
- [ ] Xcode Team set to organizational team
- [ ] Project builds successfully in Xcode
- [ ] OAuth provider redirect URIs updated
- [ ] Device tokens re-registered after app update
- [ ] Push notifications tested and working

---

## Need Help?

If you encounter issues:

1. Check Supabase Edge Function logs for APNs errors
2. Verify bundle ID matches exactly in all locations
3. Ensure the bundle ID is registered under your organizational account
4. Make sure Push Notifications capability is enabled
5. Verify device tokens are registered with the new bundle ID
