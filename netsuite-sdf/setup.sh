#!/bin/bash

# FieldPay NetSuite SDF Deployment Script
# This script helps deploy the FieldPay integration to a NetSuite account

set -e

echo "========================================"
echo "  FieldPay NetSuite Deployment"
echo "========================================"
echo ""

# Check if SuiteCloud CLI is installed
if ! command -v suitecloud &> /dev/null; then
    echo "❌ SuiteCloud CLI is not installed."
    echo ""
    echo "To install, run:"
    echo "  npm install -g @oracle/suitecloud-cli"
    echo ""
    exit 1
fi

echo "✅ SuiteCloud CLI found: $(suitecloud --version)"
echo ""

# Check if we're in the right directory
if [ ! -f "project.json" ]; then
    echo "❌ project.json not found. Please run this script from the netsuite-sdf directory."
    exit 1
fi

# Function to open URL cross-platform
open_url() {
    local url=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "$url" 2>/dev/null || echo "Open this URL: $url"
    else
        echo "Open this URL: $url"
    fi
}

echo "What would you like to do?"
echo ""
echo "  1) Set up authentication (first time)"
echo "  2) Deploy to NetSuite"
echo "  3) Validate project"
echo "  4) Exit"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "Setting up authentication..."
        echo "You'll need your NetSuite account ID and administrator credentials."
        echo ""
        suitecloud account:setup
        echo ""
        echo "✅ Authentication setup complete!"
        echo "Run this script again and choose option 2 to deploy."
        ;;
    2)
        echo ""
        read -p "Enter the NetSuite Account ID (e.g., TSTDRV1234567 or 1234567): " ACCOUNT_ID

        if [ -z "$ACCOUNT_ID" ]; then
            echo "❌ Account ID is required"
            exit 1
        fi

        echo ""
        echo "Validating project..."
        suitecloud project:validate
        echo ""
        echo "Deploying to NetSuite..."
        suitecloud project:deploy

        echo ""
        echo "========================================"
        echo "  ✅ Deployment Complete!"
        echo "========================================"
        echo ""
        echo "Opening NetSuite to get your credentials..."
        echo ""

        # Build the URL to the integrations page
        INTEGRATION_URL="https://${ACCOUNT_ID}.app.netsuite.com/app/common/integration/integrapplist.nl"

        echo "📋 IMPORTANT: Copy these credentials from NetSuite!"
        echo ""
        echo "   The Client Secret is only shown ONCE - copy it now!"
        echo ""
        echo "   1. Find 'FieldPay Mobile' in the list"
        echo "   2. Click to open it"
        echo "   3. Copy the Consumer Key (Client ID)"
        echo "   4. Copy the Consumer Secret (Client Secret)"
        echo ""

        # Open the browser
        open_url "$INTEGRATION_URL"

        echo ""
        echo "Browser opened to: $INTEGRATION_URL"
        echo ""
        echo "----------------------------------------"
        echo "After copying credentials, enter them in the FieldPay app:"
        echo "  Settings > NetSuite Connection"
        echo "----------------------------------------"
        echo ""

        # Wait for user to get credentials
        read -p "Press Enter after you've copied the credentials..."

        echo ""
        read -p "Enter the Client ID (Consumer Key) you copied: " CLIENT_ID
        read -p "Enter the Client Secret (Consumer Secret) you copied: " CLIENT_SECRET

        if [ -n "$CLIENT_ID" ] && [ -n "$CLIENT_SECRET" ]; then
            echo ""
            echo "========================================"
            echo "  FieldPay Configuration"
            echo "========================================"
            echo ""
            echo "  Account ID:    $ACCOUNT_ID"
            echo "  Client ID:     $CLIENT_ID"
            echo "  Client Secret: $CLIENT_SECRET"
            echo "  Redirect URI:  fieldpay://callback"
            echo ""
            echo "========================================"

            # Save to a local file for reference
            cat > fieldpay_credentials.txt << EOF
# FieldPay NetSuite Credentials
# Generated: $(date)
#
# Enter these in the FieldPay app under Settings > NetSuite Connection

Account ID:    $ACCOUNT_ID
Client ID:     $CLIENT_ID
Client Secret: $CLIENT_SECRET
Redirect URI:  fieldpay://callback
EOF
            echo ""
            echo "✅ Credentials saved to: fieldpay_credentials.txt"
            echo ""
            echo "⚠️  Keep this file secure and delete after configuring the app!"
        fi

        echo ""
        echo "Don't forget to assign the 'FieldPay User' role to users!"
        echo "  Setup > Users/Roles > Manage Users > [User] > Access tab"
        echo ""
        ;;
    3)
        echo ""
        echo "Validating project..."
        suitecloud project:validate --server
        ;;
    4)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
