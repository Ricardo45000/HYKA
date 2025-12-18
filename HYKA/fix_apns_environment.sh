#!/bin/bash

# ============================================================================
# Fix APNs Environment Mismatch
# ============================================================================

echo "🔧 Fixing APNs Environment Configuration"
echo ""

cd supabase 2>/dev/null || { echo "❌ Not in supabase directory"; exit 1; }

echo "📋 Current issue:"
echo "   - Your APNs key is a Development/Sandbox key"
echo "   - But APNS_ENVIRONMENT is set to 'production'"
echo "   - This causes 'BadEnvironmentKeyInToken' error"
echo ""

echo "🔧 Setting APNS_ENVIRONMENT to 'development'..."
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq

echo ""
echo "✅ APNS_ENVIRONMENT set to 'development'"
echo ""

echo "📝 Also noticed your Bundle ID is 'com.hyka.HYKA'"
echo "   Setting APNS_BUNDLE_ID to match..."
npx supabase secrets set APNS_BUNDLE_ID=com.hyka.HYKA --project-ref gvfhtiljkybbrbxoyqsq

echo ""
echo "✅ APNS_BUNDLE_ID set to 'com.hyka.HYKA'"
echo ""

echo "🔍 Verifying configuration..."
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS

echo ""
echo "✅ Configuration updated!"
echo ""
echo "📱 Next steps:"
echo "   1. Test the notification again using Supabase Dashboard"
echo "   2. Check logs - should see '✅ Push notification sent to device'"
echo ""


