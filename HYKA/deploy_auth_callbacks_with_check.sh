#!/bin/bash

# Deploy updated Auth Callback Edge Functions with app.hyka.com bundle ID
# This script checks for authentication first

cd supabase

# Check if already authenticated
echo "🔍 Checking Supabase authentication..."
if npx supabase projects list --project-ref gvfhtiljkybbrbxoyqsq > /dev/null 2>&1; then
    echo "✅ Already authenticated"
else
    echo "❌ Not authenticated. Please run: npx supabase login"
    echo ""
    echo "This will open a browser window for authentication."
    echo "After logging in, run this script again."
    exit 1
fi

echo ""
echo "🚀 Deploying auth callback functions with app.hyka.com bundle ID..."
echo ""

echo "📦 Deploying strava-auth-callback..."
npx supabase functions deploy strava-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "📦 Deploying polar-auth-callback..."
npx supabase functions deploy polar-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "📦 Deploying suunto-auth-callback..."
npx supabase functions deploy suunto-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "📦 Deploying garmin-auth-callback..."
npx supabase functions deploy garmin-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "📦 Deploying garmin-activity-notify (with updated bundle ID)..."
npx supabase functions deploy garmin-activity-notify --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "✅ All auth callback functions deployed!"
echo ""
echo "📝 Summary of changes:"
echo "   - Updated redirect URLs to use app.hyka.com://callback"
echo "   - Updated bundle ID references to app.hyka.com"
echo "   - All OAuth callbacks now use consistent deep link format"
