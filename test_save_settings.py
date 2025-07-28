#!/usr/bin/env python3
"""
Test saving settings to UserDefaults
"""

import subprocess
import sys

def test_save_settings():
    """Test saving some settings to UserDefaults"""
    print("🧪 Testing UserDefaults Save Mechanism")
    print("=" * 40)
    
    # Test saving a simple setting
    try:
        result = subprocess.run([
            'xcrun', 'simctl', 'spawn', 'iPhone 16', 
            'defaults', 'write', 'Fieldpay.fieldpay', 'test_setting', 'test_value'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Successfully saved test setting")
            
            # Now try to read it back
            read_result = subprocess.run([
                'xcrun', 'simctl', 'spawn', 'iPhone 16', 
                'defaults', 'read', 'Fieldpay.fieldpay', 'test_setting'
            ], capture_output=True, text=True)
            
            if read_result.returncode == 0:
                print(f"✅ Successfully read back: {read_result.stdout.strip()}")
            else:
                print(f"❌ Failed to read back: {read_result.stderr}")
                
        else:
            print(f"❌ Failed to save test setting: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

def save_netsuite_settings():
    """Save NetSuite settings manually"""
    print("\n🔧 Manually Saving NetSuite Settings")
    print("=" * 40)
    
    settings = {
        'netsuite_client_id': 'test_client_id',
        'netsuite_client_secret': 'test_client_secret', 
        'netsuite_account_id': 'test_account_id',
        'netsuite_redirect_uri': 'fieldpay://callback'
    }
    
    for key, value in settings.items():
        try:
            result = subprocess.run([
                'xcrun', 'simctl', 'spawn', 'iPhone 16', 
                'defaults', 'write', 'Fieldpay.fieldpay', key, value
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"✅ Saved {key}")
            else:
                print(f"❌ Failed to save {key}: {result.stderr}")
                
        except Exception as e:
            print(f"❌ Error saving {key}: {e}")

def main():
    test_save_settings()
    save_netsuite_settings()
    
    print("\n🔍 Now checking if settings were saved...")
    try:
        result = subprocess.run([
            'xcrun', 'simctl', 'spawn', 'iPhone 16', 
            'defaults', 'read', 'Fieldpay.fieldpay'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ UserDefaults domain exists!")
            print("📋 Contents:")
            print(result.stdout)
        else:
            print(f"❌ UserDefaults domain still doesn't exist: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error reading UserDefaults: {e}")

if __name__ == "__main__":
    main() 