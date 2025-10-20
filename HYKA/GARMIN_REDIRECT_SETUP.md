# Garmin OAuth Redirect Setup

## The Problem

Garmin OAuth redirects to: `https://hyka.app/garmin/callback?code=XXX`  
But the app needs: `com.hyka.app://garmin/callback?code=XXX`

## The Solution

Set up a web page at `https://hyka.app/garmin/callback` that redirects to the custom scheme URL **preserving all query parameters**.

## Implementation (Loveable/Vite React)

Create a file at: `src/pages/garmin-callback.tsx`

```typescript
import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

export default function GarminCallback() {
  const location = useLocation();
  
  useEffect(() => {
    // Get all query parameters from the HTTPS callback
    const params = new URLSearchParams(location.search);
    
    // Build custom scheme URL with all parameters
    const customSchemeURL = `com.hyka.app://garmin/callback${location.search}`;
    
    console.log('Redirecting to:', customSchemeURL);
    
    // Redirect to custom scheme (opens the app)
    window.location.href = customSchemeURL;
  }, [location]);
  
  return (
    <div style={{ 
      display: 'flex', 
      alignItems: 'center', 
      justifyContent: 'center', 
      height: '100vh',
      fontFamily: 'system-ui'
    }}>
      <div style={{ textAlign: 'center' }}>
        <h2>Redirecting to HYKA...</h2>
        <p>Please wait while we complete the connection.</p>
        <p style={{ fontSize: '12px', color: '#666', marginTop: '20px' }}>
          If you're not redirected automatically, please return to the app.
        </p>
      </div>
    </div>
  );
}
```

## Add Route

In your router configuration:

```typescript
{
  path: '/garmin/callback',
  element: <GarminCallback />
}
```

## Test

1. Deploy the page to https://hyka.app/garmin/callback
2. Test by visiting: `https://hyka.app/garmin/callback?code=test123`
3. It should redirect to: `com.hyka.app://garmin/callback?code=test123`
4. The app should open (if installed)

## Alternative: Server-Side Redirect (Faster)

If you can configure server redirects, add this to your web server config:

```nginx
# Nginx example
location = /garmin/callback {
    return 302 com.hyka.app://garmin/callback$is_args$args;
}
```

Or in Vercel (`vercel.json`):

```json
{
  "redirects": [
    {
      "source": "/garmin/callback",
      "destination": "com.hyka.app://garmin/callback?:code",
      "permanent": false
    }
  ]
}
```

## Important Notes

1. The redirect **MUST** preserve all query parameters
2. Use HTTP 302 (temporary redirect), not 301 (permanent)
3. Test thoroughly - query parameters must be passed through exactly
4. The page should redirect immediately (don't wait for user interaction)

