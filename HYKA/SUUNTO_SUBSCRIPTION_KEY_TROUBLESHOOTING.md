# Suunto Subscription Key Troubleshooting

## Error
```
{"statusCode": 401, "message": "Access denied due to missing subscription key. Make sure to include subscription key when making requests to an API."}
```

## Current Configuration

### Subscription Keys
- **Primary Key**: `8e6bcafebd494d7c94df5cf7d5154fde` ✅ (Configured)
- **Secondary Key**: `c740e56368f34bfe98cd2315f5319777` (Backup)

### Where Subscription Key is Used

1. **Token Exchange** (`/oauth/token`) - ✅ Now includes subscription key
2. **User Info** (`/v2/user`) - ✅ Includes subscription key
3. **Activities** (`/v2/workouts`) - ✅ iOS client includes subscription key
4. **Health Data** (`/v2/health/daily/{date}`) - ✅ iOS client includes subscription key

## Header Name

Suunto API requires the subscription key in the header:
```
Ocp-Apim-Subscription-Key: 8e6bcafebd494d7c94df5cf7d5154fde
```

## Troubleshooting Steps

### 1. Verify Edge Function Has Subscription Key

Check Supabase Dashboard → Edge Functions → Secrets:
- `SUUNTO_SUBSCRIPTION_KEY` should be set to: `8e6bcafebd494d7c94df5cf7d5154fde`

If not set, the edge function will use the hardcoded fallback value.

### 2. Check Edge Function Logs

After deploying, check the logs for:
```
🔑 Using subscription key: 8e6bcafebd4...
📤 Token exchange request headers: { 'Ocp-Apim-Subscription-Key': '8e6bcafebd4...' }
```

If you see "NOT SET" or "MISSING", the subscription key is not being passed correctly.

### 3. Verify iOS Config

Check `Config.swift`:
```swift
static let suuntoSubscriptionKey = "8e6bcafebd494d7c94df5cf7d5154fde"
```

### 4. Test with curl

Test the API directly to verify the subscription key works:

```bash
# Test token exchange (requires valid code)
curl -X POST https://cloudapi.suunto.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Ocp-Apim-Subscription-Key: 8e6bcafebd494d7c94df5cf7d5154fde" \
  -d "grant_type=authorization_code&code=YOUR_CODE&redirect_uri=YOUR_REDIRECT_URI&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET"

# Test user endpoint (requires valid access token)
curl -X GET https://cloudapi.suunto.com/v2/user \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Ocp-Apim-Subscription-Key: 8e6bcafebd494d7c94df5cf7d5154fde"
```

### 5. Common Issues

#### Issue: Subscription key not in environment variable
**Solution**: Set `SUUNTO_SUBSCRIPTION_KEY` in Supabase Edge Functions secrets, or the function will use the hardcoded fallback.

#### Issue: Wrong header name
**Solution**: Must use exactly `Ocp-Apim-Subscription-Key` (case-sensitive).

#### Issue: Subscription key invalid or expired
**Solution**: Check Suunto Developer Portal to verify the key is still active.

#### Issue: Token exchange endpoint also needs subscription key
**Solution**: ✅ Fixed - Now included in token exchange request.

## Current Implementation Status

- ✅ Token exchange includes subscription key
- ✅ User info fetch includes subscription key  
- ✅ iOS client includes subscription key in all API calls
- ✅ Edge function has fallback subscription key
- ✅ Logging added to debug subscription key usage

## Next Steps

1. **Deploy the updated edge function** with subscription key in token exchange
2. **Set Supabase secret** `SUUNTO_SUBSCRIPTION_KEY` (optional, has fallback)
3. **Test OAuth flow** and check logs for subscription key usage
4. **Verify** the 401 error is resolved

## Verification

After deploying, you should see in logs:
- ✅ `🔑 Using subscription key: 8e6bcafebd4...`
- ✅ `📤 Token exchange request headers: { 'Ocp-Apim-Subscription-Key': '8e6bcafebd4...' }`
- ✅ Successful token exchange (200 status)
- ✅ Successful user info fetch (200 status)

If you still see 401 errors, check:
1. The subscription key is correct (no typos)
2. The header name is exactly `Ocp-Apim-Subscription-Key`
3. The subscription key is active in Suunto Developer Portal

