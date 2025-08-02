import Foundation
import Combine

// MARK: - NetSuite API Constants

enum NetSuiteAPIPath {
    static let recordBase = "/services/rest/record/v1"
    static let queryBase = "/services/rest/query/v1"
    
    static let invoice = "\(recordBase)/invoice"
    static let customer = "\(recordBase)/customer"
    static let customerPayment = "\(recordBase)/customerpayment"
    static let transaction = "\(recordBase)/transaction"
    static let salesOrder = "\(recordBase)/salesorder"
    static let suiteQL = "\(queryBase)/suiteql"
}

// MARK: - NetSuite Resource Enum

enum NetSuiteResource {
    case invoices(limit: Int, offset: Int, status: String?)
    case invoiceDetail(id: String)
    case customers(limit: Int, offset: Int)
    case customerDetail(id: String)
    case customerPayments(customerId: String, limit: Int, offset: Int)
    case customerInvoices(customerId: String, limit: Int, offset: Int)
    case customerTransactions(customerId: String, limit: Int)
    case suiteQL(query: String)

    func url(with baseURL: String) -> URL {
        switch self {
        case .invoices(let limit, let offset, let status):
            // Use REST Record API for invoices - provides total, amountpaid, amountremaining, etc.
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.invoice)!
            var queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            
            // Add status filter if provided
            if let status = status {
                queryItems.append(URLQueryItem(name: "q", value: "status==\"\(status)\""))
            }
            
            components.queryItems = queryItems
            return components.url!
        case .invoiceDetail(let id):
            return URL(string: baseURL + NetSuiteAPIPath.invoice + "/\(id)")!
        case .customers(let limit, let offset):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.customer)!
            components.queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            return components.url!
        case .customerDetail(let id):
            return URL(string: baseURL + NetSuiteAPIPath.customer + "/\(id)")!
        case .customerPayments(let customerId, let limit, let offset):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.customerPayment)!
            components.queryItems = [
                URLQueryItem(name: "q", value: "entity==\"\(customerId)\""),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            return components.url!
        case .customerInvoices(let customerId, let limit, let offset):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.invoice)!
            components.queryItems = [
                URLQueryItem(name: "q", value: "entity==\"\(customerId)\""),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            return components.url!
        case .customerTransactions(let customerId, let limit):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.transaction)!
            components.queryItems = [
                URLQueryItem(name: "q", value: "entity==\"\(customerId)\""),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            return components.url!
        case .suiteQL(_):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.suiteQL)!
            // Add pagination parameters if they exist in the query context
            // For now, we'll add default pagination to prevent large result sets
            components.queryItems = [
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "offset", value: "0")
            ]
            return components.url!
        }
    }
    
    var method: String { 
        switch self {
        case .suiteQL:
            return "POST"
        default:
            return "GET"
        }
    }
}

// MARK: - NetSuiteAPI Generic Fetch

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
        print("Debug: ===== NetSuiteAPI.configure() called =====")
        print("Debug: Account ID: \(accountId)")
        print("Debug: Access token length: \(accessToken.count)")
        
        // Validate input parameters
        guard !accountId.isEmpty else {
            print("Debug: ERROR - Account ID is empty")
            return
        }
        
        guard !accessToken.isEmpty else {
            print("Debug: ERROR - Access token is empty")
            return
        }
        
        guard accessToken.count > 10 else {
            print("Debug: ERROR - Access token is too short, likely invalid")
            return
        }
        
        self.accountId = accountId
        self.accessToken = accessToken
        
        // Store account ID and access token securely in Keychain
        let keychainWrapper = KeychainWrapper.shared
        
        // Save configuration to Keychain
        let configSaved = keychainWrapper.saveNetSuiteConfiguration(
            accountId: accountId,
            clientId: "", // Will be set by OAuthManager
            clientSecret: "", // Will be set by OAuthManager
            redirectUri: "fieldpay://callback"
        )
        
        // Save access token to Keychain
        let tokenSaved = keychainWrapper.saveString(key: KeychainWrapper.NetSuiteKeys.accessToken, value: accessToken)
        
        if configSaved && tokenSaved {
            print("Debug: NetSuiteAPI - Configuration and token saved securely to Keychain")
        } else {
            print("Debug: NetSuiteAPI - Failed to save configuration or token to Keychain")
        }
        
        // Load token expiry from Keychain
        if let expiryDate = keychainWrapper.loadDate(key: KeychainWrapper.NetSuiteKeys.tokenExpiry) {
            self.tokenExpiryDate = expiryDate
            print("Debug: NetSuiteAPI - Loaded token expiry from Keychain: \(expiryDate)")
        } else {
            print("Debug: NetSuiteAPI - No token expiry found in Keychain")
        }
        
        print("Debug: NetSuiteAPI configured with account ID: \(accountId)")
        print("Debug: NetSuiteAPI access token length: \(accessToken.count)")
        print("Debug: NetSuiteAPI token expiry: \(tokenExpiryDate?.description ?? "not set")")
        print("Debug: NetSuiteAPI base URL: \(baseURL)")
        
        // Verify configuration was stored correctly
        let storedAccountId = UserDefaults.standard.string(forKey: "netsuite_account_id")
        print("Debug: NetSuiteAPI - Stored account ID verification: \(storedAccountId == accountId)")
        
        print("Debug: ✅ NetSuiteAPI configuration completed successfully")
    }
    
    func isConfigured() -> Bool {
        print("Debug: ===== NetSuiteAPI.isConfigured() called =====")
        
        // Always try to load configuration from Keychain first
        let keychainWrapper = KeychainWrapper.shared
        let config = keychainWrapper.loadNetSuiteConfiguration()
        let tokens = keychainWrapper.loadNetSuiteTokens()
        
        if let storedAccountId = config.accountId {
            accountId = storedAccountId
            print("Debug: NetSuiteAPI - Loaded account ID from Keychain: \(storedAccountId)")
        }
        
        if let storedAccessToken = tokens.accessToken {
            accessToken = storedAccessToken
            print("Debug: NetSuiteAPI - Loaded access token from Keychain")
        }
        
        // Load token expiry if not set
        if let storedExpiry = tokens.expiryDate {
            tokenExpiryDate = storedExpiry
            print("Debug: NetSuiteAPI - Loaded token expiry from Keychain: \(storedExpiry)")
        }
        
        let hasAccountId = accountId != nil && !accountId!.isEmpty
        let hasAccessToken = accessToken != nil && !accessToken!.isEmpty
        let configured = hasAccountId && hasAccessToken
        
        print("Debug: NetSuiteAPI configuration status: \(configured)")
        print("Debug: - Account ID present: \(hasAccountId)")
        print("Debug: - Access token present: \(hasAccessToken)")
        
        if configured {
            print("Debug: NetSuiteAPI - Account ID: \(accountId ?? "nil")")
            print("Debug: NetSuiteAPI - Access token present: \(accessToken != nil)")
            print("Debug: NetSuiteAPI - Access token length: \(accessToken?.count ?? 0)")
            print("Debug: NetSuiteAPI - Token expiry: \(tokenExpiryDate?.description ?? "not set")")
            print("Debug: NetSuiteAPI - Base URL: \(baseURL)")
        } else {
            print("Debug: NetSuiteAPI - Missing configuration:")
            print("  - Account ID: \(accountId ?? "nil")")
            print("  - Access token: \(accessToken != nil ? "present" : "missing")")
            print("  - Token expiry: \(tokenExpiryDate?.description ?? "not set")")
            
            // Additional debugging - check what's actually in Keychain
            print("Debug: NetSuiteAPI - Keychain check:")
            print("  - Stored Account ID: \(config.accountId ?? "nil")")
            print("  - Stored Access Token: \(tokens.accessToken != nil ? "present" : "missing")")
            print("  - Stored Access Token length: \(tokens.accessToken?.count ?? 0)")
            print("  - Stored Expiry: \(tokens.expiryDate?.description ?? "nil")")
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
            let (_, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
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
        print("Debug: ===== NetSuiteAPI.updateTokens() called =====")
        print("Debug: Access token length: \(accessToken.count)")
        print("Debug: Refresh token length: \(refreshToken.count)")
        print("Debug: Expiry date: \(expiryDate)")
        
        self.accessToken = accessToken
        self.tokenExpiryDate = expiryDate
        
        // Store ALL tokens securely in Keychain
        let keychainWrapper = KeychainWrapper.shared
        let tokensSaved = keychainWrapper.saveNetSuiteTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryDate: expiryDate
        )
        
        if tokensSaved {
            print("Debug: ✅ NetSuiteAPI - Tokens saved securely to Keychain")
        } else {
            print("Debug: ❌ NetSuiteAPI - Failed to save tokens to Keychain")
        }
        
        // Always ensure the account ID is set from Keychain
        let config = keychainWrapper.loadNetSuiteConfiguration()
        if let accountId = config.accountId {
            self.accountId = accountId
            print("Debug: NetSuiteAPI - Updated account ID from Keychain: \(accountId)")
        } else {
            print("Debug: NetSuiteAPI - No account ID found in Keychain")
        }
        
        // Verify tokens were stored correctly
        let storedTokens = keychainWrapper.loadNetSuiteTokens()
        
        print("Debug: NetSuiteAPI - Token storage verification:")
        print("Debug: - Access token stored: \(storedTokens.accessToken != nil)")
        print("Debug: - Access token length: \(storedTokens.accessToken?.count ?? 0)")
        print("Debug: - Refresh token stored: \(storedTokens.refreshToken != nil)")
        print("Debug: - Refresh token length: \(storedTokens.refreshToken?.count ?? 0)")
        print("Debug: - Expiry date stored: \(storedTokens.expiryDate != nil)")
        
        print("Debug: NetSuiteAPI - updateTokens completed:")
        print("Debug: NetSuiteAPI - Account ID: \(self.accountId ?? "nil")")
        print("Debug: NetSuiteAPI - Access token present: \(self.accessToken != nil)")
        print("Debug: NetSuiteAPI - Token expiry: \(expiryDate)")
        print("Debug: ✅ NetSuiteAPI tokens updated and stored securely in Keychain")
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
        print("🔍 Debug: ===== validateTokenBeforeRequest() called =====")
        print("🔍 Debug: isConfigured() result: \(isConfigured())")
        
        guard isConfigured() else {
            print("❌ Debug: NetSuiteAPI - Not configured, throwing notConfigured error")
            print("🔍 Debug: Account ID: '\(accountId ?? "nil")'")
            print("🔍 Debug: Access Token: '\(accessToken ?? "nil")'")
            throw NetSuiteError.notConfigured
        }
        
        print("✅ Debug: NetSuiteAPI - Configuration validated successfully")
        
        // Check if token is expired
        if isTokenExpired() {
            print("⚠️ Debug: NetSuiteAPI - Token expired, attempting refresh...")
            try await refreshTokenIfNeeded()
        } else {
            print("✅ Debug: NetSuiteAPI - Token is still valid")
        }
    }
    
    private func refreshTokenIfNeeded() async throws {
        let keychainWrapper = KeychainWrapper.shared
        let tokens = keychainWrapper.loadNetSuiteTokens()
        
        guard let refreshToken = tokens.refreshToken else {
            print("Debug: NetSuiteAPI - No refresh token available in Keychain")
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
            
            // Store new tokens securely in Keychain
            let tokensSaved = keychainWrapper.saveNetSuiteTokens(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken,
                expiryDate: newTokens.expiryDate
            )
            
            if tokensSaved {
                print("Debug: NetSuiteAPI - Token refresh successful and saved to Keychain")
            } else {
                print("Debug: NetSuiteAPI - Token refresh successful but failed to save to Keychain")
            }
            
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
    func fetchCustomers(limit: Int = 50, offset: Int = 0) async throws -> [Customer] {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let resource = NetSuiteResource.customers(limit: limit, offset: offset)
        let customers: [Customer] = try await fetch(resource, type: NetSuiteCustomerListResponse.self).items.map { $0.toCustomer() }
        
        print("Debug: NetSuiteAPI - Parsed \(customers.count) customers from list response")
        print("Debug: NetSuiteAPI - Response count: \(customers.count)") // Assuming NetSuiteCustomerListResponse has a count property
        print("Debug: NetSuiteAPI - Has more: \(false) // Pagination not fully implemented")
        print("Debug: NetSuiteAPI - Offset: \(offset)")
        print("Debug: NetSuiteAPI - Total results: \(customers.count) // Assuming total results is count")
        return customers
    }
    
    func fetchAllCustomers() async throws -> [Customer] {
        var allCustomers: [Customer] = []
        var offset = 0
        let limit = 1000 // Use larger limit for efficiency
        var hasMore = true
        
        print("Debug: NetSuiteAPI - Starting to fetch all customers with pagination")
        
        while hasMore {
            print("Debug: NetSuiteAPI - Fetching customers batch: offset=\(offset), limit=\(limit)")
            let batch = try await fetchCustomers(limit: limit, offset: offset)
            allCustomers.append(contentsOf: batch)
            
            // If we got fewer results than the limit, we've reached the end
            if batch.count < limit {
                hasMore = false
            } else {
                offset += limit
            }
            
            print("Debug: NetSuiteAPI - Fetched \(batch.count) customers in this batch, total so far: \(allCustomers.count)")
        }
        
        print("Debug: NetSuiteAPI - Completed fetching all customers: \(allCustomers.count) total")
        return allCustomers
    }
    
    /// Fetches detailed customer information by ID using Codable models
    func fetchDetailedCustomer(id: String) async throws -> NetSuiteCustomerRecord {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        do {
            let resource = NetSuiteResource.customerDetail(id: id)
            let customer: NetSuiteCustomerRecord = try await fetch(resource, type: NetSuiteCustomerRecord.self)
            
            print("Debug: NetSuiteAPI - Successfully parsed detailed customer: \(customer.displayName)")
            print("Debug: NetSuiteAPI - Customer balance: \(customer.formattedBalance)")
            print("Debug: NetSuiteAPI - Customer status: \(customer.statusSummary)")
            return customer
        } catch {
            print("Debug: NetSuiteAPI - Failed to fetch customer detail via REST API for ID \(id): \(error)")
            
            // Check if it's an invalid ID error and try SuiteQL fallback
            if let netSuiteError = error as? NetSuiteError, netSuiteError == .requestFailed {
                // Try to get the response data to check for specific error messages
                print("Debug: NetSuiteAPI - Detected request failed error, trying SuiteQL fallback...")
                return try await fetchCustomerDetailViaSuiteQL(id: id)
            }
            
            throw error
        }
    }
    
    /// Fallback method to fetch customer details via SuiteQL when REST API fails
    private func fetchCustomerDetailViaSuiteQL(id: String) async throws -> NetSuiteCustomerRecord {
        print("Debug: NetSuiteAPI - Fetching customer detail via SuiteQL for ID: \(id)")
        
        let query = "SELECT id, entityid, companyname, email, phone, isinactive FROM customer WHERE id = '\(id)' LIMIT 1"
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        guard let firstRow = response.items.first else {
            throw NetSuiteError.invalidResponse
        }
        
        // Create a basic NetSuiteCustomerRecord from SuiteQL data
        let customerRecord = NetSuiteCustomerRecord(
            id: firstRow.values["column0"] ?? id,
            entityId: firstRow.values["column1"],
            companyName: firstRow.values["column2"],
            email: firstRow.values["column3"],
            phone: firstRow.values["column4"],
            isInactive: firstRow.values["column5"] == "T",
            dateCreated: nil,
            lastModifiedDate: nil,
            addressbook: nil,
            subsidiary: nil,
            customFieldList: nil
        )
        
        print("Debug: NetSuiteAPI - Successfully fetched customer via SuiteQL: \(customerRecord.entityId ?? "unknown")")
        return customerRecord
    }
    
    /// Fetches detailed customer information for a list of customer IDs using Codable models
    func fetchDetailedCustomers(for customerIds: [String], concurrentLimit: Int = 10) async throws -> [NetSuiteCustomerRecord] {
        print("Debug: NetSuiteAPI - Fetching detailed customers for \(customerIds.count) IDs with concurrent limit: \(concurrentLimit)")
        
        var detailedCustomers: [NetSuiteCustomerRecord] = []
        
        // Use TaskGroup with proper concurrency control
        await withTaskGroup(of: NetSuiteCustomerRecord?.self) { group in
            // Process customers in batches to control concurrency
            for batch in stride(from: 0, to: customerIds.count, by: concurrentLimit) {
                let endIndex = min(batch + concurrentLimit, customerIds.count)
                let batchIds = Array(customerIds[batch..<endIndex])
                
                // Add tasks for this batch
                for customerId in batchIds {
                    group.addTask {
                        do {
                            let customer = try await self.fetchDetailedCustomer(id: customerId)
                            return customer
                        } catch {
                            print("Debug: NetSuiteAPI - Failed to fetch detailed customer \(customerId): \(error)")
                            return nil
                        }
                    }
                }
                
                // Wait for this batch to complete before starting the next batch
                for await result in group {
                    if let customer = result {
                        detailedCustomers.append(customer)
                    }
                }
            }
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(detailedCustomers.count) detailed customers")
        return detailedCustomers
    }
    
    // MARK: - Enhanced Pagination Methods
    
    /// Fetches all invoices using proper pagination with the NetSuite REST API structure
    func fetchAllInvoices() async throws -> [Invoice] {
        print("Debug: NetSuiteAPI - Starting to fetch all invoices with enhanced pagination")
        
        var allInvoices: [Invoice] = []
        var nextURL: String? = baseURL + "/services/rest/record/v1/invoice?limit=1000"
        
        while let url = nextURL {
            print("Debug: NetSuiteAPI - Fetching invoices from: \(url)")
            let (invoices, hasMore, nextPageURL) = try await fetchInvoicePage(from: url)
            allInvoices.append(contentsOf: invoices)
            nextURL = hasMore ? nextPageURL : nil
            
            print("Debug: NetSuiteAPI - Fetched \(invoices.count) invoices in this batch, total so far: \(allInvoices.count)")
        }
        
        print("Debug: NetSuiteAPI - Completed fetching all invoices: \(allInvoices.count) total")
        return allInvoices
    }
    
    /// Fetches a single page of invoices and returns pagination info
    private func fetchInvoicePage(from urlString: String) async throws -> (invoices: [Invoice], hasMore: Bool, nextURL: String?) {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        guard let url = URL(string: urlString) else {
            throw NetSuiteError.invalidURL
        }
        
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
                throw NetSuiteError.requestFailed
            }
            
            return try parseInvoicePageResponse(retryData)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        return try parseInvoicePageResponse(data)
    }
    
    /// Parses a single page of invoice response with pagination info
    private func parseInvoicePageResponse(_ data: Data) throws -> (invoices: [Invoice], hasMore: Bool, nextURL: String?) {
        // Log the raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Debug: NetSuiteAPI - Raw invoice page response: \(String(jsonString.prefix(1000)))...")
        }
        
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteInvoiceResponse>.self, from: data)
            let invoices = netSuiteResponse.items.map { $0.toInvoice() }
            
            // Extract pagination info
            let hasMore = netSuiteResponse.hasMore ?? false
            let nextURL = netSuiteResponse.links?.first(where: { $0.rel == "next" })?.href
            
            print("Debug: NetSuiteAPI - Page response: \(invoices.count) invoices, hasMore: \(hasMore), nextURL: \(nextURL ?? "nil")")
            
            return (invoices: invoices, hasMore: hasMore, nextURL: nextURL)
        } catch {
            print("Debug: NetSuiteAPI - Failed to decode invoice page response: \(error)")
            throw NetSuiteError.invalidResponse
        }
    }
    

    
    /// Fetches a single detailed invoice by ID using Codable models
    func fetchDetailedInvoice(id: String) async throws -> NetSuiteInvoiceRecord {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        do {
            let resource = NetSuiteResource.invoiceDetail(id: id)
            let invoice: NetSuiteInvoiceRecord = try await fetch(resource, type: NetSuiteInvoiceRecord.self)
            
            print("Debug: NetSuiteAPI - Successfully parsed detailed invoice: \(invoice.tranId ?? "unknown")")
            print("Debug: NetSuiteAPI - Invoice details:")
            print("  - ID: \(invoice.id)")
            print("  - Transaction ID: \(invoice.tranId ?? "nil")")
            print("  - Customer: \(invoice.customerName)")
            print("  - Total: \(invoice.formattedTotal)")
            print("  - Balance: \(invoice.formattedBalance)")
            print("  - Status: \(invoice.status?.rawValue ?? "nil")")
            print("  - Due Date: \(invoice.dueDate ?? "nil")")
            print("  - Line items: \(invoice.lineItemsSummary)")
            print("  - Is Paid: \(invoice.isPaid)")
            if let daysUntilDue = invoice.daysUntilDue {
                print("  - Days until due: \(daysUntilDue)")
            }
            return invoice
        } catch {
            print("Debug: NetSuiteAPI - Failed to fetch invoice detail via REST API for ID \(id): \(error)")
            
            // Check if it's an invalid ID error and try SuiteQL fallback
            if let netSuiteError = error as? NetSuiteError, netSuiteError == .requestFailed {
                // Try to get the response data to check for specific error messages
                print("Debug: NetSuiteAPI - Detected request failed error, trying SuiteQL fallback...")
                return try await fetchInvoiceDetailViaSuiteQL(id: id)
            }
            
            throw error
        }
    }
    
    /// Fallback method to fetch invoice details via SuiteQL when REST API fails
    private func fetchInvoiceDetailViaSuiteQL(id: String) async throws -> NetSuiteInvoiceRecord {
        print("Debug: NetSuiteAPI - Fetching invoice detail via SuiteQL for ID: \(id)")
        
        // First fetch the invoice basic data
        let invoiceQuery = "SELECT id, tranid, entity, amount, trandate, status, memo, duedate, amountremaining, amountpaid FROM transaction WHERE id = '\(id)' AND type = 'Invoice'"
        let invoiceResource = NetSuiteResource.suiteQL(query: invoiceQuery)
        let invoiceResponse: SuiteQLResponse = try await fetch(invoiceResource, type: SuiteQLResponse.self)
        
        guard let invoiceRow = invoiceResponse.items.first else {
            throw NetSuiteError.invalidResponse
        }
        
        // Fetch line items for the invoice
        let lineItemQuery = """
        SELECT 
            il.tranid,
            il.line,
            il.item,
            il.quantity,
            il.rate,
            il.amount,
            il.memo,
            i.itemid,
            i.displayname
        FROM transactionline il
        LEFT JOIN item i ON il.item = i.id
        WHERE il.transaction = '\(id)'
        ORDER BY il.line
        """
        
        let lineItemResource = NetSuiteResource.suiteQL(query: lineItemQuery)
        let lineItemResponse: SuiteQLResponse = try await fetch(lineItemResource, type: SuiteQLResponse.self)
        
        // Convert line items
        let lineItems = lineItemResponse.items.map { row -> LineItem in
            let itemId = row.values["column2"] ?? ""
            let itemName = row.values["column8"] ?? row.values["column7"] ?? "Unknown Item"
            
            return LineItem(
                line: Int(row.values["column1"] ?? "0"),
                description: row.values["column6"] ?? itemName,
                item: Reference(id: itemId, refName: itemName, type: "item"),
                quantity: Double(row.values["column3"] ?? "0"),
                rate: Double(row.values["column4"] ?? "0"),
                amount: Double(row.values["column5"] ?? "0"),
                taxCode: nil,
                grossAmt: nil,
                netAmount: nil,
                taxAmount: nil,
                taxRate1: nil,
                taxRate2: nil,
                customFieldList: nil
            )
        }
        
        print("Debug: NetSuiteAPI - Fetched \(lineItems.count) line items via SuiteQL")
        
        // Create a NetSuiteInvoiceRecord from SuiteQL data with line items
        let invoiceRecord = NetSuiteInvoiceRecord(
            id: invoiceRow.values["column0"] ?? id,
            tranId: invoiceRow.values["column1"],
            entity: EntityReference(id: invoiceRow.values["column2"] ?? "", refName: nil, type: nil),
            tranDate: invoiceRow.values["column4"],
            dueDate: invoiceRow.values["column7"],
            status: invoiceRow.values["column5"],
            total: Double(invoiceRow.values["column3"] ?? "0"),
            currency: nil,
            createdDate: nil,
            lastModifiedDate: nil,
            memo: invoiceRow.values["column6"],
            balance: Double(invoiceRow.values["column8"] ?? "0"),
            location: nil,
            customFieldList: nil,
            item: ItemList(item: lineItems),
            amountRemaining: Double(invoiceRow.values["column8"] ?? "0"),
            amountPaid: Double(invoiceRow.values["column9"] ?? "0"),
            billAddress: nil,
            shipAddress: nil,
            email: nil,
            customForm: nil,
            subsidiary: nil,
            terms: nil,
            postingPeriod: nil,
            source: nil,
            originator: nil,
            toBeEmailed: nil,
            toBeFaxed: nil,
            toBePrinted: nil,
            shipDate: nil,
            shipIsResidential: nil,
            shipOverride: nil,
            estGrossProfit: nil,
            estGrossProfitPercent: nil,
            exchangeRate: nil,
            totalCostEstimate: nil,
            subtotal: nil
        )
        
        print("Debug: NetSuiteAPI - Successfully fetched invoice via SuiteQL: \(invoiceRecord.tranId ?? "unknown")")
        return invoiceRecord
    }
    
    /// Fetches detailed invoice information for a list of invoice IDs using Codable models
    func fetchDetailedInvoices(for invoiceIds: [String], concurrentLimit: Int = 10) async throws -> [NetSuiteInvoiceRecord] {
        print("Debug: NetSuiteAPI - Fetching detailed invoices for \(invoiceIds.count) IDs with concurrent limit: \(concurrentLimit)")
        
        var detailedInvoices: [NetSuiteInvoiceRecord] = []
        var successfulCount = 0
        var failedCount = 0
        
        // Use TaskGroup with proper concurrency control
        await withTaskGroup(of: NetSuiteInvoiceRecord?.self) { group in
            // Process invoices in batches to control concurrency
            for batch in stride(from: 0, to: invoiceIds.count, by: concurrentLimit) {
                let endIndex = min(batch + concurrentLimit, invoiceIds.count)
                let batchIds = Array(invoiceIds[batch..<endIndex])
                
                print("Debug: NetSuiteAPI - Processing batch \(batch/concurrentLimit + 1): \(batchIds.count) invoices")
                
                // Add tasks for this batch
                for invoiceId in batchIds {
                    group.addTask {
                        do {
                            let invoice = try await self.fetchDetailedInvoice(id: invoiceId)
                            return invoice
                        } catch {
                            print("Debug: NetSuiteAPI - Failed to fetch detailed invoice \(invoiceId): \(error)")
                            return nil
                        }
                    }
                }
                
                // Wait for this batch to complete before starting the next batch
                for await result in group {
                    if let invoice = result {
                        detailedInvoices.append(invoice)
                        successfulCount += 1
                    } else {
                        failedCount += 1
                    }
                }
                
                print("Debug: NetSuiteAPI - Batch \(batch/concurrentLimit + 1) completed: \(successfulCount) successful, \(failedCount) failed")
            }
        }
        
        print("Debug: NetSuiteAPI - Completed fetching detailed invoices:")
        print("  - Total requested: \(invoiceIds.count)")
        print("  - Successfully fetched: \(successfulCount)")
        print("  - Failed: \(failedCount)")
        print("  - Success rate: \(String(format: "%.1f%%", Double(successfulCount) / Double(invoiceIds.count) * 100))")
        
        return detailedInvoices
    }
    
    func fetchCustomer(id: String) async throws -> Customer {
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        let resource = NetSuiteResource.customerDetail(id: id)
        let netSuiteCustomer: NetSuiteCustomerResponse = try await fetch(resource, type: NetSuiteCustomerResponse.self)
        
        return netSuiteCustomer.toCustomer()
    }
    
    // MARK: - Invoices
    func fetchInvoices() async throws -> [Invoice] {
        // Use the enhanced pagination method to fetch all invoices
        return try await fetchAllInvoices()
    }
    
    private func parseInvoiceResponse(_ data: Data) throws -> [Invoice] {
        // Log the raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Debug: NetSuiteAPI - Raw invoice response: \(jsonString)")
        }
        
        // Parse NetSuite invoice response using the proper response model
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteInvoiceResponse>.self, from: data)
            let invoices = netSuiteResponse.items.map { $0.toInvoice() }
            print("Debug: NetSuiteAPI - Successfully fetched \(invoices.count) invoices")
            return invoices
        } catch {
            print("Debug: NetSuiteAPI - Failed to decode invoice response as list: \(error)")
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
        
        let resource = NetSuiteResource.invoiceDetail(id: id)
        let netSuiteInvoice: NetSuiteInvoiceResponse = try await fetch(resource, type: NetSuiteInvoiceResponse.self)
        
        return netSuiteInvoice.toInvoice()
    }
    
    // MARK: - Items
    
    /// Fetches available items/products from NetSuite for invoice creation
    func fetchItems(limit: Int = 100) async throws -> [NetSuiteItem] {
        try await validateTokenBeforeRequest()
        
        let query = """
        SELECT 
            id,
            itemid,
            displayname,
            baseprice,
            description,
            isinactive,
            itemtype
        FROM item 
        WHERE isinactive = 'F' 
        AND itemtype IN ('InvtPart', 'NonInvtPart', 'Service')
        ORDER BY displayname
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        let items = response.items.compactMap { row -> NetSuiteItem? in
            guard let id = row.values["column0"],
                  let itemId = row.values["column1"] else {
                return nil
            }
            
            return NetSuiteItem(
                id: id,
                itemId: itemId,
                displayName: row.values["column2"] ?? itemId,
                basePrice: Double(row.values["column3"] ?? "0") ?? 0.0,
                description: row.values["column4"],
                itemType: row.values["column6"] ?? "Service"
            )
        }
        
        print("Debug: NetSuiteAPI - Fetched \(items.count) items")
        return items
    }
    
    // MARK: - Sales Orders
    func fetchSalesOrders() async throws -> [SalesOrder] {
        // Use SuiteQL for full control and compatibility
        let suiteQL = """
            SELECT id, tranid, entity, amount, status, trandate, memo, duedate
            FROM transaction
            WHERE type = 'SalesOrd'
            ORDER BY trandate DESC
        """
        let resource = NetSuiteResource.suiteQL(query: suiteQL)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        // Collect all unique customer IDs
        let customerIds = Set(response.items.compactMap { $0.values["column2"] }).filter { !$0.isEmpty }
        let customerNameMap = try await fetchCustomerNamesBatch(customerIds: Array(customerIds))
        
        // Map SuiteQL rows to SalesOrder
        let salesOrders: [SalesOrder] = response.items.compactMap { row in
            let id = row.values["column0"] ?? ""
            let orderNumber = row.values["column1"] ?? "SO-\(id)"
            let customerId = row.values["column2"] ?? ""
            let amount = Decimal(string: row.values["column3"] ?? "0") ?? Decimal(0)
            let statusRaw = row.values["column4"] ?? "pending_approval"
            let orderDateStr = row.values["column5"]
            let notes = row.values["column6"]
            let dueDateStr = row.values["column7"]
            let customerName = customerNameMap[customerId] ?? "Customer \(customerId)"
            let orderDate = NetSuiteDateParser.parseDate(orderDateStr) ?? Date()
            let dueDate = NetSuiteDateParser.parseDate(dueDateStr)
            return SalesOrder(
                id: id,
                orderNumber: orderNumber,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                status: SalesOrder.SalesOrderStatus(rawValue: statusRaw) ?? .pendingApproval,
                orderDate: orderDate,
                expectedShipDate: dueDate,
                netSuiteId: id,
                items: [], // Items can be fetched separately if needed
                notes: notes
            )
        }
        return salesOrders
    }
    
    /// Fetch sales orders for a specific customer
    func fetchCustomerSalesOrders(for customerId: String) async throws -> [SalesOrder] {
        // Use SuiteQL to fetch sales orders for specific customer
        let suiteQL = """
            SELECT id, tranid, entity, amount, status, trandate, memo, duedate
            FROM transaction
            WHERE type = 'SalesOrd' AND entity = '\(customerId)'
            ORDER BY trandate DESC
        """
        let resource = NetSuiteResource.suiteQL(query: suiteQL)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        // Get customer name for this specific customer
        let customerNameMap = try await fetchCustomerNamesBatch(customerIds: [customerId])
        
        // Map SuiteQL rows to SalesOrder
        let salesOrders: [SalesOrder] = response.items.compactMap { row in
            let id = row.values["column0"] ?? ""
            let orderNumber = row.values["column1"] ?? "SO-\(id)"
            let customerId = row.values["column2"] ?? ""
            let amount = Decimal(string: row.values["column3"] ?? "0") ?? Decimal(0)
            let statusRaw = row.values["column4"] ?? "pending_approval"
            let orderDateStr = row.values["column5"]
            let notes = row.values["column6"]
            let dueDateStr = row.values["column7"]
            let customerName = customerNameMap[customerId] ?? "Customer \(customerId)"
            let orderDate = NetSuiteDateParser.parseDate(orderDateStr) ?? Date()
            let dueDate = NetSuiteDateParser.parseDate(dueDateStr)
            return SalesOrder(
                id: id,
                orderNumber: orderNumber,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                status: SalesOrder.SalesOrderStatus(rawValue: statusRaw) ?? .pendingApproval,
                orderDate: orderDate,
                expectedShipDate: dueDate,
                netSuiteId: id,
                items: [], // Items can be fetched separately if needed
                notes: notes
            )
        }
        
        print("Debug: NetSuiteAPI - Fetched \(salesOrders.count) sales orders for customer \(customerId)")
        return salesOrders
    }

    /// Batch fetch customer names for a set of customer IDs (shared with Invoice logic)
    private func fetchCustomerNamesBatch(customerIds: [String]) async throws -> [String: String] {
        guard !customerIds.isEmpty else { return [:] }
        let idList = customerIds.map { "'\($0)'" }.joined(separator: ",")
        let suiteQLQuery = "SELECT id, entityid, companyname FROM customer WHERE id IN (\(idList))"
        let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        var nameMap: [String: String] = [:]
        for row in response.items {
            let id = row.values["column0"] ?? ""
            let entityId = row.values["column1"] ?? ""
            let companyName = row.values["column2"] ?? ""
            let name = !entityId.isEmpty ? entityId : (!companyName.isEmpty ? companyName : "Customer \(id)")
            nameMap[id] = name
        }
        return nameMap
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
        
        // Convert Payment to NetSuite Customer Payment Record format
        let netSuitePaymentRecord = NetSuiteCustomerPaymentRecord(payment: payment)
        let paymentData = try JSONEncoder().encode(netSuitePaymentRecord)
        
        print("Debug: NetSuiteAPI - Creating customer payment with data: \(String(data: paymentData, encoding: .utf8) ?? "nil")")
        
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
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteCustomerPaymentResponse.self, from: retryData)
            return netSuiteResponse.toPayment()
        }
        
        guard httpResponse.statusCode == 201 else {
            print("Debug: NetSuiteAPI - Create payment failed with status: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Debug: NetSuiteAPI - Error response: \(errorData)")
            }
            throw NetSuiteError.requestFailed
        }
        
        // Parse the response
        let netSuiteResponse = try JSONDecoder().decode(NetSuiteCustomerPaymentResponse.self, from: data)
        return netSuiteResponse.toPayment()
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
    
    /// Fetch recent payments from a specific date
    func fetchRecentPayments(fromDate: Date) async throws -> [Payment] {
        print("Debug: NetSuiteAPI - Fetching recent payments from date: \(fromDate)")
        
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        // Format date for NetSuite query (YYYY-MM-DD format)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDateString = dateFormatter.string(from: fromDate)
        
        // Use SuiteQL to fetch payments with date filtering
        // Note: Using simplified query that works with NetSuite's transaction table
        // Fixed: Use string comparison for type field and proper date filtering
        let query = """
        SELECT 
            id,
            tranid,
            trandate,
            status,
            entity,
            amount
        FROM transaction 
        WHERE type = 'CustPymt' AND trandate >= '\(fromDateString)'
        ORDER BY trandate DESC
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        // Convert SuiteQL response to Payment objects
        let payments = response.items.compactMap { item -> Payment? in
            guard let id = item.values["column0"],
                  let _ = item.values["column1"], // tranId not used but validates response
                  let dateString = item.values["column2"],
                  let date = NetSuiteDateParser.parseDate(dateString),
                  let customerId = item.values["column4"] else {
                return nil
            }
            
            let amount = Decimal(string: item.values["column5"] ?? "0") ?? Decimal(0)
            
            // Default to tapToPay since we can't get payment method from this query
            let paymentMethod: Payment.PaymentMethod = .tapToPay
            
            return Payment(
                id: id,
                amount: amount,
                status: .succeeded, // NetSuite payments are typically completed
                paymentMethod: paymentMethod,
                customerId: customerId,
                description: nil, // memo not available in simplified query
                netSuitePaymentId: id,
                createdDate: date
            )
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(payments.count) recent payments")
        return payments
    }
    
    /// Fetch customer payments filtered by customer ID and date
    func fetchCustomerPaymentsFiltered(customerId: String, fromDate: Date) async throws -> [Payment] {
        print("Debug: NetSuiteAPI - Fetching customer payments for customer: \(customerId), from date: \(fromDate)")
        
        // Validate token before making request
        try await validateTokenBeforeRequest()
        
        // Format date for NetSuite query (YYYY-MM-DD format)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDateString = dateFormatter.string(from: fromDate)
        
        // Use SuiteQL to fetch payments with customer and date filtering
        // Note: Using simplified query that works with NetSuite's transaction table
        // Fixed: Use string comparison for type field and remove table prefix from field names
        let query = """
        SELECT 
            id,
            tranid,
            trandate,
            status,
            entity,
            amount
        FROM transaction 
        WHERE type = 'CustPymt' 
        AND entity = '\(customerId)' 
        AND trandate >= '\(fromDateString)'
        ORDER BY trandate DESC
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        // Convert SuiteQL response to Payment objects
        let payments = response.items.compactMap { item -> Payment? in
            guard let id = item.values["column0"],
                  let _ = item.values["column1"], // tranId not used but validates response
                  let dateString = item.values["column2"],
                  let date = NetSuiteDateParser.parseDate(dateString) else {
                return nil
            }
            
            let amount = Decimal(string: item.values["column5"] ?? "0") ?? Decimal(0)
            
            // Default to tapToPay since we can't get payment method from this query
            let paymentMethod: Payment.PaymentMethod = .tapToPay
            
            return Payment(
                id: id,
                amount: amount,
                status: .succeeded, // NetSuite payments are typically completed
                paymentMethod: paymentMethod,
                customerId: customerId,
                description: nil, // memo not available in simplified query
                netSuitePaymentId: id,
                createdDate: date
            )
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(payments.count) customer payments")
        return payments
    }
    
    /// Generic fetch for any NetSuiteResource and Decodable type
    func fetch<T: Decodable>(_ resource: NetSuiteResource, type: T.Type) async throws -> T {
        return try await performWithTokenRetry(resource: resource, responseType: T.self) { [self] request in
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Debug: NetSuiteAPI - Invalid response type")
                throw NetSuiteError.requestFailed
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Debug: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Debug: NetSuiteAPI - Response body: \(responseString)")
                }
                
                if case .suiteQL = resource {
                    print("Debug: NetSuiteAPI - SuiteQL request failed - this might be due to query syntax or permissions")
                }
                
                if httpResponse.statusCode == 401 {
                    throw NetSuiteError.unauthorizedRequest
                }
                
                throw NetSuiteError.requestFailed
            }
            
            logResponseDetails(httpResponse, data: data)
            return data
        }
    }
    
    /// Centralized retry logic for token refresh on 401 errors
    private func performWithTokenRetry<T: Decodable>(
        resource: NetSuiteResource,
        responseType: T.Type,
        networkCall: @escaping (URLRequest) async throws -> Data
    ) async throws -> T {
        print("Debug: NetSuiteAPI - Fetching resource: \(resource.url(with: baseURL))")
        
        try await validateTokenBeforeRequest()
        let request = createAuthenticatedRequest(for: resource)
        logRequestDetails(request)
        
        do {
            let data = try await networkCall(request)
            return try JSONDecoder().decode(T.self, from: data)
        } catch NetSuiteError.unauthorizedRequest {
            print("Debug: NetSuiteAPI - 401 error, attempting token refresh and retry")
            try await handle401Response()
            
            // Retry with refreshed token
            let retryRequest = createAuthenticatedRequest(for: resource)
            let retryData = try await networkCall(retryRequest)
            return try JSONDecoder().decode(T.self, from: retryData)
        } catch {
            print("Debug: NetSuiteAPI - Failed to decode response: \(error)")
            throw error
        }
    }
    
    /// Create an authenticated request for a NetSuite resource
    private func createAuthenticatedRequest(for resource: NetSuiteResource) -> URLRequest {
        let url = resource.url(with: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = resource.method
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Handle SuiteQL POST requests with query in body
        if case .suiteQL(let query) = resource {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("transient", forHTTPHeaderField: "Prefer")
            let queryBody = ["q": query]
            if let bodyData = try? JSONSerialization.data(withJSONObject: queryBody) {
                request.httpBody = bodyData
            }
            print("Debug: NetSuiteAPI - SuiteQL query in body: \(query)")
        }
        
        return request
    }
    
    /// Execute a SuiteQL query
    func executeSuiteQLQuery(_ query: String) async throws -> SuiteQLResponse {
        try await validateTokenBeforeRequest()
        let resource = NetSuiteResource.suiteQL(query: query)
        return try await fetch(resource, type: SuiteQLResponse.self)
    }
    
    // MARK: - Invoice Creation Support Methods
    
    /// Fetch inventory items for invoice creation
    func fetchInventoryItems(limit: Int = 100) async throws -> [NetSuiteInventoryItem] {
        print("Debug: NetSuiteAPI - Fetching inventory items (limit: \(limit))")
        
        try await validateTokenBeforeRequest()
        let query = SuiteQLQuery.inventoryItems(limit: limit)
        let resource = NetSuiteResource.suiteQL(query: query.query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        // Convert SuiteQL response to NetSuiteInventoryItem objects
        var inventoryItems: [NetSuiteInventoryItem] = []
        for item in response.items {
            if let id = item.values["id"],
               let displayName = item.values["displayname"] {
                
                let inventoryItem = NetSuiteInventoryItem(
                    id: id,
                    itemId: item.values["itemid"],
                    displayName: displayName,
                    description: item.values["description"],
                    basePrice: 0.0, // baseprice not available in SuiteQL item table
                    isInactive: item.values["isinactive"] == "T",
                    itemType: item.values["itemtype"],
                    location: nil,
                    subsidiary: nil,
                    customFieldList: nil
                )
                inventoryItems.append(inventoryItem)
            }
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(inventoryItems.count) inventory items")
        return inventoryItems
    }
    
    /// Fetch invoice templates for invoice creation
    /// Note: Since form table is not queryable via SuiteQL, we use an alternative approach
    func fetchInvoiceTemplates(limit: Int = 50) async throws -> [NetSuiteInvoiceTemplate] {
        print("Debug: NetSuiteAPI - Fetching invoice templates (limit: \(limit))")
        print("Debug: NetSuiteAPI - Note: Using simplified approach since customform is not joinable in SuiteQL")
        
        do {
            try await validateTokenBeforeRequest()
            
            // Simple approach: Get distinct customform IDs from actual invoices
            // We can't join to customform table, so we'll get IDs and create basic templates
            let discoverFormsQuery = """
                SELECT DISTINCT customform
                FROM transaction
                WHERE type = 'CustInvc' AND customform IS NOT NULL
                ORDER BY customform
                """
            
            let resource = NetSuiteResource.suiteQL(query: discoverFormsQuery)
            let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
            
            // Convert SuiteQL response to NetSuiteInvoiceTemplate objects
            var templates: [NetSuiteInvoiceTemplate] = []
            for item in response.items {
                if let formId = item.values["customform"],
                   !formId.isEmpty {
                    
                    // Create a basic template with ID, use generic name since we can't get actual names via SuiteQL
                    let template = NetSuiteInvoiceTemplate(
                        id: formId,
                        name: "Invoice Form \(formId)", // Generic name since we can't join to get actual name
                        isInactive: false, // Assume active since it's being used in invoices
                        customForm: NetSuiteEntityReference(id: formId, refName: "Invoice Form \(formId)"),
                        subsidiary: nil,
                        requiredFields: nil
                    )
                    templates.append(template)
                }
            }
            
            // If no forms found, add a default
            if templates.isEmpty {
                let defaultTemplate = NetSuiteInvoiceTemplate(
                    id: "0", // 0 typically means "use default form" in NetSuite
                    name: "Default Invoice Form",
                    isInactive: false,
                    customForm: NetSuiteEntityReference(id: "0", refName: "Default Invoice Form"),
                    subsidiary: nil,
                    requiredFields: nil
                )
                templates.append(defaultTemplate)
            }
            
            print("Debug: NetSuiteAPI - Successfully discovered \(templates.count) invoice form IDs from actual usage")
            return templates
            
        } catch {
            // If the query fails, fall back to a default template
            print("Debug: NetSuiteAPI - Failed to discover invoice forms from transactions: \(error)")
            print("Debug: NetSuiteAPI - Falling back to default template approach")
            
            // Return a basic default template that should work for most cases
            let defaultTemplate = NetSuiteInvoiceTemplate(
                id: "0", // 0 typically means "use default form" in NetSuite
                name: "Default Invoice Form",
                isInactive: false,
                customForm: NetSuiteEntityReference(id: "0", refName: "Default Invoice Form"),
                subsidiary: nil,
                requiredFields: nil
            )
            
            return [defaultTemplate]
        }
    }
    
    /// Fetch locations for invoice creation
    func fetchLocations(limit: Int = 50) async throws -> [NetSuiteLocation] {
        print("Debug: NetSuiteAPI - Fetching locations (limit: \(limit))")
        
        try await validateTokenBeforeRequest()
        let query = SuiteQLQuery.locations(limit: limit)
        let resource = NetSuiteResource.suiteQL(query: query.query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        // Convert SuiteQL response to NetSuiteLocation objects
        var locations: [NetSuiteLocation] = []
        for item in response.items {
            if let id = item.values["id"],
               let name = item.values["name"] {
                
                let location = NetSuiteLocation(
                    id: id,
                    name: name,
                    isInactive: item.values["isinactive"] == "T",
                    subsidiary: nil,
                    address: nil
                )
                locations.append(location)
            }
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(locations.count) locations")
        return locations
    }
    
    /// Create an invoice in NetSuite
    func createInvoice(request: NetSuiteInvoiceCreationRequest) async throws -> NetSuiteInvoiceRecord {
        print("Debug: NetSuiteAPI - Creating invoice for customer: \(request.entity.refName ?? "Unknown")")
        
        try await validateTokenBeforeRequest()
        let endpoint = "/services/rest/record/v1/invoice"
        let url = URL(string: baseURL + endpoint)!
        
        let requestData = try JSONEncoder().encode(request)
        let urlRequest = createRequest(url: url, method: "POST", body: requestData)
        
        logRequestDetails(urlRequest)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        guard httpResponse.statusCode == 201 else {
            print("Debug: NetSuiteAPI - Invoice creation failed with status: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Debug: NetSuiteAPI - Error response: \(errorData)")
            }
            throw NetSuiteError.requestFailed
        }
        
        let createdInvoice = try JSONDecoder().decode(NetSuiteInvoiceRecord.self, from: data)
        print("Debug: NetSuiteAPI - Successfully created invoice: \(createdInvoice.tranId ?? "Unknown")")
        return createdInvoice
    }

    /// Debug method to test both ID formats and help identify which format works for detail API calls.
    func debugIdFormat(customerId: String) async {
        print("Debug: NetSuiteAPI - Testing ID format for customer: \(customerId)")
        
        // Test 1: Try with original ID format
        do {
            let resource = NetSuiteResource.customerDetail(id: customerId)
            let _: NetSuiteCustomerRecord = try await fetch(resource, type: NetSuiteCustomerRecord.self)
            print("Debug: NetSuiteAPI - ✅ Original ID format works: \(customerId)")
        } catch {
            print("Debug: NetSuiteAPI - ❌ Original ID format failed: \(customerId) - \(error)")
        }
        
        // Test 2: Try with numeric ID format (if different)
        if customerId.contains("-") {
            // If it's a UUID, try extracting numeric part
            let numericId = customerId.components(separatedBy: "-").first ?? customerId
            do {
                let resource = NetSuiteResource.customerDetail(id: numericId)
                let _: NetSuiteCustomerRecord = try await fetch(resource, type: NetSuiteCustomerRecord.self)
                print("Debug: NetSuiteAPI - ✅ Numeric ID format works: \(numericId)")
            } catch {
                print("Debug: NetSuiteAPI - ❌ Numeric ID format failed: \(numericId) - \(error)")
            }
        }
        
        // Test 3: Try SuiteQL query
        do {
            let query = "SELECT id, entityid, companyname FROM customer WHERE id = '\(customerId)' LIMIT 1"
            let resource = NetSuiteResource.suiteQL(query: query)
            let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
            print("Debug: NetSuiteAPI - ✅ SuiteQL query works: \(customerId) - Found \(response.items.count) results")
        } catch {
            print("Debug: NetSuiteAPI - ❌ SuiteQL query failed: \(customerId) - \(error)")
        }
    }

    /// Debug method to analyze the structure of a NetSuite API response
    func debugResponseStructure(for resource: NetSuiteResource) async {
        print("Debug: NetSuiteAPI - Analyzing response structure for: \(resource.url(with: baseURL))")
        
        do {
            try await validateTokenBeforeRequest()
            let url = resource.url(with: baseURL)
            var request = URLRequest(url: url)
            request.httpMethod = resource.method
            request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Handle SuiteQL POST requests with query in body
            if case .suiteQL(let query) = resource {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("transient", forHTTPHeaderField: "Prefer")
                let queryBody = ["q": query]
                request.httpBody = try JSONSerialization.data(withJSONObject: queryBody)
                print("Debug: NetSuiteAPI - SuiteQL query in body: \(query)")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Debug: NetSuiteAPI - Invalid response type")
                return
            }
            
            print("Debug: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: NetSuiteAPI - Response structure analysis:")
                print("  - Response length: \(responseString.count) characters")
                print("  - First 500 characters: \(String(responseString.prefix(500)))")
                
                // Try to parse as JSON and analyze structure
                if let jsonData = responseString.data(using: String.Encoding.utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
                   let jsonDict = jsonObject as? [String: Any] {
                    
                    print("Debug: NetSuiteAPI - JSON structure:")
                    for (key, value) in jsonDict {
                        let valueType = type(of: value)
                        let valueDescription: String
                        
                        if let array = value as? [Any] {
                            valueDescription = "Array with \(array.count) items"
                        } else if let dict = value as? [String: Any] {
                            valueDescription = "Dictionary with \(dict.count) keys"
                        } else {
                            valueDescription = "\(value)"
                        }
                        
                        print("  - \(key): \(valueType) = \(valueDescription)")
                    }
                }
            }
        } catch {
            print("Debug: NetSuiteAPI - Failed to analyze response structure: \(error)")
        }
    }

    /// Test SuiteQL functionality
    func testSuiteQL() async {
        print("Debug: NetSuiteAPI - Testing SuiteQL functionality...")
        
        do {
            // Test a simple SuiteQL query
            let testQuery = "SELECT id, entityid, companyname FROM customer LIMIT 1"
            let resource = NetSuiteResource.suiteQL(query: testQuery)
            let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
            
            print("Debug: NetSuiteAPI - ✅ SuiteQL test successful - Found \(response.items.count) results")
            if let firstItem = response.items.first {
                print("Debug: NetSuiteAPI - First result: \(firstItem.values)")
            }
        } catch {
            print("Debug: NetSuiteAPI - ❌ SuiteQL test failed: \(error)")
        }
    }
    
    // MARK: - SuiteQL Service Methods for Customer Data
    
    /// Fetch customer invoices using SuiteQL with proper pagination
    func fetchCustomerInvoices(for customerId: String, offset: Int = 0) async throws -> [SuiteQLInvoiceRecord] {
        print("Debug: NetSuiteAPI - Fetching customer invoices for customer: \(customerId), offset: \(offset)")
        
        let query = """
        SELECT
            t.id,
            t.tranid,
            t.trandate,
            t.status,
            t.memo,
            t.entity
        FROM transaction t
        WHERE t.entity = '\(customerId)' AND t.type = 'CustInvc'
        ORDER BY t.trandate DESC
        """
        
        let url = "\(baseURL)/services/rest/query/v1/suiteql?limit=50&offset=\(offset)"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("transient", forHTTPHeaderField: "Prefer")
        
        let payload = ["q": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("Debug: NetSuiteAPI - Customer invoices SuiteQL query: \(query)")
        print("Debug: NetSuiteAPI - Request URL: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Customer invoices request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw NetSuiteError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(SuiteQLGenericResponse<SuiteQLInvoiceRecord>.self, from: data)
        print("Debug: NetSuiteAPI - Successfully fetched \(decoded.items.count) customer invoices")
        return decoded.items
    }
    
    /// Fetch customer payments using SuiteQL with proper pagination
    func fetchCustomerPayments(for customerId: String, offset: Int = 0) async throws -> [SuiteQLPaymentRecord] {
        print("Debug: NetSuiteAPI - Fetching customer payments for customer: \(customerId), offset: \(offset)")
        
        let query = """
        SELECT
            t.id,
            t.tranid,
            t.trandate,
            t.status,
            t.memo,
            t.entity,
            t.amount
        FROM transaction t
        WHERE t.entity = '\(customerId)' AND t.type = 'CustPymt'
        ORDER BY t.trandate DESC
        """
        
        let url = "\(baseURL)/services/rest/query/v1/suiteql?limit=50&offset=\(offset)"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("transient", forHTTPHeaderField: "Prefer")
        
        let payload = ["q": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("Debug: NetSuiteAPI - Customer payments SuiteQL query: \(query)")
        print("Debug: NetSuiteAPI - Request URL: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Customer payments request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw NetSuiteError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(SuiteQLGenericResponse<SuiteQLPaymentRecord>.self, from: data)
        print("Debug: NetSuiteAPI - Successfully fetched \(decoded.items.count) customer payments")
        return decoded.items
    }
    
    /// Fetch customer transactions (both invoices and payments) using SuiteQL
    func fetchCustomerTransactions(for customerId: String, offset: Int = 0) async throws -> [CustomerTransaction] {
        print("Debug: NetSuiteAPI - Fetching customer transactions for customer: \(customerId), offset: \(offset)")
        
        let query = """
        SELECT
            t.id,
            t.tranid,
            t.trandate,
            t.status,
            t.memo,
            t.entity,
            t.type
        FROM transaction t
        WHERE t.entity = '\(customerId)' AND (t.type = 'CustInvc' OR t.type = 'CustPymt')
        ORDER BY t.trandate DESC
        """
        
        let url = "\(baseURL)/services/rest/query/v1/suiteql?limit=50&offset=\(offset)"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("transient", forHTTPHeaderField: "Prefer")
        
        let payload = ["q": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("Debug: NetSuiteAPI - Customer transactions SuiteQL query: \(query)")
        print("Debug: NetSuiteAPI - Request URL: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Debug: NetSuiteAPI - Customer transactions request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw NetSuiteError.invalidResponse
        }
        
        // Parse as generic SuiteQL response and convert to CustomerTransaction
        let decoded = try JSONDecoder().decode(SuiteQLResponse.self, from: data)
        
        let transactions = decoded.items.compactMap { item -> CustomerTransaction? in
            guard let id = item.id,
                  let tranId = item.tranid,
                  let dateString = item.trandate,
                  let date = NetSuiteDateParser.parseDate(dateString),
                  let type = item.type,
                  let status = item.status else {
                return nil
            }
            
            return CustomerTransaction(
                id: id,
                transactionNumber: tranId,
                date: date,
                amount: Decimal(0), // SuiteQL doesn't provide amount
                type: type,
                status: status,
                memo: item.memo
            )
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(transactions.count) customer transactions")
        return transactions
    }
    
    // MARK: - Debug Utilities
    
    /// Debug method to discover available columns for a SuiteQL table
    /// Usage: await netSuiteAPI.debugTableColumns("transaction")
    func debugTableColumns(_ tableName: String) async throws -> [String] {
        let query = """
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '\(tableName)'
        ORDER BY COLUMN_NAME
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        let columns = response.items.compactMap { $0.values["column0"] }
        print("Debug: Available columns for table '\(tableName)': \(columns.joined(separator: ", "))")
        return columns
    }
}

// MARK: - Errors
enum NetSuiteError: Error, LocalizedError {
    case notConfigured
    case requestFailed
    case invalidResponse
    case authenticationFailed
    case invalidURL
    case unauthorizedRequest
    
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
        case .invalidURL:
            return "Invalid URL for NetSuite API request."
        case .unauthorizedRequest:
            return "NetSuite request unauthorized (401). Token refresh required."
        }
    }
}
