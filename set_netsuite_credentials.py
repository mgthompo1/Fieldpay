#!/usr/bin/env python3
"""
Set NetSuite OAuth Credentials in UserDefaults
This script manually sets the NetSuite OAuth credentials for testing.
"""

import subprocess
import sys
import time
from datetime import datetime

def set_netsuite_credentials():
    """Set NetSuite OAuth credentials in UserDefaults."""
    
    print("🔧 Setting NetSuite OAuth Credentials")
    print("=" * 50)
    
    # NetSuite OAuth credentials (from your previous setup)
    credentials = {
        "netsuite_client_id": "2ada1369bdb25a146faf520ddfd9c88517b2e2a7d09383e2dc0c30e183ebb352",
        "netsuite_client_secret": "51cdefe493f171a859fa6be75add7daab5d7b8b6da16f2f2bfbf1249d51fa71b",
        "netsuite_account_id": "tstdrv1870144",
        "netsuite_redirect_uri": "fieldpay://callback"
    }
    
    print("📝 Setting NetSuite credentials in UserDefaults...")
    
    for key, value in credentials.items():
        print(f"   Setting {key}: {value[:10]}... (length: {len(value)})")
        
        try:
            # Write to UserDefaults
            cmd = [
                "xcrun", "simctl", "spawn", "iPhone 16",
                "defaults", "write", "Fieldpay.fieldpay", key, value
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            print(f"   ✅ {key} set successfully")
            
        except subprocess.CalledProcessError as e:
            print(f"   ❌ Failed to set {key}: {e}")
            print(f"   Error output: {e.stderr}")
            return False
    
    print("\n✅ All NetSuite credentials set successfully!")
    
    # Verify the credentials were set
    print("\n🔍 Verifying credentials...")
    verify_cmd = [
        "xcrun", "simctl", "spawn", "iPhone 16",
        "defaults", "read", "Fieldpay.fieldpay"
    ]
    
    try:
        result = subprocess.run(verify_cmd, capture_output=True, text=True, check=True)
        output = result.stdout
        
        print("📋 Current UserDefaults contents:")
        for line in output.split('\n'):
            if any(key in line for key in credentials.keys()):
                if 'netsuite_client_secret' in line:
                    # Mask the secret for security
                    parts = line.split('=')
                    if len(parts) == 2:
                        value = parts[1].strip()
                        masked_value = value[:10] + "..." if len(value) > 10 else value
                        print(f"   {parts[0].strip()} = {masked_value}")
                else:
                    print(f"   {line}")
        
        print("\n🎉 NetSuite credentials are now ready for OAuth testing!")
        print("\n💡 Next steps:")
        print("1. Run the FieldPay app")
        print("2. Go to Settings")
        print("3. Click 'Connect to NetSuite'")
        print("4. Complete the OAuth flow")
        
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to verify credentials: {e}")
        return False

if __name__ == "__main__":
    print("🚀 NetSuite Credentials Setup Tool")
    print("=" * 50)
    
    success = set_netsuite_credentials()
    
    if success:
        print("\n✅ Setup completed successfully!")
    else:
        print("\n❌ Setup failed!")
        sys.exit(1) 