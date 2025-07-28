import Foundation
import Combine

class SalesforceOAuthManager: ObservableObject {
    static let shared = SalesforceOAuthManager()
    
    private var clientId: String = ""
    private var clientSecret: String = ""
    private var redirectUri: String = "fieldpay://oauth/salesforce/callback"
    private var loginUrl: String = "https://login.salesforce.com" // or https://test.salesforce.com for sandbox
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var tokenExpiryDate: Date?
    @Published var instanceUrl: String?
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadConfiguration()
        loadTokens()
    }
    
    // MARK: - Configuration
    func updateConfiguration(clientId: String, clientSecret: String, isSandbox: Bool = false, redirectUri: String = "fieldpay://oauth/salesforce/callback") {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.loginUrl = isSandbox ? "https://test.salesforce.com" : "https://login.salesforce.com"
        self.redirectUri = redirectUri
        
        // Store in UserDefaults
        userDefaults.set(clientId, forKey: "salesforce_client_id")
        userDefaults.set(clientSecret, forKey: "salesforce_client_secret")
        userDefaults.set(isSandbox, forKey: "salesforce_is_sandbox")
        userDefaults.set(redirectUri, forKey: "salesforce_redirect_uri")
    }
    
    private func loadConfiguration() {
        clientId = userDefaults.string(forKey: "salesforce_client_id") ?? ""
        clientSecret = userDefaults.string(forKey: "salesforce_client_secret") ?? ""
        let isSandbox = userDefaults.bool(forKey: "salesforce_is_sandbox")
        loginUrl = isSandbox ? "https://test.salesforce.com" : "https://login.salesforce.com"
        redirectUri = userDefaults.string(forKey: "salesforce_redirect_uri") ?? "fieldpay://oauth/salesforce/callback"
    }
    
    // MARK: - OAuth Flow
    func startOAuthFlow() async throws -> String {
        guard !clientId.isEmpty else {
            throw SalesforceOAuthError.notConfigured
        }
        
        let authURL = "\(loginUrl)/services/oauth2/authorize"
        let scope = "api refresh_token"
        
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
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw SalesforceOAuthError.invalidCallback
        }
        
        try await exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        let tokenURL = "\(loginUrl)/services/oauth2/token"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
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
            throw SalesforceOAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(SalesforceTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.instanceUrl = tokenResponse.instanceUrl
            self.isAuthenticated = true
            
            // Store tokens
            self.saveTokens()
        }
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw SalesforceOAuthError.noRefreshToken
        }
        
        let tokenURL = "\(loginUrl)/services/oauth2/token"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SalesforceOAuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(SalesforceTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.instanceUrl = tokenResponse.instanceUrl
            self.saveTokens()
        }
    }
    
    // MARK: - Token Management
    private func loadTokens() {
        accessToken = userDefaults.string(forKey: "salesforce_access_token")
        refreshToken = userDefaults.string(forKey: "salesforce_refresh_token")
        instanceUrl = userDefaults.string(forKey: "salesforce_instance_url")
        
        if let expiryString = userDefaults.string(forKey: "salesforce_token_expiry"),
           let expiryDate = ISO8601DateFormatter().date(from: expiryString) {
            tokenExpiryDate = expiryDate
        }
        
        isAuthenticated = accessToken != nil && refreshToken != nil
    }
    
    private func saveTokens() {
        userDefaults.set(accessToken, forKey: "salesforce_access_token")
        userDefaults.set(refreshToken, forKey: "salesforce_refresh_token")
        userDefaults.set(instanceUrl, forKey: "salesforce_instance_url")
        
        if let expiryDate = tokenExpiryDate {
            userDefaults.set(ISO8601DateFormatter().string(from: expiryDate), forKey: "salesforce_token_expiry")
        }
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        instanceUrl = nil
        isAuthenticated = false
        
        // Clear from UserDefaults
        userDefaults.removeObject(forKey: "salesforce_access_token")
        userDefaults.removeObject(forKey: "salesforce_refresh_token")
        userDefaults.removeObject(forKey: "salesforce_instance_url")
        userDefaults.removeObject(forKey: "salesforce_token_expiry")
    }
    
    // MARK: - API Access
    func getValidAccessToken() async throws -> String {
        guard let accessToken = accessToken else {
            throw SalesforceOAuthError.notAuthenticated
        }
        
        // Check if token is expired
        if let expiryDate = tokenExpiryDate, Date() >= expiryDate {
            try await refreshAccessToken()
            guard let newToken = self.accessToken else {
                throw SalesforceOAuthError.tokenRefreshFailed
            }
            return newToken
        }
        
        return accessToken
    }
    
    func getInstanceURL() -> String? {
        return instanceUrl
    }
}

// MARK: - Models
struct SalesforceTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let instanceUrl: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case instanceUrl = "instance_url"
    }
}

// MARK: - Errors
enum SalesforceOAuthError: Error, LocalizedError {
    case notConfigured
    case invalidCallback
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notAuthenticated
    case noRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Salesforce not configured. Please set client ID and secret."
        case .invalidCallback:
            return "Invalid OAuth callback."
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token."
        case .tokenRefreshFailed:
            return "Failed to refresh access token."
        case .notAuthenticated:
            return "Not authenticated with Salesforce."
        case .noRefreshToken:
            return "No refresh token available."
        }
    }
} 