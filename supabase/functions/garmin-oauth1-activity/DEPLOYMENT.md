# Garmin OAuth 1.0a Activity Fetcher Deployment Guide

## Quick Start

### 1. Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:

```
GARMIN_CONSUMER_KEY=your_consumer_key_here
GARMIN_CONSUMER_SECRET=your_consumer_secret_here
```

### 2. Deploy Function

```bash
supabase functions deploy garmin-oauth1-activity
```

### 3. Test Function

```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/garmin-oauth1-activity \
  -H "Authorization: Bearer [user-jwt-token]" \
  -H "Content-Type: application/json" \
  -d '{
    "activityId": "123456789"
  }'
```

## Usage from iOS App

```swift
let url = URL(string: "https://[your-project-ref].supabase.co/functions/v1/garmin-oauth1-activity")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let body = ["activityId": activityId]
request.httpBody = try JSONSerialization.data(withJSONObject: body)

let (data, response) = try await URLSession.shared.data(for: request)
```

