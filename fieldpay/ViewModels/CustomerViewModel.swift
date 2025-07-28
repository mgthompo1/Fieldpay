import Foundation
import Combine

@MainActor
class CustomerViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // In-memory cache for session
    private var customerCache: [String: Customer] = [:]
    private var loadedPages: Set<Int> = []
    private(set) var currentPage: Int = 0
    private let pageSize: Int = 50
    private(set) var hasMore: Bool = true
    
    // Batch detail fetching
    private var detailFetchQueue: [String] = []
    private var isFetchingDetails = false
    private let maxConcurrentDetailFetches = 3
    
    // Customer transactions and payments cache
    private var customerTransactionsCache: [String: [CustomerTransaction]] = [:]
    private var customerPaymentsCache: [String: [CustomerPayment]] = [:]
    private var customerInvoicesCache: [String: [Invoice]] = [:]
    
    // Published properties for customer detail data
    @Published var customerTransactions: [CustomerTransaction] = []
    @Published var customerPayments: [CustomerPayment] = []
    @Published var customerInvoices: [Invoice] = []
    @Published var isLoadingTransactions = false
    @Published var isLoadingPayments = false
    @Published var isLoadingInvoices = false
    
    private let netSuiteAPI = NetSuiteAPI.shared
    private let oAuthManager = OAuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        oAuthManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.resetPagination()
                    Task {
                        await self?.loadNextPage()
                    }
                } else {
                    self?.customers = []
                    self?.errorMessage = nil
                    self?.customerCache.removeAll()
                    self?.loadedPages.removeAll()
                    self?.currentPage = 0
                    self?.hasMore = true
                    self?.detailFetchQueue.removeAll()
                    self?.isFetchingDetails = false
                    self?.customerTransactionsCache.removeAll()
                    self?.customerPaymentsCache.removeAll()
                }
            }
            .store(in: &cancellables)
    }
    
    func resetPagination() {
        customers = []
        customerCache.removeAll()
        loadedPages.removeAll()
        currentPage = 0
        hasMore = true
        detailFetchQueue.removeAll()
        isFetchingDetails = false
        customerTransactionsCache.removeAll()
        customerPaymentsCache.removeAll()
    }
    
    func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        let pageToLoad = currentPage
        do {
            let resource = NetSuiteResource.customers(limit: pageSize, offset: pageToLoad * pageSize)
            let response: NetSuiteCustomerListResponse = try await netSuiteAPI.fetch(resource, type: NetSuiteCustomerListResponse.self)
            let newCustomers = response.items.map { $0.toCustomer() }
            // Cache and append
            for customer in newCustomers {
                customerCache[customer.id] = customer
            }
            customers.append(contentsOf: newCustomers)
            loadedPages.insert(pageToLoad)
            currentPage += 1
            hasMore = newCustomers.count == pageSize
            isLoading = false
            
            // Queue detail fetching for new customers
            await queueDetailFetching(for: newCustomers.map { $0.id })
        } catch {
            errorMessage = "Failed to load customers: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Batch Detail Fetching
    
    private func queueDetailFetching(for customerIds: [String]) async {
        // Add new IDs to queue
        detailFetchQueue.append(contentsOf: customerIds)
        
        // Start fetching if not already in progress
        if !isFetchingDetails {
            await fetchDetailsInBatches()
        }
    }
    
    private func fetchDetailsInBatches() async {
        guard !detailFetchQueue.isEmpty else { return }
        
        isFetchingDetails = true
        
        while !detailFetchQueue.isEmpty {
            let batchSize = min(maxConcurrentDetailFetches, detailFetchQueue.count)
            let batch = Array(detailFetchQueue.prefix(batchSize))
            detailFetchQueue.removeFirst(batchSize)
            
            await withTaskGroup(of: Void.self) { group in
                for customerId in batch {
                    group.addTask {
                        await self.fetchCustomerDetail(customerId: customerId)
                    }
                }
            }
            
            // Throttle between batches
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        isFetchingDetails = false
    }
    
    private func fetchCustomerDetail(customerId: String) async {
        do {
            let resource = NetSuiteResource.customerDetail(id: customerId)
            let detailedCustomer: NetSuiteCustomerRecord = try await netSuiteAPI.fetch(resource, type: NetSuiteCustomerRecord.self)
            let customer = detailedCustomer.toCustomer()
            
            await MainActor.run {
                // Update cache
                self.customerCache[customerId] = customer
                
                // Update in published array if present
                if let index = self.customers.firstIndex(where: { $0.id == customerId }) {
                    self.customers[index] = customer
                }
            }
        } catch {
            print("Failed to fetch detail for customer \(customerId): \(error)")
        }
    }
    
    // MARK: - Customer Detail Data Fetching
    
    func loadCustomerTransactions(customerId: String) async {
        // Check cache first
        if let cachedTransactions = customerTransactionsCache[customerId] {
            await MainActor.run {
                self.customerTransactions = cachedTransactions
            }
            return
        }
        
        await MainActor.run {
            self.isLoadingTransactions = true
        }
        
        do {
            let resource = NetSuiteResource.customerTransactions(customerId: customerId, limit: 20)
            let response: CustomerTransactionResponse = try await netSuiteAPI.fetch(resource, type: CustomerTransactionResponse.self)
            let transactions = response.items.map { $0.toTransaction() }
            
            await MainActor.run {
                self.customerTransactions = transactions
                self.customerTransactionsCache[customerId] = transactions
                self.isLoadingTransactions = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                self.isLoadingTransactions = false
            }
        }
    }
    
    func loadCustomerPayments(customerId: String) async {
        print("Debug: CustomerViewModel - Loading payments for customer: \(customerId)")
        
        // Check cache first
        if let cachedPayments = customerPaymentsCache[customerId] {
            print("Debug: CustomerViewModel - Using cached payments: \(cachedPayments.count)")
            await MainActor.run {
                self.customerPayments = cachedPayments
            }
            return
        }
        
        await MainActor.run {
            self.isLoadingPayments = true
            self.errorMessage = nil
        }
        
        do {
            // First, let's try to get a list of all customer payments without filtering
            print("Debug: CustomerViewModel - Trying to fetch all customer payments first...")
            let allPaymentsResource = NetSuiteResource.suiteQL(query: "SELECT id, tranid, trandate, total, status, memo, paymentmethod FROM customerpayment LIMIT 10")
            let allPaymentsResponse: SuiteQLResponse = try await netSuiteAPI.fetch(allPaymentsResource, type: SuiteQLResponse.self)
            print("Debug: CustomerViewModel - Found \(allPaymentsResponse.items.count) total payments in system")
            
            // Now try the specific customer query
            let resource = NetSuiteResource.customerPayments(customerId: customerId)
            print("Debug: CustomerViewModel - Fetching payments from URL: \(resource.url)")
            
            let response: CustomerPaymentResponse = try await netSuiteAPI.fetch(resource, type: CustomerPaymentResponse.self)
            print("Debug: CustomerViewModel - Received response with \(response.items.count) payment items")
            
            let payments = response.items.map { $0.toPayment() }
            print("Debug: CustomerViewModel - Converted to \(payments.count) CustomerPayment objects")
            
            await MainActor.run {
                self.customerPayments = payments
                self.customerPaymentsCache[customerId] = payments
                self.isLoadingPayments = false
                print("Debug: CustomerViewModel - Successfully loaded \(payments.count) payments")
            }
        } catch {
            print("Debug: CustomerViewModel - Error loading payments via REST API: \(error)")
            print("Debug: CustomerViewModel - Trying SuiteQL fallback...")
            
            // Try SuiteQL as fallback
            do {
                let payments = try await getCustomerPaymentHistory(customerId: customerId)
                await MainActor.run {
                    self.customerPayments = payments
                    self.customerPaymentsCache[customerId] = payments
                    self.isLoadingPayments = false
                    print("Debug: CustomerViewModel - Successfully loaded \(payments.count) payments via SuiteQL")
                }
            } catch {
                print("Debug: CustomerViewModel - Error loading payments via SuiteQL: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load payments: \(error.localizedDescription)"
                    self.isLoadingPayments = false
                }
            }
        }
    }
    
    func loadCustomerInvoices(customerId: String) async {
        // Check cache first
        if let cachedInvoices = customerInvoicesCache[customerId] {
            await MainActor.run {
                self.customerInvoices = cachedInvoices
            }
            return
        }
        
        await MainActor.run {
            self.isLoadingInvoices = true
        }
        
        do {
            let resource = NetSuiteResource.customerInvoices(customerId: customerId)
            let response: NetSuiteInvoiceListResponse = try await netSuiteAPI.fetch(resource, type: NetSuiteInvoiceListResponse.self)
            let invoices = response.items.map { $0.toInvoice() }
            
            await MainActor.run {
                self.customerInvoices = invoices
                self.customerInvoicesCache[customerId] = invoices
                self.isLoadingInvoices = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load invoices: \(error.localizedDescription)"
                self.isLoadingInvoices = false
            }
        }
    }
    
    // MARK: - SuiteQL Support
    
    func executeSuiteQLQuery(_ query: String) async throws -> SuiteQLResponse {
        let resource = NetSuiteResource.suiteQL(query: query)
        return try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
    }
    
    // MARK: - Debug Methods
    
    func debugCustomerIds() async {
        print("Debug: CustomerViewModel - Testing customer ID formats...")
        
        // Test with a few customer IDs from the current list
        let testIds = Array(customers.prefix(3)).map { $0.id }
        
        for customerId in testIds {
            print("Debug: CustomerViewModel - Testing customer ID: \(customerId)")
            await netSuiteAPI.debugIdFormat(customerId: customerId)
        }
    }
    
    func testSuiteQL() async {
        print("Debug: CustomerViewModel - Testing SuiteQL functionality...")
        await netSuiteAPI.testSuiteQL()
    }
    
    func testCustomerPaymentsAPI() async {
        print("Debug: CustomerViewModel - Testing customer payments API...")
        
        do {
            // Test 1: Get all customer payments
            let allPaymentsQuery = "SELECT id, tranid, trandate, total, status, memo, paymentmethod FROM customerpayment LIMIT 5"
            let allPaymentsResponse = try await executeSuiteQLQuery(allPaymentsQuery)
            print("Debug: CustomerViewModel - Test 1: Found \(allPaymentsResponse.items.count) total payments")
            
            // Test 2: Get payments for a specific customer (using customer ID from debug view)
            let specificCustomerQuery = "SELECT id, tranid, trandate, total, status, memo, paymentmethod FROM customerpayment WHERE customer = '1264' LIMIT 5"
            let specificCustomerResponse = try await executeSuiteQLQuery(specificCustomerQuery)
            print("Debug: CustomerViewModel - Test 2: Found \(specificCustomerResponse.items.count) payments for customer 1264")
            
            // Test 3: Try the REST API approach
            let resource = NetSuiteResource.customerPayments(customerId: "1264")
            let response: CustomerPaymentResponse = try await netSuiteAPI.fetch(resource, type: CustomerPaymentResponse.self)
            print("Debug: CustomerViewModel - Test 3: REST API returned \(response.items.count) payments")
            
        } catch {
            print("Debug: CustomerViewModel - Test failed: \(error)")
        }
    }
    
    func getCustomerTransactionHistory(customerId: String) async throws -> [CustomerTransaction] {
        // Example SuiteQL query to get comprehensive transaction history
        let query = """
        SELECT 
            t.id,
            t.tranid,
            t.trandate,
            t.total,
            t.type,
            t.status,
            t.memo
        FROM transaction t
        WHERE t.entity = '\(customerId)'
        ORDER BY t.trandate DESC
        LIMIT 50
        """
        
        let response = try await executeSuiteQLQuery(query)
        
        // Convert SuiteQL response to CustomerTransaction objects
        return response.items.compactMap { item in
            guard let id = item.values["column0"],
                  let tranId = item.values["column1"],
                  let dateString = item.values["column2"],
                  let amountString = item.values["column3"],
                  let type = item.values["column4"],
                  let status = item.values["column5"],
                  let memo = item.values["column6"] else {
                return nil
            }
            
            let amount = Decimal(string: amountString) ?? 0
            let date = parseDate(dateString) ?? Date()
            
            return CustomerTransaction(
                id: id,
                transactionNumber: tranId,
                date: date,
                amount: amount,
                type: type,
                status: status,
                memo: memo.isEmpty ? nil : memo
            )
        }
    }
    
    func getCustomerPaymentHistory(customerId: String) async throws -> [CustomerPayment] {
        // Example SuiteQL query to get payment history
        let query = """
        SELECT 
            t.id,
            t.tranid,
            t.trandate,
            t.total,
            t.status,
            t.memo,
            t.paymentmethod
        FROM customerpayment t
        WHERE t.customer = '\(customerId)'
        ORDER BY t.trandate DESC
        LIMIT 50
        """
        
        let response = try await executeSuiteQLQuery(query)
        
        // Convert SuiteQL response to CustomerPayment objects
        return response.items.compactMap { item in
            guard let id = item.values["column0"],
                  let tranId = item.values["column1"],
                  let dateString = item.values["column2"],
                  let amountString = item.values["column3"],
                  let status = item.values["column4"],
                  let memo = item.values["column5"],
                  let paymentMethod = item.values["column6"] else {
                return nil
            }
            
            let amount = Decimal(string: amountString) ?? 0
            let date = parseDate(dateString) ?? Date()
            
            return CustomerPayment(
                id: id,
                paymentNumber: tranId,
                date: date,
                amount: amount,
                status: status,
                memo: memo.isEmpty ? nil : memo,
                paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod
            )
        }
    }
    
    // Helper method to parse dates
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    // MARK: - Public Detail Fetching
    
    func loadCustomerDetail(id: String) async {
        // Check cache first
        if let cachedCustomer = customerCache[id] {
            await MainActor.run {
                self.selectedCustomer = cachedCustomer
            }
            return
        }
        
        await fetchCustomerDetail(customerId: id)
        
        await MainActor.run {
            self.selectedCustomer = self.customerCache[id]
        }
    }
    
    func searchCustomers(query: String) {
        guard !query.isEmpty else {
            resetPagination()
            Task {
                await loadNextPage()
            }
            return
        }
        
        let filteredCustomers = customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(query) ||
            customer.email?.localizedCaseInsensitiveContains(query) == true ||
            customer.companyName?.localizedCaseInsensitiveContains(query) == true
        }
        
        // In a real app, you might want to search on the server side
        customers = filteredCustomers
    }
    
    func createCustomer(name: String, email: String?, phone: String?, companyName: String?) {
        let newCustomer = Customer(
            name: name,
            email: email,
            phone: phone,
            companyName: companyName
        )
        
        // In a real app, you would save this to NetSuite
        customers.append(newCustomer)
    }
    
    func updateCustomer(_ customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index] = customer
        }
        
        // In a real app, you would update this in NetSuite
    }
    
    func deleteCustomer(_ customer: Customer) {
        customers.removeAll { $0.id == customer.id }
        
        // In a real app, you would delete this from NetSuite
    }
    
    func getCustomerById(_ id: String) -> Customer? {
        return customers.first { $0.id == id }
    }
    
    func getCustomersByStatus(isActive: Bool) -> [Customer] {
        return customers.filter { $0.isActive == isActive }
    }
} 