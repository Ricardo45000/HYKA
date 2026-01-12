#!/bin/bash

# ============================================================================
# Check Garmin Redirect URI Configuration
# ============================================================================
# This script helps verify that your Config.swift and Garmin Portal match
# ============================================================================

echo "=========================================="
echo "Garmin Redirect URI Check"
echo "=========================================="
echo ""

# Check if Config.swift exists
CONFIG_FILE="ios/Config/Config.swift"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config.swift not found at: $CONFIG_FILE"
    echo ""
    echo "   Create it by copying the example:"
    echo "   cp ios/Config/Config.example.swift ios/Config/Config.swift"
    echo "   Then edit Config.swift with your actual values"
    exit 1
fi

echo "✅ Found Config.swift"
echo ""

# Extract redirect URI from Config.swift
REDIRECT_URI=$(grep -E "static let garminRedirectURI" "$CONFIG_FILE" | sed -E 's/.*= *"([^"]+)".*/\1/')

if [ -z "$REDIRECT_URI" ]; then
    echo "❌ Could not find garminRedirectURI in Config.swift"
    echo ""
    echo "   Make sure Config.swift has:"
    echo "   static let garminRedirectURI = \"app.hyka.com://callback\""
    exit 1
fi

echo "📋 Current redirect URI in Config.swift:"
echo "   $REDIRECT_URI"
echo ""

# Check if it's the correct value
if [ "$REDIRECT_URI" = "app.hyka.com://callback" ]; then
    echo "✅ Config.swift has the correct redirect URI"
else
    echo "❌ Config.swift has WRONG redirect URI!"
    echo ""
    echo "   Current: $REDIRECT_URI"
    echo "   Should be: app.hyka.com://callback"
    echo ""
    echo "   Fix: Edit ios/Config/Config.swift and change:"
    echo "   static let garminRedirectURI = \"app.hyka.com://callback\""
    echo ""
    exit 1
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. ✅ Config.swift is correct: app.hyka.com://callback"
echo ""
echo "2. 🔍 Verify Garmin Developer Portal:"
echo "   - Go to: https://developer.garmin.com/my-apps/"
echo "   - Select your HYKA app"
echo "   - Navigate to OAuth 2.0 settings"
echo "   - Check Redirect URI field"
echo "   - It MUST be EXACTLY: app.hyka.com://callback"
echo "   - Remove any other redirect URIs"
echo ""
echo "3. 🔄 If Garmin Portal is different:"
echo "   - Update it to: app.hyka.com://callback"
echo "   - Click Save"
echo "   - Wait 1-2 minutes for changes to propagate"
echo ""
echo "4. 🧪 Test again:"
echo "   - Clean and rebuild app in Xcode"
echo "   - Try connecting to Garmin"
echo "   - Check Xcode console for redirect URI logs"
echo ""
echo "=========================================="
