# Garmin Backfill Workaround

## The Problem

Garmin's backfill system has issues:
- **Remembers requests for weeks/months** - Even if you delete database entries, Garmin remembers
- **Doesn't deliver activities** - Webhooks may not arrive even when requests are "accepted"
- **Duplicate detection** - Returns 409 even for new date ranges

## Workarounds

### Option 1: Use Small Date Ranges (1 Day Chunks)

**Strategy:** Break 7 days into 7 separate 1-day requests to minimize duplicate detection.

**New Function:** `garmin-activity-direct-fetch`
- Automatically splits date ranges into 1-day chunks
- Makes multiple small requests instead of one large request
- Reduces chance of hitting duplicate detection

**Usage:**
```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-direct-fetch" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
    "days_ago": 7
  }'
```

### Option 2: Manual Webhook Trigger (Garmin Developer Portal)

**Steps:**
1. Go to Garmin Developer Portal → Endpoint Configuration
2. Find the activity webhook endpoints
3. Click the **"push"** button next to each enabled endpoint
4. This manually triggers webhooks for existing activities
5. Check Supabase logs to see if webhooks arrive

**Note:** This only works for activities that Garmin already has synced. It won't fetch new activities.

### Option 3: Use Very Recent Date Ranges (Last Few Hours)

**Strategy:** Request only the last few hours to avoid overlapping with remembered requests.

**Usage:**
```bash
# Request last 3 hours only
NOW=$(date +%s)
THREE_HOURS_AGO=$((NOW - (3 * 60 * 60)))

curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-backfill" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -d "{
    \"user_id\": \"fc600af9-2926-4b86-b841-25a25d17c10c\",
    \"summary_start_time_seconds\": $THREE_HOURS_AGO,
    \"summary_end_time_seconds\": $NOW
  }"
```

### Option 4: Wait and Monitor Webhooks

**Strategy:** Even if backfill says "duplicate", webhooks may still arrive eventually.

**Steps:**
1. Make backfill request (even if it returns 409)
2. Monitor Supabase Edge Function logs for `garmin-activity-push` or `garmin-activity-ping`
3. Wait 24-48 hours - Garmin may deliver webhooks eventually
4. Check database periodically to see if activities appear

## Recommended Approach

**For immediate needs:**
1. Use `garmin-activity-direct-fetch` with 1-day chunks
2. Manually trigger webhooks via Garmin Developer Portal "push" buttons
3. Monitor Supabase logs for webhook arrivals

**For long-term:**
- Rely on automatic webhooks for new activities (they work reliably)
- Use backfill only for historical data when absolutely necessary
- Accept that Garmin's backfill system is unreliable

## Testing the Workaround

Let's test the new `garmin-activity-direct-fetch` function:

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-direct-fetch" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
    "days_ago": 7
  }'
```

This will:
1. Split 7 days into 7 separate 1-day requests
2. Make each request with a small delay to avoid rate limiting
3. Return summary of requests made
4. Activities will arrive via webhooks (if Garmin processes them)

## Limitations

⚠️ **Important:** Garmin's API doesn't have a direct "get activities" endpoint. All methods rely on:
- Backfill requests (asynchronous, unreliable)
- Webhooks (asynchronous, but more reliable for new activities)

There's no way to **synchronously** fetch activities from Garmin. Everything is webhook-based.

## Next Steps

1. **Deploy the new function:**
   ```bash
   supabase functions deploy garmin-activity-direct-fetch
   ```

2. **Test it:**
   ```bash
   # Test with 7 days
   curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-direct-fetch" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "apikey: YOUR_ANON_KEY" \
     -d '{"user_id": "fc600af9-2926-4b86-b841-25a25d17c10c", "days_ago": 7}'
   ```

3. **Monitor webhooks:**
   - Check Supabase logs for `garmin-activity-push` invocations
   - Activities should arrive within minutes to hours

4. **Manual trigger (if needed):**
   - Use Garmin Developer Portal "push" buttons
   - This forces webhooks for existing activities

