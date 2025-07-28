# NetSuite API Integration Troubleshooting Guide

This guide helps you identify and fix issues with NetSuite API integration in your FieldPay app.

## 🔍 Quick Diagnostic Steps

### 1. Check OAuth Authentication Status
- Go to **Settings > OAuth Troubleshooting > NetSuite API Debug**
- Check if the OAuth status shows "Authenticated"
- Verify that Access Token and Account ID are displayed

### 2. Test API Connection
- In the NetSuite API Debug view, tap **"Test Connection"**
- This will test basic connectivity to NetSuite

### 3. Test Raw API Calls
- Tap **"Test Raw Customer API"** to see the actual API response
- Tap **"Test Raw Invoice API"** to see the actual API response
- Check the debug output for any error messages

## 🚨 Common Issues and Solutions

### Issue 1: "Not Authenticated" Status

**Symptoms:**
- OAuth status shows "Not Authenticated"
- Access token is missing or empty

**Solutions:**
1. **Clear OAuth Data and Re-authenticate:**
   - Go to Settings > OAuth Troubleshooting > Clear OAuth Data
   - Go to Settings > NetSuite Settings > Connect to NetSuite
   - Complete the OAuth flow again

2. **Check OAuth Configuration:**
   - Verify Client ID, Client Secret, and Account ID are correct
   - Ensure redirect URI is set to `fieldpay://callback`

3. **Check Token Expiry:**
   - NetSuite tokens expire after 1 hour
   - If tokens are expired, you'll need to re-authenticate

### Issue 2: "Request Failed" or HTTP 401/403 Errors

**Symptoms:**
- API calls return 401 (Unauthorized) or 403 (Forbidden)
- Connection test fails

**Solutions:**
1. **Check OAuth Scopes:**
   - Ensure your NetSuite OAuth app has the required scopes:
     - `restlets`
     - `rest_webservices`

2. **Verify Account Permissions:**
   - Check that your NetSuite account has API access enabled
   - Ensure the user has permissions to access customer and invoice records

3. **Check Account ID Format:**
   - Account ID should be the numeric ID (e.g., "1234567")
   - Not the account name or URL

### Issue 3: "Invalid Response" or JSON Parsing Errors

**Symptoms:**
- API calls succeed but data parsing fails
- Empty customer/invoice lists
- JSON decoding errors

**Solutions:**
1. **Check API Response Format:**
   - Use the "Test Raw API" buttons to see actual response format
   - Verify the response matches expected NetSuite API format

2. **Check Data Availability:**
   - Ensure your NetSuite account has customer and invoice data
   - Check if records are marked as inactive or deleted

3. **Verify API Endpoints:**
   - Customer endpoint: `/services/rest/record/v1/customer`
   - Invoice endpoint: `/services/rest/record/v1/invoice`

### Issue 4: Network Connectivity Issues

**Symptoms:**
- Timeout errors
- DNS resolution failures
- Network connection errors

**Solutions:**
1. **Check Internet Connection:**
   - Ensure device has stable internet connection
   - Try on different network (WiFi vs cellular)

2. **Check NetSuite Service Status:**
   - Visit NetSuite status page for any service issues
   - Try accessing NetSuite web interface

3. **Check Firewall/Proxy:**
   - Ensure no firewall blocking API calls
   - Check if corporate network allows API access

## 🔧 Advanced Debugging

### Using the Python Debug Script

1. **Install Python and requests:**
   ```bash
   pip install requests
   ```

2. **Run the debug script:**
   ```bash
   python3 debug_netsuite_api.py
   ```

3. **Enter your credentials when prompted:**
   - Account ID (numeric)
   - Access Token (from OAuth flow)

4. **Review the output:**
   - Check response status codes
   - Examine response headers
   - Verify response data format

### Using Xcode Console

1. **Open Xcode and run the app**
2. **Open Debug Console (View > Debug Area > Activate Console)**
3. **Look for debug messages starting with:**
   - `🔍 DEBUG: NetSuiteAPI`
   - `🟢 DEBUG: NetSuiteAPI`
   - `🔴 DEBUG: NetSuiteAPI`

### Using Safari Web Inspector (for OAuth)

1. **Enable Web Inspector in Safari:**
   - Safari > Preferences > Advanced > Show Develop menu
   - Safari > Develop > Simulator > [Your App]

2. **Monitor OAuth flow:**
   - Check for redirect URLs
   - Monitor network requests
   - Look for error messages

## 📋 Checklist for Resolution

- [ ] OAuth authentication is successful
- [ ] Access token is valid and not expired
- [ ] Account ID is correct (numeric format)
- [ ] OAuth scopes include `restlets` and `rest_webservices`
- [ ] NetSuite account has API access enabled
- [ ] User has permissions to access customer/invoice records
- [ ] Network connectivity is stable
- [ ] API endpoints are accessible
- [ ] Response format matches expected structure
- [ ] Data exists in NetSuite account

## 🆘 Getting Help

If you're still experiencing issues:

1. **Collect Debug Information:**
   - Screenshot of NetSuite API Debug view
   - Copy debug output from the app
   - Note any error messages

2. **Check NetSuite Documentation:**
   - [NetSuite REST API Guide](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/article_159266391391.html)
   - [OAuth 2.0 Setup Guide](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/article_159266391391.html)

3. **Contact Support:**
   - Include debug information
   - Describe the specific issue
   - Mention steps already tried

## 🔄 Testing After Fixes

After implementing fixes:

1. **Clear OAuth data and re-authenticate**
2. **Test connection in debug view**
3. **Try fetching customers and invoices**
4. **Check that data appears in the main app**
5. **Verify data is accurate and complete**

## 📝 Common NetSuite API Response Formats

### Successful Customer Response:
```json
{
  "links": [...],
  "count": 10,
  "hasMore": false,
  "offset": 0,
  "items": [
    {
      "id": "123",
      "entityId": "CUST123",
      "companyName": "Acme Corp",
      "firstName": "John",
      "lastName": "Doe",
      "email": "john@acme.com",
      "phone": "555-1234"
    }
  ]
}
```

### Successful Invoice Response:
```json
{
  "links": [...],
  "count": 5,
  "hasMore": false,
  "offset": 0,
  "items": [
    {
      "id": "456",
      "tranId": "INV-001",
      "entity": {"id": "123", "refName": "Acme Corp"},
      "tranDate": "2025-01-15",
      "total": 1000.00,
      "balance": 1000.00,
      "status": "pending"
    }
  ]
}
```

### Error Response:
```json
{
  "error": {
    "code": "INVALID_LOGIN",
    "title": "Invalid Login",
    "message": "Invalid login credentials"
  }
}
``` 