#!/bin/bash

echo "🔍 Checking NetSuite Keychain Status..."
echo "======================================"

# Check if we're running in iOS Simulator environment
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "✅ Running on macOS - can access iOS Simulator keychain"
else
    echo "❌ This script is designed for macOS to access iOS Simulator keychain"
    exit 1
fi

# Get the bundle identifier (you may need to adjust this)
BUNDLE_ID="com.yourcompany.fieldpay"

echo ""
echo "📱 Bundle ID: $BUNDLE_ID"
echo ""

# Check for NetSuite keys in the keychain
echo "🔐 Checking for NetSuite credentials in keychain..."

# List all keychain items for the app
echo "📋 All keychain items for this app:"
security find-generic-password -s "$BUNDLE_ID" 2>/dev/null | grep -E "(account|client|token)" || echo "No NetSuite items found"

echo ""
echo "🔍 Checking specific NetSuite keys:"

# Check each specific key
KEYS=("netsuite_access_token" "netsuite_refresh_token" "netsuite_token_expiry" "netsuite_account_id" "netsuite_client_id" "netsuite_client_secret" "netsuite_redirect_uri")

for key in "${KEYS[@]}"; do
    echo -n "  • $key: "
    if security find-generic-password -a "$key" -s "$BUNDLE_ID" >/dev/null 2>&1; then
        echo "✅ Found"
        # Try to get the value (will be masked for security)
        VALUE=$(security find-generic-password -a "$key" -s "$BUNDLE_ID" -w 2>/dev/null)
        if [[ -n "$VALUE" ]]; then
            LENGTH=${#VALUE}
            MASKED="${VALUE:0:4}...${VALUE: -4}"
            echo "    📝 Value: $MASKED (length: $LENGTH)"
        else
            echo "    📝 Value: <encrypted>"
        fi
    else
        echo "❌ Not found"
    fi
done

echo ""
echo "📊 Summary:"
echo "To see detailed keychain information, run the app in simulator and use the 'Check Keychain Status' button in the NetSuite Debug view."
echo ""
echo "💡 Tips:"
echo "  • Make sure the app is running in the iOS Simulator"
echo "  • The keychain is shared between simulator sessions"
echo "  • If no credentials are found, you may need to complete the OAuth flow"
echo "  • Check the Xcode console for detailed keychain debug output" 