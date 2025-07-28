import Foundation
import Combine
import CryptoKit

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
        clientId = UserDefaults.standard.string(forKey: "netsuite_client_id") ?? ""
        clientSecret = UserDefaults.standard.string(forKey: "netsuite_client_secret") ?? ""
        accountId = UserDefaults.standard.string(forKey: "netsuite_account_id") ?? ""
        redirectUri = UserDefaults.standard.string(forKey: "netsuite_redirect_uri") ?? "fieldpay://callback"
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
        
        // Clear any existing OAuth data to force fresh flow
        await clearStoredTokens()
        UserDefaults.standard.removeObject(forKey: "netsuite_code_verifier")
        UserDefaults.standard.removeObject(forKey: "netsuite_oauth_state")
        
        // NetSuite OAuth 2.0 authorization endpoint - CORRECT FORMAT
        // Format: https://{account-id}.app.netsuite.com/app/login/oauth2/authorize.nl
        // Note: For sandbox, use: https://{account-id}.sandbox.app.netsuite.com/app/login/oauth2/authorize.nl
        let url = "https://\(accountId).app.netsuite.com/app/login/oauth2/authorize.nl"
        
        print("Debug: Generating FRESH OAuth URL with account ID: \(accountId)")
        print("Debug: Client ID: \(clientId)")
        print("Debug: Redirect URI: \(redirectUri)")
        print("Debug: Final authorization URL: \(url)")
        
        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        print("Debug: Generated FRESH code verifier length: \(codeVerifier.count)")
        print("Debug: Generated FRESH code challenge length: \(codeChallenge.count)")
        
        // Store code verifier for later use in token exchange
        UserDefaults.standard.set(codeVerifier, forKey: "netsuite_code_verifier")
        
        // Generate a unique state with timestamp to force fresh authorization
        let timestamp = Int(Date().timeIntervalSince1970)
        let uniqueState = "\(UUID().uuidString)_\(timestamp)"
        UserDefaults.standard.set(uniqueState, forKey: "netsuite_oauth_state")
        
        var components = URLComponents(string: url)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: "restlets rest_webservices"),
            URLQueryItem(name: "state", value: uniqueState),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        let finalURL = components.url!.absoluteString
        print("Debug: Final OAuth URL: \(finalURL)")
        print("Debug: URL components breakdown:")
        print("  - Base URL: \(url)")
        print("  - Query items: \(components.queryItems ?? [])")
        print("  - Redirect URI: \(redirectUri)")
        print("  - Client ID: \(clientId)")
        print("  - Account ID: \(accountId)")
        
        return finalURL
    }
    
    func handleOAuthCallback(url: URL) async throws {
        print("Debug: Handling OAuth callback for URL: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("Debug: Failed to create URLComponents from URL")
            throw OAuthError.invalidCallback
        }
        
        print("Debug: URL components: \(components)")
        print("Debug: Query items: \(components.queryItems ?? [])")
        
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("Debug: No authorization code found in callback URL")
            throw OAuthError.invalidCallback
        }
        
        print("Debug: Found authorization code: \(code.prefix(10))...")
        
        try await exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        // NetSuite OAuth 2.0 token endpoint - CORRECT FORMAT
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
        
        // Get the stored code verifier
        let codeVerifier = UserDefaults.standard.string(forKey: "netsuite_code_verifier") ?? ""
        
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
            print("Debug: Token exchange failed - invalid response type")
            throw OAuthError.tokenExchangeFailed
        }
        
        print("Debug: Token exchange response status: \(httpResponse.statusCode)")
        print("Debug: Token exchange response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Debug: Token exchange response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: Token exchange failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: Token exchange error response: \(responseString)")
            }
            throw OAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        DispatchQueue.main.async {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.isAuthenticated = true
        }
        
        // Store tokens securely
        await storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
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
            await clearStoredTokens()
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
            await clearStoredTokens()
        }
    }
    
    // MARK: - Token Storage
    private func storeTokens(accessToken: String, refreshToken: String) async {
        // Store tokens in UserDefaults for now (in production, use Keychain)
        let userDefaults = UserDefaults.standard
        userDefaults.set(accessToken, forKey: "netsuite_access_token")
        userDefaults.set(refreshToken, forKey: "netsuite_refresh_token")
        
        // Set expiry to 1 hour from now (NetSuite tokens typically expire in 1 hour)
        let expiryDate = Date().addingTimeInterval(3600)
        userDefaults.set(expiryDate, forKey: "netsuite_token_expiry")
        
        print("Debug: OAuth tokens stored successfully")
        print("Debug: Access token: \(accessToken.prefix(10))...")
        print("Debug: Refresh token: \(refreshToken.prefix(10))...")
        print("Debug: Token expiry: \(expiryDate)")
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
        // Load tokens from UserDefaults
        let userDefaults = UserDefaults.standard
        
        if let accessToken = userDefaults.string(forKey: "netsuite_access_token"),
           let refreshToken = userDefaults.string(forKey: "netsuite_refresh_token"),
           let expiryDate = userDefaults.object(forKey: "netsuite_token_expiry") as? Date {
            
            // Check if token is still valid
            if Date() < expiryDate {
                DispatchQueue.main.async {
                    self.accessToken = accessToken
                    self.refreshToken = refreshToken
                    self.isAuthenticated = true
                }
                print("Debug: Loaded valid OAuth tokens from storage")
                print("Debug: Access token: \(accessToken.prefix(10))...")
                print("Debug: Token expires: \(expiryDate)")
            } else {
                print("Debug: Stored OAuth tokens are expired")
                // Clear expired tokens
                await clearStoredTokens()
            }
        } else {
            print("Debug: No stored OAuth tokens found")
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
}



// MARK: - Errors
enum OAuthError: Error, LocalizedError {
    case notConfigured
    case invalidCallback
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    case authenticationFailed
    
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
        }
    }
} 