#!/bin/bash

# ============================================================================
# Verify Bundle ID Configuration
# ============================================================================

SUPABASE_PROJECT_REF="gvfhtiljkybbrbxoyqsq"
BUNDLE_ID="app.hyka.com"

echo "=========================================="
echo "Bundle ID Verification"
echo "=========================================="
echo ""
echo "Expected Bundle ID: $BUNDLE_ID"
echo ""

# Check Supabase secrets
echo "Checking Supabase secrets..."
echo ""

cd supabase 2>/dev/null || {
    echo "❌ Error: supabase directory not found"
    echo "   Please run this script from the project root"
    exit 1
}

APNS_BUNDLE_ID=$(npx supabase secrets list --project-ref "$SUPABASE_PROJECT_REF" 2>/dev/null | grep "APNS_BUNDLE_ID" | awk '{print $1}')

if [ -z "$APNS_BUNDLE_ID" ]; then
    echo "⚠️  APNS_BUNDLE_ID is not set in Supabase secrets"
    echo ""
    echo "Setting it now..."
    npx supabase secrets set APNS_BUNDLE_ID="$BUNDLE_ID" --project-ref "$SUPABASE_PROJECT_REF"
    echo "✅ APNS_BUNDLE_ID set to: $BUNDLE_ID"
else
    CURRENT_VALUE=$(npx supabase secrets list --project-ref "$SUPABASE_PROJECT_REF" 2>/dev/null | grep "APNS_BUNDLE_ID" | awk -F'=' '{print $2}' | tr -d ' ')
    
    if [ "$CURRENT_VALUE" = "$BUNDLE_ID" ]; then
        echo "✅ APNS_BUNDLE_ID is correctly set to: $BUNDLE_ID"
    else
        echo "⚠️  APNS_BUNDLE_ID is set to: $CURRENT_VALUE"
        echo "   Expected: $BUNDLE_ID"
        echo ""
        read -p "Update to $BUNDLE_ID? (y/n): " UPDATE
        if [ "$UPDATE" = "y" ] || [ "$UPDATE" = "Y" ]; then
            npx supabase secrets set APNS_BUNDLE_ID="$BUNDLE_ID" --project-ref "$SUPABASE_PROJECT_REF"
            echo "✅ Updated to: $BUNDLE_ID"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. ✅ Verify Bundle ID in Apple Developer Portal:"
echo "   - Go to: https://developer.apple.com/account/resources/identifiers/list"
echo "   - Search for: $BUNDLE_ID"
echo "   - If not found, create it under your ORGANIZATIONAL account"
echo "   - Make sure Push Notifications capability is enabled"
echo ""
echo "2. ✅ Verify Bundle ID in Xcode:"
echo "   - Open Xcode → Select project → Target → Signing & Capabilities"
echo "   - Bundle Identifier should be: $BUNDLE_ID"
echo ""
echo "3. ✅ All code references use: $BUNDLE_ID"
echo "   - Info.plist: ✅"
echo "   - OAuth callbacks: ✅"
echo "   - Supabase functions: ✅"
echo ""
