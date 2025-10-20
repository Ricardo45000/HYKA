# Garmin Developer Portal - Webhook Configuration Guide

## Current Configuration Status

Based on your screenshot, here's what needs to be updated:

### ✅ Correctly Configured

1. **ACTIVITY - Activities**
   - URL: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping`
   - Status: ✅ Enabled
   - Type: ✅ ping-
   - **Correct!** This handles PING webhooks for new activities

2. **ACTIVITY - Activity Details**
   - URL: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push`
   - Status: ✅ Enabled
   - Type: ✅ push-
   - **Correct!** This handles PUSH webhooks with full activity details

3. **ACTIVITY - Activity Files**
   - URL: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push`
   - Status: ✅ Enabled
   - Type: ✅ push-
   - **Correct!** This handles FIT files for ultra-runner activities

### ❌ Needs Update

4. **COMMON - User Permissions Change**
   - Current: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-webhook`
   - Should be: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook`
   - **Action:** Update URL to `garmin-permission-webhook`
   - **Why:** This endpoint handles permission changes (required for certification)

5. **HEALTH - Health Snapshot**
   - Current: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-webhook`
   - **Action:** Leave as-is for now (or create specific handler if needed)
   - **Note:** If you're not using health data, you can leave this on hold

6. **HEALTH - User Metrics**
   - Current: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-webhook`
   - **Action:** Leave as-is for now (or create specific handler if needed)
   - **Note:** If you're not using health metrics, you can leave this on hold

## Required Changes

### 1. Update User Permissions Change Webhook

**Change this:**
```
COMMON - User Permissions Change
URL: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-webhook
```

**To this:**
```
COMMON - User Permissions Change
URL: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook
```

**Why:** The `garmin-permission-webhook` function handles:
- Registration webhooks
- Permission revoked webhooks
- Deregistration webhooks

This is **required for certification compliance**.

## Optional: Health Endpoints

If you're not using health data (blood pressure, sleep, stress, etc.), you can:
- Leave them as `https://example.com/path` (placeholder)
- Set them to "on hold" instead of "enabled"
- Or create a generic handler if you want to log them

## Summary

**Must Change:**
- ✅ `COMMON - User Permissions Change` → Update to `garmin-permission-webhook`
- ✅ `HEALTH - User Metrics` → Update to `garmin-health-webhook` (for Fitness Age & VO2 Max)
- ✅ `HEALTH - Health Snapshot` → Update to `garmin-health-webhook` (for Fitness Age & VO2 Max)

**Already Correct:**
- ✅ ACTIVITY endpoints (ping/push)
- ✅ Other endpoints that are correctly configured

---

## About garmin-token-exchange

**Question:** Is `garmin-token-exchange` function still necessary?

**Answer:** ❌ **No, it's deprecated.**

The `garmin-token-exchange` function has been replaced by `garmin-auth-callback` which:
1. Exchanges code for tokens
2. Fetches Garmin user ID
3. Stores connection in `garmin_connections` table

The old function returns `410 Gone` to prevent accidental usage.

**You can:**
- Keep it deployed (it just returns an error)
- Or delete it (it's not used anymore)

**iOS app now calls:** `garmin-auth-callback` instead of `garmin-token-exchange`

