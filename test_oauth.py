#!/usr/bin/env python3
"""
Test script to generate and validate NetSuite OAuth URLs
"""

import urllib.parse
from urllib.parse import urlparse

def test_oauth_url():
    # Configuration
    account_id = "1234567"  # Replace with your actual account ID
    client_id = "your_client_id_here"  # Replace with your actual client ID
    redirect_uri = "fieldpay://callback"  # Updated to match OAuthManager
    scope = "restlets rest_webservices"
    state = "test_state_123"
    code_challenge = "test_challenge"
    code_challenge_method = "S256"
    
    # NetSuite OAuth 2.0 authorization endpoint
    base_url = f"https://{account_id}.app.netsuite.com/app/login/oauth2/authorize.nl"
    
    # Build query parameters
    params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "scope": scope,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": code_challenge_method
    }
    
    # Construct full URL
    query_string = urllib.parse.urlencode(params)
    full_url = f"{base_url}?{query_string}"
    
    print("=== NetSuite OAuth URL Test ===")
    print(f"Account ID: {account_id}")
    print(f"Client ID: {client_id}")
    print(f"Redirect URI: {redirect_uri}")
    print(f"Base URL: {base_url}")
    print(f"Full OAuth URL: {full_url}")
    
    # Parse and analyze the URL
    parsed = urlparse(full_url)
    print("\n=== URL Analysis ===")
    print(f"Scheme: {parsed.scheme}")
    print(f"Netloc: {parsed.netloc}")
    print(f"Path: {parsed.path}")
    print(f"Query: {parsed.query}")
    
    # Check for common issues
    print("\n=== Common Issues Check ===")
    if not account_id or account_id == "1234567":
        print("❌ Account ID is missing or using placeholder value")
    else:
        print("✅ Account ID looks valid")
        
    if not client_id or client_id == "your_client_id_here":
        print("❌ Client ID is missing or using placeholder value")
    else:
        print("✅ Client ID looks valid")
        
    if redirect_uri.startswith("fieldpay://"):
        print("✅ Redirect URI format looks correct")
    else:
        print("❌ Redirect URI format may be incorrect")
    
    print("\n=== Recommendations ===")
    print("1. Make sure your NetSuite account ID is correct")
    print("2. Verify your Client ID and Client Secret in NetSuite")
    print("3. Check that the redirect URI matches exactly in NetSuite app settings")
    print("4. For sandbox testing, use sandbox URLs")
    print("5. Ensure your NetSuite app has the correct scopes enabled")
    
    # Test token exchange URL
    token_url = f"https://{account_id}.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token"
    print(f"\n=== Token Exchange URL Test ===")
    print(f"Token URL: {token_url}")
    
    print("\n=== Next Steps ===")
    print("1. Update the credentials in this script with your actual values")
    print("2. Run the script to verify URL generation")
    print("3. Test the generated URL in a browser")
    print("4. Check the iOS app logs for OAuth callback handling")

if __name__ == "__main__":
    test_oauth_url() 