import Foundation
import Combine

class WindcaveManager: ObservableObject {
    static let shared = WindcaveManager()
    
    private var restApiUsername: String = ""
    private var restApiKey: String = ""
    private let baseURL = "https://sec.windcave.com"
    
    @Published var isConfigured = false
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration
    func updateConfiguration(username: String, apiKey: String) {
        self.restApiUsername = username
        self.restApiKey = apiKey
        
        // Store in UserDefaults
        UserDefaults.standard.set(username, forKey: "windcave_username")
        UserDefaults.standard.set(apiKey, forKey: "windcave_api_key")
        
        self.isConfigured = !username.isEmpty && !apiKey.isEmpty
        print("Windcave configured with username: \(username)")
    }
    
    private func loadConfiguration() {
        restApiUsername = UserDefaults.standard.string(forKey: "windcave_username") ?? ""
        restApiKey = UserDefaults.standard.string(forKey: "windcave_api_key") ?? ""
        isConfigured = !restApiUsername.isEmpty && !restApiKey.isEmpty
    }
    
    // MARK: - Authentication
    private func getAuthHeader() -> String {
        let credentials = "\(restApiUsername):\(restApiKey)"
        guard let data = credentials.data(using: .utf8) else {
            return ""
        }
        return "Basic \(data.base64EncodedString())"
    }
    
    // MARK: - API Methods
    
    /// Create Windcave Hosted Payment Page session
    func createHPPSession(amount: Decimal, currency: String = "NZD", merchantReference: String, customerName: String? = nil) async throws -> WindcaveHPPSession {
        guard isConfigured else {
            print("Debug: WindcaveManager - Not configured for HPP session creation")
            throw WindcaveError.notConfigured
        }
        
        print("Debug: WindcaveManager - Creating HPP session for amount: \(amount)")
        
        let endpoint = "/api/v1/sessions"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert amount to string format (e.g., "10.50")
        let amountFormatter = NumberFormatter()
        amountFormatter.numberStyle = .decimal
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        let amountString = amountFormatter.string(from: amount as NSNumber) ?? "0.00"
        
        let sessionRequest = WindcaveHPPSessionRequest(
            type: "purchase",
            amount: amountString,
            currency: currency,
            merchantReference: merchantReference,
            callbackUrls: WindcaveCallbackUrls(
                approved: "https://httpbin.org/get?status=approved&sessionId=\(UUID().uuidString)",
                declined: "https://httpbin.org/get?status=declined&sessionId=\(UUID().uuidString)", 
                cancelled: "https://httpbin.org/get?status=cancelled&sessionId=\(UUID().uuidString)"
            ),
            notificationUrl: "https://httpbin.org/post"
        )
        
        request.httpBody = try JSONEncoder().encode(sessionRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: WindcaveManager - Invalid HTTP response for HPP session")
            throw WindcaveError.invalidResponse
        }
        
        guard httpResponse.statusCode == 202 else {
            print("Debug: WindcaveManager - HPP session HTTP error \(httpResponse.statusCode)")
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Debug: WindcaveManager - Windcave HPP error: \(errorData)")
            }
            throw WindcaveError.requestFailed
        }
        
        let hppSession = try JSONDecoder().decode(WindcaveHPPSession.self, from: data)
        print("Debug: WindcaveManager - HPP session created successfully: \(hppSession.id)")
        return hppSession
    }
    
    /// Check the status of an HPP session
    func checkHPPSessionStatus(sessionId: String) async throws -> WindcaveHPPSessionStatus {
        guard isConfigured else {
            print("Debug: WindcaveManager - Not configured for HPP session status check")
            throw WindcaveError.notConfigured
        }
        
        print("Debug: WindcaveManager - Checking HPP session status for: \(sessionId)")
        
        let endpoint = "/api/v1/sessions/\(sessionId)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: WindcaveManager - Invalid HTTP response for HPP session status")
            throw WindcaveError.invalidResponse
        }
        
        // Accept both 200 (OK) and 202 (Accepted) status codes
        // 202 is returned during session monitoring when the payment is in progress
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 202 else {
            print("Debug: WindcaveManager - HPP session status HTTP error \(httpResponse.statusCode)")
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Debug: WindcaveManager - Windcave HPP status error: \(errorData)")
            }
            throw WindcaveError.requestFailed
        }
        
        let sessionStatus = try JSONDecoder().decode(WindcaveHPPSessionStatus.self, from: data)
        print("Debug: WindcaveManager - HPP session status: \(sessionStatus.state)")
        return sessionStatus
    }
    
    func testConnection() async throws -> Bool {
        guard isConfigured else {
            throw WindcaveError.notConfigured
        }
        
        let endpoint = "/v1/merchant"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Tap to Pay Methods
    func initializeTapToPay() async throws -> TapToPaySession {
        guard isConfigured else {
            throw WindcaveError.notConfigured
        }
        
        // In a real implementation, this would integrate with the Windcave Tap to Pay SDK
        // For now, we'll simulate the initialization using REST API
        
        let endpoint = "/v1/tap-to-pay/session"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let sessionData = ["type": "contactless"]
        request.httpBody = try JSONEncoder().encode(sessionData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WindcaveError.requestFailed
        }
        
        let session = try JSONDecoder().decode(TapToPaySession.self, from: data)
        return session
    }
    
    func processTapToPayPayment(amount: Int, currency: String = "NZD", sessionId: String) async throws -> TapToPayTransaction {
        guard isConfigured else {
            throw WindcaveError.notConfigured
        }
        
        let endpoint = "/v1/tap-to-pay/transaction"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let transactionData = [
            "amount": amount,
            "currency": currency,
            "sessionId": sessionId,
            "type": "purchase"
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: transactionData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WindcaveError.requestFailed
        }
        
        let transaction = try JSONDecoder().decode(TapToPayTransaction.self, from: data)
        return transaction
    }
    
    func getTransactionStatus(transactionId: String) async throws -> TapToPayTransaction {
        guard isConfigured else {
            throw WindcaveError.notConfigured
        }
        
        let endpoint = "/v1/tap-to-pay/transaction/\(transactionId)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WindcaveError.requestFailed
        }
        
        let transaction = try JSONDecoder().decode(TapToPayTransaction.self, from: data)
        return transaction
    }
    
    // MARK: - Transaction History
    func getTransactionHistory(limit: Int = 50, offset: Int = 0) async throws -> [TapToPayTransaction] {
        guard isConfigured else {
            throw WindcaveError.notConfigured
        }
        
        let endpoint = "/v1/tap-to-pay/transactions?limit=\(limit)&offset=\(offset)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(getAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WindcaveError.requestFailed
        }
        
        let transactions = try JSONDecoder().decode([TapToPayTransaction].self, from: data)
        return transactions
    }
}

// MARK: - Windcave HPP Models

/// Request model for creating Windcave HPP session
struct WindcaveHPPSessionRequest: Codable {
    let type: String
    let amount: String
    let currency: String
    let merchantReference: String
    let callbackUrls: WindcaveCallbackUrls
    let notificationUrl: String
}

/// Callback URLs for Windcave HPP session
struct WindcaveCallbackUrls: Codable {
    let approved: String
    let declined: String
    let cancelled: String
}

/// Response model for Windcave HPP session creation
struct WindcaveHPPSession: Codable {
    let id: String
    let state: String
    let links: [WindcaveLink]
    
    /// Get the HPP URL from the links array
    var hppUrl: String? {
        return links.first { $0.rel == "hpp" }?.href
    }
}

/// Response model for Windcave HPP session status
struct WindcaveHPPSessionStatus: Codable {
    let id: String
    let state: String
    let amount: String?
    let currency: String?
    let merchantReference: String?
    let authCode: String?
    let transactionId: String?
    let cardNumber: String?
    let cardType: String?
    let responseCode: String?
    let responseText: String?
    let links: [WindcaveLink]?
    
    /// Check if payment was completed successfully
    var isCompleted: Bool {
        return state.lowercased() == "completed" || state.lowercased() == "complete"
    }
    
    /// Check if payment was approved
    var isApproved: Bool {
        // If session is completed and no explicit failure, consider it approved
        if isCompleted {
            // Check for explicit failure indicators
            let hasFailureCode = responseCode != nil && responseCode != "00" && responseCode != ""
            let hasFailureText = responseText?.lowercased().contains("declined") == true || 
                                responseText?.lowercased().contains("failed") == true ||
                                responseText?.lowercased().contains("error") == true
            
            // If no explicit failure, consider completed sessions as approved
            if !hasFailureCode && !hasFailureText {
                return true
            }
        }
        
        // Explicit approval checks
        return responseCode == "00" || responseText?.lowercased().contains("approved") == true
    }
    
    /// Check if payment failed or was declined
    var isFailed: Bool {
        return state.lowercased() == "failed" || responseCode != "00"
    }
}

/// Windcave link model
struct WindcaveLink: Codable {
    let href: String
    let rel: String
    let method: String
}

// MARK: - Windcave Models
struct TapToPaySession: Codable {
    let sessionId: String
    let status: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case expiresAt = "expires_at"
    }
}

struct TapToPayTransaction: Codable {
    let transactionId: String
    let amount: Int
    let currency: String
    let status: String
    let cardType: String?
    let cardLast4: String?
    let timestamp: String
    let merchantReference: String?
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case amount
        case currency
        case status
        case cardType = "card_type"
        case cardLast4 = "card_last4"
        case timestamp
        case merchantReference = "merchant_reference"
    }
}

// MARK: - Errors
enum WindcaveError: Error, LocalizedError {
    case notConfigured
    case requestFailed
    case invalidResponse
    case authenticationFailed
    case tapToPayNotSupported
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Windcave not configured. Please set REST API username and key."
        case .requestFailed:
            return "Windcave API request failed."
        case .invalidResponse:
            return "Invalid response from Windcave API."
        case .authenticationFailed:
            return "Windcave authentication failed."
        case .tapToPayNotSupported:
            return "Tap to Pay is not supported on this device."
        case .sessionExpired:
            return "Tap to Pay session has expired."
        }
    }
} 