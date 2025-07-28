#!/usr/bin/env python3
"""
OAuth Debug Monitor for FieldPay iOS App
This script monitors iOS simulator logs to help debug OAuth flow issues.
"""

import subprocess
import sys
import time
import re
from datetime import datetime

def run_log_monitor():
    """Monitor iOS simulator logs for OAuth-related activity."""
    
    print("🔍 FieldPay OAuth Debug Monitor")
    print("=" * 50)
    print("Monitoring iOS simulator logs for OAuth flow...")
    print("Press Ctrl+C to stop monitoring")
    print("=" * 50)
    
    # Command to monitor logs with comprehensive filtering
    cmd = [
        "xcrun", "simctl", "spawn", "iPhone 16", "log", "stream",
        "--predicate", 'process == "fieldpay"',
        "--style", "compact"
    ]
    
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            bufsize=1
        )
        
        # Keywords to look for in OAuth flow
        oauth_keywords = [
            "OAuth", "NetSuite", "token", "authorization", "callback",
            "URL", "Safari", "redirect", "code", "access_token",
            "refresh_token", "error", "ERROR", "Debug", "FRESH",
            "UIOpenURLAction", "SceneClient", "FrontBoard"
        ]
        
        print(f"📱 Monitoring started at {datetime.now().strftime('%H:%M:%S')}")
        print("🔍 Looking for OAuth-related logs...")
        print("-" * 50)
        
        while True:
            line = process.stdout.readline()
            if not line:
                break
                
            # Check if line contains any OAuth-related keywords
            if any(keyword.lower() in line.lower() for keyword in oauth_keywords):
                timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
                print(f"[{timestamp}] {line.strip()}")
                
                # Special highlighting for important events
                if "UIOpenURLAction" in line:
                    print("🔄 OAuth Callback Detected!")
                elif "ERROR" in line or "error" in line:
                    print("❌ Error Detected!")
                elif "token" in line.lower():
                    print("🔑 Token Activity Detected!")
                elif "Safari" in line:
                    print("🌐 Safari Activity Detected!")
                    
    except KeyboardInterrupt:
        print("\n🛑 Monitoring stopped by user")
        if process:
            process.terminate()
    except Exception as e:
        print(f"❌ Error monitoring logs: {e}")
        if process:
            process.terminate()

def check_simulator_status():
    """Check if iPhone 16 simulator is available and running."""
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices"],
            capture_output=True,
            text=True
        )
        
        if "iPhone 16" in result.stdout:
            print("✅ iPhone 16 simulator found")
            return True
        else:
            print("❌ iPhone 16 simulator not found")
            print("Available devices:")
            print(result.stdout)
            return False
            
    except Exception as e:
        print(f"❌ Error checking simulator status: {e}")
        return False

def check_app_installed():
    """Check if FieldPay app is installed on simulator."""
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "listapps", "iPhone 16"],
            capture_output=True,
            text=True
        )
        
        if "Fieldpay.fieldpay" in result.stdout:
            print("✅ FieldPay app found on simulator")
            return True
        else:
            print("❌ FieldPay app not found on simulator")
            return False
            
    except Exception as e:
        print(f"❌ Error checking app installation: {e}")
        return False

def main():
    """Main function to run the OAuth debug monitor."""
    print("🔧 FieldPay OAuth Debug Tool")
    print("=" * 40)
    
    # Check prerequisites
    if not check_simulator_status():
        print("Please ensure iPhone 16 simulator is available")
        sys.exit(1)
        
    if not check_app_installed():
        print("Please ensure FieldPay app is installed on simulator")
        sys.exit(1)
    
    print("\n🚀 Starting OAuth flow monitoring...")
    print("💡 Tips:")
    print("   - Start the OAuth flow in your app")
    print("   - Watch for callback URLs and token exchanges")
    print("   - Look for any error messages")
    print("   - Check Safari redirects")
    print()
    
    run_log_monitor()

if __name__ == "__main__":
    main() 