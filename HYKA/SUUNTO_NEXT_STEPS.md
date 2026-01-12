# Suunto Integration - Next Steps Checklist

## ✅ Completed

- [x] Suunto API access approved
- [x] Client ID obtained: `6a8e3aca-307b-443d-8c73-d44d38a2e74b`
- [x] Client Secret set: `HYKAIsBoss25!`
- [x] OAuth redirect URI configured
- [x] Notification URLs configured (workout + 247 activity)
- [x] iOS app code updated with Client ID
- [x] OAuth flow implemented in DeviceOAuthManager
- [x] "Coming soon" status removed from UI

## ⏳ Next Steps (In Order)

### Step 1: Run Database Schema
**Action**: Execute `suunto_schema.sql` in Supabase SQL Editor
- Creates `suunto_connections` table
- Creates `suunto_activities` table  
- Creates `suunto_activity_samples` table
- Updates `unified_activities` view

**How to do it**:
1. Go to Supabase Dashboard → SQL Editor
2. Copy contents of `suunto_schema.sql`
3. Paste and run
4. Verify tables are created

### Step 2: Set Supabase Secrets
**Action**: Add secrets in Supabase Dashboard

**Location**: Supabase Dashboard → Edge Functions → Secrets

**Add these secrets**:
- `SUUNTO_CLIENT_ID` = `6a8e3aca-307b-443d-8c73-d44d38a2e74b`
- `SUUNTO_CLIENT_SECRET` = `HYKAIsBoss25!`
- `SUUNTO_WEBHOOK_VERIFY_TOKEN` = `suunto-webhook-verify-token-2025` (or match what you set in Suunto portal)

### Step 3: Deploy Edge Functions
**Action**: Deploy the 4 Suunto edge functions

**Functions to deploy**:
1. ✅ `suunto-auth-callback` (already created)
2. ⏳ `suunto-activity-store` (need to create)
3. ⏳ `suunto-activity-webhook` (need to create)
4. ⏳ `suunto-activity-notify` (need to create)

**How to deploy**:
- Option A: Use Supabase CLI
  ```bash
  supabase functions deploy suunto-auth-callback
  ```
- Option B: Use Supabase Dashboard → Edge Functions → Deploy

### Step 4: Test OAuth Connection
**Action**: Test the connection flow

1. Build and run the iOS app
2. Go to Profile → Connexion with your wearable
3. Tap "Suunto"
4. Complete OAuth authorization
5. Verify connection is saved

### Step 5: Test Activity Sync (After Webhook Functions Ready)
**Action**: Test webhook and activity storage

1. Create a test activity in Suunto app
2. Check Supabase logs for webhook receipt
3. Verify activity in `suunto_activities` table
4. Check push notification (if implemented)

## 🚀 Quick Start (Minimum to Test OAuth)

To test OAuth connection right now, you only need:

1. ✅ **Database schema** - Run `suunto_schema.sql`
2. ✅ **Supabase secrets** - Set `SUUNTO_CLIENT_ID` and `SUUNTO_CLIENT_SECRET`
3. ✅ **Deploy `suunto-auth-callback`** - Deploy the OAuth callback function
4. ✅ **Test in app** - Try connecting Suunto

The other 3 edge functions can be created later for full activity sync.

## 📋 Current Status

**Ready to test OAuth**: ✅ Yes (after Step 1-3 above)
**Ready for activity sync**: ⏳ No (need webhook functions)
**Ready for production**: ⏳ No (need all functions + testing)

## 🐛 Troubleshooting

If OAuth fails:
- Check Supabase secrets are set correctly
- Verify `suunto-auth-callback` function is deployed
- Check function logs in Supabase Dashboard
- Verify redirect URI matches exactly in Suunto portal

If webhooks don't work:
- Verify webhook URLs in Suunto portal
- Check `SUUNTO_WEBHOOK_VERIFY_TOKEN` matches
- Review webhook function logs


