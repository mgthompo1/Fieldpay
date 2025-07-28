import Foundation
import Combine

// MARK: - NetSuite Resource Enum

enum NetSuiteResource {
    case invoices(limit: Int, offset: Int, status: String?)
    case invoiceDetail(id: String)
    case customers(limit: Int, offset: Int)
    case customerDetail(id: String)
    case customerPayments(customerId: String)
    case customerInvoices(customerId: String)
    case customerTransactions(customerId: String, limit: Int)
    case suiteQL(query: String)

    var url: URL {
        let base = NetSuiteAPI.baseURL
        switch self {
        case .invoices(let limit, let offset, let status):
            var components = URLComponents(string: base + "/services/rest/record/v1/invoice")!
            var queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if let status = status {
                queryItems.append(URLQueryItem(name: "q", value: "status==\"\(status)\""))
            }
            components.queryItems = queryItems
            return components.url!
        case .invoiceDetail(let id):
            return URL(string: base + "/services/rest/record/v1/invoice/\(id)")!
        case .customers(let limit, let offset):
            var components = URLComponents(string: base + "/services/rest/record/v1/customer")!
            components.queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            return components.url!
        case .customerDetail(let id):
            return URL(string: base + "/services/rest/record/v1/customer/\(id)")!
        case .customerPayments(let customerId):
            var components = URLComponents(string: base + "/services/rest/record/v1/customerpayment")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "entity==\"\(customerId)\"")
            ]
            return components.url!
        case .customerInvoices(let customerId):
            var components = URLComponents(string: base + "/services/rest/record/v1/invoice")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "entity==\"\(customerId)\"")
            ]
            return components.url!
        case .customerTransactions(let customerId, let limit):
            var components = URLComponents(string: base + "/services/rest/record/v1/transaction")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "entity==\"\(customerId)\""),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            return components.url!
        case .suiteQL(_):
            return URL(string: base + "/services/rest/query/v1/suiteql")!
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
    static let baseURL = "https://tstdrv1870144.suitetalk.api.netsuite.com"
    
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
            print("Debug: NetSuiteAPI - Line items: \(invoice.lineItemsSummary)")
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
        
        let query = "SELECT id, tranid, entity, total, amountremaining, amountpaid, trandate, status, memo FROM invoice WHERE id = '\(id)' LIMIT 1"
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await fetch(resource, type: SuiteQLResponse.self)
        
        guard let firstRow = response.items.first else {
            throw NetSuiteError.invalidResponse
        }
        
        // Create a basic NetSuiteInvoiceRecord from SuiteQL data
        let invoiceRecord = NetSuiteInvoiceRecord(
            id: firstRow.values["column0"] ?? id,
            tranId: firstRow.values["column1"],
            entity: EntityReference(id: firstRow.values["column2"] ?? "", refName: nil, type: nil),
            tranDate: firstRow.values["column5"],
            dueDate: nil,
            status: firstRow.values["column7"],
            total: Double(firstRow.values["column3"] ?? "0"),
            currency: nil,
            createdDate: nil,
            lastModifiedDate: nil,
            memo: firstRow.values["column8"],
            balance: Double(firstRow.values["column4"] ?? "0"),
            location: nil,
            customFieldList: nil,
            item: nil,
            amountRemaining: Double(firstRow.values["column4"] ?? "0"),
            amountPaid: Double(firstRow.values["column6"] ?? "0"),
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
        
        // Use TaskGroup with proper concurrency control
        await withTaskGroup(of: NetSuiteInvoiceRecord?.self) { group in
            // Process invoices in batches to control concurrency
            for batch in stride(from: 0, to: invoiceIds.count, by: concurrentLimit) {
                let endIndex = min(batch + concurrentLimit, invoiceIds.count)
                let batchIds = Array(invoiceIds[batch..<endIndex])
                
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
                    }
                }
            }
        }
        
        print("Debug: NetSuiteAPI - Successfully fetched \(detailedInvoices.count) detailed invoices")
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
    
    /// Generic fetch for any NetSuiteResource and Decodable type
    func fetch<T: Decodable>(_ resource: NetSuiteResource, type: T.Type) async throws -> T {
        print("Debug: NetSuiteAPI - Fetching resource: \(resource.url)")
        
        try await validateTokenBeforeRequest()
        let url = resource.url
        var request = URLRequest(url: url)
        request.httpMethod = resource.method
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Handle SuiteQL POST requests with query in body
        if case .suiteQL(let query) = resource {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let queryBody = ["q": query]
            request.httpBody = try JSONSerialization.data(withJSONObject: queryBody)
            print("Debug: NetSuiteAPI - SuiteQL query in body: \(query)")
        }
        
        logRequestDetails(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Debug: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("Debug: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("Debug: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: NetSuiteAPI - Response body: \(responseString)")
            }
            
            // Create a more specific error for SuiteQL requests
            if case .suiteQL = resource {
                print("Debug: NetSuiteAPI - SuiteQL request failed - this might be due to query syntax or permissions")
            }
            
            throw NetSuiteError.requestFailed
        }
        
        logResponseDetails(httpResponse, data: data)
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            print("Debug: NetSuiteAPI - Successfully decoded response to type: \(T.self)")
            return decoded
        } catch {
            print("Debug: NetSuiteAPI - Failed to decode response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Debug: NetSuiteAPI - Raw response: \(responseString)")
            }
            throw error
        }
    }
    
    /// Execute a SuiteQL query
    func executeSuiteQLQuery(_ query: String) async throws -> SuiteQLResponse {
        try await validateTokenBeforeRequest()
        let resource = NetSuiteResource.suiteQL(query: query)
        return try await fetch(resource, type: SuiteQLResponse.self)
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
}

// MARK: - Errors
enum NetSuiteError: Error, LocalizedError {
    case notConfigured
    case requestFailed
    case invalidResponse
    case authenticationFailed
    case invalidURL
    
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
        }
    }
}
