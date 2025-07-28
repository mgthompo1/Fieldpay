#!/usr/bin/env python3
"""
Debug UserDefaults for NetSuite Configuration
"""

import subprocess
import json
import sys

def get_userdefaults():
    """Get UserDefaults for the FieldPay app"""
    try:
        # Get UserDefaults for the app
        result = subprocess.run([
            'xcrun', 'simctl', 'spawn', 'iPhone 16', 
            'defaults', 'read', 'Fieldpay.fieldpay'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            return result.stdout
        else:
            print(f"Error reading UserDefaults: {result.stderr}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def main():
    print("🔍 Debugging NetSuite UserDefaults Configuration")
    print("=" * 50)
    
    # Get UserDefaults
    defaults = get_userdefaults()
    
    if defaults:
        print("📋 UserDefaults Content:")
        print(defaults)
        
        # Look for NetSuite specific keys
        netsuite_keys = [
            'netsuite_account_id',
            'netsuite_client_id', 
            'netsuite_client_secret',
            'netsuite_access_token',
            'netsuite_refresh_token'
        ]
        
        print("\n🔍 NetSuite Configuration Check:")
        for key in netsuite_keys:
            if key in defaults:
                print(f"✅ {key}: Found")
            else:
                print(f"❌ {key}: Not found")
    else:
        print("❌ Could not read UserDefaults")
        print("\n💡 Try these steps:")
        print("1. Make sure the app is running in the simulator")
        print("2. Go to Settings → NetSuite Settings")
        print("3. Enter your Account ID and save")
        print("4. Run this script again")

if __name__ == "__main__":
    main() 