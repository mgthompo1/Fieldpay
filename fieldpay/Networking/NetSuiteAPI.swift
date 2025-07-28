import Foundation
import Combine

class NetSuiteAPI: ObservableObject {
    static let shared = NetSuiteAPI()
    
    private(set) var accessToken: String?
    private var accountId: String?
    
    private var baseURL: String {
        guard let accountId = accountId, !accountId.isEmpty else {
            print("Debug: NetSuiteAPI - Account ID not configured, cannot make API calls")
            // Return a placeholder that will cause a clear error instead of a DNS error
            return "https://placeholder.suitetalk.api.netsuite.com"
        }
        let url = "https://\(accountId).suitetalk.api.netsuite.com"
        print("Debug: NetSuiteAPI - Using base URL: \(url)")
        return url
    }
    
    private init() {}
    
    // MARK: - Configuration
    func configure(accountId: String, accessToken: String) {
        self.accountId = accountId
        self.accessToken = accessToken
        print("Debug: NetSuiteAPI configured with account ID: \(accountId)")
        print("Debug: NetSuiteAPI access token length: \(accessToken.count)")
    }
    
    func isConfigured() -> Bool {
        // First, try to load configuration from UserDefaults if not already set
        if accountId == nil || accountId!.isEmpty {
            if let storedAccountId = UserDefaults.standard.string(forKey: "netsuite_account_id") {
                accountId = storedAccountId
                print("Debug: NetSuiteAPI - Loaded account ID from UserDefaults: \(storedAccountId)")
            }
        }
        
        if accessToken == nil || accessToken!.isEmpty {
            if let storedAccessToken = UserDefaults.standard.string(forKey: "netsuite_access_token") {
                accessToken = storedAccessToken
                print("Debug: NetSuiteAPI - Loaded access token from UserDefaults")
            }
        }
        
        let configured = accountId != nil && !accountId!.isEmpty && accessToken != nil && !accessToken!.isEmpty
        print("Debug: NetSuiteAPI configuration status: \(configured)")
        if configured {
            print("Debug: NetSuiteAPI - Account ID: \(accountId ?? "nil")")
            print("Debug: NetSuiteAPI - Access token present: \(accessToken != nil)")
        } else {
            print("Debug: NetSuiteAPI - Missing configuration:")
            print("  - Account ID: \(accountId ?? "nil")")
            print("  - Access token: \(accessToken != nil ? "present" : "missing")")
        }
        return configured
    }
    
    func testConnection() async throws {
        guard isConfigured() else {
            throw NetSuiteError.notConfigured
        }
        
        // Try to fetch a single customer to test the connection
        let endpoint = "/services/rest/record/v1/customer?limit=1"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("Debug: NetSuiteAPI - Testing connection to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        print("Debug: NetSuiteAPI - Test connection response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: NetSuiteAPI - Test connection error response: \(responseString)")
            }
            throw NetSuiteError.requestFailed
        }
        
        print("Debug: NetSuiteAPI - Connection test successful")
    }
    
    func updateTokens(accessToken: String, refreshToken: String, expiryDate: Date) {
        self.accessToken = accessToken
        // Store refresh token and expiry date for future use
        UserDefaults.standard.set(refreshToken, forKey: "netsuite_refresh_token")
        UserDefaults.standard.set(expiryDate, forKey: "netsuite_token_expiry")
        
        // Always ensure the account ID is set from UserDefaults
        if let accountId = UserDefaults.standard.string(forKey: "netsuite_account_id") {
            self.accountId = accountId
            print("Debug: NetSuiteAPI - Updated account ID from UserDefaults: \(accountId)")
        } else {
            print("Debug: NetSuiteAPI - No account ID found in UserDefaults")
        }
        
        print("Debug: NetSuiteAPI - updateTokens completed:")
        print("Debug: NetSuiteAPI - Account ID: \(self.accountId ?? "nil")")
        print("Debug: NetSuiteAPI - Access token present: \(self.accessToken != nil)")
    }
    
    // MARK: - Authentication
    func authenticate() async throws {
        // NetSuite OAuth 2.0 authentication
        // This would typically involve getting a JWT token
        guard accessToken != nil, let accountId = accountId else {
            throw NetSuiteError.notConfigured
        }
        
        // Validate token and set up session
        print("NetSuite authenticated for account: \(accountId)")
    }
    
    // MARK: - Customers
    func fetchCustomers() async throws -> [Customer] {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            print("Debug: NetSuiteAPI - Access token not configured")
            throw NetSuiteError.notConfigured
        }
        
        let endpoint = "/services/rest/record/v1/customer"
        let url = URL(string: baseURL + endpoint)!
        
        print("Debug: NetSuiteAPI - Fetching customers from: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("Debug: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("Debug: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
        print("Debug: NetSuiteAPI - Response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Debug: NetSuiteAPI - Response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        // Parse NetSuite customer response using the proper response model
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteCustomerResponse>.self, from: data)
            let customers = netSuiteResponse.items.map { $0.toCustomer() }
            print("Debug: NetSuiteAPI - Successfully fetched \(customers.count) customers")
            return customers
        } catch {
            print("Debug: NetSuiteAPI - Failed to decode customer response: \(error)")
            // Try to decode as a single customer if it's not a list response
            do {
                let singleCustomer = try JSONDecoder().decode(NetSuiteCustomerResponse.self, from: data)
                let customer = singleCustomer.toCustomer()
                print("Debug: NetSuiteAPI - Successfully fetched 1 customer (single response)")
                return [customer]
            } catch {
                print("Debug: NetSuiteAPI - Failed to decode as single customer: \(error)")
                print("Debug: NetSuiteAPI - API response could not be parsed, throwing error")
                throw NetSuiteError.invalidResponse
            }
        }
    }
    
    func fetchCustomer(id: String) async throws -> Customer {
        let endpoint = "/services/rest/record/v1/customer/\(id)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        let netSuiteCustomer = try JSONDecoder().decode(NetSuiteCustomerResponse.self, from: data)
        return netSuiteCustomer.toCustomer()
    }
    
    // MARK: - Invoices
    func fetchInvoices() async throws -> [Invoice] {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            print("Debug: NetSuiteAPI - Access token not configured")
            throw NetSuiteError.notConfigured
        }
        
        let endpoint = "/services/rest/record/v1/invoice"
        let url = URL(string: baseURL + endpoint)!
        
        print("Debug: NetSuiteAPI - Fetching invoices from: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("Debug: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("Debug: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
        print("Debug: NetSuiteAPI - Response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Debug: NetSuiteAPI - Response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        // Parse NetSuite invoice response using the proper response model
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteInvoiceResponse>.self, from: data)
            let invoices = netSuiteResponse.items.map { $0.toInvoice() }
            print("Debug: NetSuiteAPI - Successfully fetched \(invoices.count) invoices")
            return invoices
        } catch {
            print("Debug: NetSuiteAPI - Failed to decode invoice response: \(error)")
            // Try to decode as a single invoice if it's not a list response
            do {
                let singleInvoice = try JSONDecoder().decode(NetSuiteInvoiceResponse.self, from: data)
                let invoice = singleInvoice.toInvoice()
                print("Debug: NetSuiteAPI - Successfully fetched 1 invoice (single response)")
                return [invoice]
            } catch {
                print("Debug: NetSuiteAPI - Failed to decode as single invoice: \(error)")
                print("Debug: NetSuiteAPI - API response could not be parsed, throwing error")
                throw NetSuiteError.invalidResponse
            }
        }
    }
    
    func fetchInvoice(id: String) async throws -> Invoice {
        let endpoint = "/services/rest/record/v1/invoice/\(id)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        let netSuiteInvoice = try JSONDecoder().decode(NetSuiteInvoiceResponse.self, from: data)
        return netSuiteInvoice.toInvoice()
    }
    
    // MARK: - Sales Orders
    func fetchSalesOrders() async throws -> [SalesOrder] {
        let endpoint = "/services/rest/record/v1/salesorder"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        let salesOrders = try JSONDecoder().decode([SalesOrder].self, from: data)
        return salesOrders
    }
    
    func fetchSalesOrder(id: String) async throws -> SalesOrder {
        let endpoint = "/services/rest/record/v1/salesorder/\(id)"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        let salesOrder = try JSONDecoder().decode(SalesOrder.self, from: data)
        return salesOrder
    }
    
    // MARK: - Payments
    func createPayment(_ payment: Payment) async throws -> Payment {
        let endpoint = "/services/rest/record/v1/customerpayment"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let paymentData = try JSONEncoder().encode(payment)
        request.httpBody = paymentData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw NetSuiteError.requestFailed
        }
        
        let createdPayment = try JSONDecoder().decode(Payment.self, from: data)
        return createdPayment
    }
    
    func fetchPayments() async throws -> [Payment] {
        let endpoint = "/services/rest/record/v1/customerpayment"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        let payments = try JSONDecoder().decode([Payment].self, from: data)
        return payments
    }
}

// MARK: - Errors
enum NetSuiteError: Error, LocalizedError {
    case notConfigured
    case requestFailed
    case invalidResponse
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "NetSuite API not configured. Please set account ID and access token."
        case .requestFailed:
            return "NetSuite API request failed."
        case .invalidResponse:
            return "Invalid response from NetSuite API."
        case .authenticationFailed:
            return "NetSuite authentication failed."
        }
    }
} 
