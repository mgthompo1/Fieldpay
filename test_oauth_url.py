#!/usr/bin/env python3
"""
Test script to validate NetSuite OAuth authorization URL generation
"""

import urllib.parse
import hashlib
import base64
import secrets
import string

def generate_code_verifier():
    """Generate a random code verifier for PKCE"""
    allowed_chars = string.ascii_letters + string.digits + '-._~'
    length = secrets.randbelow(86) + 43  # 43-128 characters
    return ''.join(secrets.choice(allowed_chars) for _ in range(length))

def generate_code_challenge(code_verifier):
    """Generate code challenge from code verifier using SHA256"""
    sha256_hash = hashlib.sha256(code_verifier.encode('utf-8')).digest()
    return base64.urlsafe_b64encode(sha256_hash).decode('utf-8').rstrip('=')

def generate_state():
    """Generate a random state parameter"""
    import time
    timestamp = int(time.time())
    return f"{secrets.token_urlsafe(16)}_{timestamp}"

def build_authorization_url(account_id, client_id, redirect_uri):
    """Build NetSuite OAuth 2.0 authorization URL"""
    
    # Generate PKCE parameters
    code_verifier = generate_code_verifier()
    code_challenge = generate_code_challenge(code_verifier)
    state = generate_state()
    
    # Base URL
    base_url = f"https://{account_id}.app.netsuite.com/app/login/oauth2/authorize.nl"
    
    # Query parameters
    params = {
        'response_type': 'code',
        'client_id': client_id,
        'redirect_uri': redirect_uri,
        'scope': 'restlets rest_webservices',
        'state': state,
        'code_challenge': code_challenge,
        'code_challenge_method': 'S256'
    }
    
    # Build URL
    query_string = urllib.parse.urlencode(params)
    auth_url = f"{base_url}?{query_string}"
    
    return auth_url, code_verifier, state

def validate_url(url):
    """Validate the generated authorization URL"""
    try:
        parsed = urllib.parse.urlparse(url)
        
        # Check scheme
        if parsed.scheme != 'https':
            return False, "URL must use HTTPS"
        
        # Check domain
        if 'netsuite.com' not in parsed.netloc:
            return False, "URL must be a NetSuite domain"
        
        # Check path
        if not parsed.path.endswith('/app/login/oauth2/authorize.nl'):
            return False, "Invalid authorization endpoint path"
        
        # Check required parameters
        query_params = urllib.parse.parse_qs(parsed.query)
        required_params = ['response_type', 'client_id', 'redirect_uri', 'scope', 'state', 'code_challenge', 'code_challenge_method']
        
        for param in required_params:
            if param not in query_params:
                return False, f"Missing required parameter: {param}"
        
        # Check specific parameter values
        if query_params['response_type'][0] != 'code':
            return False, "response_type must be 'code'"
        
        if query_params['code_challenge_method'][0] != 'S256':
            return False, "code_challenge_method must be 'S256'"
        
        if query_params['scope'][0] != 'restlets rest_webservices':
            return False, "scope must be 'restlets rest_webservices'"
        
        return True, "URL is valid"
        
    except Exception as e:
        return False, f"URL validation error: {str(e)}"

def main():
    """Main test function"""
    print("=== NetSuite OAuth Authorization URL Test ===\n")
    
    # Test parameters (replace with actual values)
    account_id = "123456"  # Replace with actual NetSuite account ID
    client_id = "test_client_id"  # Replace with actual client ID
    redirect_uri = "fieldpay://callback"
    
    print(f"Test Parameters:")
    print(f"  Account ID: {account_id}")
    print(f"  Client ID: {client_id}")
    print(f"  Redirect URI: {redirect_uri}")
    print()
    
    # Generate authorization URL
    auth_url, code_verifier, state = build_authorization_url(account_id, client_id, redirect_uri)
    
    print(f"Generated Authorization URL:")
    print(f"  {auth_url}")
    print()
    
    print(f"PKCE Parameters:")
    print(f"  Code Verifier: {code_verifier[:20]}... (length: {len(code_verifier)})")
    print(f"  Code Challenge: {code_verifier[:20]}... (length: {len(code_verifier)})")
    print(f"  State: {state}")
    print()
    
    # Validate URL
    is_valid, message = validate_url(auth_url)
    print(f"URL Validation: {'✅ PASS' if is_valid else '❌ FAIL'}")
    print(f"  {message}")
    print()
    
    # Test URL parsing
    parsed = urllib.parse.urlparse(auth_url)
    query_params = urllib.parse.parse_qs(parsed.query)
    
    print(f"URL Components:")
    print(f"  Scheme: {parsed.scheme}")
    print(f"  Netloc: {parsed.netloc}")
    print(f"  Path: {parsed.path}")
    print(f"  Query Parameters:")
    for key, values in query_params.items():
        print(f"    {key}: {values[0]}")
    
    print()
    print("=== Test Complete ===")

if __name__ == "__main__":
    main() 