# Garmin Developer Portal - Webhook Configuration Guide

Complete step-by-step guide for configuring webhooks in the Garmin Developer Portal.

## Prerequisites

Before you begin, ensure you have:

1. ✅ **Garmin Developer Portal Account**
   - Sign up at: https://developerportal.garmin.com/
   - Verify your email address

2. ✅ **Garmin Application Registered**
   - OAuth 1.0a application created
   - Consumer Key and Consumer Secret obtained

3. ✅ **Supabase Edge Function Deployed**
   - `garmin-webhook` function deployed
   - Webhook URL ready: `https://[your-project-ref].supabase.co/functions/v1/garmin-webhook`

4. ✅ **Environment Variables Set**
   - `GARMIN_CONSUMER_KEY` set in Supabase
   - `GARMIN_CONSUMER_SECRET` set in Supabase

## Step 1: Access Garmin Developer Portal

1. Go to **https://developerportal.garmin.com/**
2. Click **Sign In** (top right)
3. Enter your credentials and sign in

## Step 2: Navigate to Your Application

1. Once signed in, you'll see the **Dashboard**
2. Click on **"My Apps"** in the top navigation menu
3. Find your **HYKA** application (or the app you created for OAuth 1.0a)
4. Click on the application name to open it

## Step 3: Access Webhook Configuration

The webhook configuration location may vary depending on Garmin's portal interface. Look for one of these:

### Option A: Direct Webhook Section
1. In your app's detail page, look for a **"Webhooks"** tab or section
2. Click on **"Webhooks"** or **"Push Notifications"**

### Option B: Settings/Configuration
1. Look for **"Settings"**, **"Configuration"**, or **"API Settings"**
2. Navigate to **"Webhooks"** or **"Push Notifications"** subsection

### Option C: Endpoint Configuration
1. Some apps have an **"Endpoint Configuration"** page
2. This is where you configure webhook URLs

## Step 4: Request Webhook Access (If Required)

⚠️ **Important**: Webhook/Push Notification access may require approval from Garmin.

1. If you see a message like **"Request Access"** or **"Enable Webhooks"**, click it
2. Fill out any required forms:
   - **Use Case**: Describe how you'll use webhooks (e.g., "Real-time activity synchronization for fitness app")
   - **Expected Volume**: Estimate webhook frequency
   - **Webhook URL**: Provide your Supabase Edge Function URL
3. Submit the request
4. **Wait for approval** (this may take 1-3 business days)

## Step 5: Add Webhook Endpoint

Once you have webhook access:

1. Click **"Add Webhook"** or **"Configure Webhook"** button
2. You'll see a form with the following fields:

### Webhook URL
```
https://[your-project-ref].supabase.co/functions/v1/garmin-webhook
```

**Example:**
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-webhook
```

### Event Types (Select which events to receive)

Check the boxes for:
- ✅ **`activity.created`** - When a new activity is completed
- ✅ **`activity.updated`** - When an activity is modified
- ⬜ **`activity.deleted`** - When an activity is deleted (optional)

### Additional Settings (If Available)

- **Retry Policy**: How many times to retry failed webhooks
- **Timeout**: Request timeout (default: 30 seconds)
- **Secret/Token**: Optional webhook secret for signature verification

## Step 6: Save Configuration

1. Review your webhook configuration
2. Click **"Save"** or **"Create Webhook"**
3. You should see a confirmation message

## Step 7: Test Webhook (If Available)

Garmin may provide a test feature:

1. Look for a **"Test Webhook"** or **"Send Test"** button
2. Click it to send a test notification
3. Check your Supabase Edge Function logs:
   ```bash
   supabase functions logs garmin-webhook
   ```
4. Verify the test payload was received

## Step 8: Verify Webhook Status

1. In the webhook list, you should see:
   - **Status**: Active/Enabled
   - **URL**: Your Supabase Edge Function URL
   - **Events**: Selected event types
   - **Last Triggered**: Timestamp of last webhook (will be empty initially)

2. If status shows **"Pending"** or **"Inactive"**, check:
   - Is the webhook URL accessible?
   - Are there any errors in Supabase logs?
   - Did you receive approval for webhook access?

## Step 9: Monitor Webhook Activity

### In Garmin Portal

1. Navigate back to **Webhooks** section
2. Check **"Last Triggered"** timestamp
3. View **"Webhook Logs"** or **"Delivery History"** (if available)
4. Look for any **failed** or **error** statuses

### In Supabase

1. Go to **Supabase Dashboard** → **Edge Functions** → **garmin-webhook**
2. Click on **"Logs"** tab
3. Monitor incoming requests:
   - Look for POST requests to `/functions/v1/garmin-webhook`
   - Check for successful responses (200 status)
   - Watch for errors (400, 500, etc.)

## Troubleshooting

### Webhook Not Appearing in Portal

**Possible Causes:**
- Webhook feature not enabled for your app type
- Need to request access first
- Wrong application selected

**Solution:**
- Contact Garmin Developer Support
- Check if your app type supports webhooks
- Verify you're using the correct application

### Webhook Status: "Failed" or "Error"

**Possible Causes:**
- Invalid webhook URL
- Supabase Edge Function not deployed
- CORS issues
- Authentication errors

**Solution:**
1. Verify webhook URL is correct:
   ```bash
   curl -X POST https://[your-project-ref].supabase.co/functions/v1/garmin-webhook \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```

2. Check Supabase logs for errors:
   ```bash
   supabase functions logs garmin-webhook
   ```

3. Verify environment variables are set:
   - `GARMIN_CONSUMER_KEY`
   - `GARMIN_CONSUMER_SECRET`

### Webhook Not Receiving Notifications

**Possible Causes:**
- User hasn't authorized webhook notifications
- OAuth 1.0a credentials not stored correctly
- Event types not selected

**Solution:**
1. Ensure users complete OAuth 1.0a flow
2. Verify `oauth_connections` table has:
   - `access_token`
   - `token_secret`
3. Check that correct event types are selected

### "Access Denied" or "Unauthorized"

**Possible Causes:**
- Webhook access not approved
- Application doesn't have webhook permissions
- OAuth credentials invalid

**Solution:**
- Request webhook access from Garmin
- Verify OAuth 1.0a application is active
- Check consumer key/secret are correct

## Alternative: Manual Webhook Testing

If Garmin doesn't provide a test feature, you can manually test:

### 1. Test with cURL

```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/garmin-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "activityId": "123456789",
    "activityName": "Test Activity",
    "userAccessToken": "test_oauth_token",
    "userTokenSecret": "test_oauth_token_secret",
    "userId": "test-user-id",
    "eventType": "activity.created",
    "timestamp": "2025-01-15T10:30:00Z"
  }'
```

### 2. Check Response

You should receive:
```json
{
  "success": true,
  "activityId": "123456789",
  "message": "Activity processed successfully"
}
```

### 3. Verify Database

```sql
SELECT * FROM workouts 
WHERE provider = 'garmin' 
ORDER BY created_at DESC 
LIMIT 1;
```

## Webhook Payload Format

Garmin sends webhooks in this format:

```json
{
  "activityId": "123456789",
  "activityName": "Morning Run",
  "userAccessToken": "oauth1_access_token",
  "userTokenSecret": "oauth1_token_secret",
  "userId": "optional-garmin-user-id",
  "eventType": "activity.created",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

## Security Best Practices

### 1. Webhook Signature Verification (Recommended)

If Garmin provides webhook signatures:

1. Get the webhook secret from Garmin Portal
2. Store it in Supabase environment variables:
   ```
   GARMIN_WEBHOOK_SECRET=your_webhook_secret
   ```
3. Update `garmin-webhook/index.ts` to verify signatures

### 2. HTTPS Only

- ✅ Always use HTTPS for webhook URLs
- ❌ Never use HTTP (insecure)

### 3. Rate Limiting

- Monitor webhook frequency
- Implement rate limiting if needed
- Use Supabase Edge Function rate limiting features

## Next Steps

After configuring the webhook:

1. ✅ **Test with Real Device**
   - Complete an activity on a Garmin device
   - Check if webhook is triggered
   - Verify activity is stored in Supabase

2. ✅ **Monitor Logs**
   - Watch Supabase Edge Function logs
   - Check for any errors
   - Verify successful processing

3. ✅ **Update iOS App**
   - Ensure OAuth 1.0a flow stores `token_secret`
   - Test manual sync functionality
   - Verify activities appear in app

## Support Resources

- **Garmin Developer Portal**: https://developerportal.garmin.com/
- **Garmin Developer Support**: Contact via Developer Portal
- **Garmin API Documentation**: https://developerportal.garmin.com/documentation/
- **Supabase Edge Functions Docs**: https://supabase.com/docs/guides/functions

## Checklist

Before considering webhook setup complete:

- [ ] Garmin Developer Portal account created
- [ ] OAuth 1.0a application registered
- [ ] Webhook access requested (if required)
- [ ] Webhook access approved
- [ ] Supabase Edge Function deployed
- [ ] Webhook URL configured in Garmin Portal
- [ ] Event types selected (activity.created, activity.updated)
- [ ] Webhook status shows "Active"
- [ ] Test webhook sent (if available)
- [ ] Supabase logs show successful requests
- [ ] Environment variables set (GARMIN_CONSUMER_KEY, GARMIN_CONSUMER_SECRET)

## Common Questions

### Q: How long does webhook approval take?

**A:** Typically 1-3 business days. Garmin reviews each request manually.

### Q: Can I use the same webhook URL for multiple apps?

**A:** Yes, but you'll need to handle routing based on the payload. It's better to have separate webhook endpoints per app.

### Q: What happens if my webhook is down?

**A:** Garmin will retry failed webhooks according to their retry policy. Check Garmin's documentation for retry details.

### Q: Can I change the webhook URL after setup?

**A:** Yes, you can update the webhook URL in the Garmin Portal at any time.

### Q: Do I need OAuth 1.0a for webhooks?

**A:** Yes, webhooks require OAuth 1.0a credentials (`access_token` and `token_secret`) to fetch activity details from Garmin's Activity API.

---

**Need Help?** If you encounter issues not covered in this guide, check the Garmin Developer Portal documentation or contact Garmin Developer Support.

