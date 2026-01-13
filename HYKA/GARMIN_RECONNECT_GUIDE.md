# Garmin Reconnection Guide

## Problem: "Token refresh failed - Refresh token is invalid or expired"

This error means your Garmin refresh token has expired or become invalid. Garmin refresh tokens can expire after a period of inactivity or if the connection was revoked.

## Solution: Reconnect Your Garmin Account

### Steps:

1. **Open the HYKA app**
2. **Go to Profile tab** (bottom navigation)
3. **Tap "Connect with your wearables"**
4. **Find Garmin** in the list
5. **Tap "Disconnect"** (if connected) or the Garmin button
6. **Tap "Agree"** to reconnect
7. **Complete the OAuth flow** in Safari
8. **Return to the app** - you should see "Connected"

### After Reconnecting:

- ✅ New access token will be saved
- ✅ New refresh token will be saved  
- ✅ `garmin_user_id` will be saved (critical for webhooks!)
- ✅ Health sync will work again

### Verify Connection:

Run this SQL in Supabase to check your connection:

```sql
SELECT 
    user_id,
    garmin_user_id,
    token_expires_at,
    CASE 
        WHEN garmin_user_id IS NULL THEN '❌ MISSING - Reconnect!'
        WHEN token_expires_at < NOW() THEN '⚠️ Token Expired'
        ELSE '✅ OK'
    END as status
FROM garmin_connections
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c';
```

### Why This Happens:

- **Token Expiration**: Garmin refresh tokens can expire after extended periods
- **Account Changes**: If you changed your Garmin password or security settings
- **Revoked Access**: If you revoked app access in Garmin Connect settings
- **Long Inactivity**: Tokens may expire if not used for a long time

### Prevention:

- The app automatically refreshes tokens when they're about to expire
- Webhooks keep the connection active by receiving health data
- Regular syncs help maintain token validity

---

**Note**: After reconnecting, wait a few minutes for Garmin to send webhook data, or manually trigger a sync using the `garmin-health-sync` Edge Function.
