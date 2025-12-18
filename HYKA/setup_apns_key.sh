#!/bin/bash

# ============================================================================
# Setup APNs Key in Supabase
# ============================================================================

KEY_FILE="/Users/ricardoda-silva/Downloads/AuthKey_Q95C66T7NR.p8"
KEY_ID="Q95C66T7NR"
BUNDLE_ID="com.hyka.HYKA"

echo "🔧 Setting up APNs Key in Supabase"
echo ""

cd supabase 2>/dev/null || { echo "❌ Not in supabase directory"; exit 1; }

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
  echo "❌ Key file not found: $KEY_FILE"
  exit 1
fi

echo "📋 Configuration:"
echo "   Key ID: $KEY_ID"
echo "   Key File: $KEY_FILE"
echo "   Bundle ID: $BUNDLE_ID"
echo ""

# Get Team ID (user needs to provide this)
read -p "Enter your Apple Team ID (found in Apple Developer Portal, top right): " TEAM_ID

if [ -z "$TEAM_ID" ]; then
  echo "❌ Team ID is required"
  exit 1
fi

echo ""
echo "🔧 Setting APNs secrets..."

# Set Key ID
echo "   Setting APNS_KEY_ID..."
npx supabase secrets set APNS_KEY_ID="$KEY_ID" --project-ref gvfhtiljkybbrbxoyqsq

# Set Team ID
echo "   Setting APNS_TEAM_ID..."
npx supabase secrets set APNS_TEAM_ID="$TEAM_ID" --project-ref gvfhtiljkybbrbxoyqsq

# Set Key Content
echo "   Setting APNS_KEY_CONTENT..."
npx supabase secrets set APNS_KEY_CONTENT="$(cat "$KEY_FILE")" --project-ref gvfhtiljkybbrbxoyqsq

# Set Bundle ID
echo "   Setting APNS_BUNDLE_ID..."
npx supabase secrets set APNS_BUNDLE_ID="$BUNDLE_ID" --project-ref gvfhtiljkybbrbxoyqsq

# Ask about environment
echo ""
echo "📱 Which environment do you want to use?"
echo "   1. development (for debug builds/testing)"
echo "   2. production (for TestFlight/App Store)"
read -p "Enter choice (1 or 2): " env_choice

if [ "$env_choice" = "1" ]; then
  ENVIRONMENT="development"
elif [ "$env_choice" = "2" ]; then
  ENVIRONMENT="production"
else
  echo "⚠️  Invalid choice, defaulting to production"
  ENVIRONMENT="production"
fi

echo "   Setting APNS_ENVIRONMENT to $ENVIRONMENT..."
npx supabase secrets set APNS_ENVIRONMENT="$ENVIRONMENT" --project-ref gvfhtiljkybbrbxoyqsq

echo ""
echo "✅ APNs configuration complete!"
echo ""
echo "🔍 Verifying configuration..."
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS

echo ""
echo "📱 Next steps:"
echo "   1. Test notification using Supabase Dashboard"
echo "   2. If you get 'BadEnvironmentKeyInToken', try switching environment:"
echo "      npx supabase secrets set APNS_ENVIRONMENT=<development|production> --project-ref gvfhtiljkybbrbxoyqsq"
echo "   3. If you get 'BadDeviceToken', you may need to:"
echo "      - Delete old device token from database"
echo "      - Re-register by opening the app"
echo ""


