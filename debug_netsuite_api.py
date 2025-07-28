#!/usr/bin/env python3
"""
NetSuite API Debug Script
This script helps debug NetSuite API integration issues by testing API calls directly.
"""

import requests
import json
import sys
from urllib.parse import urlparse

def test_netsuite_api():
    """Test NetSuite API calls to identify issues"""
    
    print("🔍 NetSuite API Debug Script")
    print("=" * 50)
    
    # Get configuration from user
    print("\n📋 Configuration:")
    account_id = input("Enter your NetSuite Account ID: ").strip()
    access_token = input("Enter your NetSuite Access Token: ").strip()
    
    if not account_id or not access_token:
        print("❌ Error: Account ID and Access Token are required")
        return
    
    base_url = f"https://{account_id}.suitetalk.api.netsuite.com"
    
    print(f"\n🌐 Base URL: {base_url}")
    print(f"🔑 Access Token: {access_token[:20]}...")
    
    # Test 1: Connection test
    print("\n🧪 Test 1: Connection Test")
    print("-" * 30)
    
    try:
        # Test with a simple endpoint
        test_url = f"{base_url}/services/rest/record/v1/customer?limit=1"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json"
        }
        
        print(f"📡 Making request to: {test_url}")
        response = requests.get(test_url, headers=headers, timeout=30)
        
        print(f"📊 Response Status: {response.status_code}")
        print(f"📋 Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ Connection successful!")
            try:
                data = response.json()
                print(f"📄 Response data: {json.dumps(data, indent=2)}")
            except json.JSONDecodeError:
                print(f"⚠️  Response is not valid JSON: {response.text}")
        else:
            print(f"❌ Connection failed with status {response.status_code}")
            print(f"📄 Error response: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return
    
    # Test 2: Customer endpoint
    print("\n🧪 Test 2: Customer Endpoint")
    print("-" * 30)
    
    try:
        customer_url = f"{base_url}/services/rest/record/v1/customer"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json"
        }
        
        print(f"📡 Making request to: {customer_url}")
        response = requests.get(customer_url, headers=headers, timeout=30)
        
        print(f"📊 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Customer endpoint successful!")
            try:
                data = response.json()
                print(f"📄 Response structure: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
                
                if isinstance(data, dict):
                    if 'items' in data:
                        print(f"📊 Number of customers: {len(data['items'])}")
                        if data['items']:
                            print(f"📋 First customer: {json.dumps(data['items'][0], indent=2)}")
                    else:
                        print(f"📄 Full response: {json.dumps(data, indent=2)}")
                else:
                    print(f"📄 Response is not a dict: {type(data)}")
                    print(f"📄 Response: {data}")
                    
            except json.JSONDecodeError:
                print(f"⚠️  Response is not valid JSON: {response.text}")
        else:
            print(f"❌ Customer endpoint failed with status {response.status_code}")
            print(f"📄 Error response: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
    
    # Test 3: Invoice endpoint
    print("\n🧪 Test 3: Invoice Endpoint")
    print("-" * 30)
    
    try:
        invoice_url = f"{base_url}/services/rest/record/v1/invoice"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json"
        }
        
        print(f"📡 Making request to: {invoice_url}")
        response = requests.get(invoice_url, headers=headers, timeout=30)
        
        print(f"📊 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Invoice endpoint successful!")
            try:
                data = response.json()
                print(f"📄 Response structure: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
                
                if isinstance(data, dict):
                    if 'items' in data:
                        print(f"📊 Number of invoices: {len(data['items'])}")
                        if data['items']:
                            print(f"📋 First invoice: {json.dumps(data['items'][0], indent=2)}")
                    else:
                        print(f"📄 Full response: {json.dumps(data, indent=2)}")
                else:
                    print(f"📄 Response is not a dict: {type(data)}")
                    print(f"📄 Response: {data}")
                    
            except json.JSONDecodeError:
                print(f"⚠️  Response is not valid JSON: {response.text}")
        else:
            print(f"❌ Invoice endpoint failed with status {response.status_code}")
            print(f"📄 Error response: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
    
    # Test 4: Check permissions
    print("\n🧪 Test 4: Permissions Check")
    print("-" * 30)
    
    try:
        # Try to get account information
        account_url = f"{base_url}/services/rest/record/v1/account"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json"
        }
        
        print(f"📡 Making request to: {account_url}")
        response = requests.get(account_url, headers=headers, timeout=30)
        
        print(f"📊 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Account endpoint accessible - good permissions!")
        elif response.status_code == 403:
            print("❌ Permission denied - check your OAuth scopes")
            print("Required scopes: restlets, rest_webservices")
        else:
            print(f"⚠️  Account endpoint returned status {response.status_code}")
            print(f"📄 Response: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")

def main():
    """Main function"""
    print("🚀 Starting NetSuite API Debug...")
    
    try:
        test_netsuite_api()
    except KeyboardInterrupt:
        print("\n⏹️  Debug interrupted by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    
    print("\n🏁 Debug complete!")

if __name__ == "__main__":
    main() 