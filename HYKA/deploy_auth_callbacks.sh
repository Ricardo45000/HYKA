#!/bin/bash

# Deploy updated Auth Callback Edge Functions with app.hyka.com bundle ID
# Run this from the project root directory after running: npx supabase login

cd supabase

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
