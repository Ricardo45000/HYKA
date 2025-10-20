# How to Find Garmin Consumer Key & Consumer Secret

## Overview

The **Consumer Key** and **Consumer Secret** are OAuth 1.0a credentials required for secure data access to Garmin APIs. These are different from your OAuth 2.0 Client ID and Client Secret.

## Step-by-Step Instructions

### 1. Log in to Garmin Developer Portal

1. Go to [https://developerportal.garmin.com/](https://developerportal.garmin.com/)
2. Log in with your Garmin Developer account

### 2. Navigate to Your Application

1. Click on **"My Apps"** or **"Applications"** in the navigation menu
2. Select your application (the one you're using for HYKA)

### 3. Find OAuth 1.0a Credentials

The Consumer Key and Secret are typically found in one of these locations:

#### Option A: OAuth 1.0a Section
1. Look for a section labeled **"OAuth 1.0a"** or **"OAuth 1.0a Credentials"**
2. You should see:
   - **Consumer Key** (also called "OAuth Consumer Key" or "API Key")
   - **Consumer Secret** (also called "OAuth Consumer Secret" or "API Secret")

#### Option B: API Credentials Section
1. Look for **"API Credentials"** or **"Credentials"** tab/section
2. You may see separate sections for:
   - OAuth 2.0 (Client ID, Client Secret) - **NOT what you need**
   - OAuth 1.0a (Consumer Key, Consumer Secret) - **THIS is what you need**

#### Option C: Application Settings
1. Go to **"Settings"** or **"Application Settings"**
2. Look for **"OAuth Configuration"** or **"API Access"**
3. Find the OAuth 1.0a credentials section

### 4. Copy the Credentials

1. **Consumer Key**: Copy the entire key (usually a UUID format like `695055f8-9786-4fda-a3a7-f7c2e88382f0`)
2. **Consumer Secret**: Copy the entire secret (usually a longer string with special characters)

⚠️ **Important**: 
- Keep these credentials **secret** - never commit them to public repositories
- Copy them exactly as shown (no extra spaces or characters)
- The Consumer Secret may contain special characters like `/`, `+`, `=`

## Where to Use These Credentials

### 1. iOS App (`GarminConfig.swift`)

Update the hardcoded values in `ios/Integrations/GarminConfig.swift`:

```swift
private static let defaultConsumerKey = "YOUR_CONSUMER_KEY_HERE"
private static let defaultConsumerSecret = "YOUR_CONSUMER_SECRET_HERE"
```

**OR** add them to your `Info.plist`:

```xml
<key>GARMIN_CONSUMER_KEY</key>
<string>YOUR_CONSUMER_KEY_HERE</string>
<key>GARMIN_CONSUMER_SECRET</key>
<string>YOUR_CONSUMER_SECRET_HERE</string>
```

### 2. Supabase Edge Function (`garmin-sync-all-users`)

1. Go to Supabase Dashboard → **Edge Functions**
2. Select **`garmin-sync-all-users`**
3. Go to **Settings** → **Environment Variables**
4. Add:
   - **Name**: `GARMIN_CONSUMER_KEY`
     **Value**: `YOUR_CONSUMER_KEY_HERE`
   - **Name**: `GARMIN_CONSUMER_SECRET`
     **Value**: `YOUR_CONSUMER_SECRET_HERE`
5. Click **Save**

### 3. Supabase Edge Function (`garmin-webhook`) - If Updated

If you update `garmin-webhook` to use OAuth 1.0a, add the same environment variables there too.

## Verification

After setting the credentials:

1. **Test iOS App**: Try syncing with Garmin - check logs for OAuth 1.0a signature generation
2. **Test Edge Function**: Run the sync function manually and check logs
3. **Check for Errors**: 
   - "Invalid signature" = Wrong Consumer Key/Secret
   - "Invalid nonce and timestamp" = Usually a clock sync issue, not credentials

## Current Values in Your Code

Based on your codebase, you're currently using:
- **Consumer Key**: `695055f8-9786-4fda-a3a7-f7c2e88382f0`
- **Consumer Secret**: `0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q`

**Verify these match exactly** what's shown in your Garmin Developer Portal. If they don't match, update them with the correct values.

## Troubleshooting

### Can't Find OAuth 1.0a Section?

1. **Check Application Type**: Some Garmin applications may only support OAuth 2.0. If you don't see OAuth 1.0a credentials, you may need to:
   - Create a new application with OAuth 1.0a support
   - Contact Garmin Developer Support
   - Check if your application type supports OAuth 1.0a

2. **Check Permissions**: Ensure your application has the necessary permissions:
   - `ACTIVITY_EXPORT`
   - `HEALTH_EXPORT`
   - `WORKOUT_IMPORT`

3. **Check Documentation**: Refer to Garmin's API documentation for your specific application type

### Credentials Not Working?

1. **Verify Exact Match**: Copy-paste directly from Developer Portal (no manual typing)
2. **Check for Hidden Characters**: Ensure no extra spaces or line breaks
3. **Regenerate if Needed**: Some portals allow regenerating secrets - try this if credentials seem incorrect
4. **Check Application Status**: Ensure your application is approved and active

## Security Best Practices

1. ✅ **Never commit credentials to Git** - Use environment variables or secure storage
2. ✅ **Use different credentials for dev/prod** if possible
3. ✅ **Rotate secrets periodically** if your portal supports it
4. ✅ **Restrict access** - Only team members who need access should see these credentials

## Need Help?

If you can't find the Consumer Key/Secret:
1. Check Garmin Developer Portal documentation
2. Contact Garmin Developer Support
3. Verify your application type supports OAuth 1.0a

