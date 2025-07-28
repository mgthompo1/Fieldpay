import Foundation
import Combine

class NetSuiteAPI: ObservableObject {
    static let shared = NetSuiteAPI()
    
    private(set) var accessToken: String?
    private var accountId: String?
    private var tokenExpiryDate: Date?
    
    // Reference to OAuthManager for token refresh
    private var oAuthManager: OAuthManager?
    
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
    
    private init() {
        // Initialize OAuthManager on main actor when needed
    }
    
    // MARK: - Configuration
    func configure(accountId: String, accessToken: String) {
        self.accountId = accountId
        self.accessToken = accessToken
        
        // Load token expiry from UserDefaults
        if let expiryDate = UserDefaults.standard.object(forKey: "netsuite_token_expiry") as? Date {
            self.tokenExpiryDate = expiryDate
            print("Debug: NetSuiteAPI - Loaded token expiry: \(expiryDate)")
        }
        
        print("Debug: NetSuiteAPI configured with account ID: \(accountId)")
        print("Debug: NetSuiteAPI access token length: \(accessToken.count)")
        print("Debug: NetSuiteAPI token expiry: \(tokenExpiryDate?.description ?? "not set")")
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
        
        // Load token expiry if not set
        if tokenExpiryDate == nil {
            if let storedExpiry = UserDefaults.standard.object(forKey: "netsuite_token_expiry") as? Date {
                tokenExpiryDate = storedExpiry
                print("Debug: NetSuiteAPI - Loaded token expiry from UserDefaults: \(storedExpiry)")
            }
        }
        
        let configured = accountId != nil && !accountId!.isEmpty && accessToken != nil && !accessToken!.isEmpty
        print("Debug: NetSuiteAPI configuration status: \(configured)")
        if configured {
            print("Debug: NetSuiteAPI - Account ID: \(accountId ?? "nil")")
            print("Debug: NetSuiteAPI - Access token present: \(accessToken != nil)")
            print("Debug: NetSuiteAPI - Token expiry: \(tokenExpiryDate?.description ?? "not set")")
        } else {
            print("Debug: NetSuiteAPI - Missing configuration:")
            print("  - Account ID: \(accountId ?? "nil")")
            print("  - Access token: \(accessToken != nil ? "present" : "missing")")
            print("  - Token expiry: \(tokenExpiryDate?.description ?? "not set")")
        }
        return configured
    }
    
    func testConnection() async throws {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        // Try to fetch a single customer to test the connection
        let endpoint = "/services/rest/record/v1/customer?limit=1"
        let url = URL(string: baseURL + endpoint)!
        
        let request = createRequest(url: url)
        logRequestDetails(request)
        
        print("Debug: NetSuiteAPI - Testing connection to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 200 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            print("Debug: NetSuiteAPI - Connection test successful after token refresh")
            return
        }
        
        if httpResponse.statusCode != 200 {
            print("Debug: NetSuiteAPI - Test connection failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        print("Debug: NetSuiteAPI - Connection test successful")
    }
    
    func updateTokens(accessToken: String, refreshToken: String, expiryDate: Date) {
        self.accessToken = accessToken
        self.tokenExpiryDate = expiryDate
        
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
        print("Debug: NetSuiteAPI - Token expiry: \(expiryDate)")
    }
    
    // MARK: - Token Validation and Refresh
    private func isTokenExpired() -> Bool {
        guard let expiryDate = tokenExpiryDate else {
            print("Debug: NetSuiteAPI - No token expiry date set, assuming expired")
            return true
        }
        
        let now = Date()
        let isExpired = now >= expiryDate
        print("Debug: NetSuiteAPI - Token expiry check: \(expiryDate), current time: \(now), expired: \(isExpired)")
        return isExpired
    }
    
    private func validateTokenBeforeRequest() async throws {
        guard isConfigured() else {
            throw NetSuiteError.notConfigured
        }
        
        // Check if token is expired
        if isTokenExpired() {
            print("Debug: NetSuiteAPI - Token expired, attempting refresh...")
            try await refreshTokenIfNeeded()
        }
    }
    
    private func refreshTokenIfNeeded() async throws {
        guard let refreshToken = UserDefaults.standard.string(forKey: "netsuite_refresh_token") else {
            print("Debug: NetSuiteAPI - No refresh token available")
            throw NetSuiteError.authenticationFailed
        }
        
        print("Debug: NetSuiteAPI - Refreshing access token...")
        
        // Get OAuthManager on main actor
        let oAuthManager = await MainActor.run {
            if self.oAuthManager == nil {
                self.oAuthManager = OAuthManager.shared
            }
            return self.oAuthManager!
        }
        
        do {
            let newTokens = try await oAuthManager.refreshAccessToken(refreshToken: refreshToken)
            
            // Update tokens in NetSuiteAPI
            self.accessToken = newTokens.accessToken
            self.tokenExpiryDate = newTokens.expiryDate
            
            // Store new tokens
            UserDefaults.standard.set(newTokens.refreshToken, forKey: "netsuite_refresh_token")
            UserDefaults.standard.set(newTokens.expiryDate, forKey: "netsuite_token_expiry")
            
            print("Debug: NetSuiteAPI - Token refresh successful")
            print("Debug: NetSuiteAPI - New token expiry: \(newTokens.expiryDate)")
        } catch {
            print("Debug: NetSuiteAPI - Token refresh failed: \(error)")
            throw NetSuiteError.authenticationFailed
        }
    }
    
    private func handle401Response() async throws {
        print("Debug: NetSuiteAPI - Received 401 Unauthorized, attempting token refresh...")
        try await refreshTokenIfNeeded()
    }
    
    // MARK: - Helper Methods
    private func createRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Set consistent headers
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func logRequestDetails(_ request: URLRequest) {
        print("Debug: NetSuiteAPI - Request URL: \(request.url?.absoluteString ?? "nil")")
        print("Debug: NetSuiteAPI - Request method: \(request.httpMethod ?? "nil")")
        print("Debug: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Debug: NetSuiteAPI - Request body: \(bodyString)")
        }
    }
    
    private func logResponseDetails(_ response: HTTPURLResponse, data: Data) {
        print("Debug: NetSuiteAPI - Response status: \(response.statusCode)")
        print("Debug: NetSuiteAPI - Response headers: \(response.allHeaderFields)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Debug: NetSuiteAPI - Response body: \(responseString)")
        }
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
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let endpoint = "/services/rest/record/v1/customer"
        let url = URL(string: baseURL + endpoint)!
        
        print("Debug: NetSuiteAPI - Fetching customers from: \(url)")
        
        let request = createRequest(url: url)
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 200 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            // Parse the retry response
            return try parseCustomerResponse(retryData)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        // Parse the response
        return try parseCustomerResponse(data)
    }
    
    private func parseCustomerResponse(_ data: Data) throws -> [Customer] {
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
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let endpoint = "/services/rest/record/v1/customer/\(id)"
        let url = URL(string: baseURL + endpoint)!
        
        let request = createRequest(url: url)
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 200 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            // Parse the retry response
            let netSuiteCustomer = try JSONDecoder().decode(NetSuiteCustomerResponse.self, from: retryData)
            return netSuiteCustomer.toCustomer()
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        let netSuiteCustomer = try JSONDecoder().decode(NetSuiteCustomerResponse.self, from: data)
        return netSuiteCustomer.toCustomer()
    }
    
    // MARK: - Invoices
    func fetchInvoices() async throws -> [Invoice] {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let endpoint = "/services/rest/record/v1/invoice"
        let url = URL(string: baseURL + endpoint)!
        
        print("Debug: NetSuiteAPI - Fetching invoices from: \(url)")
        
        let request = createRequest(url: url)
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 200 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            // Parse the retry response
            return try parseInvoiceResponse(retryData)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        // Parse the response
        return try parseInvoiceResponse(data)
    }
    
    private func parseInvoiceResponse(_ data: Data) throws -> [Invoice] {
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
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let endpoint = "/services/rest/record/v1/invoice/\(id)"
        let url = URL(string: baseURL + endpoint)!
        
        let request = createRequest(url: url)
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 200 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            // Parse the retry response
            let netSuiteInvoice = try JSONDecoder().decode(NetSuiteInvoiceResponse.self, from: retryData)
            return netSuiteInvoice.toInvoice()
        }
        
        guard httpResponse.statusCode == 200 else {
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
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let endpoint = "/services/rest/record/v1/customerpayment"
        let url = URL(string: baseURL + endpoint)!
        
        let paymentData = try JSONEncoder().encode(payment)
        let request = createRequest(url: url, method: "POST", body: paymentData)
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url, method: "POST", body: paymentData)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 201 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            // Parse the retry response
            let createdPayment = try JSONDecoder().decode(Payment.self, from: retryData)
            return createdPayment
        }
        
        guard httpResponse.statusCode == 201 else {
            throw NetSuiteError.requestFailed
        }
        
        let createdPayment = try JSONDecoder().decode(Payment.self, from: data)
        return createdPayment
    }
    
    func fetchPayments() async throws -> [Payment] {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let endpoint = "/services/rest/record/v1/customerpayment"
        let url = URL(string: baseURL + endpoint)!
        
        let request = createRequest(url: url)
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        // Handle 401 Unauthorized with automatic token refresh
        if httpResponse.statusCode == 401 {
            try await handle401Response()
            // Retry the request with new token
            let retryRequest = createRequest(url: url)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw NetSuiteError.requestFailed
            }
            
            if retryHttpResponse.statusCode != 200 {
                print("Debug: NetSuiteAPI - Retry request failed with status: \(retryHttpResponse.statusCode)")
                throw NetSuiteError.requestFailed
            }
            
            // Parse the retry response
            let payments = try JSONDecoder().decode([Payment].self, from: retryData)
            return payments
        }
        
        guard httpResponse.statusCode == 200 else {
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
