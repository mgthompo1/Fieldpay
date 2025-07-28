import Foundation
import Combine
import CryptoKit

@MainActor
class OAuthManager: ObservableObject {
    static let shared = OAuthManager()
    
    private var clientId: String = ""
    private var clientSecret: String = ""
    private var redirectUri: String = "fieldpay://callback"
    private var accountId: String = ""
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var refreshToken: String?
    
    private init() {
        // Load from UserDefaults if available
        loadConfiguration()
        
        // Load stored tokens if available
        Task {
            await loadStoredTokens()
        }
    }
    
    // MARK: - Configuration
    func updateConfiguration(clientId: String, clientSecret: String, accountId: String, redirectUri: String = "fieldpay://callback") {
        print("Debug: ===== updateConfiguration() called =====")
        print("Debug: Client ID: \(clientId.prefix(10))... (length: \(clientId.count))")
        print("Debug: Client Secret: \(clientSecret.prefix(10))... (length: \(clientSecret.count))")
        print("Debug: Account ID: \(accountId)")
        print("Debug: Redirect URI: \(redirectUri)")
        
        // Validate input parameters
        guard !clientId.isEmpty else {
            print("Debug: ERROR - Client ID is empty")
            return
        }
        
        guard !clientSecret.isEmpty else {
            print("Debug: ERROR - Client Secret is empty")
            return
        }
        
        guard !accountId.isEmpty else {
            print("Debug: ERROR - Account ID is empty")
            return
        }
        
        guard redirectUri.hasPrefix("fieldpay://") else {
            print("Debug: ERROR - Invalid redirect URI format")
            return
        }
        
        // Validate account ID format (should be numeric for production, alphanumeric for sandbox)
        let accountIdCharacterSet = CharacterSet.alphanumerics
        guard accountId.rangeOfCharacter(from: accountIdCharacterSet.inverted) == nil else {
            print("Debug: ERROR - Account ID should contain only alphanumeric characters")
            return
        }
        
        // Validate client ID format (should be alphanumeric)
        let clientIdCharacterSet = CharacterSet.alphanumerics
        guard clientId.rangeOfCharacter(from: clientIdCharacterSet.inverted) == nil else {
            print("Debug: ERROR - Client ID should contain only alphanumeric characters")
            return
        }
        
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.accountId = accountId
        self.redirectUri = redirectUri
        
        // Store in UserDefaults
        UserDefaults.standard.set(clientId, forKey: "netsuite_client_id")
        UserDefaults.standard.set(clientSecret, forKey: "netsuite_client_secret")
        UserDefaults.standard.set(accountId, forKey: "netsuite_account_id")
        UserDefaults.standard.set(redirectUri, forKey: "netsuite_redirect_uri")
        
        // Verify configuration was stored correctly
        let storedClientId = UserDefaults.standard.string(forKey: "netsuite_client_id")
        let storedClientSecret = UserDefaults.standard.string(forKey: "netsuite_client_secret")
        let storedAccountId = UserDefaults.standard.string(forKey: "netsuite_account_id")
        let storedRedirectUri = UserDefaults.standard.string(forKey: "netsuite_redirect_uri")
        
        print("Debug: Configuration storage verification:")
        print("Debug: Client ID stored: \(storedClientId != nil)")
        print("Debug: Client Secret stored: \(storedClientSecret != nil)")
        print("Debug: Account ID stored: \(storedAccountId != nil)")
        print("Debug: Redirect URI stored: \(storedRedirectUri != nil)")
        
        print("Debug: ✅ OAuth configuration updated successfully")
        print("OAuth configured for NetSuite account: \(accountId)")
    }
    
    // MARK: - Configuration Validation
    func validateOAuthConfiguration() -> Bool {
        print("Debug: ===== validateOAuthConfiguration() called =====")
        
        // Check if all required fields are present
        let hasClientId = !clientId.isEmpty
        let hasClientSecret = !clientSecret.isEmpty
        let hasAccountId = !accountId.isEmpty
        let hasRedirectUri = !redirectUri.isEmpty && redirectUri.hasPrefix("fieldpay://")
        
        print("Debug: Configuration validation:")
        print("Debug: - Client ID present: \(hasClientId)")
        print("Debug: - Client Secret present: \(hasClientSecret)")
        print("Debug: - Account ID present: \(hasAccountId)")
        print("Debug: - Redirect URI valid: \(hasRedirectUri)")
        
        // Validate account ID format
        let accountIdValid = accountId.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
        print("Debug: - Account ID format valid: \(accountIdValid)")
        
        // Validate client ID format
        let clientIdValid = clientId.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
        print("Debug: - Client ID format valid: \(clientIdValid)")
        
        let isValid = hasClientId && hasClientSecret && hasAccountId && hasRedirectUri && accountIdValid && clientIdValid
        
        print("Debug: Overall configuration valid: \(isValid)")
        
        if !isValid {
            print("Debug: ❌ OAuth configuration validation failed")
            if !hasClientId { print("Debug:   - Missing Client ID") }
            if !hasClientSecret { print("Debug:   - Missing Client Secret") }
            if !hasAccountId { print("Debug:   - Missing Account ID") }
            if !hasRedirectUri { print("Debug:   - Invalid Redirect URI") }
            if !accountIdValid { print("Debug:   - Invalid Account ID format") }
            if !clientIdValid { print("Debug:   - Invalid Client ID format") }
        } else {
            print("Debug: ✅ OAuth configuration validation passed")
        }
        
        return isValid
    }
    
    private func loadConfiguration() {
        print("Debug: OAuthManager.loadConfiguration() called")
        
        clientId = UserDefaults.standard.string(forKey: "netsuite_client_id") ?? ""
        clientSecret = UserDefaults.standard.string(forKey: "netsuite_client_secret") ?? ""
        accountId = UserDefaults.standard.string(forKey: "netsuite_account_id") ?? ""
        redirectUri = UserDefaults.standard.string(forKey: "netsuite_redirect_uri") ?? "fieldpay://callback"
        
        print("Debug: Loaded configuration:")
        print("Debug: - clientId: '\(clientId)' (length: \(clientId.count))")
        print("Debug: - clientSecret: '\(clientSecret)' (length: \(clientSecret.count))")
        print("Debug: - accountId: '\(accountId)' (length: \(accountId.count))")
        print("Debug: - redirectUri: '\(redirectUri)'")
    }
    
    // MARK: - PKCE Helper Functions
    private func generateCodeVerifier() -> String {
        let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let length = Int.random(in: 43...128)
        return String((0..<length).map { _ in allowedCharacters.randomElement()! })
    }
    
    private func generateCodeChallenge(from codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateState() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(UUID().uuidString)_\(timestamp)"
    }
    
    // MARK: - OAuth Flow
    func startOAuthFlow() async throws -> String {
        print("Debug: OAuthManager.startOAuthFlow() called - FRESH OAuth Flow")
        print("Debug: clientId: '\(clientId)' (length: \(clientId.count))")
        print("Debug: accountId: '\(accountId)' (length: \(accountId.count))")
        print("Debug: redirectUri: '\(redirectUri)'")
        
        // Validate OAuth configuration first
        guard validateOAuthConfiguration() else {
            print("Debug: ERROR - OAuth configuration validation failed")
            throw OAuthError.notConfigured
        }
        
        // Check if we already have valid tokens and are authenticated
        if isAuthenticated {
            print("Debug: Already authenticated, skipping OAuth flow")
            return "Already authenticated"
        }
        
        // Only clear tokens if we're not already authenticated
        print("Debug: Clearing stored tokens for fresh OAuth flow")
        await clearStoredTokens()
        
        // Generate PKCE challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = generateState()
        
        // Store PKCE and state for verification
        let userDefaults = UserDefaults.standard
        userDefaults.set(codeVerifier, forKey: "netsuite_code_verifier")
        userDefaults.set(state, forKey: "netsuite_oauth_state")
        
        print("Debug: Generated PKCE parameters:")
        print("Debug: - Code verifier: \(codeVerifier.prefix(10))... (length: \(codeVerifier.count))")
        print("Debug: - Code challenge: \(codeChallenge.prefix(10))... (length: \(codeChallenge.count))")
        print("Debug: - State: \(state)")
        
        // Build authorization URL according to NetSuite OAuth 2.0 specification
        // Format: https://{account-id}.app.netsuite.com/app/login/oauth2/authorize.nl
        let baseURL = "https://\(accountId).app.netsuite.com/app/login/oauth2/authorize.nl"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: "restlets rest_webservices"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authURL = components.url else {
            print("Debug: ERROR - Failed to construct authorization URL")
            print("Debug: Base URL: \(baseURL)")
            print("Debug: Query items: \(components.queryItems ?? [])")
            throw OAuthError.invalidURL
        }
        
        print("Debug: ✅ Generated OAuth authorization URL successfully")
        print("Debug: Authorization URL: \(authURL)")
        print("Debug: URL components:")
        print("Debug: - Base URL: \(baseURL)")
        print("Debug: - Response type: code")
        print("Debug: - Client ID: \(clientId.prefix(10))...")
        print("Debug: - Redirect URI: \(redirectUri)")
        print("Debug: - Scope: restlets rest_webservices")
        print("Debug: - State: \(state)")
        print("Debug: - Code challenge method: S256")
        print("Debug: - Code challenge: \(codeChallenge.prefix(10))...")
        
        // Validate the URL format
        guard authURL.scheme == "https" else {
            print("Debug: ERROR - Authorization URL must use HTTPS")
            throw OAuthError.invalidURL
        }
        
        guard authURL.host?.contains("netsuite.com") == true else {
            print("Debug: ERROR - Authorization URL must be a NetSuite domain")
            throw OAuthError.invalidURL
        }
        
        print("Debug: ✅ Authorization URL validation passed")
        print("Debug: 🚀 Ready to redirect user to NetSuite OAuth authorization page")
        return authURL.absoluteString
    }
    
    // MARK: - Debug Methods
    func generateAuthorizationURLForDebug() -> String? {
        print("Debug: ===== generateAuthorizationURLForDebug() called =====")
        
        // Validate OAuth configuration first
        guard validateOAuthConfiguration() else {
            print("Debug: ERROR - OAuth configuration validation failed")
            return nil
        }
        
        // Generate PKCE challenge for debug
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = generateState()
        
        print("Debug: Generated debug PKCE parameters:")
        print("Debug: - Code verifier: \(codeVerifier.prefix(10))... (length: \(codeVerifier.count))")
        print("Debug: - Code challenge: \(codeChallenge.prefix(10))... (length: \(codeChallenge.count))")
        print("Debug: - State: \(state)")
        
        // Build authorization URL according to NetSuite OAuth 2.0 specification
        let baseURL = "https://\(accountId).app.netsuite.com/app/login/oauth2/authorize.nl"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: "restlets rest_webservices"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authURL = components.url else {
            print("Debug: ERROR - Failed to construct debug authorization URL")
            return nil
        }
        
        print("Debug: ✅ Generated debug authorization URL successfully")
        print("Debug: Debug Authorization URL: \(authURL)")
        
        return authURL.absoluteString
    }
    
    func handleOAuthCallback(url: URL) async throws {
        print("Debug: ===== OAuthManager.handleOAuthCallback() called =====")
        print("Debug: Handling OAuth callback for URL: \(url)")
        print("Debug: URL absolute string: \(url.absoluteString)")
        print("Debug: URL scheme: \(url.scheme ?? "nil")")
        print("Debug: URL host: \(url.host ?? "nil")")
        print("Debug: URL path: \(url.path)")
        print("Debug: URL query: \(url.query ?? "nil")")
        
        // Verify the callback URL matches our expected redirect URI
        let expectedScheme = "fieldpay"
        let expectedHost = "callback"
        
        guard url.scheme == expectedScheme else {
            print("Debug: ERROR - URL scheme mismatch!")
            print("Debug: Expected scheme: \(expectedScheme)")
            print("Debug: Actual scheme: \(url.scheme ?? "nil")")
            throw OAuthError.invalidCallback
        }
        
        guard url.host == expectedHost else {
            print("Debug: ERROR - URL host mismatch!")
            print("Debug: Expected host: \(expectedHost)")
            print("Debug: Actual host: \(url.host ?? "nil")")
            throw OAuthError.invalidCallback
        }
        
        print("Debug: ✅ Callback URL validation passed")
        print("Debug: Expected redirect URI: \(redirectUri)")
        print("Debug: Actual callback URL: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("Debug: ERROR - Failed to create URLComponents from URL")
            throw OAuthError.invalidCallback
        }
        
        print("Debug: URL components: \(components)")
        print("Debug: Query items: \(components.queryItems ?? [])")
        
        // Check for authorization code - look in query items first
        var code: String?
        if let queryItems = components.queryItems {
            code = queryItems.first(where: { $0.name == "code" })?.value
        }
        
        // If not found in query items, check if the URL itself contains the code
        if code == nil {
            let urlString = url.absoluteString
            if let codeRange = urlString.range(of: "code=") {
                let afterCode = String(urlString[codeRange.upperBound...])
                if let ampersandRange = afterCode.range(of: "&") {
                    code = String(afterCode[..<ampersandRange.lowerBound])
                } else {
                    code = afterCode
                }
                print("Debug: Extracted code from URL string: \(code?.prefix(10) ?? "nil")...")
            }
        }
        
        guard let authorizationCode = code, !authorizationCode.isEmpty else {
            print("Debug: ERROR - No authorization code found in callback URL")
            print("Debug: Available query items: \(components.queryItems?.map { "\($0.name)=\($0.value ?? "")" } ?? [])")
            print("Debug: Full URL string: \(url.absoluteString)")
            throw OAuthError.invalidCallback
        }
        
        print("Debug: Found authorization code: \(authorizationCode.prefix(10))...")
        print("Debug: Authorization code length: \(authorizationCode.count)")
        
        // Check for state parameter (optional but recommended)
        if let state = components.queryItems?.first(where: { $0.name == "state" })?.value {
            print("Debug: Found state parameter: \(state)")
            
            // Verify state matches what we stored
            let storedState = UserDefaults.standard.string(forKey: "netsuite_oauth_state")
            if storedState != state {
                print("Debug: WARNING - State parameter mismatch!")
                print("Debug: Expected state: \(storedState ?? "nil")")
                print("Debug: Actual state: \(state)")
            } else {
                print("Debug: ✅ State parameter validation passed")
            }
        } else {
            print("Debug: No state parameter found in callback")
        }
        
        print("Debug: Proceeding to token exchange...")
        try await exchangeCodeForToken(code: authorizationCode)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        print("Debug: ===== exchangeCodeForToken() called =====")
        print("Debug: Authorization code: \(code.prefix(10))...")
        print("Debug: Account ID: \(accountId)")
        print("Debug: Client ID: \(clientId.prefix(10))...")
        
        // Validate required parameters
        guard !clientId.isEmpty else {
            print("Debug: ERROR - Client ID is empty")
            throw OAuthError.notConfigured
        }
        
        guard !clientSecret.isEmpty else {
            print("Debug: ERROR - Client Secret is empty")
            throw OAuthError.notConfigured
        }
        
        guard !accountId.isEmpty else {
            print("Debug: ERROR - Account ID is empty")
            throw OAuthError.notConfigured
        }
        
        // NetSuite OAuth 2.0 token endpoint - CORRECT FORMAT
        // Format: https://{account-id}.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token
        let url = "https://\(accountId).suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token"
        
        print("Debug: Token endpoint URL: \(url)")
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic Auth with Base64 encoded clientid:clientsecret
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        print("Debug: Authorization header set (credentials length: \(credentials.count))")
        
        // Get the stored code verifier
        let codeVerifier = UserDefaults.standard.string(forKey: "netsuite_code_verifier") ?? ""
        print("Debug: Code verifier from storage: \(codeVerifier.prefix(10))... (length: \(codeVerifier.count))")
        
        // Validate code verifier
        guard !codeVerifier.isEmpty else {
            print("Debug: ERROR - Code verifier is empty or missing")
            throw OAuthError.tokenExchangeFailed
        }
        
        // URL encode the parameters properly
        let bodyParameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "code_verifier": codeVerifier
        ]
        
        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("Debug: Token exchange request URL: \(url)")
        print("Debug: Token exchange request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Debug: Token exchange request body: \(bodyString)")
        
        print("Debug: Sending token exchange request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: ERROR - Token exchange failed - invalid response type")
            throw OAuthError.tokenExchangeFailed
        }
        
        print("Debug: Token exchange response status: \(httpResponse.statusCode)")
        print("Debug: Token exchange response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Debug: Token exchange response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: ERROR - Token exchange failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: Token exchange error response: \(responseString)")
            }
            throw OAuthError.tokenExchangeFailed
        }
        
        // Validate response data
        guard !data.isEmpty else {
            print("Debug: ERROR - Token exchange returned empty response")
            throw OAuthError.tokenExchangeFailed
        }
        
        let tokenResponse: TokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            print("Debug: ERROR - Failed to decode token response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: Raw response that failed to decode: \(responseString)")
            }
            throw OAuthError.tokenExchangeFailed
        }
        
        // Validate token response
        guard !tokenResponse.accessToken.isEmpty else {
            print("Debug: ERROR - Received empty access token")
            throw OAuthError.tokenExchangeFailed
        }
        
        guard !tokenResponse.refreshToken.isEmpty else {
            print("Debug: ERROR - Received empty refresh token")
            throw OAuthError.tokenExchangeFailed
        }
        
        print("Debug: SUCCESS - Valid tokens received from NetSuite")
        print("Debug: Access token: \(tokenResponse.accessToken.prefix(10))...")
        print("Debug: Refresh token: \(tokenResponse.refreshToken.prefix(10))...")
        print("Debug: Token type: \(tokenResponse.tokenType)")
        print("Debug: Expires in: \(tokenResponse.expiresIn) seconds")
        
        // Only set authentication state if we have valid tokens
        DispatchQueue.main.async {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.isAuthenticated = true
        }
        
        // Store tokens securely
        try await storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
        
        // Configure NetSuiteAPI with the new tokens
        NetSuiteAPI.shared.configure(accountId: accountId, accessToken: tokenResponse.accessToken)
        print("Debug: NetSuiteAPI configured with account ID: \(accountId) and access token")
        
        // Verify NetSuiteAPI configuration
        let isConfigured = NetSuiteAPI.shared.isConfigured()
        print("Debug: NetSuiteAPI configuration verification: \(isConfigured)")
        
        if !isConfigured {
            print("Debug: ERROR - NetSuiteAPI not properly configured after OAuth!")
            throw OAuthError.tokenExchangeFailed
        }
        
        // Test the connection immediately
        do {
            try await NetSuiteAPI.shared.testConnection()
            print("Debug: ✅ NetSuite connection test successful after OAuth")
            
            // Verify we can make a real API call
            do {
                let customers = try await NetSuiteAPI.shared.fetchCustomers()
                print("Debug: ✅ Real API call successful - fetched \(customers.count) customers")
            } catch {
                print("Debug: ⚠️ Real API call failed: \(error)")
            }
            
        } catch {
            print("Debug: ⚠️ NetSuite connection test failed after OAuth: \(error)")
            throw OAuthError.tokenExchangeFailed
        }
        
        // Clear OAuth session data after successful token exchange
        UserDefaults.standard.removeObject(forKey: "netsuite_code_verifier")
        UserDefaults.standard.removeObject(forKey: "netsuite_oauth_state")
        print("Debug: OAuth session data cleared after successful token exchange")
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw OAuthError.noRefreshToken
        }
        
        _ = try await refreshAccessToken(refreshToken: refreshToken)
    }
    
    func refreshAccessToken(refreshToken: String) async throws -> OAuthTokenResponse {
        guard !clientId.isEmpty && !accountId.isEmpty else {
            throw OAuthError.notConfigured
        }
        
        // NetSuite OAuth 2.0 token endpoint for refresh - CORRECT FORMAT
        // Format: https://{account-id}.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token
        let url = "https://\(accountId).suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic Auth with Base64 encoded clientid:clientsecret
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // URL encode the parameters properly
        let bodyParameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        DispatchQueue.main.async {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
        }
        
        // Store updated tokens
        try await storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
        
        // Configure NetSuiteAPI with the updated tokens
        NetSuiteAPI.shared.configure(accountId: accountId, accessToken: tokenResponse.accessToken)
        print("Debug: NetSuiteAPI reconfigured with updated access token")
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        return OAuthTokenResponse(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiryDate: expiryDate
        )
    }
    
    func logout() {
        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.isAuthenticated = false
        }
        
        // Clear stored tokens
        Task {
            await clearStoredTokensAndState()
        }
    }
    
    func clearTokens() {
        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.isAuthenticated = false
        }
        
        // Clear stored tokens
        Task {
            await clearStoredTokensAndState()
        }
    }
    
    // MARK: - Token Storage
    private func storeTokens(accessToken: String, refreshToken: String) async throws {
        print("Debug: ===== storeTokens() called ======")
        print("Debug: Storing access token: \(accessToken.prefix(10))... (length: \(accessToken.count))")
        print("Debug: Storing refresh token: \(refreshToken.prefix(10))... (length: \(refreshToken.count))")
        
        let userDefaults = UserDefaults.standard
        
        // Store tokens
        userDefaults.set(accessToken, forKey: "netsuite_access_token")
        userDefaults.set(refreshToken, forKey: "netsuite_refresh_token")
        
        // Calculate and store expiry time (NetSuite tokens typically expire in 1 hour)
        let expiryDate = Date().addingTimeInterval(3600) // 1 hour from now
        userDefaults.set(expiryDate, forKey: "netsuite_token_expiry")
        
        // Update internal state
        DispatchQueue.main.async {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.isAuthenticated = true
        }
        
        // Verify tokens were stored correctly
        let storedAccessToken = userDefaults.string(forKey: "netsuite_access_token")
        let storedRefreshToken = userDefaults.string(forKey: "netsuite_refresh_token")
        let storedExpiry = userDefaults.object(forKey: "netsuite_token_expiry") as? Date
        
        print("Debug: Tokens stored successfully in UserDefaults")
        print("Debug: Verification of stored tokens:")
        print("Debug: Access token stored: \(storedAccessToken != nil)")
        print("Debug: Refresh token stored: \(storedRefreshToken != nil)")
        print("Debug: Expiry stored: \(storedExpiry != nil)")
        print("Debug: Stored access token matches: \(storedAccessToken?.prefix(10) ?? "nil")...")
        
        // Verify token integrity
        guard let storedAccessToken = storedAccessToken,
              let storedRefreshToken = storedRefreshToken,
              let storedExpiry = storedExpiry else {
            print("Debug: ERROR - Token storage verification failed!")
            throw OAuthError.tokenExchangeFailed
        }
        
        guard storedAccessToken == accessToken else {
            print("Debug: ERROR - Stored access token doesn't match original!")
            throw OAuthError.tokenExchangeFailed
        }
        
        guard storedRefreshToken == refreshToken else {
            print("Debug: ERROR - Stored refresh token doesn't match original!")
            throw OAuthError.tokenExchangeFailed
        }
        
        print("Debug: ✅ Token storage verification passed")
        print("Debug: Access token integrity: ✅")
        print("Debug: Refresh token integrity: ✅")
        print("Debug: Expiry date integrity: ✅")
        
        // Configure NetSuiteAPI with the new tokens
        NetSuiteAPI.shared.configure(accountId: accountId, accessToken: accessToken)
        
        print("Debug: NetSuiteAPI configured with account ID: \(accountId) and access token")
        
        // Clear OAuth session data (code verifier, state) but keep tokens
        userDefaults.removeObject(forKey: "netsuite_code_verifier")
        userDefaults.removeObject(forKey: "netsuite_oauth_state")
        print("Debug: OAuth session data cleared after successful token exchange")
    }
    
    private func clearAllTokens() async {
        print("Debug: ===== clearAllTokens() called =====")
        
        let userDefaults = UserDefaults.standard
        
        // Clear all OAuth-related data
        userDefaults.removeObject(forKey: "netsuite_access_token")
        userDefaults.removeObject(forKey: "netsuite_refresh_token")
        userDefaults.removeObject(forKey: "netsuite_token_expiry")
        userDefaults.removeObject(forKey: "netsuite_code_verifier")
        userDefaults.removeObject(forKey: "netsuite_oauth_state")
        
        // Clear internal state
        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.isAuthenticated = false
        }
        
        print("Debug: All OAuth tokens and session data cleared")
        print("Debug: Internal state reset to unauthenticated")
    }
    
    private func clearStoredTokens() async {
        // Clear tokens from UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "netsuite_access_token")
        userDefaults.removeObject(forKey: "netsuite_refresh_token")
        userDefaults.removeObject(forKey: "netsuite_token_expiry")
        userDefaults.removeObject(forKey: "netsuite_code_verifier")
        userDefaults.removeObject(forKey: "netsuite_oauth_state")
        
        print("Debug: OAuth tokens and session data cleared from storage")
    }
    
    private func clearStoredTokensAndState() async {
        // Clear tokens from UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "netsuite_access_token")
        userDefaults.removeObject(forKey: "netsuite_refresh_token")
        userDefaults.removeObject(forKey: "netsuite_token_expiry")
        userDefaults.removeObject(forKey: "netsuite_code_verifier")
        userDefaults.removeObject(forKey: "netsuite_oauth_state")
        
        // Clear internal state
        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.isAuthenticated = false
        }
        
        print("Debug: OAuth tokens and session data cleared from storage and internal state reset")
    }
    
    func forceFreshOAuthFlow() async {
        print("Debug: Force clearing all OAuth data for fresh flow")
        await clearStoredTokens()
        
        // Clear any other OAuth-related data
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "netsuite_client_id")
        userDefaults.removeObject(forKey: "netsuite_client_secret")
        userDefaults.removeObject(forKey: "netsuite_account_id")
        userDefaults.removeObject(forKey: "netsuite_redirect_uri")
        
        // Reset authentication state
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.accessToken = nil
            self.refreshToken = nil
        }
        
        print("Debug: All OAuth data cleared, ready for fresh flow")
    }
    
    func loadStoredTokens() async {
        print("Debug: ===== loadStoredTokens() called =====")
        
        // Load tokens from UserDefaults
        let userDefaults = UserDefaults.standard
        
        if let accessToken = userDefaults.string(forKey: "netsuite_access_token"),
           let refreshToken = userDefaults.string(forKey: "netsuite_refresh_token"),
           let expiryDate = userDefaults.object(forKey: "netsuite_token_expiry") as? Date {
            
            print("Debug: Found stored tokens:")
            print("Debug: Access token: \(accessToken.prefix(10))... (length: \(accessToken.count))")
            print("Debug: Refresh token: \(refreshToken.prefix(10))... (length: \(refreshToken.count))")
            print("Debug: Token expiry: \(expiryDate)")
            print("Debug: Current time: \(Date())")
            print("Debug: Token valid: \(Date() < expiryDate)")
            
            // Validate token format and length
            guard accessToken.count > 10 else {
                print("Debug: ERROR - Stored access token is too short, likely invalid")
                await clearStoredTokens()
                return
            }
            
            guard refreshToken.count > 10 else {
                print("Debug: ERROR - Stored refresh token is too short, likely invalid")
                await clearStoredTokens()
                return
            }
            
            // Check if token is still valid
            if Date() < expiryDate {
                print("Debug: SUCCESS - Loading valid stored OAuth tokens")
                
                DispatchQueue.main.async {
                    self.accessToken = accessToken
                    self.refreshToken = refreshToken
                    self.isAuthenticated = true
                }
                
                // Configure NetSuiteAPI with loaded tokens
                NetSuiteAPI.shared.configure(accountId: accountId, accessToken: accessToken)
                print("Debug: NetSuiteAPI configured with loaded tokens")
                print("Debug: Loaded valid OAuth tokens from storage")
                print("Debug: Access token: \(accessToken.prefix(10))...")
                print("Debug: Token expires: \(expiryDate)")
            } else {
                print("Debug: ERROR - Stored OAuth tokens are expired")
                print("Debug: Token expired at: \(expiryDate)")
                print("Debug: Current time: \(Date())")
                // Clear expired tokens
                await clearStoredTokens()
                
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    self.accessToken = nil
                    self.refreshToken = nil
                }
            }
        } else {
            print("Debug: No stored OAuth tokens found or tokens are incomplete")
            print("Debug: Access token present: \(userDefaults.string(forKey: "netsuite_access_token") != nil)")
            print("Debug: Refresh token present: \(userDefaults.string(forKey: "netsuite_refresh_token") != nil)")
            print("Debug: Expiry date present: \(userDefaults.object(forKey: "netsuite_token_expiry") != nil)")
            
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.accessToken = nil
                self.refreshToken = nil
            }
        }
    }
    
    // MARK: - API Access
    func getValidAccessToken() async throws -> String {
        guard let accessToken = accessToken else {
            throw OAuthError.authenticationFailed
        }
        
        // For now, we'll assume the token is valid
        // In a real implementation, you would check token expiry and refresh if needed
        return accessToken
    }
    
    // MARK: - Validation
    func validateAuthenticationState() async {
        print("Debug: ===== validateAuthenticationState() called =====")
        
        let userDefaults = UserDefaults.standard
        
        // Check if we have stored tokens
        if let accessToken = userDefaults.string(forKey: "netsuite_access_token"),
           let refreshToken = userDefaults.string(forKey: "netsuite_refresh_token"),
           let expiryDate = userDefaults.object(forKey: "netsuite_token_expiry") as? Date {
            
            print("Debug: Found stored tokens:")
            print("Debug: Access token: \(accessToken.prefix(10))... (length: \(accessToken.count))")
            print("Debug: Refresh token: \(refreshToken.prefix(10))... (length: \(refreshToken.count))")
            print("Debug: Token expiry: \(expiryDate)")
            print("Debug: Current time: \(Date())")
            print("Debug: Token valid: \(Date() < expiryDate)")
            
            // Validate token format and length
            guard accessToken.count > 10 else {
                print("Debug: ERROR - Stored access token is too short, likely invalid")
                await clearAllTokens()
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                }
                return
            }
            
            guard refreshToken.count > 10 else {
                print("Debug: ERROR - Stored refresh token is too short, likely invalid")
                await clearAllTokens()
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                }
                return
            }
            
            // Check if token is expired
            let now = Date()
            if expiryDate <= now {
                print("Debug: WARNING - Access token is expired!")
                print("Debug: Token expired at: \(expiryDate)")
                print("Debug: Current time: \(now)")
                print("Debug: Time difference: \(now.timeIntervalSince(expiryDate)) seconds")
                
                // Try to refresh the token first
                do {
                    print("Debug: Attempting to refresh expired token...")
                    let newTokens = try await refreshAccessToken(refreshToken: refreshToken)
                    print("Debug: ✅ Token refresh successful")
                    
                    // Update internal state with new tokens
                    DispatchQueue.main.async {
                        self.accessToken = newTokens.accessToken
                        self.refreshToken = newTokens.refreshToken
                        self.isAuthenticated = true
                    }
                    
                    // Configure NetSuiteAPI with new tokens
                    NetSuiteAPI.shared.configure(accountId: accountId, accessToken: newTokens.accessToken)
                    print("Debug: NetSuiteAPI configured with refreshed tokens")
                    
                    // Test the connection with new tokens
                    do {
                        try await NetSuiteAPI.shared.testConnection()
                        print("Debug: ✅ Connection test successful with refreshed tokens")
                    } catch {
                        print("Debug: ⚠️ Connection test failed with refreshed tokens: \(error)")
                    }
                    
                    return
                } catch {
                    print("Debug: ❌ Token refresh failed: \(error)")
                    // Clear expired tokens if refresh failed
                    await clearAllTokens()
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                    }
                    print("Debug: Cleared expired tokens and set isAuthenticated = false")
                    return
                }
            }
            
            // Check if we have required OAuth configuration
            let clientId = userDefaults.string(forKey: "netsuite_client_id") ?? ""
            let clientSecret = userDefaults.string(forKey: "netsuite_client_secret") ?? ""
            let accountId = userDefaults.string(forKey: "netsuite_account_id") ?? ""
            
            print("Debug: OAuth configuration check:")
            print("Debug: Client ID present: \(!clientId.isEmpty)")
            print("Debug: Client Secret present: \(!clientSecret.isEmpty)")
            print("Debug: Account ID present: \(!accountId.isEmpty)")
            
            if clientId.isEmpty || clientSecret.isEmpty || accountId.isEmpty {
                print("Debug: ERROR - Missing OAuth configuration!")
                await clearAllTokens()
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                }
                print("Debug: Cleared tokens due to missing OAuth configuration")
                return
            }
            
            // Update internal state
            DispatchQueue.main.async {
                self.accessToken = accessToken
                self.refreshToken = refreshToken
                self.isAuthenticated = true
            }
            
            // Configure NetSuiteAPI
            NetSuiteAPI.shared.configure(accountId: accountId, accessToken: accessToken)
            print("Debug: NetSuiteAPI configured with valid tokens")
            
            // Test the connection to verify tokens work
            do {
                try await NetSuiteAPI.shared.testConnection()
                print("Debug: ✅ Connection test successful with stored tokens")
            } catch {
                print("Debug: ⚠️ Connection test failed with stored tokens: \(error)")
                // If connection test fails, the tokens might be invalid
                print("Debug: Clearing tokens due to failed connection test")
                await clearAllTokens()
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                }
                return
            }
            
            print("Debug: SUCCESS - Valid authentication state confirmed")
            print("Debug: isAuthenticated set to: true")
            
        } else {
            print("Debug: No stored tokens found")
            print("Debug: Access token present: \(userDefaults.string(forKey: "netsuite_access_token") != nil)")
            print("Debug: Refresh token present: \(userDefaults.string(forKey: "netsuite_refresh_token") != nil)")
            print("Debug: Token expiry present: \(userDefaults.object(forKey: "netsuite_token_expiry") != nil)")
            
            DispatchQueue.main.async {
                self.isAuthenticated = false
            }
            print("Debug: Set isAuthenticated = false due to missing tokens")
        }
    }
    
    func forceClearAllOAuthData() async {
        print("Debug: ===== forceClearAllOAuthData() called =====")
        
        // Clear all OAuth-related data
        let userDefaults = UserDefaults.standard
        
        // Clear tokens
        userDefaults.removeObject(forKey: "netsuite_access_token")
        userDefaults.removeObject(forKey: "netsuite_refresh_token")
        userDefaults.removeObject(forKey: "netsuite_token_expiry")
        
        // Clear OAuth session data
        userDefaults.removeObject(forKey: "netsuite_code_verifier")
        userDefaults.removeObject(forKey: "netsuite_oauth_state")
        
        // Clear configuration (optional - comment out if you want to keep credentials)
        // userDefaults.removeObject(forKey: "netsuite_client_id")
        // userDefaults.removeObject(forKey: "netsuite_client_secret")
        // userDefaults.removeObject(forKey: "netsuite_account_id")
        // userDefaults.removeObject(forKey: "netsuite_redirect_uri")
        
        // Reset authentication state
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.accessToken = nil
            self.refreshToken = nil
        }
        
        print("Debug: All OAuth data cleared")
    }
    
    // MARK: - OAuth Flow Verification
    func verifyOAuthFlow() async -> Bool {
        print("Debug: ===== verifyOAuthFlow() called =====")
        
        let userDefaults = UserDefaults.standard
        
        // Check OAuth configuration
        let clientId = userDefaults.string(forKey: "netsuite_client_id") ?? ""
        let clientSecret = userDefaults.string(forKey: "netsuite_client_secret") ?? ""
        let accountId = userDefaults.string(forKey: "netsuite_account_id") ?? ""
        let redirectUri = userDefaults.string(forKey: "netsuite_redirect_uri") ?? ""
        
        print("Debug: OAuth Configuration Check:")
        print("Debug: - Client ID: \(clientId.isEmpty ? "❌ Missing" : "✅ Present")")
        print("Debug: - Client Secret: \(clientSecret.isEmpty ? "❌ Missing" : "✅ Present")")
        print("Debug: - Account ID: \(accountId.isEmpty ? "❌ Missing" : "✅ Present")")
        print("Debug: - Redirect URI: \(redirectUri.isEmpty ? "❌ Missing" : "✅ Present")")
        
        // Check stored tokens
        let accessToken = userDefaults.string(forKey: "netsuite_access_token")
        let refreshToken = userDefaults.string(forKey: "netsuite_refresh_token")
        let expiryDate = userDefaults.object(forKey: "netsuite_token_expiry") as? Date
        
        print("Debug: Token Status Check:")
        print("Debug: - Access Token: \(accessToken == nil ? "❌ Missing" : "✅ Present")")
        print("Debug: - Refresh Token: \(refreshToken == nil ? "❌ Missing" : "✅ Present")")
        print("Debug: - Expiry Date: \(expiryDate == nil ? "❌ Missing" : "✅ Present")")
        
        if let expiryDate = expiryDate {
            let isValid = Date() < expiryDate
            print("Debug: - Token Valid: \(isValid ? "✅ Valid" : "❌ Expired")")
        }
        
        // Check NetSuiteAPI configuration
        let isNetSuiteConfigured = NetSuiteAPI.shared.isConfigured()
        print("Debug: NetSuiteAPI Configuration: \(isNetSuiteConfigured ? "✅ Configured" : "❌ Not Configured")")
        
        // Check authentication state
        print("Debug: Authentication State: \(isAuthenticated ? "✅ Authenticated" : "❌ Not Authenticated")")
        
        // Determine overall status
        let hasConfiguration = !clientId.isEmpty && !clientSecret.isEmpty && !accountId.isEmpty && !redirectUri.isEmpty
        let hasValidTokens = accessToken != nil && refreshToken != nil && expiryDate != nil && (expiryDate ?? Date()) > Date()
        let isFullyConfigured = hasConfiguration && hasValidTokens && isNetSuiteConfigured && isAuthenticated
        
        print("Debug: Overall OAuth Flow Status: \(isFullyConfigured ? "✅ Complete" : "❌ Incomplete")")
        
        return isFullyConfigured
    }
}

// MARK: - Models
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        
        // Handle expiresIn as either String or Int
        if let expiresInInt = try? container.decode(Int.self, forKey: .expiresIn) {
            expiresIn = expiresInInt
        } else if let expiresInString = try? container.decode(String.self, forKey: .expiresIn),
                  let expiresInInt = Int(expiresInString) {
            expiresIn = expiresInInt
        } else {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(
                codingPath: [CodingKeys.expiresIn],
                debugDescription: "Expected expires_in to be either Int or String convertible to Int"
            ))
        }
    }
}



// MARK: - Errors
enum OAuthError: Error, LocalizedError {
    case notConfigured
    case invalidCallback
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    case authenticationFailed
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OAuth not configured. Please set client ID and secret."
        case .invalidCallback:
            return "Invalid OAuth callback URL."
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for access token."
        case .tokenRefreshFailed:
            return "Failed to refresh access token."
        case .noRefreshToken:
            return "No refresh token available."
        case .authenticationFailed:
            return "OAuth authentication failed."
        case .invalidURL:
            return "Failed to generate a valid authorization URL."
        }
    }
} 