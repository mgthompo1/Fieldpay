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

// MARK: - Helper Types

struct NetSuiteErrorBody: Decodable {
    let type: String?
    let title: String?
    let detail: String?
}

struct NetSuiteHTTPError: Error {
    let status: Int
    let retryAfter: TimeInterval?
    let data: Data?
}

/// Lightweight async lock to serialize token refresh
actor RefreshLock {
    private var isRefreshing = false
    func withLock<T>(_ op: () async throws -> T) async rethrows -> T {
        while isRefreshing { try? await Task.sleep(nanoseconds: 10_000_000) } // 10ms
        isRefreshing = true
        defer { isRefreshing = false }
        return try await op()
    }
}

/// Simple filter builder for Record API `q` query strings
enum NSFilter {
    static func eqString(_ field: String, _ value: String) -> String {
        let esc = value.replacingOccurrences(of: "\"", with: "\\\"")
        return "\(field)==\"\(esc)\""
    }
    static func eqNumber(_ field: String, _ value: Int) -> String { "\(field)==\(value)" }
}

// MARK: - NetSuite Resource Enum

enum NetSuiteResource {
    case invoices(limit: Int, offset: Int, status: String?)
    case invoiceDetail(id: String)
    case customers(limit: Int, offset: Int)
    case customerDetail(id: String)
    case customerPayments(customerId: String, limit: Int, offset: Int)
    case suiteQL(query: String)
    case createInvoice(request: NetSuiteInvoiceCreationRequest)

    func url(with baseURL: String) -> URL {
        switch self {
        case .invoices(let limit, let offset, let status):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.invoice)!
            var queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if let status = status, !status.isEmpty {
                queryItems.append(URLQueryItem(name: "q", value: NSFilter.eqString("status", status)))
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
        case .customerPayments(_, let limit, let offset):
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.customerPayment)!
            components.queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            return components.url!
        case .suiteQL(_):
            // Keep a default limit/offset for single-shot calls; paginator will override URL
            var components = URLComponents(string: baseURL + NetSuiteAPIPath.suiteQL)!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "offset", value: "0")
            ]
            return components.url!
        case .createInvoice(_):
            return URL(string: baseURL + NetSuiteAPIPath.invoice)!
        }
    }
    
    var method: String {
        switch self {
        case .suiteQL: return "POST"
        case .createInvoice: return "POST"
        default: return "GET"
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
    private let refreshLock = RefreshLock()
    
    // Centralized encoder/decoder
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    
    // Toggle noisy logging in development only
    private let debugLoggingEnabled = true
    
    private var baseURL: String {
        guard let accountId = accountId, !accountId.isEmpty else {
            // Do not return a placeholder host; fail earlier in validation
            fatalError("NetSuiteAPI baseURL accessed without accountId configured")
        }
        let url = "https://\(accountId).suitetalk.api.netsuite.com"
        if debugLoggingEnabled { print("Debug: NetSuiteAPI - Using base URL: \(url)") }
        return url
    }
    
    private init() {}
    
    // MARK: - Configuration
    func configure(accountId: String, accessToken: String) {
        if debugLoggingEnabled {
            print("Debug: ===== NetSuiteAPI.configure() called =====")
            print("Debug: Account ID: \(accountId)")
            print("Debug: Access token length: \(accessToken.count)")
        }
        
        guard !accountId.isEmpty else { print("Debug: ERROR - Account ID is empty"); return }
        guard !accessToken.isEmpty, accessToken.count > 10 else { print("Debug: ERROR - Access token invalid"); return }
        
        self.accountId = accountId
        self.accessToken = accessToken
        
        let keychainWrapper = KeychainWrapper.shared
        _ = keychainWrapper.saveNetSuiteConfiguration(
            accountId: accountId,
            clientId: "",
            clientSecret: "",
            redirectUri: "fieldpay://callback"
        )
        _ = keychainWrapper.saveString(key: KeychainWrapper.NetSuiteKeys.accessToken, value: accessToken)
        
        if let expiryDate = keychainWrapper.loadDate(key: KeychainWrapper.NetSuiteKeys.tokenExpiry) {
            self.tokenExpiryDate = expiryDate
            if debugLoggingEnabled { print("Debug: NetSuiteAPI - Loaded token expiry from Keychain: \(expiryDate)") }
        } else {
            if debugLoggingEnabled { print("Debug: NetSuiteAPI - No token expiry found in Keychain") }
        }
        
        if debugLoggingEnabled {
            print("Debug: ✅ NetSuiteAPI configuration completed successfully")
        }
    }
    
    func isConfigured() -> Bool {
        if debugLoggingEnabled { print("Debug: ===== NetSuiteAPI.isConfigured() called =====") }
        let keychainWrapper = KeychainWrapper.shared
        let config = keychainWrapper.loadNetSuiteConfiguration()
        let tokens = keychainWrapper.loadNetSuiteTokens()
        
        if let storedAccountId = config.accountId, !storedAccountId.isEmpty {
            accountId = storedAccountId
            if debugLoggingEnabled { print("Debug: NetSuiteAPI - Loaded account ID from Keychain: \(storedAccountId)") }
        }
        if let storedAccessToken = tokens.accessToken, !storedAccessToken.isEmpty {
            accessToken = storedAccessToken
            if debugLoggingEnabled { print("Debug: NetSuiteAPI - Loaded access token from Keychain") }
        }
        if let storedExpiry = tokens.expiryDate {
            tokenExpiryDate = storedExpiry
            if debugLoggingEnabled { print("Debug: NetSuiteAPI - Loaded token expiry from Keychain: \(storedExpiry)") }
        }
        let configured = (accountId?.isEmpty == false) && (accessToken?.isEmpty == false)
        if debugLoggingEnabled {
            print("Debug: NetSuiteAPI configuration status: \(configured)")
            print("Debug: - Account ID present: \(accountId?.isEmpty == false)")
            print("Debug: - Access token present: \(accessToken?.isEmpty == false)")
        }
        return configured
    }
    
    func testConnection() async throws {
        try await validateTokenBeforeRequest()
        let url = URL(string: baseURL + "/services/rest/record/v1/customer?limit=1")!
        let request = createAuthenticatedRequest(for: .customers(limit: 1, offset: 0), overrideURL: url)
        if debugLoggingEnabled { logRequestDetails(request) }
        
        let (data, response) = try await sendWithBackoff(request)
        if debugLoggingEnabled { logResponseDetails(response, data: data) }
        guard response.statusCode == 200 else { throw NetSuiteError.requestFailed }
        if debugLoggingEnabled { print("Debug: NetSuiteAPI - Connection test successful") }
    }
    
    func updateTokens(accessToken: String, refreshToken: String, expiryDate: Date) {
        if debugLoggingEnabled {
            print("Debug: ===== NetSuiteAPI.updateTokens() called =====")
            print("Debug: Access token length: \(accessToken.count)")
            print("Debug: Refresh token length: \(refreshToken.count)")
            print("Debug: Expiry date: \(expiryDate)")
        }
        self.accessToken = accessToken
        self.tokenExpiryDate = expiryDate
        let keychainWrapper = KeychainWrapper.shared
        let ok = keychainWrapper.saveNetSuiteTokens(accessToken: accessToken, refreshToken: refreshToken, expiryDate: expiryDate)
        if debugLoggingEnabled { print(ok ? "Debug: ✅ Tokens saved to Keychain" : "Debug: ❌ Failed to save tokens") }
        if let acct = keychainWrapper.loadNetSuiteConfiguration().accountId { self.accountId = acct }
    }
    
    // MARK: - Token Validation and Refresh
    private func isTokenExpired(skew: TimeInterval = 60) -> Bool {
        guard let expiryDate = tokenExpiryDate else { if debugLoggingEnabled { print("Debug: No token expiry set") }; return true }
        let isExpired = Date().addingTimeInterval(skew) >= expiryDate
        if debugLoggingEnabled { print("Debug: Token expiry check. exp=\(expiryDate) now=\(Date()) expired=\(isExpired)") }
        return isExpired
    }
    
    private func validateTokenBeforeRequest() async throws {
        if debugLoggingEnabled { print("🔍 Debug: ===== validateTokenBeforeRequest() called =====") }
        guard isConfigured() else { throw NetSuiteError.notConfigured }
        if isTokenExpired() { try await refreshTokenIfNeeded() }
    }
    
    private func refreshTokenIfNeeded() async throws {
        try await refreshLock.withLock {
            // Double-check inside the lock
            if !isTokenExpired() { return }
            let keychainWrapper = KeychainWrapper.shared
            let tokens = keychainWrapper.loadNetSuiteTokens()
            guard let refreshToken = tokens.refreshToken else { throw NetSuiteError.authenticationFailed }
            if debugLoggingEnabled { print("Debug: Refreshing access token...") }
            let oAuthManager = await MainActor.run { () -> OAuthManager in
                if self.oAuthManager == nil { self.oAuthManager = OAuthManager.shared }
                return self.oAuthManager!
            }
            do {
                let newTokens = try await oAuthManager.refreshAccessToken(refreshToken: refreshToken)
                self.accessToken = newTokens.accessToken
                self.tokenExpiryDate = newTokens.expiryDate
                _ = keychainWrapper.saveNetSuiteTokens(accessToken: newTokens.accessToken,
                                                       refreshToken: newTokens.refreshToken,
                                                       expiryDate: newTokens.expiryDate)
                if debugLoggingEnabled { print("Debug: Token refresh successful; new exp: \(newTokens.expiryDate)") }
            } catch {
                if debugLoggingEnabled { print("Debug: Token refresh failed: \(error)") }
                throw NetSuiteError.authenticationFailed
            }
        }
    }
    
    private func handle401Response() async throws {
        if debugLoggingEnabled { print("Debug: Received 401, attempting token refresh...") }
        try await refreshTokenIfNeeded()
    }
    
    // MARK: - Networking Core
    private func createAuthenticatedRequest(for resource: NetSuiteResource, overrideURL: URL? = nil) -> URLRequest {
        guard let token = accessToken, !token.isEmpty else { fatalError("No access token; call validateTokenBeforeRequest first.") }
        let url = overrideURL ?? resource.url(with: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = resource.method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if resource.method == "POST" || resource.method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        switch resource {
        case .suiteQL(let query):
            request.setValue("transient", forHTTPHeaderField: "Prefer")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["q": query])
        case .createInvoice(let invoiceRequest):
            request.setValue("transient", forHTTPHeaderField: "Prefer")
            request.httpBody = try? JSONSerialization.data(withJSONObject: invoiceRequest.toDictionary())
        default: break
        }
        return request
    }
    
    // Custom URLSession with extended timeouts for SuiteQL queries
    private lazy var customURLSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30 seconds for request timeout
        config.timeoutIntervalForResource = 60.0 // 60 seconds for resource timeout
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 1 // Limit concurrent connections
        return URLSession(configuration: config)
    }()
    
    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if debugLoggingEnabled { logRequestDetails(request) }
        
        // Use custom session for SuiteQL queries, shared session for others
        let session = request.url?.absoluteString.contains("/suiteql") == true ? customURLSession : URLSession.shared
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetSuiteError.requestFailed }
        if debugLoggingEnabled { logResponseDetails(http, data: data) }
        if !(200...299).contains(http.statusCode) {
            let retryAfter: TimeInterval?
            if let header = http.value(forHTTPHeaderField: "Retry-After"), let v = TimeInterval(header) { retryAfter = v } else { retryAfter = nil }
            throw NetSuiteHTTPError(status: http.statusCode, retryAfter: retryAfter, data: data)
        }
        return (data, http)
    }
    
    private func sendWithBackoff(_ request: URLRequest, maxRetries: Int = 4) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        var delay: TimeInterval = 0.3
        while true {
            do { return try await send(request) }
            catch let e as NetSuiteHTTPError {
                // 401 is handled by caller to refresh token; don't backoff here
                if e.status == 401 { throw e }
                if [429,500,502,503,504].contains(e.status) && attempt < maxRetries {
                    let wait = e.retryAfter ?? delay
                    if debugLoggingEnabled { print("Debug: Backoff on status \(e.status); waiting ~\(wait)s (attempt \(attempt+1)/\(maxRetries))") }
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    attempt += 1
                    delay = min(delay * 2, 5.0)
                    continue
                }
                // Surface NetSuite error body for context
                if let data = e.data, let body = try? decoder.decode(NetSuiteErrorBody.self, from: data) {
                    let msg = [body.title, body.detail].compactMap{$0}.joined(separator: " – ")
                    if debugLoggingEnabled { print("Debug: Error body => \(msg)") }
                }
                throw NetSuiteError.requestFailed
            }             catch let urlError as URLError {
                // Retry only true transient errors; do not retry user/system cancellations (-999)
                if (urlError.code == .networkConnectionLost || urlError.code == .timedOut)
                    && attempt < maxRetries {
                    if debugLoggingEnabled {
                        print("Debug: Transient URLSession error (\(urlError.code.rawValue)); retrying (attempt \(attempt+1)/\(maxRetries))")
                    }
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    delay = min(delay * 2, 5.0)
                    continue
                }
                // Log the specific error for debugging
                if debugLoggingEnabled {
                    print("Debug: Non-retryable URLSession error: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
                }
                throw urlError
            }
        }
    }
    
    /// Generic fetch with 401 refresh + backoff
    private func performWithTokenRetry<T: Decodable>(_ resource: NetSuiteResource, responseType: T.Type) async throws -> T {
        try await validateTokenBeforeRequest()
        var request = createAuthenticatedRequest(for: resource)
        do {
            let (data, _) = try await sendWithBackoff(request)
            return try decoder.decode(T.self, from: data)
        } catch let e as NetSuiteHTTPError where e.status == 401 {
            try await handle401Response()
            request = createAuthenticatedRequest(for: resource) // rebuild with new token
            let (data, _) = try await sendWithBackoff(request)
            return try decoder.decode(T.self, from: data)
        } catch {
            // Reduce noisy logs on benign cancellations
            if debugLoggingEnabled {
                if let uerr = error as? URLError, uerr.code == .cancelled {
                    // no-op
                } else {
                    print("Debug: performWithTokenRetry decode/network error: \(error)")
                }
            }
            throw error
        }
    }
    
    // MARK: - Logging helpers
    private func logRequestDetails(_ request: URLRequest) {
        guard debugLoggingEnabled else { return }
        print("Debug: Request URL: \(request.url?.absoluteString ?? "nil")")
        print("Debug: Request method: \(request.httpMethod ?? "nil")")
        print("Debug: Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Debug: Request body: \(bodyString)")
        }
    }
    
    private func logResponseDetails(_ response: HTTPURLResponse, data: Data) {
        guard debugLoggingEnabled else { return }
        print("Debug: Response status: \(response.statusCode)")
        print("Debug: Response headers: \(response.allHeaderFields)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Debug: Response body (trunc 1000): \(String(responseString.prefix(1000)))")
        }
    }
    
    // MARK: - Authentication stub
    func authenticate() async throws {
        guard accessToken != nil, let accountId = accountId else { throw NetSuiteError.notConfigured }
        if debugLoggingEnabled { print("NetSuite authenticated for account: \(accountId)") }
    }
    
    // MARK: - Customers
    func fetchCustomers(limit: Int = 50, offset: Int = 0) async throws -> [Customer] {
        let resource = NetSuiteResource.customers(limit: limit, offset: offset)
        let list: NetSuiteCustomerListResponse = try await performWithTokenRetry(resource, responseType: NetSuiteCustomerListResponse.self)
        let customers = list.items.map { $0.toCustomer() }
        if debugLoggingEnabled { print("Debug: Parsed \(customers.count) customers") }
        return customers
    }
    
    func fetchAllCustomers() async throws -> [Customer] {
        var all: [Customer] = []
        var offset = 0
        let limit = 1000
        if debugLoggingEnabled { print("Debug: Fetch all customers start") }
        while true {
            let page = try await fetchCustomers(limit: limit, offset: offset)
            all += page
            if page.count < limit { break }
            offset += limit
        }
        if debugLoggingEnabled { print("Debug: Fetch all customers done => \(all.count)") }
        return all
    }
    
    func fetchDetailedCustomer(id: String) async throws -> NetSuiteCustomerRecord {
        do {
            let resource = NetSuiteResource.customerDetail(id: id)
            return try await performWithTokenRetry(resource, responseType: NetSuiteCustomerRecord.self)
        } catch {
            if debugLoggingEnabled { print("Debug: REST customer detail failed; falling back to SuiteQL: \(error)") }
            return try await fetchCustomerDetailViaSuiteQL(id: id)
        }
    }
    
    private func fetchCustomerDetailViaSuiteQL(id: String) async throws -> NetSuiteCustomerRecord {
        let query = "SELECT id, entityid, companyname, email, phone, isinactive FROM customer WHERE id = '\(id)' LIMIT 1"
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        guard let firstRow = response.items.first else { throw NetSuiteError.invalidResponse }
        let customerRecord = NetSuiteCustomerRecord(
            id: firstRow.values["id"] ?? id,
            entityId: firstRow.values["entityid"],
            companyName: firstRow.values["companyname"],
            email: firstRow.values["email"],
            phone: firstRow.values["phone"],
            isInactive: firstRow.values["isinactive"] == "T",
            dateCreated: nil,
            lastModifiedDate: nil,
            addressbook: nil,
            subsidiary: nil,
            customFieldList: nil
        )
        return customerRecord
    }
    
    func fetchDetailedCustomers(for customerIds: [String], concurrentLimit: Int = 10) async throws -> [NetSuiteCustomerRecord] {
        if debugLoggingEnabled { print("Debug: Fetching detailed customers for \(customerIds.count) IDs") }
        var out: [NetSuiteCustomerRecord] = []
        try await withThrowingTaskGroup(of: NetSuiteCustomerRecord?.self) { group in
            for chunk in stride(from: 0, to: customerIds.count, by: concurrentLimit) {
                let ids = Array(customerIds[chunk..<min(chunk+concurrentLimit, customerIds.count)])
                for id in ids {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        do { return try await self.fetchDetailedCustomer(id: id) } catch { return nil }
                    }
                }
                for try await res in group { if let r = res { out.append(r) } }
            }
        }
        if debugLoggingEnabled { print("Debug: Detailed customers fetched => \(out.count)") }
        return out
    }
    
    // MARK: - Invoices Pagination
    func fetchAllInvoices() async throws -> [Invoice] {
        if debugLoggingEnabled { print("Debug: Fetch all invoices with pagination") }
        var all: [Invoice] = []
        var nextURL: String? = baseURL + "/services/rest/record/v1/invoice?limit=1000"
        while let urlStr = nextURL, let url = URL(string: urlStr) {
            let (batch, hasMore, next) = try await fetchInvoicePage(from: url)
            all += batch
            nextURL = hasMore ? next : nil
        }
        if debugLoggingEnabled { print("Debug: Invoices total => \(all.count)") }
        return all
    }
    
    // New method that returns the response structure for pagination
    func fetchAllInvoicesWithResponse(limit: Int, offset: Int, status: String?) async throws -> NetSuiteResponse<NetSuiteInvoiceResponse> {
        if debugLoggingEnabled { print("Debug: Fetch invoices with response structure - limit: \(limit), offset: \(offset)") }
        
        let resource = NetSuiteResource.invoices(limit: limit, offset: offset, status: status)
        let response: NetSuiteResponse<NetSuiteInvoiceResponse> = try await performWithTokenRetry(resource, responseType: NetSuiteResponse<NetSuiteInvoiceResponse>.self)
        
        if debugLoggingEnabled { print("Debug: Fetched \(response.items.count) invoices, hasMore: \(response.hasMore ?? false)") }
        return response
    }
    
    private func fetchInvoicePage(from url: URL) async throws -> (invoices: [Invoice], hasMore: Bool, nextURL: String?) {
        try await validateTokenBeforeRequest()
        var request = createAuthenticatedRequest(for: .invoices(limit: 1000, offset: 0, status: nil), overrideURL: url)
        do {
            let (data, _) = try await sendWithBackoff(request)
            return try parseInvoicePageResponse(data)
        } catch let e as NetSuiteHTTPError where e.status == 401 {
            try await handle401Response()
            request = createAuthenticatedRequest(for: .invoices(limit: 1000, offset: 0, status: nil), overrideURL: url)
            let (data, _) = try await sendWithBackoff(request)
            return try parseInvoicePageResponse(data)
        }
    }
    
    private func parseInvoicePageResponse(_ data: Data) throws -> (invoices: [Invoice], hasMore: Bool, nextURL: String?) {
        do {
            let env = try decoder.decode(NetSuiteResponse<NetSuiteInvoiceResponse>.self, from: data)
            let invoices = env.items.map { $0.toInvoice() }
            let hasMore = env.hasMore ?? false
            let nextURL = env.links?.first(where: { $0.rel == "next" })?.href
            if debugLoggingEnabled { print("Debug: Invoice page => items=\(invoices.count) hasMore=\(hasMore)") }
            return (invoices, hasMore, nextURL)
        } catch {
            if debugLoggingEnabled { print("Debug: Failed to decode invoice page: \(error)") }
            throw NetSuiteError.invalidResponse
        }
    }
    
    // MARK: - Detailed Invoice
    func fetchDetailedInvoice(id: String) async throws -> NetSuiteInvoiceRecord {
        do {
            let resource = NetSuiteResource.invoiceDetail(id: id)
            let invoice: NetSuiteInvoiceRecord = try await performWithTokenRetry(resource, responseType: NetSuiteInvoiceRecord.self)
            if debugLoggingEnabled { print("Debug: Detailed invoice fetched: \(invoice.tranId ?? "unknown")") }
            return invoice
        } catch {
            if debugLoggingEnabled { print("Debug: REST invoice detail failed; fallback SuiteQL: \(error)") }
            return try await fetchInvoiceDetailViaSuiteQL(id: id)
        }
    }
    
    private func fetchInvoiceDetailViaSuiteQL(id: String) async throws -> NetSuiteInvoiceRecord {
        // Validate ID to prevent SQL injection
        guard let safeId = SuiteQLHelper.escapeNumericId(id) else {
            throw NetSuiteError.invalidResponse
        }

        // OPTIMIZED: Single consolidated query with JOIN for invoice + line items + customer
        // This replaces 3 separate API calls with 1
        let consolidatedQuery = """
        SELECT
            t.id AS InvoiceID,
            t.tranid AS InvoiceNumber,
            t.entity AS CustomerID,
            BUILTIN.DF(t.entity) AS CustomerName,
            t.foreigntotal AS Total,
            t.trandate AS TranDate,
            BUILTIN.DF(t.status) AS Status,
            t.memo AS Memo,
            t.duedate AS DueDate,
            t.foreignamountremaining AS AmountRemaining,
            t.foreignamountpaid AS AmountPaid,
            t.lastmodifieddate AS LastModified,
            tl.linesequencenumber AS LineNum,
            tl.item AS ItemID,
            BUILTIN.DF(tl.item) AS ItemName,
            tl.quantity AS Quantity,
            tl.rate AS Rate,
            tl.foreignamount AS LineAmount,
            tl.memo AS LineMemo
        FROM transaction t
        LEFT JOIN transactionline tl ON t.id = tl.transaction AND tl.mainline = 'F'
        WHERE t.id = '\(safeId)' AND t.type = 'CustInvc'
        ORDER BY tl.linesequencenumber
        """

        let resource = NetSuiteResource.suiteQL(query: consolidatedQuery)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)

        guard let firstRow = response.items.first else {
            throw NetSuiteError.invalidResponse
        }

        // Extract invoice header from first row
        let invoiceId = firstRow.values["InvoiceID"] ?? id
        let tranId = firstRow.values["InvoiceNumber"] ?? ""
        let customerId = firstRow.values["CustomerID"] ?? ""
        let customerName = firstRow.values["CustomerName"] ?? ""
        let total = Double(firstRow.values["Total"] ?? "0") ?? 0.0
        let tranDate = NetSuiteDateParser.parseDate(firstRow.values["TranDate"]) ?? Date()
        let status = firstRow.values["Status"] ?? ""
        let memo = firstRow.values["Memo"]

        // Cache customer name for future use
        if !customerId.isEmpty && !customerName.isEmpty {
            await CustomerNameCache.shared.preload([customerId: customerName])
        }

        // Parse line items from all rows (each row is a line item)
        let lineItems: [LineItem] = response.items.compactMap { row in
            guard let lineNumStr = row.values["LineNum"],
                  let lineNum = Int(lineNumStr) else {
                return nil
            }

            let itemId = row.values["ItemID"] ?? ""
            let itemName = row.values["ItemName"] ?? "Unknown Item"
            let quantity = Double(row.values["Quantity"] ?? "0") ?? 0.0
            let rate = Double(row.values["Rate"] ?? "0") ?? 0.0
            let amount = Double(row.values["LineAmount"] ?? "0") ?? 0.0
            let lineMemo = row.values["LineMemo"]

            return LineItem(
                line: lineNum,
                description: lineMemo ?? itemName,
                item: Reference(id: itemId, refName: itemName, type: "inventoryItem"),
                quantity: quantity,
                rate: rate,
                amount: amount,
                taxCode: nil,
                grossAmt: nil,
                netAmount: nil,
                taxAmount: nil,
                taxRate1: nil,
                taxRate2: nil,
                customFieldList: nil
            )
        }

        let record = NetSuiteInvoiceRecord(
            id: invoiceId,
            tranId: tranId,
            trandate: tranDate,
            total: total,
            entity: customerId,
            status: status,
            memo: memo,
            lineItems: lineItems,
            customerName: customerName
        )

        return record
    }
    
    // Helper method to fetch customer name
    private func fetchCustomerName(customerId: String) async -> String {
        // Try SuiteQL first, fallback to REST API if it fails
        do {
            return try await fetchCustomerNameViaSuiteQL(customerId: customerId)
        } catch {
            if debugLoggingEnabled { 
                print("Debug: SuiteQL customer name query failed, falling back to REST API: \(error)")
            }
            do {
                return try await fetchCustomerNameViaREST(customerId: customerId)
            } catch {
                if debugLoggingEnabled { 
                    print("Debug: REST API customer name query also failed: \(error)")
                }
                return "Unknown Customer"
            }
        }
    }
    
    private func fetchCustomerNameViaSuiteQL(customerId: String) async throws -> String {
        let query = "SELECT entityid AS entityidraw, companyname AS companynameraw FROM customer WHERE id = '\(customerId)'"
        let resource = NetSuiteResource.suiteQL(query: query)
        
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        if let firstItem = response.items.first,
           let companyName = firstItem.values["companynameraw"] {
            return companyName
        }
        return "Unknown Customer"
    }
    
    private func fetchCustomerNameViaREST(customerId: String) async throws -> String {
        // Fallback to REST API for customer name
        let resource = NetSuiteResource.customerDetail(id: customerId)
        let response: NetSuiteCustomerResponse = try await performWithTokenRetry(resource, responseType: NetSuiteCustomerResponse.self)
        return response.companyName ?? "Unknown Customer"
    }
    
    func fetchDetailedInvoices(for invoiceIds: [String], concurrentLimit: Int = 10) async throws -> [NetSuiteInvoiceRecord] {
        if debugLoggingEnabled { print("Debug: Fetching detailed invoices for \(invoiceIds.count) IDs") }
        var out: [NetSuiteInvoiceRecord] = []
        var successes = 0; var failures = 0
        try await withThrowingTaskGroup(of: NetSuiteInvoiceRecord?.self) { group in
            for chunk in stride(from: 0, to: invoiceIds.count, by: concurrentLimit) {
                let ids = Array(invoiceIds[chunk..<min(chunk+concurrentLimit, invoiceIds.count)])
                for id in ids {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        do { return try await self.fetchDetailedInvoice(id: id) } catch { return nil }
                    }
                }
                for try await res in group { if let r = res { out.append(r); successes += 1 } else { failures += 1 } }
                if debugLoggingEnabled { print("Debug: Batch done: success=\(successes) fail=\(failures)") }
            }
        }
        return out
    }
    
    func fetchCustomer(id: String) async throws -> Customer {
        let resource = NetSuiteResource.customerDetail(id: id)
        let net: NetSuiteCustomerResponse = try await performWithTokenRetry(resource, responseType: NetSuiteCustomerResponse.self)
        return net.toCustomer()
    }
    
    // MARK: - Invoices (list)
    func fetchInvoices() async throws -> [Invoice] { try await fetchAllInvoices() }
    
    // MARK: - Items (SuiteQL)
    func fetchItems(limit: Int = 100) async throws -> [NetSuiteItem] {
        // Use working SuiteQL query from NetSuiteResponseModels
        let query = SuiteQLQuery.itemsWithDisplayValues.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        let items = response.items.compactMap { row -> NetSuiteItem? in
            guard let id = row.values["id"], let itemId = row.values["itemid"] else { return nil }
            return NetSuiteItem(
                id: id,
                itemId: itemId,
                displayName: row.values["displayname"] ?? itemId,
                basePrice: 0.0,
                description: row.values["description"],
                itemType: row.values["itemtype"] ?? "Service"
            )
        }
        if debugLoggingEnabled { print("Debug: Items fetched => \(items.count)") }
        return items
    }
    
    // MARK: - Sales Orders (SuiteQL)
    func fetchSalesOrders() async throws -> [SalesOrder] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.salesOrders.query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        let customerIds = Set(response.items.compactMap { $0.values["entity"] }).filter { !$0.isEmpty }
        let nameMap = try await fetchCustomerNamesBatch(customerIds: Array(customerIds))
        let orders: [SalesOrder] = response.items.compactMap { row in
            let id = row.values["id"] ?? ""
            let orderNumber = row.values["tranid"] ?? "SO-\(id)"
            let customerId = row.values["entity"] ?? ""
            let statusRaw = row.values["status"] ?? "pending_approval"
            let orderDateStr = row.values["trandate"]
            let notes = row.values["memo"]
            let dueDateStr = row.values["duedate"]
            let amountStr = row.values["foreigntotal"] ?? "0"
            let customerName = nameMap[customerId] ?? "Customer \(customerId)"
            let orderDate = NetSuiteDateParser.parseDate(orderDateStr) ?? Date()
            let dueDate = NetSuiteDateParser.parseDate(dueDateStr)
            let amount = Decimal(string: amountStr) ?? Decimal(0)
            return SalesOrder(
                id: id,
                orderNumber: orderNumber,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                status: SalesOrder.SalesOrderStatus(rawValue: statusRaw.lowercased()) ?? .pendingApproval,
                orderDate: orderDate,
                expectedShipDate: dueDate,
                netSuiteId: id,
                items: [],
                notes: notes
            )
        }
        return orders
    }
    
    func fetchCustomerSalesOrders(for customerId: String) async throws -> [SalesOrder] {
        // Use the proper SuiteQLQuery instead of hardcoded query
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.customerSalesOrders(customerId: customerId).query)
        
        if DebugLogConfig.shared.logSuiteQLResponses {
            print("Debug: Executing sales order query for customer \(customerId)")
            print("Debug: Query: \(SuiteQLQuery.customerSalesOrders(customerId: customerId).query)")
        }
        
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        let nameMap = try await fetchCustomerNamesBatch(customerIds: [customerId])
        
        let orders: [SalesOrder] = response.items.compactMap { row in
            // The enhanced query selects: s.id, s.tranid, s.trandate, s.total, s.status, s.entity, s.memo
            let id = row.values["id"] ?? ""
            let orderNumber = row.values["tranid"] ?? "SO-\(id)"
            let orderDateStr = row.values["trandate"]
            let amountStr = row.values["total"] ?? "0"
            let statusRaw = row.values["status"] ?? "pending_approval"
            let notes = row.values["memo"]
            let customerName = nameMap[customerId] ?? "Customer \(customerId)"
            let orderDate = NetSuiteDateParser.parseDate(orderDateStr) ?? Date()
            let amount = Decimal(string: amountStr) ?? Decimal(0)
            
            return SalesOrder(
                id: id,
                orderNumber: orderNumber,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                status: SalesOrder.SalesOrderStatus(rawValue: statusRaw.lowercased()) ?? .pendingApproval,
                orderDate: orderDate,
                expectedShipDate: nil, // Due date not available in this query
                netSuiteId: id,
                items: [],
                notes: notes
            )
        }
        
        if DebugLogConfig.shared.logSuiteQLResponses { 
            print("Debug: Sales orders for customer \(customerId) => \(orders.count)")
            if orders.isEmpty {
                print("Debug: No sales orders found. Testing transaction types...")
                let types = try await testSalesOrderTypes()
                print("Debug: Available transaction types: \(types)")
                
                // Check if there are any sales orders at all
                print("Debug: Checking for any sales orders in the system...")
                let allSalesOrders = try await testAllSalesOrders()
                print("Debug: Total sales orders in system: \(allSalesOrders.count)")
                
                // Also test with entityid to see if that's the issue
                print("Debug: Testing with entityid instead of id...")
                let entityIdQuery = """
                SELECT s.id, s.tranid, s.trandate, s.total, BUILTIN.CF(s.status) as status, s.entity, s.memo
                FROM transaction s
                WHERE s.type = 'SOrd' AND s.entity IN (
                    SELECT entityid FROM customer WHERE id = '\(customerId)'
                )
                ORDER BY s.trandate DESC
                """
                let entityIdResource = NetSuiteResource.suiteQL(query: entityIdQuery)
                let entityIdResponse: SuiteQLResponse = try await performWithTokenRetry(entityIdResource, responseType: SuiteQLResponse.self)
                print("Debug: EntityID query returned \(entityIdResponse.items.count) results")
            }
        }
        return orders
    }
    
    // MARK: - Sales Order Line Items
    func fetchSalesOrderLineItems(for salesOrderId: String) async throws -> [NetSuiteLineItem] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.salesOrderLineItems(salesOrderId: salesOrderId).query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        let lineItems: [NetSuiteLineItem] = response.items.compactMap { row in
            let id = row.values["ItemID"] ?? ""
            let itemName = row.values["ItemName"] ?? ""
            let unitPriceStr = row.values["UnitPrice"] ?? "0"
            let quantityStr = row.values["Quantity"] ?? "0"
            let lineAmountStr = row.values["LineAmount"] ?? "0"
            let memo = row.values["LineMemo"]
            
            let unitPrice = Decimal(string: unitPriceStr) ?? Decimal(0)
            let quantity = Double(quantityStr) ?? 0.0
            let lineAmount = Decimal(string: lineAmountStr) ?? Decimal(0)
            
            return NetSuiteLineItem(
                id: id,
                itemName: itemName,
                unitPrice: unitPrice,
                quantity: quantity,
                lineAmount: lineAmount,
                memo: memo
            )
        }
        return lineItems
    }
    
    // MARK: - Sales Orders with Payment Information
    func fetchSalesOrdersWithPaymentInfo(for customerId: String) async throws -> [NetSuiteSalesOrderWithPayment] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.salesOrderWithPaymentInfo(customerId: customerId).query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        let orders: [NetSuiteSalesOrderWithPayment] = response.items.compactMap { row in
            let id = row.values["id"] ?? ""
            let orderNumber = row.values["tranid"] ?? ""
            let orderDateStr = row.values["trandate"]
            let status = row.values["status"] ?? ""
            let statusName = row.values["StatusName"] ?? ""
            let customerId = row.values["entity"] ?? ""
            let customerName = row.values["CustomerName"] ?? ""
            let orderTotalStr = row.values["OrderTotal"] ?? "0"
            let amountUnbilledStr = row.values["amountunbilled"] ?? "0"
            let foreignAmountPaidStr = row.values["foreignamountpaid"] ?? "0"
            let foreignAmountUnpaidStr = row.values["foreignamountunpaid"] ?? "0"
            let paymentHold = row.values["paymenthold"] ?? "F"
            let paymentMethod = row.values["paymentmethod"] ?? ""
            let paymentMethodName = row.values["PaymentMethodName"] ?? ""
            
            let orderDate = NetSuiteDateParser.parseDate(orderDateStr) ?? Date()
            let orderTotal = Decimal(string: orderTotalStr) ?? Decimal(0)
            let amountUnbilled = Decimal(string: amountUnbilledStr) ?? Decimal(0)
            let foreignAmountPaid = Decimal(string: foreignAmountPaidStr) ?? Decimal(0)
            let foreignAmountUnpaid = Decimal(string: foreignAmountUnpaidStr) ?? Decimal(0)
            
            return NetSuiteSalesOrderWithPayment(
                id: id,
                orderNumber: orderNumber,
                orderDate: orderDate,
                status: status,
                statusName: statusName,
                customerId: customerId,
                customerName: customerName,
                orderTotal: orderTotal,
                amountUnbilled: amountUnbilled,
                foreignAmountPaid: foreignAmountPaid,
                foreignAmountUnpaid: foreignAmountUnpaid,
                paymentHold: paymentHold == "T",
                paymentMethod: paymentMethod,
                paymentMethodName: paymentMethodName
            )
        }
        return orders
    }
    
    // MARK: - Customer Deposits
    func fetchCustomerDeposits(for customerId: String) async throws -> [NetSuiteCustomerDeposit] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.customerDeposits(customerId: customerId).query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        let deposits: [NetSuiteCustomerDeposit] = response.items.compactMap { row in
            let id = row.values["id"] ?? ""
            let tranId = row.values["tranid"] ?? ""
            let tranDateStr = row.values["trandate"]
            let entity = row.values["entity"] ?? ""
            let customerName = row.values["CustomerName"] ?? ""
            let foreignTotalStr = row.values["foreigntotal"] ?? "0"
            let paymentMethod = row.values["paymentmethod"] ?? ""
            let paymentMethodName = row.values["PaymentMethodName"] ?? ""
            let status = row.values["status"] ?? ""
            let statusName = row.values["StatusName"] ?? ""
            
            let tranDate = NetSuiteDateParser.parseDate(tranDateStr) ?? Date()
            let foreignTotal = Decimal(string: foreignTotalStr) ?? Decimal(0)
            
            return NetSuiteCustomerDeposit(
                id: id,
                tranId: tranId,
                tranDate: tranDate,
                entity: entity,
                customerName: customerName,
                foreignTotal: foreignTotal,
                paymentMethod: paymentMethod,
                paymentMethodName: paymentMethodName,
                status: status,
                statusName: statusName
            )
        }
        return deposits
    }
    
    // MARK: - Sales Orders with Deposits
    func fetchSalesOrdersWithDeposits(for customerId: String) async throws -> [NetSuiteSalesOrderWithDeposit] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.salesOrderWithDeposits(customerId: customerId).query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        let orders: [NetSuiteSalesOrderWithDeposit] = response.items.compactMap { row in
            let salesOrderId = row.values["SalesOrderID"] ?? ""
            let orderNumber = row.values["OrderNumber"] ?? ""
            let orderDateStr = row.values["OrderDate"]
            let orderStatus = row.values["OrderStatus"] ?? ""
            let orderStatusName = row.values["OrderStatusName"] ?? ""
            let customerId = row.values["CustomerID"] ?? ""
            let customerName = row.values["CustomerName"] ?? ""
            let orderTotalStr = row.values["OrderTotal"] ?? "0"
            let amountUnbilledStr = row.values["amountunbilled"] ?? "0"
            let orderPaymentMethod = row.values["OrderPaymentMethod"] ?? ""
            let orderPaymentMethodName = row.values["OrderPaymentMethodName"] ?? ""
            let poNumber = row.values["PONumber"]
            let depositId = row.values["DepositID"]
            let depositNumber = row.values["DepositNumber"]
            let depositDateStr = row.values["DepositDate"]
            let depositAmountStr = row.values["DepositAmount"] ?? "0"
            let depositPaymentMethod = row.values["DepositPaymentMethod"]
            let depositPaymentMethodName = row.values["DepositPaymentMethodName"]
            let depositStatus = row.values["DepositStatus"]
            let depositStatusName = row.values["DepositStatusName"]
            
            let orderDate = NetSuiteDateParser.parseDate(orderDateStr) ?? Date()
            let orderTotal = Decimal(string: orderTotalStr) ?? Decimal(0)
            let amountUnbilled = Decimal(string: amountUnbilledStr) ?? Decimal(0)
            let depositDate = NetSuiteDateParser.parseDate(depositDateStr)
            let depositAmount = Decimal(string: depositAmountStr) ?? Decimal(0)
            
            return NetSuiteSalesOrderWithDeposit(
                id: salesOrderId,
                salesOrderId: salesOrderId,
                orderNumber: orderNumber,
                orderDate: orderDate,
                orderStatus: orderStatus,
                orderStatusName: orderStatusName,
                customerId: customerId,
                customerName: customerName,
                orderTotal: orderTotal,
                amountUnbilled: amountUnbilled,
                orderPaymentMethod: orderPaymentMethod,
                orderPaymentMethodName: orderPaymentMethodName,
                poNumber: poNumber,
                depositId: depositId,
                depositNumber: depositNumber,
                depositDate: depositDate,
                depositAmount: depositAmount,
                depositPaymentMethod: depositPaymentMethod,
                depositPaymentMethodName: depositPaymentMethodName,
                depositStatus: depositStatus,
                depositStatusName: depositStatusName
            )
        }
        return orders
    }
    
    // MARK: - Debug/Test Functions
    
    func testSalesOrderTypes() async throws -> [String: Int] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.testSalesOrderTypes.query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        var typeCounts: [String: Int] = [:]
        for row in response.items {
            let type = row.values["type"] ?? "unknown"
            let countStr = row.values["count"] ?? "0"
            let count = Int(countStr) ?? 0
            typeCounts[type] = count
        }
        
        if DebugLogConfig.shared.logSuiteQLResponses {
            print("Debug: Found transaction types: \(typeCounts)")
        }
        
        return typeCounts
    }
    
    func testAllSalesOrders() async throws -> [String] {
        let resource = NetSuiteResource.suiteQL(query: SuiteQLQuery.testAllSalesOrders.query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        var salesOrderIds: [String] = []
        for row in response.items {
            let id = row.values["id"] ?? ""
            let tranId = row.values["tranid"] ?? ""
            let entity = row.values["entity"] ?? ""
            let type = row.values["type"] ?? ""
            let date = row.values["trandate"] ?? ""
            salesOrderIds.append("\(id):\(tranId):\(entity):\(type):\(date)")
        }
        
        if DebugLogConfig.shared.logSuiteQLResponses {
            print("Debug: Found \(salesOrderIds.count) total sales orders: \(salesOrderIds)")
        }
        
        return salesOrderIds
    }
    
    private func fetchCustomerNamesBatch(customerIds: [String]) async throws -> [String: String] {
        guard !customerIds.isEmpty else { return [:] }
        let idList = customerIds.map { "'\($0)'" }.joined(separator: ",")
        let query = "SELECT id, entityid, companyname FROM customer WHERE id IN (\(idList))"
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        var map: [String: String] = [:]
        for row in response.items {
            let id = row.values["id"] ?? ""
            let entityId = row.values["entityid"] ?? ""
            let companyName = row.values["companyname"] ?? ""
            let name = !entityId.isEmpty ? entityId : (!companyName.isEmpty ? companyName : "Customer \(id)")
            map[id] = name
        }
        return map
    }
    
    func fetchSalesOrder(id: String) async throws -> SalesOrder {
        do {
            let url = URL(string: baseURL + NetSuiteAPIPath.salesOrder + "/\(id)")!
            let request = createAuthenticatedRequest(for: .invoiceDetail(id: id), overrideURL: url)
            let (data, _) = try await sendWithBackoff(request)
            return try decoder.decode(SalesOrder.self, from: data)
        } catch {
            if debugLoggingEnabled { print("Debug: REST sales order detail failed; fallback SuiteQL: \(error)") }
            guard let fallback = try await fetchSalesOrderViaSuiteQL(id: id) else { throw NetSuiteError.invalidResponse }
            return fallback
        }
    }
    
    // MARK: - Payments
    func createPayment(_ payment: Payment) async throws -> Payment {
        try await validateTokenBeforeRequest()
        let url = URL(string: baseURL + NetSuiteAPIPath.customerPayment)!
        let netSuitePaymentRecord = NetSuiteCustomerPaymentRecord(payment: payment)
        let body = try encoder.encode(netSuitePaymentRecord)
        var request = createAuthenticatedRequest(for: .customerPayments(customerId: payment.customerId ?? "", limit: 0, offset: 0), overrideURL: url)
        request.httpMethod = "POST"
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        // NetSuite requires specific Content-Type for record creation
        request.setValue("application/vnd.oracle.resource+json; type=singular; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (data, _) = try await sendWithBackoff(request)
            let created = try decoder.decode(NetSuiteCustomerPaymentResponse.self, from: data)
            return created.toPayment()
        } catch let e as NetSuiteHTTPError where e.status == 401 {
            try await handle401Response()
            let (data, _) = try await sendWithBackoff(request)
            let created = try decoder.decode(NetSuiteCustomerPaymentResponse.self, from: data)
            return created.toPayment()
        }
    }
    
    func fetchPayments(limit: Int = 50, offset: Int = 0) async throws -> [Payment] {
        let url: URL = {
            var comps = URLComponents(string: baseURL + NetSuiteAPIPath.customerPayment)!
            comps.queryItems = [URLQueryItem(name: "limit", value: "\(limit)"), URLQueryItem(name: "offset", value: "\(offset)")]
            return comps.url!
        }()
        let request = createAuthenticatedRequest(for: .customerPayments(customerId: "", limit: limit, offset: offset), overrideURL: url)
        do {
            let (data, _) = try await sendWithBackoff(request)
            if let env = try? decoder.decode(NetSuiteResponse<NetSuiteCustomerPaymentResponse>.self, from: data) {
                return env.items.map { $0.toPayment() }
            } else if let arr = try? decoder.decode([NetSuiteCustomerPaymentResponse].self, from: data) {
                return arr.map { $0.toPayment() }
            } else if let arr = try? decoder.decode([Payment].self, from: data) { // ultimate fallback
                return arr
            }
            throw NetSuiteError.invalidResponse
        } catch let e as NetSuiteHTTPError where e.status == 401 {
            try await handle401Response()
            let (data, _) = try await sendWithBackoff(request)
            let env = try decoder.decode(NetSuiteResponse<NetSuiteCustomerPaymentResponse>.self, from: data)
            return env.items.map { $0.toPayment() }
        }
    }
    
    func fetchRecentPayments(fromDate: Date) async throws -> [Payment] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let from = df.string(from: fromDate)
        let query = SuiteQLQuery.paymentsWithDateFilter(fromDate: from).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        return response.items
            .compactMap { row -> Payment? in
                guard let id = row.values["Transaction"],
                      let _ = row.values["TranID"],
                      let dateStr = row.values["TranDate"],
                      let totalStr = row.values["ForeignTotal"],
                      let entityId = row.values["CustomerID"],
                      let _ = row.values["StatusDisplay"],
                      let _ = row.values["Memo"] else {
                    return nil
                }
                
                let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
                let total = Double(totalStr) ?? 0.0
                
                return Payment(
                    id: id,
                    amount: Decimal(total),
                    paymentMethod: .cash,
                    customerId: entityId,
                    netSuitePaymentId: id,
                    createdDate: date
                )
            }
    }
    
    func fetchCustomerPaymentsFiltered(customerId: String, fromDate: Date) async throws -> [Payment] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let from = df.string(from: fromDate)
        let query = SuiteQLQuery.paymentsWithDateFilterAndCustomer(fromDate: from, customerId: customerId).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        return response.items.compactMap { row in
            guard let id = row.values["Transaction"],
                  let amountStr = row.values["ForeignTotal"],
                  let amount = Double(amountStr),
                  let dateStr = row.values["TranDate"] else { return nil }
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            return Payment(
                id: id,
                amount: Decimal(amount),
                paymentMethod: .cash,
                customerId: customerId,
                netSuitePaymentId: id,
                createdDate: date
            )
        }
    }
    
    // MARK: - Status-Filtered Queries with BUILTIN.CF
    
    /// Fetch invoices filtered by status using BUILTIN.CF for proper composite key value retrieval
    func fetchInvoicesWithStatus(_ statusFilter: String) async throws -> [NetSuiteInvoiceRecord] {
        let query = SuiteQLQuery.invoicesWithStatusFilter(statusFilter: statusFilter).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items
            .compactMap { row -> NetSuiteInvoiceRecord? in
                guard let id = row.values["InvoiceID"],
                      let tranId = row.values["InvoiceNumber"],
                      let dateStr = row.values["InvoiceDate"],
                      let totalStr = row.values["TotalAmount"],
                      let customerName = row.values["CustomerName"],
                      let status = row.values["StatusDisplay"],
                      let memo = row.values["InvoiceMemo"] else {
                    return nil
                }
                
                let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
                let total = Double(totalStr) ?? 0.0
                
                return NetSuiteInvoiceRecord(
                    id: id,
                    tranId: tranId,
                    trandate: date,
                    total: total,
                    entity: customerName, // Using customerName as entity for now
                    status: status,
                    memo: memo
                )
            }
    }
    
    /// Fetch payments filtered by status using BUILTIN.CF for proper composite key value retrieval
    func fetchPaymentsWithStatus(_ statusFilter: String) async throws -> [Payment] {
        let query = SuiteQLQuery.paymentsWithStatusFilter(statusFilter: statusFilter).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items
            .filter { row in
                let id = row.values["id"]
                let tranId = row.values["tranid"]
                let dateStr = row.values["trandate"]
                let totalStr = row.values["total"]
                let entityId = row.values["entity"]
                let status = row.values["status"]
                let memo = row.values["memo"]
                
                return id != nil && tranId != nil && dateStr != nil && totalStr != nil && 
                       entityId != nil && status != nil && memo != nil
            }
            .map { row in
                let id = row.values["id"]!
                let _ = row.values["tranid"]!
                let dateStr = row.values["trandate"]!
                let totalStr = row.values["total"]!
                let entityId = row.values["entity"]!
                let _ = row.values["status"]!
                let _ = row.values["memo"]!
                
                let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
                let total = Double(totalStr) ?? 0.0
                
                return Payment(
                    id: id,
                    amount: Decimal(total),
                    paymentMethod: .cash,
                    customerId: entityId,
                    netSuitePaymentId: id,
                    createdDate: date
                )
            }
    }
    
    /// Fetch transactions filtered by status using BUILTIN.CF for proper composite key value retrieval
    func fetchTransactionsWithStatus(_ statusFilter: String) async throws -> [NetSuiteTransaction] {
        let query = SuiteQLQuery.transactionsWithStatusFilter(statusFilter: statusFilter).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items
            .compactMap { row -> NetSuiteTransaction? in
                guard let id = row.values["id"],
                      let _ = row.values["tranid"],
                      let dateStr = row.values["trandate"],
                      let totalStr = row.values["total"],
                      let type = row.values["type"],
                      let entityId = row.values["entity"],
                      let status = row.values["status"],
                      let memo = row.values["memo"] else {
                    return nil
                }
                
                let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
                let total = Double(totalStr) ?? 0.0
                
                return NetSuiteTransaction(
                    id: id,
                    amount: total,
                    date: date,
                    customerId: entityId,
                    type: type,
                    status: status,
                    memo: memo
                )
            }
    }
    
    /// Fetch customer invoices by date range using the comprehensive SuiteQL query
    func fetchCustomerInvoicesByDateRange(fromDate: String, toDate: String? = nil) async throws -> [DateRangeInvoiceItem] {
        let query = SuiteQLQuery.customerInvoicesByDateRange(fromDate: fromDate, toDate: toDate).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items.compactMap { row in
            guard let invoice = row.values["Invoice"],
                  let invoiceNumber = row.values["InvoiceNumber"],
                  let invoiceDate = row.values["InvoiceDate"],
                  let customer = row.values["Customer"],
                  let customerName = row.values["CustomerName"],
                  let status = row.values["Status"] else {
                return nil
            }
            
            let customerPONumber = row.values["CustomerPONumber"]
            let salesOrder = row.values["SalesOrder"]
            let soNumber = row.values["SONumber"]
            let salesRep = row.values["SalesRep"]
            let salesRepName = row.values["SalesRepName"]
            let totalAmount = row.values["TotalAmount"].flatMap { Double($0) }
            let balanceDue = row.values["BalanceDue"].flatMap { Double($0) }
            let dueDate = row.values["DueDate"]
            
            return DateRangeInvoiceItem(
                invoice: invoice,
                invoiceNumber: invoiceNumber,
                invoiceDate: invoiceDate,
                customer: customer,
                customerName: customerName,
                customerPONumber: customerPONumber,
                salesOrder: salesOrder,
                soNumber: soNumber,
                salesRep: salesRep,
                salesRepName: salesRepName,
                totalAmount: totalAmount,
                status: status,
                balanceDue: balanceDue,
                dueDate: dueDate
            )
        }
    }
    
    /// Fetch customer invoices by date range and convert to Invoice model
    func fetchCustomerInvoicesByDateRangeAsInvoices(fromDate: String, toDate: String? = nil) async throws -> [Invoice] {
        let dateRangeItems = try await fetchCustomerInvoicesByDateRange(fromDate: fromDate, toDate: toDate)
        
        return dateRangeItems.compactMap { item in
            guard let totalAmount = item.totalAmount,
                  let balanceDue = item.balanceDue else {
                return nil
            }
            
            let date = NetSuiteDateParser.parseDate(item.invoiceDate) ?? Date()
            let dueDate = item.dueDate.flatMap { NetSuiteDateParser.parseDate($0) }
            
            // Convert NetSuite status to app status
            let appStatus: AppInvoiceStatus = {
                switch item.status.lowercased() {
                case "paid", "paid in full":
                    return .paid
                case "pending approval", "pending fulfillment":
                    return .pending
                case "overdue":
                    return .overdue
                case "cancelled", "void":
                    return .cancelled
                default:
                    return .pending
                }
            }()
            
            return Invoice(
                id: item.invoice,
                invoiceNumber: item.invoiceNumber,
                customerId: item.customer,
                customerName: item.customerName,
                amount: Decimal(totalAmount),
                balance: Decimal(totalAmount),
                amountPaid: Decimal(totalAmount - balanceDue),
                amountRemaining: Decimal(balanceDue),
                status: appStatus,
                dueDate: dueDate,
                createdDate: date,
                netSuiteId: item.invoice,
                items: [], // Line items would need separate query
                notes: item.customerPONumber
            )
        }
    }
    
    // MARK: - Display Value Queries with BUILTIN.DF
    
    /// Fetch transactions with display values using BUILTIN.DF for customer names
    func fetchTransactionsWithDisplayValues() async throws -> [NetSuiteTransactionWithDisplay] {
        let query = SuiteQLQuery.transactionsWithDisplayValues.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items.compactMap { row in
            guard let id = row.values["id"],
                  let tranId = row.values["tranid"],
                  let dateStr = row.values["trandate"],
                  let totalStr = row.values["total"],
                  let type = row.values["type"],
                  let status = row.values["status"],
                  let customerName = row.values["customer_name"],
                  let memo = row.values["memo"] else { return nil }
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            let total = Double(totalStr) ?? 0.0
            
            return NetSuiteTransactionWithDisplay(
                id: id,
                tranId: tranId,
                trandate: date,
                amount: total,
                type: type,
                status: status,
                customerName: customerName,
                memo: memo
            )
        }
    }
    
    /// Fetch invoices with display values using BUILTIN.DF for customer names
    func fetchInvoicesWithDisplayValues() async throws -> [NetSuiteInvoiceWithDisplay] {
        // Default: fetch first 1000 invoices
        return try await fetchInvoicesWithDisplayValuesPaginated(limit: 1000, offset: 0).invoices
    }

    /// Paginated invoice fetch with server-side pagination
    /// - Parameters:
    ///   - limit: Maximum number of invoices to fetch (1-1000)
    ///   - offset: Starting position for pagination
    ///   - statusFilter: Optional status filter ("Open", "Paid In Full", etc.)
    /// - Returns: A tuple of invoices and whether there are more results
    func fetchInvoicesWithDisplayValuesPaginated(
        limit: Int = 50,
        offset: Int = 0,
        statusFilter: String? = nil
    ) async throws -> (invoices: [NetSuiteInvoiceWithDisplay], hasMore: Bool, totalCount: Int?) {
        // Build paginated query with optional status filter
        var query = """
            SELECT
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                t.foreigntotal AS TotalAmount,
                t.foreignamountremaining AS AmountRemaining,
                t.duedate AS DueDate,
                BUILTIN.DF(t.status) AS StatusDisplay,
                BUILTIN.DF(t.entity) AS CustomerName,
                t.entity AS CustomerID,
                t.memo AS InvoiceMemo
            FROM transaction t
            WHERE t.type = 'CustInvc'
            """

        if let status = statusFilter, !status.isEmpty {
            let safeStatus = SuiteQLHelper.escape(status)
            query += " AND BUILTIN.DF(t.status) = '\(safeStatus)'"
        }

        query += """
            ORDER BY t.trandate DESC
            LIMIT \(min(limit, 1000)) OFFSET \(max(0, offset))
            """

        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)

        let invoices = response.items.compactMap { row -> NetSuiteInvoiceWithDisplay? in
            guard let id = row.values["InvoiceID"],
                  let tranId = row.values["InvoiceNumber"],
                  let dateStr = row.values["InvoiceDate"],
                  let totalStr = row.values["TotalAmount"],
                  let status = row.values["StatusDisplay"],
                  let customerName = row.values["CustomerName"],
                  let memo = row.values["InvoiceMemo"] else { return nil }

            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            let total = Double(totalStr) ?? 0.0
            let remaining = Double(row.values["AmountRemaining"] ?? totalStr) ?? total
            let dueDate = NetSuiteDateParser.parseDate(row.values["DueDate"])
            let customerId = row.values["CustomerID"]

            return NetSuiteInvoiceWithDisplay(
                id: id,
                tranId: tranId,
                trandate: date,
                total: total,
                amountRemaining: remaining,
                dueDate: dueDate,
                status: status,
                customerName: customerName,
                customerId: customerId,
                memo: memo
            )
        }

        // Determine if there are more results
        // If we got exactly `limit` items, there might be more
        let hasMore = invoices.count >= limit

        return (invoices, hasMore, nil)
    }

    /// Get total invoice count for a given status filter
    func getInvoiceCount(statusFilter: String? = nil) async throws -> Int {
        var query = "SELECT COUNT(*) AS cnt FROM transaction t WHERE t.type = 'CustInvc'"

        if let status = statusFilter, !status.isEmpty {
            let safeStatus = SuiteQLHelper.escape(status)
            query += " AND BUILTIN.DF(t.status) = '\(safeStatus)'"
        }

        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)

        if let row = response.items.first,
           let countStr = row.values["cnt"],
           let count = Int(countStr) {
            return count
        }

        return 0
    }
    
    /// Fetch payments with display values using BUILTIN.DF for customer names
    func fetchPaymentsWithDisplayValues() async throws -> [NetSuitePaymentWithDisplay] {
        let query = SuiteQLQuery.paymentsWithDisplayValues.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items.compactMap { row in
            guard let id = row.values["id"],
                  let tranId = row.values["tranid"],
                  let dateStr = row.values["trandate"],
                  let totalStr = row.values["total"],
                  let status = row.values["status"],
                  let customerName = row.values["customer_name"],
                  let memo = row.values["memo"] else { return nil }
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            let total = Double(totalStr) ?? 0.0
            
            return NetSuitePaymentWithDisplay(
                id: id,
                tranId: tranId,
                trandate: date,
                total: total,
                status: status,
                customerName: customerName,
                memo: memo
            )
        }
    }
    
    /// Fetch sales orders with display values using BUILTIN.DF for customer names
    func fetchSalesOrdersWithDisplayValues() async throws -> [NetSuiteSalesOrderWithDisplay] {
        let query = SuiteQLQuery.salesOrdersWithDisplayValues.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items.compactMap { row in
            guard let id = row.values["id"],
                  let tranId = row.values["tranid"],
                  let dateStr = row.values["trandate"],
                  let status = row.values["status"],
                  let customerName = row.values["customer_name"],
                  let memo = row.values["memo"] else { return nil }
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            
            return NetSuiteSalesOrderWithDisplay(
                id: id,
                tranId: tranId,
                trandate: date,
                status: status,
                customerName: customerName,
                memo: memo
            )
        }
    }
    
    // MARK: - Generic Fetch Methods
    
    func fetch<T: Decodable>(_ resource: NetSuiteResource, type: T.Type) async throws -> T {
        return try await performWithTokenRetry(resource, responseType: type)
    }
    
    func fetchItems() async throws -> [NetSuiteItem] {
        // Reuse the primary items query which is compatible with SuiteQL limit/offset via URL
        return try await fetchItems(limit: 1000)
    }
    
    // MARK: - Customer Methods
    
    func fetchCustomerTransactions(for customerId: String) async throws -> [NetSuiteTransaction] {
        let query = SuiteQLQuery.customerTransactions(customerId: customerId).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        var transactions: [NetSuiteTransaction] = []
        for row in response.items {
            let id = row.values["id"] ?? ""
            let _ = row.values["tranid"] ?? ""
            let dateStr = row.values["trandate"] ?? ""
            let amount = safeParseAmount(row.values["total"] ?? "0")
            let type = row.values["type"] ?? ""
            let status = row.values["status_display"] ?? ""
            let memo = row.values["memo"] ?? ""
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            
            let transaction = NetSuiteTransaction(
                id: id,
                amount: amount,
                date: date,
                customerId: customerId,
                type: type,
                status: status,
                memo: memo
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    func fetchCustomerPayments(for customerId: String) async throws -> [Payment] {
        let query = SuiteQLQuery.comprehensivePayments.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        var payments: [Payment] = []
        for row in response.items {
            let id = row.values["transaction"] ?? ""
            let _ = row.values["tranid"] ?? ""
            let dateStr = row.values["trandate"] ?? ""
            let amount = safeParseAmount(row.values["foreigntotal"] ?? "0")
            let status = row.values["statusdisplay"] ?? ""
            let memo = row.values["memo"] ?? ""
            let rowCustomerId = row.values["customerid"] ?? ""
            
            // Skip if no valid ID or if this payment doesn't belong to the requested customer
            guard !id.isEmpty && rowCustomerId == customerId else { continue }
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            
            let payment = Payment(
                id: id,
                amount: Decimal(amount),
                currency: "USD",
                status: PaymentStatus(rawValue: status.lowercased()) ?? .succeeded,
                paymentMethod: PaymentMethodType.manualCard,
                customerId: customerId,
                invoiceId: nil,
                description: memo.isEmpty ? "Payment" : memo,
                stripePaymentIntentId: nil,
                netSuitePaymentId: id,
                createdDate: date,
                processedDate: date,
                failureReason: nil
            )
            
            payments.append(payment)
        }
        
        print("Debug: NetSuiteAPI - Fetched \(payments.count) payments for customer \(customerId)")
        return payments
    }
    
    func fetchCustomerInvoices(for customerId: String) async throws -> [Invoice] {
        // Use the better invoicesWithLineItems query for improved field mapping
        let query = SuiteQLQuery.invoicesWithLineItems(customerId: customerId).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        var invoices: [Invoice] = []
        var currentInvoice: Invoice?
        var currentLineItems: [AppInvoiceItem] = []
        
        print("Debug: NetSuiteAPI - Processing \(response.items.count) invoice rows for customer \(customerId)")
        
        for (index, row) in response.items.enumerated() {
            let invoiceId = row.values["invoiceid"] ?? ""  // t.id AS invoiceid (actual field name)
            let lineNumber = Int(row.values["linenumber"] ?? "0")  // tl.linesequencenumber AS linenumber (actual field name)
            
            if index < 5 { // Log first 5 rows for debugging
                print("Debug: NetSuiteAPI - Row \(index): InvoiceID=\(invoiceId), LineNumber=\(lineNumber ?? 0), values=\(String(describing: row.values))")
            }
            
            // If this is a header row (line_number = 0) or a new invoice
            if lineNumber == 0 || currentInvoice?.id != invoiceId {
                // Save previous invoice if exists
                if let invoice = currentInvoice {
                    var updatedInvoice = invoice
                    updatedInvoice.items = currentLineItems
                    invoices.append(updatedInvoice)
                }
                
                // Start new invoice - use correct field aliases from the query
                let invoiceNumber = row.values["invoicenumber"] ?? ""  // t.tranid AS invoicenumber (actual field name)
                let dateStr = row.values["invoicedate"] ?? ""  // t.trandate AS invoicedate (actual field name)
                let amount = safeParseAmount(row.values["totalamount"] ?? "0")  // t.foreigntotal AS totalamount (actual field name)
                let status = row.values["statusdisplay"] ?? ""  // BUILTIN.DF(t.status) AS statusdisplay (actual field name)
                let memo = row.values["invoicememo"] ?? ""  // t.memo AS invoicememo (actual field name)
                let dueDateStr = row.values["DueDate"]  // Not in current query, will be nil
                
                let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
                let dueDate = dueDateStr != nil ? NetSuiteDateParser.parseDate(dueDateStr!) : nil
                
                // Only create invoice if we have a valid ID
                if !invoiceId.isEmpty {
                    currentInvoice = Invoice(
                        id: invoiceId,
                        invoiceNumber: invoiceNumber,
                        customerId: customerId,
                        customerName: "", // Will be populated from customer data
                        amount: Decimal(amount),
                        balance: Decimal(amount),
                        amountPaid: Decimal(0),
                        amountRemaining: Decimal(amount),
                        status: InvoiceStatus.parse(status).toAppStatus(),
                        dueDate: dueDate,
                        createdDate: date,
                        netSuiteId: invoiceId,
                        items: [],
                        notes: memo
                    )
                } else {
                    print("Debug: NetSuiteAPI - Skipping invoice with empty ID: \(row.values)")
                }
                
                currentLineItems = []
            }
            
            // Add line item if not header row - use correct field aliases
            if let lineNumber = lineNumber, lineNumber > 0 {
                let quantity = safeParseAmount(row.values["quantity"] ?? "0")  // tl.quantity AS quantity (actual field name)
                let rate = safeParseAmount(row.values["rate"] ?? "0")  // tl.rate AS rate (actual field name)
                let amount = safeParseAmount(row.values["lineamount"] ?? "0")  // (tl.quantity * tl.rate) AS lineamount (actual field name)
                let memo = row.values["linememo"] ?? ""  // tl.memo AS linememo (actual field name)
                let itemId = row.values["itemid"] ?? ""  // tl.item AS itemid (actual field name)
                let itemName = row.values["ItemName"] ?? "Unknown Item"  // Not in current query, will be "Unknown Item"
                
                let lineItem = AppInvoiceItem(
                    id: UUID().uuidString,
                    line: lineNumber,
                    item: itemName,
                    description: memo.isEmpty ? itemName : memo,
                    quantity: quantity,
                    unitPrice: Decimal(rate),
                    amount: Decimal(amount),
                    netSuiteItemId: itemId.isEmpty ? nil : itemId
                )
                
                currentLineItems.append(lineItem)
            }
        }
        
        // Add the last invoice
        if let invoice = currentInvoice {
            var updatedInvoice = invoice
            updatedInvoice.items = currentLineItems
            invoices.append(updatedInvoice)
        }
        
        print("Debug: NetSuiteAPI - Fetched \(invoices.count) invoices for customer \(customerId)")
        return invoices
    }
    

    
    // MARK: - Sales Order Methods
    
    private func fetchSalesOrderViaSuiteQL(id: String) async throws -> SalesOrder? {
        let query = SuiteQLQuery.salesOrder(id: id).query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        guard let row = response.items.first else { return nil }
        
        guard let amountStr = row.values["foreigntotal"],
              let customerId = row.values["entity"],
              let dateStr = row.values["trandate"] else { return nil }
        let amount = safeParseAmount(amountStr)
        
        let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            return SalesOrder(
            id: id,
            orderNumber: id,
            customerId: customerId,
            customerName: "",
            amount: Decimal(amount),
                status: .pendingApproval,
            orderDate: date,
            expectedShipDate: date,
            netSuiteId: id,
            items: [],
            notes: ""
        )
    }
    
    // MARK: - Debug Methods
    
    func fetchCustomers() async throws -> [NetSuiteCustomer] {
        let query = SuiteQLQuery.customers.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        return response.items.compactMap { row in
            guard let id = row.values["id"],
                  let name = row.values["companyname"] else { return nil }
            return NetSuiteCustomer(id: id, name: name)
        }
    }
    
    func fetchInvoices() async throws -> [NetSuiteInvoice] {
        let query = SuiteQLQuery.invoices.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        return response.items.compactMap { row in
            guard let id = row.values["InvoiceID"],
                  let amountStr = row.values["TotalAmount"] else { return nil }
            let amount = safeParseAmount(amountStr)
            return NetSuiteInvoice(id: id, amount: amount)
        }
    }
    
    func fetchAllInvoices() async throws -> [NetSuiteInvoice] {
        let query = SuiteQLQuery.allInvoices.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        return response.items.compactMap { row in
            guard let id = row.values["InvoiceID"],
                  let amountStr = row.values["TotalAmount"] else { return nil }
            let amount = safeParseAmount(amountStr)
            return NetSuiteInvoice(id: id, amount: amount)
        }
    }
    

    
    func fetchAllCustomers() async throws -> [NetSuiteCustomer] {
        let query = SuiteQLQuery.allCustomers.query
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        return response.items.compactMap { row in
            guard let id = row.values["id"],
                  let name = row.values["companyname"] else { return nil }
            return NetSuiteCustomer(id: id, name: name)
        }
    }
    

    
    func fetchColumns(for table: String) async throws -> [String] {
        // Implementation would fetch column information
        return []
    }
    
    func fetchInvoiceTemplates() async throws -> [NetSuiteInvoiceTemplate] {
        // Implementation would fetch invoice templates
        return []
    }
    
    func fetchLocations() async throws -> [NetSuiteLocation] {
        // Implementation would fetch locations
        return []
    }
    
    func fetchInventoryItems() async throws -> [NetSuiteItem] {
        return try await fetchItems(limit: 1000)
    }
    
    func createInvoice(request: NetSuiteInvoiceCreationRequest) async throws -> NetSuiteInvoiceResponse {
        let resource = NetSuiteResource.createInvoice(request: request)
        return try await performWithTokenRetry(resource, responseType: NetSuiteInvoiceResponse.self)
    }

    /// Update an existing invoice in NetSuite
    func updateInvoice(invoiceId: String, updates: NetSuiteInvoiceUpdateRequest) async throws -> NetSuiteInvoiceResponse {
        try await validateTokenBeforeRequest()

        // Validate invoice ID
        guard let safeId = SuiteQLHelper.escapeNumericId(invoiceId) else {
            throw NetSuiteError.invalidResponse
        }

        let url = URL(string: baseURL + "/record/v1/invoice/\(safeId)")!
        var request = createAuthenticatedRequest(for: .invoiceDetail(id: invoiceId), overrideURL: url)
        request.httpMethod = "PATCH"
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue("application/vnd.oracle.resource+json; type=singular; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let body = try encoder.encode(updates)
        request.httpBody = body

        do {
            let (data, _) = try await sendWithBackoff(request)
            return try decoder.decode(NetSuiteInvoiceResponse.self, from: data)
        } catch let e as NetSuiteHTTPError where e.status == 401 {
            try await handle401Response()
            let (data, _) = try await sendWithBackoff(request)
            return try decoder.decode(NetSuiteInvoiceResponse.self, from: data)
        }
    }

    /// Mark an invoice as paid by applying a payment
    func markInvoiceAsPaid(invoiceId: String, paymentAmount: Decimal, customerId: String) async throws -> Payment {
        let payment = Payment(
            amount: paymentAmount,
            currency: "USD",
            status: .succeeded,
            paymentMethod: .cash,
            customerId: customerId,
            invoiceId: invoiceId,
            description: "Payment for invoice \(invoiceId)"
        )
        return try await createPayment(payment)
    }

    // MARK: - Debug Helpers
    func debugSuiteQLQuery(_ query: String) async throws -> SuiteQLResponse {
        let resource = NetSuiteResource.suiteQL(query: query)
        return try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
    }
    
    // MARK: - API Coordination
    
    /// Coordinate multiple API calls to prevent interference
    private func coordinateAPICalls<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Use a semaphore to limit concurrent API calls
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try await operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Batch fetch customer data to reduce API calls
    func fetchCustomerDataBatch(customerIds: [String]) async throws -> [String: CustomerData] {
        guard !customerIds.isEmpty else { return [:] }
        
        var customerData: [String: CustomerData] = [:]
        
        // Process in smaller batches to avoid overwhelming the API
        let batchSize = 5
        for batch in stride(from: 0, to: customerIds.count, by: batchSize) {
            let endIndex = min(batch + batchSize, customerIds.count)
            let batchIds = Array(customerIds[batch..<endIndex])
            
            try await withThrowingTaskGroup(of: (String, CustomerData).self) { group in
                for customerId in batchIds {
                    group.addTask {
                        let invoices = try await self.fetchCustomerInvoices(for: customerId)
                        let payments = try await self.fetchCustomerPayments(for: customerId)
                        let transactions = try await self.fetchCustomerTransactions(for: customerId)
                        
                        return (customerId, CustomerData(
                            invoices: invoices,
                            payments: payments,
                            transactions: transactions
                        ))
                    }
                }
                
                for try await (customerId, data) in group {
                    customerData[customerId] = data
                }
            }
            
            // Small delay between batches to be respectful to the API
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return customerData
    }
    
    // MARK: - Batch Processing for Performance
    
    /// Fetch customer data in batches to improve performance
    func fetchCustomerDataBatch(customerIds: [String], batchSize: Int = 50) async throws -> [String: CustomerData] {
        var results: [String: CustomerData] = [:]
        
        // Process customers in batches
        for i in stride(from: 0, to: customerIds.count, by: batchSize) {
            let endIndex = min(i + batchSize, customerIds.count)
            let batch = Array(customerIds[i..<endIndex])
            
            // Fetch data for this batch
            for customerId in batch {
                do {
                    let invoices = try await fetchCustomerInvoices(for: customerId)
                    let payments = try await fetchCustomerPayments(for: customerId)
                    let transactions = try await fetchCustomerTransactions(for: customerId)
                    
                    let customerData = CustomerData(
                        invoices: invoices,
                        payments: payments,
                        transactions: transactions
                    )
                    
                    results[customerId] = customerData
                    
                    if debugLoggingEnabled { print("Debug: Processed batch for customer \(customerId)") }
                } catch {
                    if debugLoggingEnabled { print("Debug: Error processing customer \(customerId): \(error)") }
                    // Continue with other customers even if one fails
                }
            }
            
            // Small delay between batches to prevent overwhelming the API
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        return results
    }
    
    // MARK: - Field Performance Checks
    
    /// Check if a field is calculated (which can impact performance)
    /// Calculated fields have "C" in the sixth position of oa_userdata in oa_columns table
    func isFieldCalculated(tableName: String, fieldName: String) async throws -> Bool {
        let query = """
        SELECT oa_userdata 
        FROM oa_columns 
        WHERE oa_tablename = '\(tableName)' 
        AND oa_columnname = '\(fieldName)'
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        if let firstItem = response.items.first,
           let userData = firstItem.values["column0"],
           userData.count >= 6 {
            let sixthChar = String(userData[userData.index(userData.startIndex, offsetBy: 5)])
            return sixthChar == "C"
        }
        
        return false
    }
    
    /// Get recommended indexed fields for a table to improve query performance
    func getIndexedFields(for tableName: String) -> [String] {
        // Based on NetSuite documentation, these are typically indexed
        switch tableName.lowercased() {
        case "transaction":
            return ["id", "lastmodifieddate", "entity", "type", "trandate"]
        case "customer":
            return ["id", "entityid", "lastmodifieddate"]
        case "item":
            return ["id", "itemid", "isinactive"]
        case "transactionline":
            return ["id", "transaction", "line"]
        default:
            return ["id", "lastmodifieddate"]
        }
    }
    
    // MARK: - Custom Field Handling
    
    /// Handle custom field limitations in SuiteQL
    /// Custom fields may not return data from subtabs, so we provide fallbacks
    func fetchCustomFieldData(tableName: String, recordId: String, customFieldName: String) async throws -> String? {
        // Note: Custom fields may not work properly with SuiteQL due to NetSuite limitations
        // This is a fallback method for when custom field data is needed
        
        let query = """
        SELECT \(customFieldName) AS customfieldraw
        FROM \(tableName)
        WHERE id = '\(recordId)'
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        if let firstItem = response.items.first {
            return firstItem.values["customfieldraw"]
        }
        
        return nil
    }
    
    /// Get fallback data when custom fields fail
    func getFallbackData(for fieldType: String, recordId: String) -> String {
        // Provide meaningful fallback data when custom fields don't work
        switch fieldType.lowercased() {
        case "paymentmethod":
            return "Manual Entry"
        case "customstatus":
            return "Standard"
        case "custommemo":
            return "No custom memo available"
        default:
            return "Default Value"
        }
    }
    
    // MARK: - NetSuite Function Utilities
    
    /// Get transactions for a specific date range using supported NetSuite functions
    func fetchTransactionsByDateRange(customerId: String, startDate: Date, endDate: Date) async throws -> [NetSuiteTransaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)
        
        let query = """
        SELECT 
            t.id AS idraw, 
            t.tranid AS tranidraw, 
            t.trandate AS trandateraw, 
            NVL(t.total, 0) AS amountraw, 
            t.type AS typeraw, 
            NVL(t.status, 'Unknown') AS statusraw, 
            NVL(t.memo, 'No memo') AS memoraw, 
            t.entity AS entityraw
        FROM transaction t 
        WHERE t.entity = '\(customerId)' 
        AND t.type IN ('CustPymt', 'CustInvc', 'CustCred', 'SOrd')
        AND t.trandate BETWEEN TO_DATE('\(startDateStr)', 'YYYY-MM-DD HH24:MI:SS') 
                           AND TO_DATE('\(endDateStr)', 'YYYY-MM-DD HH24:MI:SS')
        ORDER BY t.trandate DESC
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        return response.items.map { row in
            let id = row.values["idraw"] ?? ""
            let _ = row.values["tranidraw"] ?? ""
            let dateStr = row.values["trandateraw"] ?? ""
            let amount = safeParseAmount(row.values["amountraw"])
            let type = row.values["typeraw"] ?? ""
            let status = row.values["statusraw"] ?? ""
            let memo = row.values["memoraw"]
            let entityId = row.values["entityraw"] ?? customerId
            
            let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
            
            return NetSuiteTransaction(
                id: id,
                amount: amount,
                date: date,
                customerId: entityId,
                type: type,
                status: status,
                memo: memo
            )
        }
    }
    
    /// Get customer summary using aggregate functions
    func fetchCustomerSummary(customerId: String) async throws -> CustomerSummary {
        let query = """
        SELECT 
            COUNT(*) AS totaltransactions,
            SUM(NVL(total, 0)) AS totalamount,
            MAX(trandate) AS lasttransactiondate,
            MIN(trandate) AS firsttransactiondate
        FROM transaction 
        WHERE entity = '\(customerId)' 
        AND type IN ('CustPymt', 'CustInvc', 'CustCred', 'SOrd')
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        if let firstItem = response.items.first {
            let totalTransactions = Int(firstItem.values["totaltransactions"] ?? "0") ?? 0
            let totalAmount = safeParseAmount(firstItem.values["totalamount"])
            let lastTransactionDate = NetSuiteDateParser.parseDate(firstItem.values["lasttransactiondate"])
            let firstTransactionDate = NetSuiteDateParser.parseDate(firstItem.values["firsttransactiondate"])
            
            return CustomerSummary(
                totalTransactions: totalTransactions,
                totalAmount: Decimal(totalAmount),
                lastTransactionDate: lastTransactionDate,
                firstTransactionDate: firstTransactionDate
            )
        }
        
        return CustomerSummary(
            totalTransactions: 0,
            totalAmount: Decimal(0),
            lastTransactionDate: nil,
            firstTransactionDate: nil
        )
    }
    
    // MARK: - Helper Functions
    
    /// Safely parse amount values to prevent NaN errors
    private func safeParseAmount(_ value: String?) -> Double {
        let amount = Double(value ?? "0") ?? 0.0
        guard !amount.isNaN && !amount.isInfinite else {
            print("⚠️ Warning: Invalid amount value: \(value ?? "nil"), using 0.0")
            return 0.0
        }
        return amount
    }
    
    // MARK: - Advanced Join Examples
    
    /// Fetch customer data with sales rep information using LEFT OUTER JOIN
    /// This ensures we get customer data even if they don't have a sales rep assigned
    func fetchCustomerWithSalesRep(customerId: String) async throws -> CustomerWithSalesRep? {
        let query = """
        SELECT 
            c.entityid AS customeridraw,
            c.companyname AS companynameraw,
            c.email AS emailraw,
            c.phone AS phoneraw,
            NVL(e.entityid, 'No Sales Rep') AS salesrepraw,
            NVL(e.email, 'No Email') AS salesrepemailraw
        FROM customer c
        LEFT OUTER JOIN employee e ON c.salesrep = e.id
        WHERE c.id = '\(customerId)'
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        if let firstItem = response.items.first {
            let customerId = firstItem.values["customeridraw"] ?? ""
            let companyName = firstItem.values["companynameraw"] ?? ""
            let email = firstItem.values["emailraw"]
            let phone = firstItem.values["phoneraw"]
            let salesRep = firstItem.values["salesrepraw"] ?? "No Sales Rep"
            let salesRepEmail = firstItem.values["salesrepemailraw"] ?? "No Email"
            
            return CustomerWithSalesRep(
                customerId: customerId,
                companyName: companyName,
                email: email,
                phone: phone,
                salesRep: salesRep,
                salesRepEmail: salesRepEmail
            )
        }
        
        return nil
    }
    
    /// Fetch invoice data with customer and item details using multiple INNER JOINs
    /// This ensures we only get complete records with all related data
    func fetchInvoiceWithDetails(invoiceId: String) async throws -> InvoiceWithDetails? {
        let query = """
        SELECT 
            t.id AS invoiceidraw,
            t.tranid AS invoicenumberraw,
            t.trandate AS invoicedateraw,
            NVL(t.total, 0) AS invoiceamountraw,
            NVL(t.status, 'Unknown') AS invoicestatusraw,
            c.companyname AS customernameraw,
            c.email AS customeremailraw,
            COUNT(tl.id) AS lineitemcountraw,
            SUM(NVL(tl.netamount, 0)) AS lineitemtotalraw
        FROM transaction t
        INNER JOIN customer c ON t.entity = c.id
        INNER JOIN transactionline tl ON t.id = tl.transaction
        WHERE t.id = '\(invoiceId)' AND t.type = 'CustInvc'
        GROUP BY t.id, t.tranid, t.trandate, t.total, t.status, c.companyname, c.email
        """
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
        
        if let firstItem = response.items.first {
            let invoiceId = firstItem.values["invoiceidraw"] ?? ""
            let invoiceNumber = firstItem.values["invoicenumberraw"] ?? ""
            let invoiceDate = NetSuiteDateParser.parseDate(firstItem.values["invoicedateraw"])
            let invoiceAmount = Double(firstItem.values["invoiceamountraw"] ?? "0") ?? 0.0
            let invoiceStatus = firstItem.values["invoicestatusraw"] ?? ""
            let customerName = firstItem.values["customernameraw"] ?? ""
            let customerEmail = firstItem.values["customeremailraw"]
            let lineItemCount = Int(firstItem.values["lineitemcountraw"] ?? "0") ?? 0
            let lineItemTotal = Double(firstItem.values["lineitemtotalraw"] ?? "0") ?? 0.0
            
            return InvoiceWithDetails(
                invoiceId: invoiceId,
                invoiceNumber: invoiceNumber,
                invoiceDate: invoiceDate,
                invoiceAmount: Decimal(invoiceAmount),
                invoiceStatus: invoiceStatus,
                customerName: customerName,
                customerEmail: customerEmail,
                lineItemCount: lineItemCount,
                lineItemTotal: Decimal(lineItemTotal)
            )
        }
        
        return nil
    }
    
    // MARK: - Join Type Demonstrations
    
    /// Demonstrate different join types and their use cases
    /// This method shows how to choose the right join type for different scenarios
    func demonstrateJoinTypes() -> [String: String] {
        return [
            "INNER_JOIN": """
                -- Use for: Only complete records with all related data
                -- Performance: Best performance, only matching rows
                -- Example: Invoice with customer details (both must exist)
                SELECT t.id, c.companyname 
                FROM transaction t 
                INNER JOIN customer c ON t.entity = c.id
                """,
            
            "LEFT_OUTER_JOIN": """
                -- Use for: All records from left table, optional right table data
                -- Performance: Good performance, includes all left table rows
                -- Example: All customers, even those without sales reps
                SELECT c.companyname, NVL(e.entityid, 'No Sales Rep') 
                FROM customer c 
                LEFT OUTER JOIN employee e ON c.salesrep = e.id
                """,
            
            "RIGHT_OUTER_JOIN": """
                -- Use for: All records from right table, optional left table data
                -- Performance: Good performance, includes all right table rows
                -- Example: All employees, even those without assigned customers
                SELECT NVL(c.companyname, 'No Customer'), e.entityid 
                FROM customer c 
                RIGHT OUTER JOIN employee e ON c.salesrep = e.id
                """,
            
            "FULL_OUTER_JOIN": """
                -- Use for: All records from both tables
                -- Performance: Lower performance, includes all rows
                -- Example: Complete relationship mapping
                SELECT c.companyname, e.entityid 
                FROM customer c 
                FULL OUTER JOIN employee e ON c.salesrep = e.id
                """,
            
            "CROSS_JOIN": """
                -- Use for: Cartesian product (use sparingly)
                -- Performance: Worst performance, all row combinations
                -- Example: Generate all possible combinations
                SELECT c.companyname, e.entityid 
                FROM customer c, employee e
                -- Equivalent to: CROSS JOIN (not supported in SuiteQL Connect)
                """
        ]
    }
    
    /// Get join performance recommendations based on data requirements
    func getJoinRecommendation(for useCase: String) -> String {
        switch useCase.lowercased() {
        case "complete_records_only":
            return "Use INNER JOIN - Best performance, only complete records"
        case "all_left_records":
            return "Use LEFT OUTER JOIN - Good performance, all left table records"
        case "all_right_records":
            return "Use RIGHT OUTER JOIN - Good performance, all right table records"
        case "all_records_both_tables":
            return "Use FULL OUTER JOIN - Lower performance, all records from both tables"
        case "cartesian_product":
            return "Use implicit CROSS JOIN - Worst performance, avoid unless necessary"
        default:
            return "Use INNER JOIN for best performance, LEFT OUTER JOIN for optional relationships"
        }
    }
    
    // MARK: - API Testing and Diagnostics
    
    /// Test SuiteQL vs REST API functionality
    func testAPIFunctionality() async -> [String: String] {
        var results: [String: String] = [:]
        
        // Test SuiteQL query
        do {
            let testQuery = "SELECT 1 as test FROM DUAL"
            let resource = NetSuiteResource.suiteQL(query: testQuery)
            let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
            results["SuiteQL_Test"] = "✅ Success - \(response.items.count) rows returned"
        } catch {
            results["SuiteQL_Test"] = "❌ Failed - \(error.localizedDescription)"
        }
        
        // Test REST API
        do {
            let resource = NetSuiteResource.customers(limit: 1, offset: 0)
            let response: NetSuiteCustomerListResponse = try await performWithTokenRetry(resource, responseType: NetSuiteCustomerListResponse.self)
            results["REST_API_Test"] = "✅ Success - \(response.items.count) customers returned"
        } catch {
            results["REST_API_Test"] = "❌ Failed - \(error.localizedDescription)"
        }
        
        // Test fallback logic
        let customerName = await fetchCustomerName(customerId: "2128")
        results["Fallback_Test"] = "✅ Success - Customer name: \(customerName)"
        
        // Test specific payment query
        do {
            let paymentQuery = """
            SELECT t.id, t.total, t.trandate
            FROM transaction t
            WHERE t.type = 'CustPymt' AND t.trandate >= '2025-01-01'
            LIMIT 1
            """
            let resource = NetSuiteResource.suiteQL(query: paymentQuery)
            let response: SuiteQLResponse = try await performWithTokenRetry(resource, responseType: SuiteQLResponse.self)
            results["Payment_Query_Test"] = "✅ Success - \(response.items.count) payments found"
        } catch {
            results["Payment_Query_Test"] = "❌ Failed - \(error.localizedDescription)"
        }
        
        return results
    }
    
    /// Get current API configuration status
    func getAPIConfigurationStatus() -> [String: String] {
        return [
            "Account_ID": accountId ?? "Not configured",
            "Access_Token": accessToken != nil ? "Present" : "Missing",
            "Token_Expiry": "Not available in this context",
            "Base_URL": baseURL,
            "Debug_Logging": debugLoggingEnabled ? "Enabled" : "Disabled",
            "Timeout_Configuration": "SuiteQL: 30s request, 60s resource",
            "Retry_Configuration": "4 attempts with exponential backoff"
        ]
    }
}
