# Fix: Cloudflare Challenge Blocking Garmin OAuth

## Problem

When connecting to Garmin, you see:
```
sso.garmin.com
Please unblock challenges.cloudflare.com to proceed.
```

This is Cloudflare's bot protection blocking the OAuth flow.

## Solution

I've updated the code to allow cookies in the OAuth session. Cloudflare needs cookies to verify you're a real user.

**Change made:**
- Set `prefersEphemeralWebBrowserSession = false` for Garmin OAuth
- This allows cookies to be saved, which Cloudflare needs for verification

## What This Means

- **Before:** OAuth session was ephemeral (no cookies) → Cloudflare blocked it
- **After:** OAuth session allows cookies → Cloudflare can verify you're human

## Testing

1. Try connecting to Garmin again
2. The OAuth flow should now pass Cloudflare's challenge
3. You may see a brief Cloudflare check, but it should complete automatically

## If It Still Fails

If you still see Cloudflare challenges:

1. **Wait a moment** - Cloudflare checks can take a few seconds
2. **Complete the challenge manually** - If a challenge appears, complete it in the browser
3. **Check your network** - Some networks/VPNs trigger more Cloudflare challenges

## Security Note

Allowing cookies is safe because:
- Cookies are only used during the OAuth flow
- They're cleared after the session ends
- Garmin's OAuth is secure and requires user consent

---

The fix is in the code. Try connecting to Garmin again!

