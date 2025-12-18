#!/bin/bash

# ============================================================================
# Check Current APNs Configuration
# ============================================================================

echo "🔍 Checking APNs Configuration in Supabase..."
echo ""

cd supabase 2>/dev/null || { echo "❌ Not in supabase directory"; exit 1; }

echo "📋 Current APNs Secrets:"
echo ""

# List all APNs secrets
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq 2>/dev/null | grep APNS || echo "   No APNs secrets found"

echo ""
echo "📝 Required Secrets:"
echo "   ✅ APNS_KEY_ID - Your APNs key ID from Apple Developer Portal"
echo "   ✅ APNS_TEAM_ID - Your Apple Team ID"
echo "   ✅ APNS_KEY_CONTENT - Contents of your .p8 key file"
echo "   ⚠️  APNS_BUNDLE_ID - Optional (defaults to com.hyka.app)"
echo "   ⚠️  APNS_ENVIRONMENT - Optional (defaults to production)"
echo ""

echo "🔗 Find Your APNs Key:"
echo "   1. Go to: https://developer.apple.com/account/resources/authkeys/list"
echo "   2. Look for keys with 'Apple Push Notifications service (APNs)' enabled"
echo "   3. Note the Key ID and Team ID"
echo "   4. Download the .p8 file (if you haven't already)"
echo ""

echo "📖 For detailed instructions, see: find_apns_key.md"
echo ""


