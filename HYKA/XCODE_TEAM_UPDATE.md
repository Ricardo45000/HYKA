# Updating Xcode Team Settings for Organizational Account

## Quick Steps

### 1. Open Your Project in Xcode

```bash
# Navigate to your project directory
cd "/Volumes/Rissie T7/Ricardo/Project/HYKA_V1_Starter/HYKA/HYKA"

# Open in Xcode (if you have an .xcodeproj or .xcworkspace file)
open *.xcodeproj
# OR
open *.xcworkspace
```

### 2. Update Team Setting

1. **Select your project** in the Project Navigator (top item, blue icon)
2. **Select your target** (HYKA) in the main editor area
3. Click on the **"Signing & Capabilities"** tab
4. Under **"Team"**, click the dropdown
5. **Select your organizational team** from the list
   - If you don't see it, click "Add Account..." and sign in with your organizational Apple ID
6. Xcode will automatically:
   - Update the Team ID
   - Create/update the provisioning profile
   - Update code signing settings

### 3. Verify Bundle Identifier

In the same **"Signing & Capabilities"** tab:
- **Bundle Identifier** should be: `app.hyka.com`
- If it's different, click on it and change it to `app.hyka.com`

### 4. Check for Errors

Look for any red error messages in the Signing & Capabilities section:
- **"No profiles for 'app.hyka.com' were found"**
  - Click "Download Manual Profiles" or create one in Apple Developer Portal
- **"Your account already has a valid certificate"**
  - This is fine, Xcode will use it
- **"App ID is not available"**
  - You need to register the Bundle ID in Apple Developer Portal first

### 5. Clean and Rebuild

1. **Clean Build Folder:**
   - Menu: **Product** → **Clean Build Folder**
   - Or press: **Shift + Cmd + K**

2. **Build:**
   - Menu: **Product** → **Build**
   - Or press: **Cmd + B**

3. **Verify no errors** appear in the Issue Navigator (left sidebar)

### 6. Verify Team ID Changed

To confirm the Team ID was updated:

1. In Xcode, go to **Preferences** → **Accounts**
2. Select your organizational team
3. Note the **Team ID** shown
4. This should match the Team ID you set in Supabase secrets

---

## Troubleshooting

### Issue: "No accounts with Apple ID found"

**Solution:**
1. Xcode → Preferences → Accounts
2. Click **+** → **Apple ID**
3. Sign in with your organizational Apple ID
4. Go back to Signing & Capabilities and select the team

### Issue: "Bundle ID not available"

**Solution:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Click **+** to create new App ID
3. Bundle ID: `app.hyka.com`
4. Enable **Push Notifications**
5. Click **Continue** → **Register**
6. Go back to Xcode and try again

### Issue: "Provisioning profile not found"

**Solution:**
1. In Xcode Signing & Capabilities tab
2. Click **"Download Manual Profiles"**
3. Or go to [Profiles](https://developer.apple.com/account/resources/profiles/list) and create one manually

### Issue: Code signing errors persist

**Solution:**
1. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
2. Clean build folder in Xcode (Shift+Cmd+K)
3. Quit and restart Xcode
4. Try building again

---

## What Gets Updated Automatically

When you change the Team in Xcode, it automatically updates:
- ✅ **DEVELOPMENT_TEAM** build setting
- ✅ Code signing identity
- ✅ Provisioning profile (creates/updates automatically)
- ✅ Team ID in project.pbxproj

You don't need to manually edit these files - Xcode handles it.

---

## Verification Checklist

After updating:
- [ ] Team dropdown shows your organizational team
- [ ] Bundle Identifier is `app.hyka.com`
- [ ] No red errors in Signing & Capabilities
- [ ] Project builds successfully (Cmd+B)
- [ ] Team ID in Xcode Preferences matches Supabase `APNS_TEAM_ID`
