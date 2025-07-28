import Foundation
import Combine

class XeroOAuthManager: ObservableObject {
    static let shared = XeroOAuthManager()
    
    private var clientId: String = ""
    private var clientSecret: String = ""
    private var redirectUri: String = "fieldpay://oauth/xero/callback"
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var tokenExpiryDate: Date?
    @Published var tenantId: String?
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadConfiguration()
        loadTokens()
    }
    
    // MARK: - Configuration
    func updateConfiguration(clientId: String, clientSecret: String, redirectUri: String = "fieldpay://oauth/xero/callback") {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUri = redirectUri
        
        // Store in UserDefaults
        userDefaults.set(clientId, forKey: "xero_client_id")
        userDefaults.set(clientSecret, forKey: "xero_client_secret")
        userDefaults.set(redirectUri, forKey: "xero_redirect_uri")
    }
    
    private func loadConfiguration() {
        clientId = userDefaults.string(forKey: "xero_client_id") ?? ""
        clientSecret = userDefaults.string(forKey: "xero_client_secret") ?? ""
        redirectUri = userDefaults.string(forKey: "xero_redirect_uri") ?? "fieldpay://oauth/xero/callback"
    }
    
    // MARK: - OAuth Flow
    func startOAuthFlow() async throws -> String {
        guard !clientId.isEmpty else {
            throw XeroOAuthError.notConfigured
        }
        
        let authURL = "https://login.xero.com/identity/connect/authorize"
        let scope = "offline_access accounting.transactions accounting.contacts accounting.settings"
        
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
            throw XeroOAuthError.invalidCallback
        }
        
        try await exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        let tokenURL = "https://identity.xero.com/connect/token"
        
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
            throw XeroOAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(XeroTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.isAuthenticated = true
            
            // Store tokens
            self.saveTokens()
        }
        
        // Get tenant ID
        try await getTenantId()
    }
    
    private func getTenantId() async throws {
        guard let accessToken = accessToken else {
            throw XeroOAuthError.notAuthenticated
        }
        
        let connectionsURL = "https://api.xero.com/connections"
        
        var request = URLRequest(url: URL(string: connectionsURL)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw XeroOAuthError.tenantFetchFailed
        }
        
        let connections = try JSONDecoder().decode([XeroConnection].self, from: data)
        
        if let firstConnection = connections.first {
            await MainActor.run {
                self.tenantId = firstConnection.tenantId
                self.saveTokens()
            }
        }
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw XeroOAuthError.noRefreshToken
        }
        
        let tokenURL = "https://identity.xero.com/connect/token"
        
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
            throw XeroOAuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(XeroTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.saveTokens()
        }
    }
    
    // MARK: - Token Management
    private func loadTokens() {
        accessToken = userDefaults.string(forKey: "xero_access_token")
        refreshToken = userDefaults.string(forKey: "xero_refresh_token")
        tenantId = userDefaults.string(forKey: "xero_tenant_id")
        
        if let expiryString = userDefaults.string(forKey: "xero_token_expiry"),
           let expiryDate = ISO8601DateFormatter().date(from: expiryString) {
            tokenExpiryDate = expiryDate
        }
        
        isAuthenticated = accessToken != nil && refreshToken != nil
    }
    
    private func saveTokens() {
        userDefaults.set(accessToken, forKey: "xero_access_token")
        userDefaults.set(refreshToken, forKey: "xero_refresh_token")
        userDefaults.set(tenantId, forKey: "xero_tenant_id")
        
        if let expiryDate = tokenExpiryDate {
            userDefaults.set(ISO8601DateFormatter().string(from: expiryDate), forKey: "xero_token_expiry")
        }
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        tenantId = nil
        isAuthenticated = false
        
        // Clear from UserDefaults
        userDefaults.removeObject(forKey: "xero_access_token")
        userDefaults.removeObject(forKey: "xero_refresh_token")
        userDefaults.removeObject(forKey: "xero_tenant_id")
        userDefaults.removeObject(forKey: "xero_token_expiry")
    }
    
    // MARK: - API Access
    func getValidAccessToken() async throws -> String {
        guard let accessToken = accessToken else {
            throw XeroOAuthError.notAuthenticated
        }
        
        // Check if token is expired
        if let expiryDate = tokenExpiryDate, Date() >= expiryDate {
            try await refreshAccessToken()
            guard let newToken = self.accessToken else {
                throw XeroOAuthError.tokenRefreshFailed
            }
            return newToken
        }
        
        return accessToken
    }
}

// MARK: - Models
struct XeroTokenResponse: Codable {
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

struct XeroConnection: Codable {
    let tenantId: String
    let tenantName: String
    let tenantType: String
    
    enum CodingKeys: String, CodingKey {
        case tenantId = "tenantId"
        case tenantName = "tenantName"
        case tenantType = "tenantType"
    }
}

// MARK: - Errors
enum XeroOAuthError: Error, LocalizedError {
    case notConfigured
    case invalidCallback
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notAuthenticated
    case noRefreshToken
    case tenantFetchFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Xero not configured. Please set client ID and secret."
        case .invalidCallback:
            return "Invalid OAuth callback."
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token."
        case .tokenRefreshFailed:
            return "Failed to refresh access token."
        case .notAuthenticated:
            return "Not authenticated with Xero."
        case .noRefreshToken:
            return "No refresh token available."
        case .tenantFetchFailed:
            return "Failed to fetch Xero tenant information."
        }
    }
} 