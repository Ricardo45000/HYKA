# Cleanup: Remove Deprecated Functions

## Functions to Delete

These functions are **deprecated** and return 410 Gone. They can be safely deleted:

### ❌ Delete These:

1. **`garmin-activity-fetch/`**
   - Status: Deprecated (returns 410 Gone)
   - Reason: Used Wellness API polling (doesn't work with OAuth 2.0)
   - Replacement: `garmin-activity-ping` → `pull` → `store`

2. **`garmin-historical-backfill/`**
   - Status: Deprecated (returns 410 Gone)
   - Reason: Used Wellness API polling (doesn't work with OAuth 2.0)
   - Replacement: Use Garmin Developer Portal's backfill tool

3. **`garmin-hourly-sync/`**
   - Status: Deprecated (returns 410 Gone)
   - Reason: Used Wellness API polling (doesn't work with OAuth 2.0)
   - Replacement: Webhooks are real-time (no hourly sync needed)

---

## Functions to Keep

### ✅ Keep These (Active):

1. **`garmin-activity-ping/`** - Receives webhooks from Garmin
2. **`garmin-activity-pull/`** - Fetches activity data from callbackUrl
3. **`garmin-activity-store/`** - Stores activities in Supabase
4. **`garmin-token-exchange/`** - OAuth token exchange (still needed)

### ⚠️ Check This One:

5. **`garmin-activity-push/`** - Receives PUSH webhooks (with full data)
   - **Question:** Is this still used, or should it also be deprecated?
   - **Note:** PING is preferred (lighter, uses callbackUrl)
   - **Recommendation:** Check if Garmin sends PUSH webhooks, or only PING

---

## How to Delete

### Option 1: Delete Folders Manually

```bash
cd supabase/functions
rm -rf garmin-activity-fetch
rm -rf garmin-historical-backfill
rm -rf garmin-hourly-sync
```

### Option 2: Keep for Reference

If you want to keep them for reference but not deploy them:
- They already return 410 Gone, so they won't be used
- You can leave them as-is
- Or move them to a `_deprecated/` folder

---

## Also Update/Remove

### SQL Files:
- `garmin_hourly_sync_setup.sql` - Can be deleted or updated to remove cron job

### Documentation:
- Update any docs that reference deprecated functions
- Mark as "deprecated" or remove references

---

## Recommendation

**Delete the deprecated functions** - they're not being used and just add confusion. The new webhook flow is the only way that works with OAuth 2.0.

**Keep `garmin-activity-push` for now** - check if Garmin actually sends PUSH webhooks. If not, deprecate it too.

