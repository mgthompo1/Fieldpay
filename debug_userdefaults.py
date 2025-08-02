#!/usr/bin/env python3
"""
UserDefaults Debug Monitor for FieldPay iOS App
This script monitors iOS simulator logs to help debug UserDefaults storage issues.
"""

import subprocess
import sys
import time
import re
from datetime import datetime

def run_userdefaults_monitor():
    """Monitor iOS simulator logs for UserDefaults-related activity."""
    
    print("🔍 FieldPay UserDefaults Debug Monitor")
    print("=" * 50)
    print("Monitoring iOS simulator logs for UserDefaults storage...")
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
        
        # Keywords to look for in UserDefaults operations
        userdefaults_keywords = [
            "UserDefaults", "netsuite_access_token", "netsuite_refresh_token", 
            "netsuite_token_expiry", "netsuite_client_id", "netsuite_client_secret",
            "netsuite_account_id", "netsuite_redirect_uri", "netsuite_code_verifier",
            "netsuite_oauth_state", "storeTokens", "loadStoredTokens", 
            "clearStoredTokens", "updateConfiguration", "configure",
            "Debug.*save", "Debug.*load", "Debug.*store", "Debug.*clear",
            "Debug.*UserDefaults", "Debug.*token", "Debug.*configured",
            "Debug.*OAuthManager", "Debug.*NetSuiteAPI", "Debug.*isConfigured"
        ]
        
        print(f"📱 Monitoring started at {datetime.now().strftime('%H:%M:%S')}")
        print("🔍 Looking for UserDefaults-related logs...")
        print("-" * 50)
        
        while True:
            line = process.stdout.readline()
            if not line:
                break
                
            # Check if line contains any UserDefaults-related keywords
            if any(keyword.lower() in line.lower() for keyword in userdefaults_keywords):
                timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
                print(f"[{timestamp}] {line.strip()}")
                
                # Special highlighting for important events
                if "storeTokens" in line:
                    print("💾 Token Storage Detected!")
                elif "loadStoredTokens" in line:
                    print("📂 Token Loading Detected!")
                elif "clearStoredTokens" in line:
                    print("🗑️ Token Clearing Detected!")
                elif "netsuite_access_token" in line:
                    print("🔑 Access Token Operation Detected!")
                elif "netsuite_refresh_token" in line:
                    print("🔄 Refresh Token Operation Detected!")
                elif "isConfigured" in line:
                    print("⚙️ Configuration Check Detected!")
                elif "ERROR" in line or "error" in line:
                    print("❌ Error Detected!")
                elif "✅" in line:
                    print("✅ Success Detected!")
                elif "❌" in line:
                    print("❌ Failure Detected!")
                    
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
    """Main function to run the UserDefaults debug monitor."""
    print("🔧 FieldPay UserDefaults Debug Tool")
    print("=" * 40)
    
    # Check prerequisites
    if not check_simulator_status():
        print("Please ensure iPhone 16 simulator is available")
        sys.exit(1)
        
    if not check_app_installed():
        print("Please ensure FieldPay app is installed on simulator")
        sys.exit(1)
    
    print("\n🚀 Starting UserDefaults monitoring...")
    print("💡 Tips:")
    print("   - Start the OAuth flow in your app")
    print("   - Watch for token storage and retrieval operations")
    print("   - Look for configuration status checks")
    print("   - Check for any storage errors")
    print()
    
    run_userdefaults_monitor()

if __name__ == "__main__":
    main() 