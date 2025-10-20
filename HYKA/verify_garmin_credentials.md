# Garmin OAuth 1.0a Credentials Verification

## Current Credentials
- **Consumer Key**: `695055f8-9786-4fda-a3a7-f7c2e88382f0`
- **Consumer Secret**: `0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q`
- **Callback URL**: `https://hyka.app/garmin/callback`

## Error
Garmin is returning: **"Invalid nonce and timestamp"**

## Possible Causes

1. **Consumer Credentials Not Registered**
   - Verify in [Garmin Developer Portal](https://developer.garmin.com/) that:
     - Consumer Key matches exactly
     - Consumer Secret matches exactly
     - Application is active/approved

2. **Callback URL Mismatch**
   - Verify `https://hyka.app/garmin/callback` is registered in Garmin Developer Portal
   - Must match exactly (including https, no trailing slash)

3. **Clock Skew**
   - Device time might be off from Garmin server time
   - Garmin typically accepts timestamps within ±5 minutes
   - Check device time settings

4. **Nonce Format**
   - Current implementation uses 32-character hex string from SecRandomCopyBytes
   - This should be valid, but Garmin might have specific requirements

## Next Steps

1. **Verify Credentials in Garmin Developer Portal**
   - Log into https://developer.garmin.com/
   - Check that the Consumer Key and Secret match
   - Verify the callback URL is registered

2. **Test with Fresh Credentials**
   - If credentials are incorrect, update them in the code
   - Re-register the application if needed

3. **Check Device Time**
   - Ensure device time is synchronized (use NTP)
   - Verify timezone settings

4. **Contact Garmin Support**
   - If credentials are correct, contact Garmin API support
   - They may have specific requirements not in public documentation

