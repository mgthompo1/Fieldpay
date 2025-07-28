#!/usr/bin/env python3
"""
Test NetSuite OAuth URL Generation
This script helps debug OAuth URL issues.
"""

import urllib.parse
import json

def test_oauth_url():
    """Test OAuth URL generation with sample credentials"""
    
    # Sample NetSuite credentials (replace with actual values)
    account_id = "1234567"  # Replace with actual account ID
    client_id = "your_client_id_here"  # Replace with actual client ID
    redirect_uri = "fieldpay://oauth/callback"
    
    # Generate OAuth authorization URL
    base_url = f"https://{account_id}.app.netsuite.com/app/login/oauth2/authorize.nl"
    
    params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "scope": "restlets rest_webservices",
        "state": "test-state-123",
        "code_challenge": "test-code-challenge",
        "code_challenge_method": "S256"
    }
    
    # Build URL with parameters
    query_string = urllib.parse.urlencode(params)
    full_url = f"{base_url}?{query_string}"
    
    print("=== NetSuite OAuth URL Test ===")
    print(f"Account ID: {account_id}")
    print(f"Client ID: {client_id}")
    print(f"Redirect URI: {redirect_uri}")
    print(f"Base URL: {base_url}")
    print(f"Full OAuth URL: {full_url}")
    print()
    
    # Test URL parsing
    parsed_url = urllib.parse.urlparse(full_url)
    print("=== URL Analysis ===")
    print(f"Scheme: {parsed_url.scheme}")
    print(f"Netloc: {parsed_url.netloc}")
    print(f"Path: {parsed_url.path}")
    print(f"Query: {parsed_url.query}")
    print()
    
    # Test redirect URI parsing
    redirect_parsed = urllib.parse.urlparse(redirect_uri)
    print("=== Redirect URI Analysis ===")
    print(f"Scheme: {redirect_parsed.scheme}")
    print(f"Netloc: {redirect_parsed.netloc}")
    print(f"Path: {redirect_parsed.path}")
    print()
    
    # Check for potential issues
    print("=== Potential Issues ===")
    
    if not account_id or account_id == "1234567":
        print("⚠️  WARNING: Using placeholder account ID")
    
    if not client_id or client_id == "your_client_id_here":
        print("⚠️  WARNING: Using placeholder client ID")
    
    if redirect_parsed.scheme != "fieldpay":
        print("⚠️  WARNING: Redirect URI scheme doesn't match URL scheme")
    
    if not redirect_parsed.path.startswith("/oauth/callback"):
        print("⚠️  WARNING: Redirect URI path format may be incorrect")
    
    print()
    print("=== Recommendations ===")
    print("1. Ensure account_id is your actual NetSuite account number")
    print("2. Ensure client_id is your actual NetSuite client ID")
    print("3. Verify redirect_uri matches your app's URL scheme")
    print("4. Check that the redirect URI is registered in NetSuite")

if __name__ == "__main__":
    test_oauth_url() 