#!/bin/bash

# ============================================================================
# Switch to Production APNs Key
# ============================================================================
# 
# This script helps you switch from development to production APNs key
# You need to have a production APNs key from Apple Developer Portal
# ============================================================================

echo "🔧 Switching to Production APNs Configuration"
echo ""

cd supabase 2>/dev/null || { echo "❌ Not in supabase directory"; exit 1; }

echo "📋 Prerequisites:"
echo "   1. You have a Production APNs key from Apple Developer Portal"
echo "   2. You have the .p8 file downloaded"
echo "   3. You know the Key ID"
echo ""

read -p "Do you have a production APNs key? (y/n): " has_key

if [ "$has_key" != "y" ]; then
  echo ""
  echo "❌ You need to create a production APNs key first:"
  echo "   1. Go to: https://developer.apple.com/account/resources/authkeys/list"
  echo "   2. Click '+' to create new key"
  echo "   3. Enable 'Apple Push Notifications service (APNs)'"
  echo "   4. Download the .p8 file"
  echo "   5. Note the Key ID"
  echo ""
  echo "Then run this script again."
  exit 1
fi

echo ""
read -p "Enter your Production Key ID: " key_id
read -p "Enter path to your .p8 file: " key_path

if [ ! -f "$key_path" ]; then
  echo "❌ File not found: $key_path"
  exit 1
fi

echo ""
echo "🔧 Setting production APNs configuration..."

# Set production key ID
npx supabase secrets set APNS_KEY_ID="$key_id" --project-ref gvfhtiljkybbrbxoyqsq

# Set production key content
npx supabase secrets set APNS_KEY_CONTENT="$(cat "$key_path")" --project-ref gvfhtiljkybbrbxoyqsq

# Set production environment
npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq

# Set bundle ID
npx supabase secrets set APNS_BUNDLE_ID=com.hyka.HYKA --project-ref gvfhtiljkybbrbxoyqsq

echo ""
echo "✅ Production APNs configuration set!"
echo ""
echo "🔍 Verifying..."
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS

echo ""
echo "📱 Next steps:"
echo "   1. Test notification using Supabase Dashboard"
echo "   2. Check logs for '✅ Push notification sent to device'"
echo ""


