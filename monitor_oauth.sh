#!/bin/bash

# Focused OAuth Monitoring Script
# This script monitors specific OAuth events to help debug the flow

echo "🔍 FieldPay OAuth Flow Monitor"
echo "=============================="
echo "Monitoring specific OAuth events..."
echo "Press Ctrl+C to stop"
echo ""

# Function to highlight important events
highlight_event() {
    local event_type=$1
    local message=$2
    case $event_type in
        "callback")
            echo "🔄 OAuth Callback: $message"
            ;;
        "error")
            echo "❌ Error: $message"
            ;;
        "token")
            echo "🔑 Token Event: $message"
            ;;
        "safari")
            echo "🌐 Safari Event: $message"
            ;;
        "debug")
            echo "🐛 Debug: $message"
            ;;
        *)
            echo "ℹ️  Info: $message"
            ;;
    esac
}

# Monitor logs with specific event detection
xcrun simctl spawn "iPhone 16" log stream \
    --predicate 'process == "fieldpay"' \
    --style compact | while IFS= read -r line; do
    
    # Check for specific OAuth events
    if echo "$line" | grep -q "UIOpenURLAction"; then
        highlight_event "callback" "URL action received - OAuth callback detected"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "SceneClient.*Received action.*UIOpenURLAction"; then
        highlight_event "callback" "Scene client received URL action"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "Debug.*OAuth"; then
        highlight_event "debug" "OAuth debug message"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "ERROR\|error"; then
        highlight_event "error" "Error detected"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "token"; then
        highlight_event "token" "Token-related activity"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "Safari"; then
        highlight_event "safari" "Safari-related activity"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "FRESH"; then
        highlight_event "debug" "Fresh OAuth flow detected"
        echo "   Raw: $line"
    elif echo "$line" | grep -q "C1"; then
        highlight_event "debug" "Network connection activity"
        echo "   Raw: $line"
    fi
done 