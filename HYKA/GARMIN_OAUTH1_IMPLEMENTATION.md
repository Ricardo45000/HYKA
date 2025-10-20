# Garmin OAuth 1.0a Implementation Guide

## Overview

Garmin uses a **hybrid OAuth approach**:
- **OAuth 2.0 + PKCE** for user authentication (secure login)
- **OAuth 1.0a HMAC-SHA1** for secure data access (fetching activities, samples, etc.)

## Token Mapping

When you authenticate with OAuth 2.0, you receive:
- `access_token` → Use as `oauth_token` in OAuth 1.0a requests
- `refresh_token` → Use as `oauth_token_secret` in OAuth 1.0a requests

## Implementation Status

### ✅ Completed

1. **OAuth 1.0a Helper (`OAuth1Helper.swift`)**
   - HMAC-SHA1 signature generation
   - RFC 3986 percent-encoding
   - Authorization header construction

2. **Garmin API Client (`GarminAPIClient.swift`)**
   - Updated to use OAuth 1.0a signatures instead of Bearer tokens
   - All API requests now use `addOAuth1Header()` method
   - Supports fetching activities, samples, health metrics, training data

3. **Configuration (`GarminConfig.swift`)**
   - Stores Consumer Key and Secret
   - Can load from Info.plist or use hardcoded values

4. **.FIT File Parser (`FITParser.swift`)**
   - Basic .FIT file parsing implementation
   - Extracts GPS coordinates, heart rate, cadence, speed, etc.
   - Converts to `ProviderSample` format

5. **Edge Function (`garmin-sync-all-users/index.ts`)**
   - Updated to use OAuth 1.0a for server-side syncing
   - Includes OAuth 1.0a helper for Deno/TypeScript

### 📋 Required Setup

1. **Get Consumer Key and Secret from Garmin Developer Portal:**
   - Go to https://developerportal.garmin.com/
   - Navigate to your application
   - Find "OAuth 1.0a" or "Consumer Key/Secret" section
   - Copy the Consumer Key and Consumer Secret

2. **Update `GarminConfig.swift`:**
   - Replace `defaultConsumerKey` with your Consumer Key
   - Replace `defaultConsumerSecret` with your Consumer Secret
   - Or add to Info.plist:
     ```xml
     <key>GARMIN_CONSUMER_KEY</key>
     <string>your-consumer-key</string>
     <key>GARMIN_CONSUMER_SECRET</key>
     <string>your-consumer-secret</string>
     ```

3. **Set Edge Function Environment Variables:**
   - In Supabase Dashboard → Edge Functions → `garmin-sync-all-users`
   - Add environment variables:
     - `GARMIN_CONSUMER_KEY` = your Consumer Key
     - `GARMIN_CONSUMER_SECRET` = your Consumer Secret

## How It Works

1. **User Authentication (OAuth 2.0 + PKCE):**
   - User authenticates via `DeviceOAuthManager`
   - Receives `access_token` and `refresh_token`
   - Tokens stored in Supabase `oauth_connections` table

2. **Data Access (OAuth 1.0a HMAC-SHA1):**
   - `GarminAPIClient` retrieves tokens from Supabase
   - Maps `access_token` → `oauth_token`
   - Maps `refresh_token` → `oauth_token_secret`
   - Generates OAuth 1.0a signature for each API request
   - Includes signature in `Authorization` header

## API Endpoints Using OAuth 1.0a

All Garmin API requests now use OAuth 1.0a:
- `/rest/user/id` - Get user ID
- `/rest/user/permissions` - Get permissions
- `/rest/activities` - List activities
- `/rest/activityDetails` - Get activity details
- `/rest/activityFile` - Get .FIT file
- `/activity-service/activity/{id}` - Get activity
- `/activity-service/activity/{id}/samples` - Get samples
- `/health-service/health/daily/{date}` - Get health metrics
- `/training-service/training/plans` - Get training plans

## .FIT File Parsing

The `FITParser` can parse basic .FIT files and extract:
- GPS coordinates (latitude, longitude)
- Elevation
- Heart rate
- Cadence
- Speed
- Power
- Temperature

For production use, consider adding a Swift Package Manager dependency:
```swift
dependencies: [
    .package(url: "https://github.com/roznet/FitFileParser", from: "1.5.2")
]
```

## Testing

1. Rebuild the iOS app
2. Connect to Garmin (OAuth 2.0 authentication)
3. Sync activities (OAuth 1.0a data access)
4. Check logs for OAuth 1.0a signature generation
5. Verify activities and samples are fetched and stored

## Troubleshooting

- **"Invalid nonce and timestamp"**: Check system clock synchronization
- **"Invalid signature"**: Verify Consumer Key/Secret are correct
- **Empty responses**: Ensure OAuth 2.0 tokens are valid and not expired
- **.FIT parsing errors**: Check file format and consider using a library

