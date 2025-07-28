#!/usr/bin/env python3
"""
Quick NetSuite API Test - OAuth 2.0 Version
"""

import requests
import json
import sys
import os

def quick_test():
    print("🔍 Quick NetSuite API Test (OAuth 2.0)")
    print("=" * 45)
    
    # Get credentials
    account_id = input("Enter NetSuite Account ID: ").strip()
    
    if not account_id:
        print("❌ Missing Account ID")
        return
    
    # For OAuth, we need to check if the app has stored tokens
    print("\n🔐 Checking OAuth tokens...")
    print("Note: This test assumes you've completed OAuth flow in the app")
    print("If you haven't, please complete OAuth authentication in the app first")
    
    # Test connection using OAuth endpoint
    print("\n🔗 Testing OAuth connection...")
    url = f"https://{account_id}.restlets.api.netsuite.com/rest/platform/v1/record/customer"
    
    # For OAuth testing, we need the access token from the app
    print("\n📱 To get your access token:")
    print("1. Open the FieldPay app")
    print("2. Go to Settings → OAuth Troubleshooting")
    print("3. Copy the Access Token value")
    
    access_token = input("\nEnter Access Token from app: ").strip()
    
    if not access_token:
        print("❌ Missing access token")
        return
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    try:
        print(f"\n🌐 Making request to: {url}")
        response = requests.get(url, headers=headers, timeout=10)
        print(f"✅ Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Response received: {len(str(data))} characters")
            print(f"📊 Response keys: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
            
            # Check for customers
            if 'records' in data:
                print(f"👥 Found {len(data['records'])} customers")
                if data['records']:
                    print(f"📝 First customer: {data['records'][0].get('companyName', 'N/A')}")
            elif 'items' in data:
                print(f"👥 Found {len(data['items'])} customers")
                if data['items']:
                    print(f"📝 First customer: {data['items'][0].get('companyName', 'N/A')}")
            else:
                print("⚠️  No customer records found in response")
                print("🔍 Response structure:")
                print(json.dumps(data, indent=2)[:500] + "...")
                
        elif response.status_code == 401:
            print("❌ Authentication failed - OAuth token may be expired")
            print("💡 Try refreshing the token in the app")
        elif response.status_code == 403:
            print("❌ Permission denied - check your NetSuite permissions")
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text[:200]}...")
            
    except requests.exceptions.Timeout:
        print("❌ Request timed out")
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
    except json.JSONDecodeError:
        print("❌ Invalid JSON response")
        print(f"Raw response: {response.text[:200]}...")

if __name__ == "__main__":
    quick_test() 