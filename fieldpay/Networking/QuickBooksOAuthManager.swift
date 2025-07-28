import Foundation
import Combine

class QuickBooksOAuthManager: ObservableObject {
    static let shared = QuickBooksOAuthManager()
    
    private var clientId: String = ""
    private var clientSecret: String = ""
    private var redirectUri: String = "fieldpay://oauth/quickbooks/callback"
    private var environment: String = "sandbox" // or "production"
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var tokenExpiryDate: Date?
    @Published var realmId: String?
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadConfiguration()
        loadTokens()
    }
    
    // MARK: - Configuration
    func updateConfiguration(clientId: String, clientSecret: String, environment: String = "sandbox", redirectUri: String = "fieldpay://oauth/quickbooks/callback") {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.environment = environment
        self.redirectUri = redirectUri
        
        // Store in UserDefaults
        userDefaults.set(clientId, forKey: "quickbooks_client_id")
        userDefaults.set(clientSecret, forKey: "quickbooks_client_secret")
        userDefaults.set(environment, forKey: "quickbooks_environment")
        userDefaults.set(redirectUri, forKey: "quickbooks_redirect_uri")
    }
    
    private func loadConfiguration() {
        clientId = userDefaults.string(forKey: "quickbooks_client_id") ?? ""
        clientSecret = userDefaults.string(forKey: "quickbooks_client_secret") ?? ""
        environment = userDefaults.string(forKey: "quickbooks_environment") ?? "sandbox"
        redirectUri = userDefaults.string(forKey: "quickbooks_redirect_uri") ?? "fieldpay://oauth/quickbooks/callback"
    }
    
    // MARK: - OAuth Flow
    func startOAuthFlow() async throws -> String {
        guard !clientId.isEmpty else {
            throw QuickBooksOAuthError.notConfigured
        }
        
        let baseURL = environment == "production" ? "https://appcenter.intuit.com" : "https://appcenter.intuit.com"
        let authURL = "\(baseURL)/connect/oauth2"
        let scope = "com.intuit.quickbooks.accounting"
        
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        
        return components.url?.absoluteString ?? ""
    }
    
    func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let realmId = components.queryItems?.first(where: { $0.name == "realmId" })?.value else {
            throw QuickBooksOAuthError.invalidCallback
        }
        
        try await exchangeCodeForToken(code: code, realmId: realmId)
    }
    
    private func exchangeCodeForToken(code: String, realmId: String) async throws {
        let baseURL = environment == "production" ? "https://oauth.platform.intuit.com" : "https://oauth.platform.intuit.com"
        let tokenURL = "\(baseURL)/oauth2/v1/tokens/bearer"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(getBasicAuthHeader())", forHTTPHeaderField: "Authorization")
        
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QuickBooksOAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(QuickBooksTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.realmId = realmId
            self.isAuthenticated = true
            
            // Store tokens
            self.saveTokens()
        }
    }
    
    private func getBasicAuthHeader() -> String {
        let credentials = "\(clientId):\(clientSecret)"
        guard let data = credentials.data(using: .utf8) else {
            return ""
        }
        return data.base64EncodedString()
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw QuickBooksOAuthError.noRefreshToken
        }
        
        let baseURL = environment == "production" ? "https://oauth.platform.intuit.com" : "https://oauth.platform.intuit.com"
        let tokenURL = "\(baseURL)/oauth2/v1/tokens/bearer"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(getBasicAuthHeader())", forHTTPHeaderField: "Authorization")
        
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QuickBooksOAuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(QuickBooksTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.saveTokens()
        }
    }
    
    // MARK: - Token Management
    private func loadTokens() {
        accessToken = userDefaults.string(forKey: "quickbooks_access_token")
        refreshToken = userDefaults.string(forKey: "quickbooks_refresh_token")
        realmId = userDefaults.string(forKey: "quickbooks_realm_id")
        
        if let expiryString = userDefaults.string(forKey: "quickbooks_token_expiry"),
           let expiryDate = ISO8601DateFormatter().date(from: expiryString) {
            tokenExpiryDate = expiryDate
        }
        
        isAuthenticated = accessToken != nil && refreshToken != nil
    }
    
    private func saveTokens() {
        userDefaults.set(accessToken, forKey: "quickbooks_access_token")
        userDefaults.set(refreshToken, forKey: "quickbooks_refresh_token")
        userDefaults.set(realmId, forKey: "quickbooks_realm_id")
        
        if let expiryDate = tokenExpiryDate {
            userDefaults.set(ISO8601DateFormatter().string(from: expiryDate), forKey: "quickbooks_token_expiry")
        }
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        realmId = nil
        isAuthenticated = false
        
        // Clear from UserDefaults
        userDefaults.removeObject(forKey: "quickbooks_access_token")
        userDefaults.removeObject(forKey: "quickbooks_refresh_token")
        userDefaults.removeObject(forKey: "quickbooks_realm_id")
        userDefaults.removeObject(forKey: "quickbooks_token_expiry")
    }
    
    // MARK: - API Access
    func getValidAccessToken() async throws -> String {
        guard let accessToken = accessToken else {
            throw QuickBooksOAuthError.notAuthenticated
        }
        
        // Check if token is expired
        if let expiryDate = tokenExpiryDate, Date() >= expiryDate {
            try await refreshAccessToken()
            guard let newToken = self.accessToken else {
                throw QuickBooksOAuthError.tokenRefreshFailed
            }
            return newToken
        }
        
        return accessToken
    }
    
    func getBaseURL() -> String {
        return environment == "production" ? "https://quickbooks.api.intuit.com" : "https://sandbox-quickbooks.api.intuit.com"
    }
}

// MARK: - Models
struct QuickBooksTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Errors
enum QuickBooksOAuthError: Error, LocalizedError {
    case notConfigured
    case invalidCallback
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notAuthenticated
    case noRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "QuickBooks not configured. Please set client ID and secret."
        case .invalidCallback:
            return "Invalid OAuth callback."
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token."
        case .tokenRefreshFailed:
            return "Failed to refresh access token."
        case .notAuthenticated:
            return "Not authenticated with QuickBooks."
        case .noRefreshToken:
            return "No refresh token available."
        }
    }
} 