#!/bin/bash

# Deploy updated Supabase Edge Functions
# Run this from the project root directory

cd supabase

echo "🚀 Deploying strava-activity-webhook..."
npx supabase functions deploy strava-activity-webhook --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "🚀 Deploying polar-activity-store..."
npx supabase functions deploy polar-activity-store --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "🚀 Deploying suunto-activity-store..."
npx supabase functions deploy suunto-activity-store --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "🚀 Deploying polar-file-processor..."
npx supabase functions deploy polar-file-processor --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt

echo ""
echo "✅ All functions deployed!"

