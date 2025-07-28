import Foundation
import Combine

class WindcaveManager: ObservableObject {
    static let shared = WindcaveManager()
    
    private var restApiUsername: String = ""
    private var restApiKey: String = ""
    private let baseURL = "https://api.windcave.com"
    
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