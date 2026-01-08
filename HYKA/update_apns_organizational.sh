#!/bin/bash

# ============================================================================
# Update APNs Configuration for Organizational Apple Developer Account
# ============================================================================
# This script helps update Supabase secrets when transitioning from
# personal to organizational Apple Developer account.
# ============================================================================

set -e

SUPABASE_PROJECT_REF="gvfhtiljkybbrbxoyqsq"

echo "=========================================="
echo "APNs Organizational Account Migration"
echo "=========================================="
echo ""
echo "This script will help you update APNs configuration"
echo "for your organizational Apple Developer account."
echo ""
echo "Project: $SUPABASE_PROJECT_REF"
echo ""

# Check if supabase CLI is available
if ! command -v npx &> /dev/null; then
    echo "❌ Error: npx is not installed"
    echo "   Please install Node.js and npm first"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "supabase" ]; then
    echo "❌ Error: supabase directory not found"
    echo "   Please run this script from the project root"
    exit 1
fi

echo "Step 1: Get your new organizational Team ID"
echo "--------------------------------------------"
echo ""
echo "1. Go to: https://developer.apple.com/account"
echo "2. Sign in with your ORGANIZATIONAL account"
echo "3. Look at the top right corner for your Team ID"
echo "   (Format: ABC123XYZ - 10 characters)"
echo ""
read -p "Enter your new organizational Team ID: " NEW_TEAM_ID

if [ -z "$NEW_TEAM_ID" ]; then
    echo "❌ Error: Team ID is required"
    exit 1
fi

echo ""
echo "Step 2: APNs Key Information"
echo "--------------------------------------------"
echo ""
echo "Did you create a NEW APNs key under the organizational account? (y/n)"
read -p "> " CREATE_NEW_KEY

if [ "$CREATE_NEW_KEY" = "y" ] || [ "$CREATE_NEW_KEY" = "Y" ]; then
    echo ""
    echo "Enter the Key ID of your new APNs key:"
    read -p "> " NEW_KEY_ID
    
    if [ -z "$NEW_KEY_ID" ]; then
        echo "❌ Error: Key ID is required"
        exit 1
    fi
    
    echo ""
    echo "Enter the path to your downloaded .p8 file:"
    echo "  (e.g., ~/Downloads/AuthKey_ABC123XYZ.p8)"
    read -p "> " KEY_FILE_PATH
    
    if [ ! -f "$KEY_FILE_PATH" ]; then
        echo "❌ Error: Key file not found at: $KEY_FILE_PATH"
        exit 1
    fi
    
    KEY_CONTENT=$(cat "$KEY_FILE_PATH")
    
    echo ""
    echo "Step 3: Updating Supabase Secrets"
    echo "--------------------------------------------"
    echo ""
    
    echo "📝 Updating APNS_TEAM_ID..."
    npx supabase secrets set APNS_TEAM_ID="$NEW_TEAM_ID" --project-ref "$SUPABASE_PROJECT_REF"
    
    echo "📝 Updating APNS_KEY_ID..."
    npx supabase secrets set APNS_KEY_ID="$NEW_KEY_ID" --project-ref "$SUPABASE_PROJECT_REF"
    
    echo "📝 Updating APNS_KEY_CONTENT..."
    npx supabase secrets set APNS_KEY_CONTENT="$KEY_CONTENT" --project-ref "$SUPABASE_PROJECT_REF"
    
    echo "📝 Verifying APNS_BUNDLE_ID..."
    npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref "$SUPABASE_PROJECT_REF"
    
    echo ""
    echo "✅ All secrets updated!"
    
else
    echo ""
    echo "Using existing APNs key (only updating Team ID)"
    echo ""
    
    echo "Step 3: Updating Supabase Secrets"
    echo "--------------------------------------------"
    echo ""
    
    echo "📝 Updating APNS_TEAM_ID..."
    npx supabase secrets set APNS_TEAM_ID="$NEW_TEAM_ID" --project-ref "$SUPABASE_PROJECT_REF"
    
    echo ""
    echo "✅ Team ID updated!"
    echo ""
    echo "⚠️  Note: If your old APNs key was tied to your personal account,"
    echo "   you may need to create a new key under the organizational account."
    echo "   If push notifications don't work, create a new key and run this script again."
fi

echo ""
echo "Step 4: Verify Configuration"
echo "--------------------------------------------"
echo ""
echo "Current APNs secrets:"
echo ""
npx supabase secrets list --project-ref "$SUPABASE_PROJECT_REF" | grep APNS || echo "No APNS secrets found"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. ✅ Update Xcode Team setting:"
echo "   - Open Xcode → Select project → Signing & Capabilities"
echo "   - Select your organizational team from the Team dropdown"
echo ""
echo "2. ✅ Clean and rebuild:"
echo "   - Product → Clean Build Folder (Shift+Cmd+K)"
echo "   - Product → Build (Cmd+B)"
echo ""
echo "3. ✅ Re-register device tokens:"
echo "   - Run the app on your device"
echo "   - The app will automatically register a new token"
echo ""
echo "4. ✅ Test push notifications:"
echo "   - Run: ./diagnose_notification.sh"
echo ""
echo "For detailed instructions, see: ORGANIZATIONAL_ACCOUNT_MIGRATION.md"
echo ""
