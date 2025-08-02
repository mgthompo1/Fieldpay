import Foundation
import Combine

class StripeManager: ObservableObject {
    static let shared = StripeManager()
    
    private var publishableKey: String = ""
    private var secretKey: String = ""
    private var accountId: String = ""
    private let baseURL = "https://api.stripe.com/v1"
    
    private init() {
        // Load from UserDefaults if available
        loadConfiguration()
    }
    
    // MARK: - Configuration
    func updateConfiguration(publicKey: String, secretKey: String, accountId: String) {
        self.publishableKey = publicKey
        self.secretKey = secretKey
        self.accountId = accountId
        
        // Store in UserDefaults
        UserDefaults.standard.set(publicKey, forKey: "stripe_public_key")
        UserDefaults.standard.set(secretKey, forKey: "stripe_secret_key")
        UserDefaults.standard.set(accountId, forKey: "stripe_account_id")
        
        print("Stripe configured with publishable key: \(publicKey.prefix(10))...")
    }
    
    private func loadConfiguration() {
        publishableKey = UserDefaults.standard.string(forKey: "stripe_public_key") ?? ""
        secretKey = UserDefaults.standard.string(forKey: "stripe_secret_key") ?? ""
        accountId = UserDefaults.standard.string(forKey: "stripe_account_id") ?? ""
    }
    
    func testConnection() async throws -> Bool {
        guard !secretKey.isEmpty else {
            throw StripeError.notConfigured
        }
        
        let endpoint = "/account"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        
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
    
    // MARK: - Payment Processing
    func createPaymentIntent(amount: Int, currency: String = "usd", customerId: String? = nil) async throws -> PaymentIntent {
        guard !secretKey.isEmpty else {
            print("Debug: StripeManager - Secret key not configured")
            throw StripeError.notConfigured
        }
        
        print("Debug: StripeManager - Creating payment intent for amount: \(amount)")
        let endpoint = "/payment_intents"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "amount", value: "\(amount)"),
            URLQueryItem(name: "currency", value: currency)
        ]
        
        if let customerId = customerId {
            bodyComponents.queryItems?.append(URLQueryItem(name: "customer", value: customerId))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: StripeManager - Invalid HTTP response for payment intent")
            throw StripeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: StripeManager - Payment intent HTTP error \(httpResponse.statusCode)")
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("Debug: StripeManager - Stripe payment intent error: \(message)")
            }
            throw StripeError.requestFailed
        }
        
        let paymentIntent = try JSONDecoder().decode(PaymentIntent.self, from: data)
        return paymentIntent
    }
    
    func confirmPaymentIntent(paymentIntentId: String, paymentMethodId: String) async throws -> PaymentIntent {
        let endpoint = "/payment_intents/\(paymentIntentId)/confirm"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "payment_method=\(paymentMethodId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.requestFailed
        }
        
        let paymentIntent = try JSONDecoder().decode(PaymentIntent.self, from: data)
        return paymentIntent
    }
    
    func createCustomer(email: String, name: String? = nil) async throws -> StripeCustomer {
        guard !secretKey.isEmpty else {
            print("Debug: StripeManager - Secret key not configured for customer creation")
            throw StripeError.notConfigured
        }
        
        print("Debug: StripeManager - Creating customer with email: \(email)")
        let endpoint = "/customers"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "email", value: email)
        ]
        
        if let name = name {
            bodyComponents.queryItems?.append(URLQueryItem(name: "name", value: name))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.requestFailed
        }
        
        let customer = try JSONDecoder().decode(StripeCustomer.self, from: data)
        return customer
    }
    
    func createPaymentMethod(type: String, cardToken: String? = nil) async throws -> PaymentMethod {
        let endpoint = "/payment_methods"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "type", value: type)
        ]
        
        if let cardToken = cardToken {
            bodyComponents.queryItems?.append(URLQueryItem(name: "card", value: cardToken))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.requestFailed
        }
        
        let paymentMethod = try JSONDecoder().decode(PaymentMethod.self, from: data)
        return paymentMethod
    }
    
    func createCardToken(cardNumber: String, expMonth: Int, expYear: Int, cvc: String) async throws -> String {
        guard !secretKey.isEmpty else {
            print("Debug: StripeManager - Secret key not configured for card token creation")
            throw StripeError.notConfigured
        }
        
        print("Debug: StripeManager - Creating card token")
        let endpoint = "/tokens"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "card[number]", value: cardNumber),
            URLQueryItem(name: "card[exp_month]", value: "\(expMonth)"),
            URLQueryItem(name: "card[exp_year]", value: "\(expYear)"),
            URLQueryItem(name: "card[cvc]", value: cvc)
        ]
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.requestFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(CardTokenResponse.self, from: data)
        return tokenResponse.id
    }
    
    func attachPaymentMethodToCustomer(paymentMethodId: String, customerId: String) async throws {
        let endpoint = "/payment_methods/\(paymentMethodId)/attach"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "customer=\(customerId)"
        request.httpBody = body.data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.requestFailed
        }
    }
    
    // MARK: - Stripe Checkout (Hosted Payment Page)
    func createCheckoutSession(amount: Decimal, currency: String = "usd", customerEmail: String, customerName: String, merchantReference: String) async throws -> StripeCheckoutSession {
        guard !secretKey.isEmpty else {
            print("Debug: StripeManager - Secret key not configured for checkout session")
            throw StripeError.notConfigured
        }
        
        print("Debug: StripeManager - Creating Stripe Checkout session for amount: \(amount)")
        
        let endpoint = "/checkout/sessions"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Convert amount to cents
        let amountInCents = Int((amount as NSDecimalNumber).doubleValue * 100)
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "payment_method_types[]", value: "card"),
            URLQueryItem(name: "line_items[0][price_data][currency]", value: currency),
            URLQueryItem(name: "line_items[0][price_data][product_data][name]", value: "Payment to \(customerName)"),
            URLQueryItem(name: "line_items[0][price_data][unit_amount]", value: "\(amountInCents)"),
            URLQueryItem(name: "line_items[0][quantity]", value: "1"),
            URLQueryItem(name: "mode", value: "payment"),
            URLQueryItem(name: "success_url", value: "https://httpbin.org/get?status=success&session_id={CHECKOUT_SESSION_ID}"),
            URLQueryItem(name: "cancel_url", value: "https://httpbin.org/get?status=cancelled&session_id={CHECKOUT_SESSION_ID}"),
            URLQueryItem(name: "customer_email", value: customerEmail),
            URLQueryItem(name: "metadata[merchant_reference]", value: merchantReference)
        ]
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: StripeManager - Invalid HTTP response for checkout session")
            throw StripeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: StripeManager - Checkout session HTTP error \(httpResponse.statusCode)")
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Debug: StripeManager - Stripe checkout error: \(errorData)")
            }
            throw StripeError.requestFailed
        }
        
        let checkoutSession = try JSONDecoder().decode(StripeCheckoutSession.self, from: data)
        print("Debug: StripeManager - Checkout session created successfully: \(checkoutSession.id)")
        return checkoutSession
    }
    
    /// Check the status of a Stripe Checkout session
    func checkCheckoutSessionStatus(sessionId: String) async throws -> StripeCheckoutSessionStatus {
        guard !secretKey.isEmpty else {
            print("Debug: StripeManager - Secret key not configured for session status check")
            throw StripeError.notConfigured
        }
        
        print("Debug: StripeManager - Checking Stripe Checkout session status for: \(sessionId)")
        
        let endpoint = "/checkout/sessions/\(sessionId)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: StripeManager - Invalid HTTP response for session status")
            throw StripeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: StripeManager - Session status HTTP error \(httpResponse.statusCode)")
            throw StripeError.requestFailed
        }
        
        let sessionStatus = try JSONDecoder().decode(StripeCheckoutSessionStatus.self, from: data)
        print("Debug: StripeManager - Stripe session status: \(sessionStatus.paymentStatus)")
        return sessionStatus
    }
    
    // MARK: - Tap to Pay (for iOS)
    func setupTapToPay() async throws {
        // This would integrate with Stripe's Tap to Pay SDK
        // For now, we'll just print a setup message
        print("Setting up Stripe Tap to Pay...")
    }
    
    func processTapToPayPayment(amount: Int, currency: String = "usd") async throws -> PaymentIntent {
        // This would use Stripe's Tap to Pay SDK to process contactless payments
        // For now, we'll create a payment intent
        return try await createPaymentIntent(amount: amount, currency: currency)
    }
}

// MARK: - Stripe Models
struct PaymentIntent: Codable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let clientSecret: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case currency
        case status
        case clientSecret = "client_secret"
    }
}

struct StripeCustomer: Codable {
    let id: String
    let email: String?
    let name: String?
    let created: Int
}

struct PaymentMethod: Codable {
    let id: String
    let type: String
    let card: CardDetails?
    
    struct CardDetails: Codable {
        let brand: String
        let last4: String
        let expMonth: Int
        let expYear: Int
        
        enum CodingKeys: String, CodingKey {
            case brand
            case last4
            case expMonth = "exp_month"
            case expYear = "exp_year"
        }
    }
}

struct CardTokenResponse: Codable {
    let id: String
    let type: String
    let card: CardTokenDetails?
    
    struct CardTokenDetails: Codable {
        let brand: String
        let last4: String
        let expMonth: Int
        let expYear: Int
        
        enum CodingKeys: String, CodingKey {
            case brand
            case last4
            case expMonth = "exp_month"
            case expYear = "exp_year"
        }
    }
}

// MARK: - Stripe Checkout Models
struct StripeCheckoutSession: Codable {
    let id: String
    let object: String
    let url: String?
    let paymentStatus: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case url
        case paymentStatus = "payment_status"
        case status
    }
}

struct StripeCheckoutSessionStatus: Codable {
    let id: String
    let object: String
    let paymentStatus: String
    let status: String
    let amountTotal: Int?
    let currency: String?
    let customerEmail: String?
    let paymentIntentId: String?
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case paymentStatus = "payment_status"
        case status
        case amountTotal = "amount_total"
        case currency
        case customerEmail = "customer_email"
        case paymentIntentId = "payment_intent"
        case metadata
    }
    
    /// Check if payment was completed successfully
    var isCompleted: Bool {
        return paymentStatus == "paid"
    }
    
    /// Check if session is still open
    var isOpen: Bool {
        return status == "open"
    }
    
    /// Check if session expired
    var isExpired: Bool {
        return status == "expired"
    }
}

// MARK: - Errors
enum StripeError: Error, LocalizedError {
    case notConfigured
    case requestFailed
    case paymentFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Stripe not configured. Please set publishable and secret keys."
        case .requestFailed:
            return "Stripe API request failed."
        case .paymentFailed:
            return "Payment processing failed."
        case .invalidResponse:
            return "Invalid response from Stripe API."
        }
    }
} 