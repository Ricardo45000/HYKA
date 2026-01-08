# TestFlight Redeploy Guide After Bundle ID Change

## ⚠️ Important: Bundle ID Change = New App (Potentially)

When you change the bundle ID from `com.hyka.app` to `app.hyka.com`, Apple treats this as a **different app**. Here's what you need to know:

---

## Scenario 1: App Not Yet Published to App Store

**If your app is only in TestFlight and hasn't been published to the App Store:**

### Option A: Create New App in App Store Connect (Recommended)

1. **Create a new app in App Store Connect:**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Click **My Apps** → **+** → **New App**
   - **Bundle ID:** Select `app.hyka.com` (must be registered first in Apple Developer Portal)
   - **App Name:** HYKA (or your preferred name)
   - **Primary Language:** Your language
   - **SKU:** Unique identifier (e.g., `hyka-app-2025`)

2. **Build and upload:**
   - Build your app in Xcode with bundle ID `app.hyka.com`
   - Archive and upload to App Store Connect
   - Submit to TestFlight for the new app

3. **Update TestFlight testers:**
   - Add testers to the new app
   - They'll need to install the new app (old one won't update)

### Option B: Keep Old App, Create New One

- Keep `com.hyka.app` for existing testers
- Create `app.hyka.com` as a new app
- Gradually migrate testers

---

## Scenario 2: App Already Published to App Store

**If your app is already live on the App Store:**

⚠️ **You CANNOT change the bundle ID of a published app.**

You have two options:

### Option A: Create New App (Recommended for Organizational Account)

1. Create a new app with `app.hyka.com` bundle ID
2. Publish as a new app
3. Eventually deprecate the old app
4. Users will need to download the new app

### Option B: Keep Using Old Bundle ID

1. Keep `com.hyka.app` for the published app
2. Only use `app.hyka.com` for internal/development builds
3. Not ideal if you need the organizational account features

---

## What You Need Before Redeploying

### 1. ✅ Register Bundle ID in Apple Developer Portal

**Critical:** The bundle ID must be registered before you can use it in App Store Connect.

1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **+** → **App IDs** → **App**
3. **Bundle ID:** `app.hyka.com`
4. **Enable capabilities:**
   - ✅ Push Notifications
   - ✅ Any other capabilities your app uses
5. Click **Continue** → **Register**

### 2. ✅ Update Xcode Project

1. Open Xcode
2. Select project → Target → **Signing & Capabilities**
3. **Bundle Identifier:** `app.hyka.com`
4. **Team:** Select your organizational team
5. Xcode will create/update provisioning profile

### 3. ✅ Verify Build Settings

1. **Product** → **Scheme** → **Edit Scheme**
2. Ensure **Build Configuration** is set correctly (Debug/Release)
3. **Product** → **Clean Build Folder** (Shift+Cmd+K)
4. **Product** → **Build** (Cmd+B) - verify no errors

### 4. ✅ Update Supabase Secrets

```bash
cd supabase
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

### 5. ✅ Delete Old Device Tokens

```sql
-- In Supabase SQL Editor
DELETE FROM user_devices;
```

Users will re-register tokens when they install the new app.

---

## Step-by-Step Redeploy Process

### Step 1: Archive the App

1. In Xcode, select **Any iOS Device** (not a simulator)
2. **Product** → **Archive**
3. Wait for archive to complete

### Step 2: Upload to App Store Connect

1. In Organizer window, select your archive
2. Click **Distribute App**
3. Choose **App Store Connect**
4. Click **Next**
5. Choose **Upload**
6. Click **Next**
7. Select your distribution options
8. Click **Upload**

### Step 3: Create/Select App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. If creating new app:
   - Click **My Apps** → **+** → **New App**
   - Select bundle ID `app.hyka.com`
   - Fill in app information
3. If using existing app (and bundle ID matches):
   - Select your app
   - The new build will appear in TestFlight

### Step 4: Submit to TestFlight

1. Go to **TestFlight** tab
2. Select your build
3. Add testers or test groups
4. Submit for review (if needed)

---

## Important Considerations

### ⚠️ Users Will Need to Reinstall

- **Old app** (`com.hyka.app`) and **new app** (`app.hyka.com`) are separate apps
- Users will need to **uninstall the old app** and **install the new one**
- Data won't transfer automatically (unless you implement data migration)

### ⚠️ TestFlight Build Numbers

- Build numbers are per app
- Your new app starts at build 1
- Old app's build numbers don't carry over

### ⚠️ App Store Reviews

- If creating a new app, it needs a new App Store review
- TestFlight builds also need review (usually faster)

### ⚠️ App Store Listing

- If creating a new app, you'll need to create a new App Store listing
- Screenshots, descriptions, etc. need to be re-uploaded

---

## Migration Strategy for Existing Users

If you have existing TestFlight users:

1. **Communicate the change:**
   - Send email/notification about the bundle ID change
   - Explain they need to install the new app
   - Provide clear instructions

2. **Data migration (if needed):**
   - If users have local data, consider implementing export/import
   - Or use iCloud/cloud sync to preserve data

3. **Timeline:**
   - Upload new build
   - Wait for TestFlight processing (usually 10-30 minutes)
   - Notify testers
   - Give them time to migrate

---

## Checklist Before Redeploying

- [ ] Bundle ID `app.hyka.com` registered in Apple Developer Portal
- [ ] Push Notifications capability enabled for bundle ID
- [ ] Xcode Bundle Identifier set to `app.hyka.com`
- [ ] Xcode Team set to organizational team
- [ ] Project builds successfully (no errors)
- [ ] Supabase `APNS_BUNDLE_ID` secret updated
- [ ] Old device tokens deleted (or will be when users install new app)
- [ ] App Store Connect app created (if new app)
- [ ] TestFlight testers notified (if applicable)
- [ ] Archive created successfully
- [ ] Build uploaded to App Store Connect

---

## Quick Answer

**Yes, you should redeploy to TestFlight**, but:

1. **If app is not published:** Create a new app in App Store Connect with `app.hyka.com`
2. **If app is published:** You'll need to create a new app (can't change bundle ID of published app)
3. **Users will need to reinstall** - old and new apps are separate
4. **Make sure bundle ID is registered** in Apple Developer Portal first

---

## Need Help?

If you're unsure:
1. Check if your app is published: Go to App Store Connect → My Apps
2. If published → Create new app
3. If not published → You can create new app or update existing (if bundle ID not yet set)

The key is: **Bundle ID change = potentially new app from Apple's perspective.**
