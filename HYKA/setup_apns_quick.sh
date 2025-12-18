#!/bin/bash

# ============================================================================
# Quick Setup - APNs Key (Non-Interactive)
# ============================================================================
# 
# This script sets up the APNs key with production environment by default
# Modify the variables below if needed
# ============================================================================

KEY_FILE="/Users/ricardoda-silva/Downloads/AuthKey_Q95C66T7NR.p8"
KEY_ID="Q95C66T7NR"
BUNDLE_ID="com.hyka.HYKA"
ENVIRONMENT="production"  # Change to "development" if needed

# ⚠️ YOU NEED TO SET YOUR TEAM ID HERE
TEAM_ID="YOUR_TEAM_ID_HERE"  # Get from Apple Developer Portal, top right

echo "🔧 Quick Setup: APNs Key"
echo ""

cd supabase 2>/dev/null || { echo "❌ Not in supabase directory"; exit 1; }

if [ "$TEAM_ID" = "YOUR_TEAM_ID_HERE" ]; then
  echo "❌ Please edit this script and set TEAM_ID"
  echo "   Get it from: https://developer.apple.com/account"
  echo "   It's shown in the top right corner"
  exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
  echo "❌ Key file not found: $KEY_FILE"
  exit 1
fi

echo "📋 Setting up:"
echo "   Key ID: $KEY_ID"
echo "   Team ID: $TEAM_ID"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Environment: $ENVIRONMENT"
echo ""

npx supabase secrets set APNS_KEY_ID="$KEY_ID" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_TEAM_ID="$TEAM_ID" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_KEY_CONTENT="$(cat "$KEY_FILE")" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_BUNDLE_ID="$BUNDLE_ID" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_ENVIRONMENT="$ENVIRONMENT" --project-ref gvfhtiljkybbrbxoyqsq

echo ""
echo "✅ Done! Configuration:"
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS

echo ""
echo "📱 Test notification now!"


