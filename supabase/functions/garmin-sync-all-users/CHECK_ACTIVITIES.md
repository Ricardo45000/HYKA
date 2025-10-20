# How to Check if Activities Were Synced

## 1. Check Supabase `workouts` Table

### Via Supabase Dashboard:
1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/editor
2. Navigate to **Table Editor** → `workouts` table
3. Filter by:
   - `provider` = `garmin`
   - `user_id` = `fc600af9-2926-4b86-b841-25a25d17c10c` (or your user ID)
4. Check `start_time` column to see activity dates

### Via SQL Query:
```sql
-- Check all Garmin workouts for a specific user
SELECT 
  id,
  name,
  start_time,
  distance_m,
  elapsed_seconds,
  activity_type_code,
  created_at
FROM workouts
WHERE provider = 'garmin'
  AND user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
ORDER BY start_time DESC
LIMIT 20;

-- Count total Garmin workouts
SELECT COUNT(*) as total_workouts
FROM workouts
WHERE provider = 'garmin'
  AND user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c';

-- Check activities from last 90 days
SELECT COUNT(*) as activities_last_90_days
FROM workouts
WHERE provider = 'garmin'
  AND user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
  AND start_time >= NOW() - INTERVAL '90 days';
```

## 2. Check Function Logs

### Via Supabase Dashboard:
1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions/garmin-sync-all-users
2. Click **Logs** tab
3. Look for:
   - `📅 Fetching activities for user...`
   - `✅ Fetched X activities from Wellness API`
   - `✅ Synced X activities for user...`

### What to Look For:
- **If activities were fetched**: You'll see `✅ Fetched X activities from Wellness API`
- **If activities were stored**: You'll see `✅ Synced X activities for user...`
- **If no activities**: You'll see `ℹ️ Wellness API returned empty response` or `No new activities for user`

## 3. Test the Function Again

After updating the function to fetch 90 days, test it:

```bash
curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-sync-all-users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## 4. Verify OAuth Connection

Make sure the user has a valid Garmin OAuth connection:

```sql
SELECT 
  user_id,
  provider,
  access_token IS NOT NULL as has_access_token,
  refresh_token IS NOT NULL as has_refresh_token,
  expires_at,
  created_at
FROM oauth_connections
WHERE provider = 'garmin'
  AND user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c';
```

## 5. Check Activity Types

The function only syncs running, hiking, and walking activities. If the user has other activity types, they won't be synced.

```sql
-- See what activity types exist in Garmin account (if you have access to raw API responses)
-- The function filters to only: running, hiking, walking
```

## Troubleshooting

### If `totalSynced: 0`:
1. **Check logs** - See what Garmin API returned
2. **Verify OAuth token** - Make sure `access_token` is valid
3. **Check date range** - Make sure activities exist in the last 90 days
4. **Check activity types** - Only running/hiking/walking are synced
5. **Check if already synced** - Activities might already be in the database

### If activities exist but not syncing:
- Check if they're already in the database (upsert prevents duplicates)
- Check if they match the activity type filter (running/hiking/walking only)
- Check the `start_time` - make sure it's within the last 90 days

