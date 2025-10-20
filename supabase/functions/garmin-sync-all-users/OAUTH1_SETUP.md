# OAuth 1.0a Setup for Garmin Data Access

## Overview

Garmin uses a **hybrid OAuth approach**:
- **OAuth 2.0 + PKCE** for user authentication (already implemented in `garmin-token-exchange`)
- **OAuth 1.0a HMAC-SHA1** for secure data access (this implementation)

## Token Mapping

When you authenticate with OAuth 2.0, you receive:
- `access_token` → Use as `oauth_token` in OAuth 1.0a requests
- `refresh_token` → Use as `oauth_token_secret` in OAuth 1.0a requests

## Environment Variables Required

Set these in your Supabase Edge Function environment:

```bash
GARMIN_CONSUMER_KEY=your_consumer_key_from_garmin_developer_portal
GARMIN_CONSUMER_SECRET=your_consumer_secret_from_garmin_developer_portal
```

## How to Get Consumer Key and Secret

1. Go to [Garmin Developer Portal](https://developerportal.garmin.com/)
2. Navigate to your application
3. Find "OAuth 1.0a" or "Consumer Key/Secret" section
4. Copy the Consumer Key and Consumer Secret

## Implementation Details

The `oauth1.ts` helper implements:
- RFC 3986 percent-encoding
- HMAC-SHA1 signature generation
- OAuth 1.0a authorization header construction
- Nonce and timestamp generation

## Usage

The Edge Function automatically uses OAuth 1.0a for all Garmin API requests:
- Activities fetching (`/rest/activities`)
- Activity details (`/rest/activityDetails`)
- Health metrics
- Training data

No code changes needed - just set the environment variables!

