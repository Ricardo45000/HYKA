# Deploy and Use garmin-activity-direct-fetch

## Step 1: Deploy the Function

```bash
# Login to Supabase (if not already logged in)
supabase login

# Deploy the function
supabase functions deploy garmin-activity-direct-fetch
```

## Step 2: Make Function Public

After deployment, make the function public in Supabase Dashboard:

1. Go to **Supabase Dashboard → Edge Functions**
2. Click on **`garmin-activity-direct-fetch`**
3. Go to **Settings** or **Configuration**
4. **Disable** "Require Authentication" (or enable "Allow Anonymous Access")
5. Save

## Step 3: Test the Function

### Request 7 days of activities:

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-direct-fetch" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w" \
  -d '{
    "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
    "days_ago": 7
  }'
```

### Request specific date range:

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-direct-fetch" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
    "start_date": "2025-11-19T00:00:00Z",
    "end_date": "2025-11-26T23:59:59Z"
  }'
```

## How It Works

1. **Splits date range into 1-day chunks** - Minimizes duplicate detection
2. **Makes multiple small requests** - One per day instead of one large request
3. **Adds delays between requests** - Avoids rate limiting
4. **Returns summary** - Shows how many chunks were requested

## Expected Response

```json
{
  "success": true,
  "message": "Initiated 7 backfill requests (1 day each)",
  "chunks_requested": 7,
  "date_range": {
    "start": "2025-11-19T00:00:00.000Z",
    "end": "2025-11-26T23:59:59.000Z"
  },
  "note": "Activities will arrive via webhooks. This workaround uses small date ranges (1 day) to minimize Garmin's duplicate detection. Check Supabase logs for webhook arrivals.",
  "duration": "8500ms"
}
```

## What Happens Next

1. Function makes 7 separate 1-day backfill requests to Garmin
2. Garmin processes each request (may still return 409 for some, but that's OK)
3. Activities arrive via webhooks (`garmin-activity-push` or `garmin-activity-ping`)
4. Activities are stored in Supabase database
5. Check Supabase logs to monitor webhook arrivals

## Monitor Progress

Check Supabase Edge Function logs:
- `garmin-activity-direct-fetch` - See which chunks were requested
- `garmin-activity-push` - See activities arriving via webhooks
- `garmin-activity-store` - See activities being stored

## Troubleshooting

**If function returns 404:**
- Function not deployed yet - run `supabase functions deploy garmin-activity-direct-fetch`

**If function returns 401:**
- Function not made public - go to Dashboard and disable authentication requirement

**If activities don't arrive:**
- Check webhook logs in Supabase
- Garmin may still remember requests - try manual push buttons in Developer Portal
- Wait 24-48 hours - webhooks may arrive eventually

