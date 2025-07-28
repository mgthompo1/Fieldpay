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
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.accountId = accountId
        self.redirectUri = redirectUri
        
        // Store in UserDefaults
        UserDefaults.standard.set(clientId, forKey: "netsuite_client_id")
        UserDefaults.standard.set(clientSecret, forKey: "netsuite_client_secret")
        UserDefaults.standard.set(accountId, forKey: "netsuite_account_id")
        UserDefaults.standard.set(redirectUri, forKey: "netsuite_redirect_uri")
        
        print("OAuth configured for NetSuite account: \(accountId)")
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
        
        guard !clientId.isEmpty && !accountId.isEmpty else {
            print("Debug: ERROR - OAuth not configured properly")
            print("Debug: clientId empty: \(clientId.isEmpty)")
            print("Debug: accountId empty: \(accountId.isEmpty)")
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
        
        // Build authorization URL
        var components = URLComponents(string: "https://\(accountId).app.netsuite.com/app/login/oauth2/authorize.nl")!
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
            throw OAuthError.invalidURL
        }
        
        print("Debug: Generated auth URL: \(authURL)")
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
        await storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
        
        // Configure NetSuiteAPI with the new tokens
        NetSuiteAPI.shared.configure(accountId: accountId, accessToken: tokenResponse.accessToken)
        print("Debug: NetSuiteAPI configured with account ID: \(accountId) and access token")
        
        // Test the connection immediately
        do {
            try await NetSuiteAPI.shared.testConnection()
            print("Debug: ✅ NetSuite connection test successful after OAuth")
        } catch {
            print("Debug: ⚠️ NetSuite connection test failed after OAuth: \(error)")
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
        await storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
        
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
    private func storeTokens(accessToken: String, refreshToken: String) async {
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
            
            // Check if token is expired
            let now = Date()
            if expiryDate <= now {
                print("Debug: WARNING - Access token is expired!")
                print("Debug: Token expired at: \(expiryDate)")
                print("Debug: Current time: \(now)")
                print("Debug: Time difference: \(now.timeIntervalSince(expiryDate)) seconds")
                
                // Clear expired tokens
                await clearAllTokens()
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                }
                print("Debug: Cleared expired tokens and set isAuthenticated = false")
                return
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