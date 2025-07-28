#!/bin/bash

# FieldPay OAuth Flow Test Script
# This script helps test and debug the OAuth flow

set -e

echo "🔧 FieldPay OAuth Flow Test Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if simulator is running
check_simulator() {
    print_status $BLUE "🔍 Checking iPhone 16 simulator status..."
    
    if xcrun simctl list devices | grep -q "iPhone 16.*Booted"; then
        print_status $GREEN "✅ iPhone 16 simulator is running"
        return 0
    else
        print_status $RED "❌ iPhone 16 simulator is not running"
        print_status $YELLOW "Please start the iPhone 16 simulator in Xcode"
        return 1
    fi
}

# Check if app is installed
check_app() {
    print_status $BLUE "🔍 Checking if FieldPay app is installed..."
    
    if xcrun simctl listapps "iPhone 16" | grep -q "Fieldpay.fieldpay"; then
        print_status $GREEN "✅ FieldPay app is installed"
        return 0
    else
        print_status $RED "❌ FieldPay app is not installed"
        print_status $YELLOW "Please build and run the app from Xcode"
        return 1
    fi
}

# Clear app data
clear_app_data() {
    print_status $BLUE "🧹 Clearing app data..."
    xcrun simctl terminate "iPhone 16" Fieldpay.fieldpay 2>/dev/null || true
    xcrun simctl uninstall "iPhone 16" Fieldpay.fieldpay 2>/dev/null || true
    print_status $GREEN "✅ App data cleared"
}

# Install and launch app
launch_app() {
    print_status $BLUE "🚀 Launching FieldPay app..."
    
    # Build the app
    print_status $YELLOW "📦 Building app..."
    xcodebuild -project fieldpay.xcodeproj -scheme fieldpay -destination 'platform=iOS Simulator,name=iPhone 16' build
    
    # Install and launch
    print_status $YELLOW "📱 Installing and launching app..."
    xcrun simctl install "iPhone 16" DerivedData/Build/Products/Debug-iphonesimulator/fieldpay.app
    xcrun simctl launch "iPhone 16" Fieldpay.fieldpay
    
    print_status $GREEN "✅ App launched successfully"
}

# Monitor logs
monitor_logs() {
    print_status $BLUE "📊 Starting log monitoring..."
    print_status $YELLOW "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor logs with comprehensive filtering
    xcrun simctl spawn "iPhone 16" log stream \
        --predicate 'process == "fieldpay"' \
        --style compact | grep -E "(Debug|OAuth|NetSuite|ERROR|Safari|URL|token|FRESH|C1|UIOpenURLAction|SceneClient|FrontBoard)" --line-buffered
}

# Test OAuth configuration
test_oauth_config() {
    print_status $BLUE "🔧 Testing OAuth configuration..."
    
    # Check Info.plist URL scheme
    if grep -q "fieldpay" fieldpay/Info.plist; then
        print_status $GREEN "✅ URL scheme 'fieldpay' found in Info.plist"
    else
        print_status $RED "❌ URL scheme 'fieldpay' not found in Info.plist"
    fi
    
    # Check OAuthManager redirect URI
    if grep -q 'redirectUri: String = "fieldpay://callback"' fieldpay/Networking/OAuthManager.swift; then
        print_status $GREEN "✅ OAuthManager redirect URI is correct"
    else
        print_status $RED "❌ OAuthManager redirect URI is incorrect"
    fi
    
    # Check app callback handling
    if grep -q 'url.host == "callback"' fieldpay/fieldpayApp.swift; then
        print_status $GREEN "✅ App callback handling is configured"
    else
        print_status $RED "❌ App callback handling is not configured"
    fi
}

# Main function
main() {
    echo ""
    print_status $BLUE "🚀 Starting OAuth flow test..."
    echo ""
    
    # Check prerequisites
    if ! check_simulator; then
        exit 1
    fi
    
    if ! check_app; then
        print_status $YELLOW "Would you like to build and install the app? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            launch_app
        else
            exit 1
        fi
    fi
    
    # Test configuration
    test_oauth_config
    
    echo ""
    print_status $GREEN "✅ Prerequisites check passed!"
    echo ""
    
    # Instructions
    print_status $BLUE "📋 Next steps:"
    echo "1. Navigate to Settings > NetSuite Configuration in the app"
    echo "2. Enter your NetSuite credentials:"
    echo "   - Client ID: 3b3be000f782e38c768282f6a2f4281b39ff406cfe890cad9744d7f0a74ec661"
    echo "   - Client Secret: [your client secret]"
    echo "   - Account ID: tstdrv1870144"
    echo "   - Redirect URI: fieldpay://callback"
    echo "3. Click 'Connect to NetSuite'"
    echo "4. Watch the logs below for OAuth flow"
    echo ""
    
    # Start monitoring
    monitor_logs
}

# Handle script arguments
case "${1:-}" in
    "clear")
        clear_app_data
        ;;
    "launch")
        launch_app
        ;;
    "config")
        test_oauth_config
        ;;
    "monitor")
        monitor_logs
        ;;
    *)
        main
        ;;
esac 