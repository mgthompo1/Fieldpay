#!/bin/bash

echo "=== Safari Web Inspector Setup ==="
echo ""

# Enable Safari developer features
echo "Enabling Safari developer features..."
xcrun simctl spawn "iPhone 16" defaults write com.apple.Safari WebKitDeveloperExtras -bool true
xcrun simctl spawn "iPhone 16" defaults write com.apple.Safari IncludeDevelopMenu -bool true
xcrun simctl spawn "iPhone 16" defaults write com.apple.Safari WebKitDeveloperExtras -bool true

echo "Safari developer features enabled!"
echo ""
echo "To access Safari Web Inspector:"
echo "1. Open Safari in the simulator"
echo "2. Go to Develop menu (if not visible, go to Safari > Settings > Advanced > Show Develop menu)"
echo "3. Select 'Simulator' > 'fieldpay' to open Web Inspector"
echo ""
echo "Alternative method:"
echo "1. Open Safari in simulator"
echo "2. Go to the OAuth page"
echo "3. Right-click and select 'Inspect Element'"
echo "4. Check the Console tab for errors"
echo ""
echo "You can also use the monitor_oauth.sh script to watch logs in real-time." 