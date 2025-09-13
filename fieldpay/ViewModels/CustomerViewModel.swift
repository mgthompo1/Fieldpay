import Foundation
import Combine

// MARK: - CustomerViewModel Debug Configuration
extension CustomerViewModel {
    var debugLoggingEnabled: Bool {
        return DebugLogConfig.shared.logErrorDetails
    }
}

@MainActor
class CustomerViewModel: ObservableObject, CustomerManaging {
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
    
    func initializeIfNeeded() async {
        guard customers.isEmpty && !isLoading else { return }
        if debugLoggingEnabled { print("Debug: CustomerViewModel - Initializing customers on first load") }
        await loadNextPage()
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
            if debugLoggingEnabled { print("Debug: CustomerViewModel - Loading detailed customer information for \(newCustomers.count) customers") }
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
        
        // Use the new batch fetching method to prevent interference
        do {
            let customerData = try await netSuiteAPI.fetchCustomerDataBatch(customerIds: [customerId])
            if let data = customerData[customerId] {
                await MainActor.run {
                    self.customerInvoices = data.invoices
                        .filter { !$0.id.isEmpty } // Filter out invoices with empty IDs
                        .sorted { $0.createdDate > $1.createdDate }
                    self.customerPayments = data.payments
                        .filter { !$0.id.isEmpty } // Filter out payments with empty IDs
                        .map { payment in
                            CustomerPayment(
                                id: payment.id,
                                paymentNumber: payment.netSuitePaymentId ?? payment.id,
                                date: payment.processedDate ?? payment.createdDate,
                                amount: payment.amount,
                                status: payment.status.rawValue,
                                memo: payment.description,
                                paymentMethod: payment.paymentMethod.rawValue
                            )
                        }.sorted { $0.date > $1.date }
                    self.customerTransactions = data.transactions.map { $0.toCustomerTransaction() }
                    
                    // Update caches
                    self.customerInvoicesCache[customerId] = self.customerInvoices
                    self.customerPaymentsCache[customerId] = self.customerPayments
                    self.customerTransactionsCache[customerId] = self.customerTransactions
                    
                    // Clear loading states
                    self.isLoadingInvoices = false
                    self.isLoadingPayments = false
                    self.isLoadingTransactions = false
                    
                    print("Debug: CustomerViewModel - Successfully loaded all data for customer \(customerId)")
                    print("Debug: CustomerViewModel - Loaded \(self.customerPayments.count) payments, \(self.customerInvoices.count) invoices, \(self.customerTransactions.count) transactions")
                }
            }
        } catch {
            print("Debug: CustomerViewModel - Error loading customer data: \(error)")
            await MainActor.run {
                self.invoicesError = "Failed to load invoices: \(error.localizedDescription)"
                self.paymentsError = "Failed to load payments: \(error.localizedDescription)"
                self.transactionsError = "Failed to load transactions: \(error.localizedDescription)"
                
                // Clear loading states
                self.isLoadingInvoices = false
                self.isLoadingPayments = false
                self.isLoadingTransactions = false
            }
        }
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
        // Check cache first
        if await useCacheIfAvailable(
            cache: customerTransactionsCache, 
            key: customerId, 
            setPublished: { self.customerTransactions = $0 }
        ) {
            return
        }
        
        await MainActor.run {
            self.isLoadingTransactions = true
            self.transactionsError = nil
        }
        
        do {
            let transactions = try await netSuiteAPI.fetchCustomerTransactions(for: customerId)
            let customerTransactions = transactions.map { $0.toCustomerTransaction() }
            
            await MainActor.run {
                self.customerTransactions = customerTransactions
                self.customerTransactionsCache[customerId] = customerTransactions
                self.isLoadingTransactions = false
            }
        } catch {
            await MainActor.run {
                self.transactionsError = "Failed to load transactions: \(error.localizedDescription)"
                self.customerTransactions = []
                self.customerTransactionsCache[customerId] = []
                self.isLoadingTransactions = false
            }
        }
    }
    
    func loadCustomerPayments(customerId: String) async {
        // Check cache first
        if await useCacheIfAvailable(
            cache: customerPaymentsCache,
            key: customerId,
            setPublished: { self.customerPayments = $0 }
        ) {
            return
        }
        
        await MainActor.run {
            self.isLoadingPayments = true
            self.paymentsError = nil
        }
        
        do {
            let netSuitePayments = try await netSuiteAPI.fetchCustomerPayments(for: customerId)
            let payments = netSuitePayments
                .filter { !$0.id.isEmpty } // Filter out payments with empty IDs
                .map { $0.toCustomerPayment() }
            
            // Sort payments by date (most recent first)
            let sortedPayments = payments.sorted { $0.date > $1.date }
            
            await MainActor.run {
                self.customerPayments = sortedPayments
                self.customerPaymentsCache[customerId] = sortedPayments
                self.isLoadingPayments = false
            }
        } catch {
            await MainActor.run {
                self.paymentsError = "Failed to load payments: \(error.localizedDescription)"
                self.customerPayments = []
                self.customerPaymentsCache[customerId] = []
                self.isLoadingPayments = false
            }
        }
    }
    
    func loadCustomerInvoices(customerId: String) async throws {
        // Check cache first
        if await useCacheIfAvailable(
            cache: customerInvoicesCache,
            key: customerId,
            setPublished: { self.customerInvoices = $0 }
        ) {
            return
        }
        
        await MainActor.run {
            self.isLoadingInvoices = true
            self.invoicesError = nil
        }
        
        do {
            let invoices = try await netSuiteAPI.fetchCustomerInvoices(for: customerId)
            
            // Filter out invoices with empty IDs and sort by date (most recent first)
            let sortedInvoices = invoices
                .filter { !$0.id.isEmpty }
                .sorted { $0.createdDate > $1.createdDate }
            
            await MainActor.run {
                self.customerInvoices = sortedInvoices
                self.customerInvoicesCache[customerId] = sortedInvoices
                self.isLoadingInvoices = false
            }
        } catch {
            await MainActor.run {
                self.invoicesError = "Failed to load invoices: \(error.localizedDescription)"
                self.customerInvoices = []
                self.customerInvoicesCache[customerId] = []
                self.isLoadingInvoices = false
            }
        }
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
                WHERE (
                    UPPER(entityid) LIKE UPPER('%\(sanitizedQuery)%') OR 
                    UPPER(companyname) LIKE UPPER('%\(sanitizedQuery)%') OR 
                    UPPER(email) LIKE UPPER('%\(sanitizedQuery)%')
                )
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
    
    // MARK: - CustomerManaging Protocol Compliance
    
    @MainActor func storeLocalPayment(_ payment: CustomerPayment, for customerId: String) {
        // Implementation for storing local payments
        // This method is required by the CustomerManaging protocol
        if debugLoggingEnabled {
            print("Debug: CustomerViewModel - Storing local payment for customer \(customerId)")
        }
        // TODO: Implement local payment storage if needed
    }
    

}

 