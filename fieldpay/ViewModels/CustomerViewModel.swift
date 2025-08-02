import Foundation
import Combine

@MainActor
class CustomerViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Granular error handling for different operations
    @Published var transactionsError: String?
    @Published var paymentsError: String?
    @Published var invoicesError: String?
    
    // In-memory cache for session
    private var customerCache: [String: Customer] = [:]
    private var loadedPages: Set<Int> = []
    private(set) var currentPage: Int = 0
    private let pageSize: Int = 50
    private(set) var hasMore: Bool = true
    
    // Customer transactions and payments cache - only loaded when needed
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
    
    private let netSuiteAPI: NetSuiteAPI
    private let oAuthManager: OAuthManager
    private var cancellables = Set<AnyCancellable>()
    
    init(netSuiteAPI: NetSuiteAPI = .shared, oAuthManager: OAuthManager = .shared) {
        self.netSuiteAPI = netSuiteAPI
        self.oAuthManager = oAuthManager
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
                    self?.customerTransactionsCache.removeAll()
                    self?.customerPaymentsCache.removeAll()
                    self?.customerInvoicesCache.removeAll()
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
        customerTransactionsCache.removeAll()
        customerPaymentsCache.removeAll()
        customerInvoicesCache.removeAll()
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
            
            // Fetch detailed customer information for each customer to get proper names
            print("Debug: CustomerViewModel - Loading detailed customer information for \(newCustomers.count) customers")
            let detailedCustomers = await fetchDetailedCustomers(for: newCustomers)
            
            // Cache detailed customer info
            for customer in detailedCustomers {
                customerCache[customer.id] = customer
            }
            customers.append(contentsOf: detailedCustomers)
            loadedPages.insert(pageToLoad)
            currentPage += 1
            hasMore = newCustomers.count == pageSize
            isLoading = false
            
            print("Debug: CustomerViewModel - Loaded \(detailedCustomers.count) customers with detailed info (page \(pageToLoad))")
        } catch {
            errorMessage = "Failed to load customers: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Batch Customer Detail Loading
    
    private func fetchDetailedCustomers(for basicCustomers: [Customer]) async -> [Customer] {
        print("Debug: CustomerViewModel - Fetching detailed info for \(basicCustomers.count) customers")
        
        var detailedCustomers: [Customer] = []
        let concurrentLimit = 5 // Limit concurrent requests to avoid overwhelming the API
        
        // Process customers in batches
        for batch in stride(from: 0, to: basicCustomers.count, by: concurrentLimit) {
            let endIndex = min(batch + concurrentLimit, basicCustomers.count)
            let batchCustomers = Array(basicCustomers[batch..<endIndex])
            
            print("Debug: CustomerViewModel - Processing batch \(batch/concurrentLimit + 1): \(batchCustomers.count) customers")
            
            // Create tasks for this batch
            let tasks = batchCustomers.map { customer in
                Task {
                    do {
                        let resource = NetSuiteResource.customerDetail(id: customer.id)
                        let detailedCustomer: NetSuiteCustomerRecord = try await netSuiteAPI.fetch(resource, type: NetSuiteCustomerRecord.self)
                        return detailedCustomer.toCustomer()
                    } catch {
                        print("Debug: CustomerViewModel - Failed to fetch detail for customer \(customer.id): \(error)")
                        // Return the basic customer if detailed fetch fails
                        return customer
                    }
                }
            }
            
            // Wait for all tasks in this batch to complete
            let batchResults = await withTaskGroup(of: Customer.self) { group in
                for task in tasks {
                    group.addTask {
                        return await task.value
                    }
                }
                
                var results: [Customer] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            detailedCustomers.append(contentsOf: batchResults)
            print("Debug: CustomerViewModel - Completed batch \(batch/concurrentLimit + 1): \(batchResults.count) customers processed")
        }
        
        print("Debug: CustomerViewModel - Successfully fetched detailed info for \(detailedCustomers.count) customers")
        return detailedCustomers
    }
    
    // MARK: - On-Demand Customer Detail Loading
    
    func loadCustomerDetail(id: String) async {
        print("Debug: CustomerViewModel - Loading customer detail for ID: \(id)")
        
        // Clear any previous customer data to avoid showing stale information
        await MainActor.run {
            self.customerTransactions = []
            self.customerPayments = []
            self.customerInvoices = []
            self.errorMessage = nil
        }
        
        // Customer details are now loaded upfront, so we just need to set the selected customer
        if let cachedCustomer = customerCache[id] {
            await MainActor.run {
                self.selectedCustomer = cachedCustomer
            }
            print("Debug: CustomerViewModel - Set selected customer: \(cachedCustomer.name)")
            
            // Load customer transactions, payments, and invoices when customer is selected (last 6 months only)
            await loadCustomerData(customerId: id)
        } else {
            print("Debug: CustomerViewModel - Customer not found in cache for ID: \(id)")
        }
    }
    
    // MARK: - Load All Customer Data
    
    private func loadCustomerData(customerId: String) async {
        print("Debug: CustomerViewModel - Loading all data for customer: \(customerId)")
        
        // Load transactions, payments, and invoices concurrently
        async let transactionsTask = loadCustomerTransactions(customerId: customerId)
        async let paymentsTask = loadCustomerPayments(customerId: customerId)
        
        // Handle invoices separately since it can throw
        do {
            async let invoicesTask = loadCustomerInvoices(customerId: customerId)
            await (transactionsTask, paymentsTask, try invoicesTask)
        } catch {
            print("Debug: CustomerViewModel - Error loading invoices: \(error)")
            await (transactionsTask, paymentsTask)
        }
        
        print("Debug: CustomerViewModel - Completed loading all data for customer: \(customerId)")
    }
    
    // MARK: - Cache Helper Methods
    
    /// Generic cache checking helper to reduce code duplication
    private func useCacheIfAvailable<T>(
        cache: [String: T], 
        key: String, 
        setPublished: @escaping (T) -> Void
    ) async -> Bool {
        if let cached = cache[key] {
            await MainActor.run { setPublished(cached) }
            return true
        }
        return false
    }
    
    // MARK: - Lazy Loading of Customer Detail Data
    
    func loadCustomerTransactions(customerId: String) async {
        print("Debug: CustomerViewModel - Loading transactions for customer: \(customerId)")
        
        // Check cache first using helper
        if await useCacheIfAvailable(
            cache: customerTransactionsCache, 
            key: customerId, 
            setPublished: { self.customerTransactions = $0 }
        ) {
            print("Debug: CustomerViewModel - Using cached transactions: \(customerTransactions.count)")
            return
        }
        
        await MainActor.run {
            self.isLoadingTransactions = true
            self.transactionsError = nil
        }
        
        do {
            // Use the new dedicated SuiteQL method for customer transactions
            print("Debug: CustomerViewModel - Fetching transactions via dedicated SuiteQL method...")
            let transactions = try await netSuiteAPI.fetchCustomerTransactions(for: customerId)
            
            print("Debug: CustomerViewModel - Found \(transactions.count) transactions via SuiteQL")
            
            await MainActor.run {
                self.customerTransactions = transactions
                self.customerTransactionsCache[customerId] = transactions
                self.isLoadingTransactions = false
                print("Debug: CustomerViewModel - Successfully loaded \(transactions.count) transactions")
            }
        } catch {
            print("Debug: CustomerViewModel - Error loading transactions: \(error)")
            await MainActor.run {
                self.transactionsError = "Failed to load transactions: \(error.localizedDescription)"
                self.customerTransactions = []
                self.customerTransactionsCache[customerId] = []
                self.isLoadingTransactions = false
            }
        }
    }
    
    func loadCustomerPayments(customerId: String) async {
        print("Debug: CustomerViewModel - Loading payments for customer: \(customerId)")
        
        // Check cache first using helper
        if await useCacheIfAvailable(
            cache: customerPaymentsCache,
            key: customerId,
            setPublished: { self.customerPayments = $0 }
        ) {
            print("Debug: CustomerViewModel - Using cached payments: \(customerPayments.count)")
            return
        }
        
        await MainActor.run {
            self.isLoadingPayments = true
            self.paymentsError = nil
        }
        
        do {
            // Try to get payments from multiple sources
            var allPayments: [CustomerPayment] = []
            
            // 1. Try to get payments from NetSuite via SuiteQL
            do {
                let suiteQLPayments = try await netSuiteAPI.fetchCustomerPayments(for: customerId)
                let netSuitePayments = suiteQLPayments.map { $0.toCustomerPayment() }
                allPayments.append(contentsOf: netSuitePayments)
                print("Debug: CustomerViewModel - Found \(netSuitePayments.count) payments from NetSuite")
            } catch {
                print("Debug: CustomerViewModel - Failed to load NetSuite payments: \(error)")
                // Continue with other payment sources
            }
            
            // 2. Try to get local payments (Stripe payments that might not be in NetSuite yet)
            do {
                let localPayments = try await getLocalCustomerPayments(customerId: customerId)
                allPayments.append(contentsOf: localPayments)
                print("Debug: CustomerViewModel - Found \(localPayments.count) local payments")
            } catch {
                print("Debug: CustomerViewModel - Failed to load local payments: \(error)")
            }
            
            // Sort payments by date (most recent first)
            allPayments.sort { $0.date > $1.date }
            
            // Update UI state in a single MainActor call
            await MainActor.run {
                self.customerPayments = allPayments
                self.customerPaymentsCache[customerId] = allPayments
                self.isLoadingPayments = false
                print("Debug: CustomerViewModel - Successfully loaded \(allPayments.count) total payments")
            }
        } catch {
            print("Debug: CustomerViewModel - Error loading payments: \(error)")
            await MainActor.run {
                self.paymentsError = "Failed to load payments: \(error.localizedDescription)"
                self.customerPayments = []
                self.customerPaymentsCache[customerId] = []
                self.isLoadingPayments = false
            }
        }
    }
    
    // MARK: - Local Payment Storage
    
    // In-memory storage for local payments (in a real app, this would be Core Data or a database)
    private var localPayments: [String: [CustomerPayment]] = [:]
    
    /// Store a local payment (e.g., from Stripe) that hasn't been synced to NetSuite yet
    func storeLocalPayment(_ payment: CustomerPayment, for customerId: String) {
        print("Debug: CustomerViewModel - Storing local payment for customer \(customerId): \(payment.paymentNumber)")
        
        if localPayments[customerId] == nil {
            localPayments[customerId] = []
        }
        localPayments[customerId]?.append(payment)
        
        // Clear cache for this customer so payments will be reloaded
        customerPaymentsCache.removeValue(forKey: customerId)
        
        // If this customer is currently selected, refresh the payments immediately
        if selectedCustomer?.id == customerId {
            Task {
                await loadCustomerPayments(customerId: customerId)
            }
        }
        
        print("Debug: CustomerViewModel - Local payments for customer \(customerId): \(localPayments[customerId]?.count ?? 0)")
    }
    
    /// Get local payments (Stripe payments that might not be synced to NetSuite yet)
    private func getLocalCustomerPayments(customerId: String) async throws -> [CustomerPayment] {
        print("Debug: CustomerViewModel - Getting local payments for customer: \(customerId)")
        
        let payments = localPayments[customerId] ?? []
        print("Debug: CustomerViewModel - Found \(payments.count) local payments for customer \(customerId)")
        
        return payments
    }
    
    /// Force refresh customer payments (clears cache and reloads)
    func refreshCustomerPayments(customerId: String) async {
        print("Debug: CustomerViewModel - Force refreshing payments for customer: \(customerId)")
        
        // Clear cache
        customerPaymentsCache.removeValue(forKey: customerId)
        
        // Reload payments
        await loadCustomerPayments(customerId: customerId)
    }
    
    func loadCustomerInvoices(customerId: String) async throws {
        print("Debug: CustomerViewModel - Loading invoices for customer: \(customerId)")
        
        // Check cache first using helper
        if await useCacheIfAvailable(
            cache: customerInvoicesCache,
            key: customerId,
            setPublished: { self.customerInvoices = $0 }
        ) {
            print("Debug: CustomerViewModel - Using cached invoices: \(customerInvoices.count)")
            return
        }
        
        await MainActor.run {
            self.isLoadingInvoices = true
            self.invoicesError = nil
        }
        
        do {
            // Use the new dedicated SuiteQL method for customer invoices
            print("Debug: CustomerViewModel - Fetching invoices via dedicated SuiteQL method...")
            let suiteQLInvoices = try await netSuiteAPI.fetchCustomerInvoices(for: customerId)
            
            // Convert SuiteQL records to our app's Invoice models
            let invoices = suiteQLInvoices.map { $0.toInvoice() }
            
            print("Debug: CustomerViewModel - Found \(invoices.count) invoices via SuiteQL")
            
            await MainActor.run {
                self.customerInvoices = invoices
                self.customerInvoicesCache[customerId] = invoices
                self.isLoadingInvoices = false
                print("Debug: CustomerViewModel - Successfully loaded \(invoices.count) invoices")
            }
        } catch {
            print("Debug: CustomerViewModel - Error loading invoices: \(error)")
            await MainActor.run {
                self.invoicesError = "Failed to load invoices: \(error.localizedDescription)"
                self.customerInvoices = []
                self.customerInvoicesCache[customerId] = []
                self.isLoadingInvoices = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get customer payment history from NetSuite via SuiteQL
    private func getCustomerPaymentHistory(customerId: String) async throws -> [CustomerPayment] {
        print("Debug: CustomerViewModel - Getting payment history for customer: \(customerId)")
        
        // Sanitize customerId to prevent SQL injection
        let sanitizedCustomerId = customerId.replacingOccurrences(of: "'", with: "''")
        
        let query = """
        SELECT 
            t.id,
            t.tranid,
            t.trandate,
            t.payment,
            t.status,
            t.memo,
            t.entity,
            t.paymentmethod
        FROM transaction t
        WHERE t.entity = '\(sanitizedCustomerId)' AND t.type = 'CustPymt'
        ORDER BY t.trandate DESC
        """
        
        print("Debug: CustomerViewModel - Executing SuiteQL query: \(query)")
        
        let resource = NetSuiteResource.suiteQL(query: query)
        let response: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
        
        print("Debug: CustomerViewModel - SuiteQL response received: \(response.items.count) items")
        
        var payments: [CustomerPayment] = []
        for (index, item) in response.items.enumerated() {
            print("Debug: CustomerViewModel - Processing payment item \(index + 1): \(item.values)")
            
            if let id = item.values["id"],
               let tranId = item.values["tranid"],
               let trandate = item.values["trandate"],
               let totalStr = item.values["payment"],
               let status = item.values["status"] {
                
                let total = Double(totalStr) ?? 0.0
                let date = parseDate(trandate) ?? Date()
                
                let payment = CustomerPayment(
                    id: id,
                    paymentNumber: tranId,
                    date: date,
                    amount: Decimal(total),
                    status: status,
                    memo: item.values["memo"],
                    paymentMethod: item.values["paymentmethod"]
                )
                payments.append(payment)
                print("Debug: CustomerViewModel - Successfully created payment: \(tranId) - $\(total)")
            } else {
                print("Debug: CustomerViewModel - Skipping payment item \(index + 1) - missing required fields")
                print("Debug: CustomerViewModel - Available fields: \(item.values.keys)")
            }
        }
        
        print("Debug: CustomerViewModel - Successfully processed \(payments.count) payments from \(response.items.count) items")
        return payments
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try alternative format
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    // MARK: - Search and Filter
    
    func filteredCustomers(searchText: String, selectedFilter: CustomerFilter) -> [Customer] {
        var filtered = customers
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.email?.localizedCaseInsensitiveContains(searchText) == true ||
                customer.companyName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.isActive }
        case .inactive:
            filtered = filtered.filter { !$0.isActive }
        }
        
        return filtered
    }
    
    func searchCustomers(query: String) async throws -> [Customer] {
        // If query is empty, return all cached customers
        if query.isEmpty {
            return customers
        }
        
        // First, try to find in cached customers
        let cachedResults = customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(query) ||
            customer.companyName?.localizedCaseInsensitiveContains(query) == true ||
            customer.email?.localizedCaseInsensitiveContains(query) == true
        }
        
        // If we have good results from cache, return them
        if !cachedResults.isEmpty {
            return cachedResults
        }
        
        // Otherwise, search NetSuite API
        do {
            // Sanitize search query to prevent SQL injection
            let sanitizedQuery = query.replacingOccurrences(of: "'", with: "''")
            
            let suiteQLQuery = """
                SELECT id, entityid, companyname, email, phone, isinactive 
                FROM customer 
                WHERE (entityid ILIKE '%\(sanitizedQuery)%' OR companyname ILIKE '%\(sanitizedQuery)%' OR email ILIKE '%\(sanitizedQuery)%')
                AND isinactive = 'F'
                ORDER BY companyname
                """
            
            let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
            let response: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
            
            let searchResults = response.items.compactMap { row -> Customer? in
                let id = row.values["column0"] ?? ""
                let entityId = row.values["column1"] ?? ""
                let companyName = row.values["column2"] ?? ""
                let email = row.values["column3"] ?? ""
                let phone = row.values["column4"] ?? ""
                let isInactive = row.values["column5"] == "T"
                
                // Create customer from search results
                return Customer(
                    id: id,
                    name: entityId.isEmpty ? companyName : entityId,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    address: nil,
                    netSuiteId: id,
                    companyName: companyName.isEmpty ? nil : companyName,
                    isActive: !isInactive,
                    createdDate: Date(),
                    lastModifiedDate: Date()
                )
            }
            
            return searchResults
        } catch {
            print("Failed to search customers: \(error)")
            // Return cached results even if empty
            return cachedResults
        }
    }
    
    // MARK: - Customer Management
    
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

 