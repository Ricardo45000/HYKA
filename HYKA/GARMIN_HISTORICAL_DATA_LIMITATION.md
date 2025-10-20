# Garmin Historical Data Limitation

## The Problem: Data from Before Connection Date

**Question**: "What about the data from 29 days before? Where are they and how can I get them?"

**Answer**: Unfortunately, **Garmin's backfill API only allows retrieving data from the connection date forward, not backward.**

---

## Why This Limitation Exists

Garmin's `/rest/backfill/activities` endpoint has a strict requirement:
- ✅ **Allowed**: Backfill from connection date → future
- ❌ **Not Allowed**: Backfill from before connection date

This is a **Garmin API limitation**, not a limitation of our implementation.

---

## Where Is Your Historical Data?

Your historical activities **still exist in Garmin's system** - they're just not accessible via the backfill API after you connect.

**The data is:**
- ✅ Stored in Garmin Connect (you can see it in the Garmin Connect app/website)
- ✅ Available in Garmin's database
- ❌ **Not accessible** via the backfill API for dates before connection

---

## Why Can't We Get It?

When you connect your Garmin account to HYKA:
1. Garmin records the **connection timestamp** (`connected_at`)
2. Garmin's backfill API enforces: `startTime >= connected_at`
3. Any request with `startTime < connected_at` is **rejected** with error:
   ```
   "start time before min start time of [connection_date]"
   ```

This is a **security/privacy measure** by Garmin to prevent:
- Accessing data from before user consent
- Bulk data harvesting
- Privacy violations

---

## Potential Workarounds

### Option 1: Manual Export from Garmin Connect (Recommended)

1. **Go to Garmin Connect** (web or app)
2. **Export activities** you want:
   - Select activities → Export → GPX/TCX format
3. **Import into HYKA**:
   - Use the GPX upload feature in HYKA
   - Activities will be stored in Supabase

**Pros:**
- ✅ You get all your historical data
- ✅ Works for any date range
- ✅ Full control over which activities to import

**Cons:**
- ❌ Manual process (not automated)
- ❌ Requires exporting from Garmin Connect

---

### Option 2: Connect Earlier (For Future Reference)

If you know you'll want historical data:
- **Connect Garmin to HYKA BEFORE you need the data**
- This way, activities sync automatically as they happen
- No need for backfill

**Note**: This doesn't help for data that already exists before connection.

---

### Option 3: Check Garmin Developer Portal

Some Garmin API endpoints might allow historical access:
- **Activity Export API**: Might have different permissions
- **Health API**: Different endpoints might have different rules
- **Training API**: Separate API with different access rules

**Status**: Needs investigation - Garmin documentation is unclear on this.

---

### Option 4: Use Garmin Connect Web Interface

1. **Log into Garmin Connect** (web)
2. **View activities** from before connection
3. **Manually record key metrics** if needed
4. **Or export** and import into HYKA

---

## What Data IS Available?

After connecting, you can get:

1. **Activities from connection date forward**:
   - ✅ Via backfill API (up to 30 days at a time)
   - ✅ Via webhooks (automatic for new activities)

2. **Future activities**:
   - ✅ Automatically synced via webhooks
   - ✅ No manual action needed

---

## Current Implementation Status

### What We're Doing:
- ✅ Backfilling from connection date → now (up to 29 days)
- ✅ Automatically syncing new activities via webhooks
- ✅ Handling edge cases (recent connections, small date ranges)

### What We CAN'T Do:
- ❌ Backfill data from before connection date
- ❌ Access historical data via API (Garmin limitation)
- ❌ Force Garmin to allow pre-connection backfill

---

## Recommended Solution

**For your historical data (29 days before connection):**

1. **Export from Garmin Connect**:
   - Go to Garmin Connect → Activities
   - Select activities from the date range you want
   - Export as GPX or TCX
   - Import into HYKA via GPX upload

2. **For future data**:
   - Activities will sync automatically via webhooks
   - No action needed

---

## Technical Details

### Garmin Backfill API Response (When Requesting Pre-Connection Data):

```json
{
  "errorMessage": "[uuid]start 2025-10-20T20:12:30Z before min start time of 2025-11-18T20:12:30.056Z"
}
```

This error confirms that Garmin **rejects** any backfill request where:
```
summaryStartTimeInSeconds < connection_timestamp
```

### Our Current Validation:

We validate this in the Edge Function:
```typescript
if (startTimeSeconds < connectedAtSeconds) {
  return error("Cannot backfill before connection date")
}
```

This prevents unnecessary API calls that Garmin will reject anyway.

---

## Summary

**Your historical data:**
- ✅ Still exists in Garmin Connect
- ✅ Can be viewed in Garmin Connect app/website
- ❌ Cannot be retrieved via backfill API (Garmin limitation)
- ✅ Can be manually exported and imported into HYKA

**Best approach:**
1. Export historical activities from Garmin Connect
2. Import them into HYKA via GPX upload
3. Future activities will sync automatically

