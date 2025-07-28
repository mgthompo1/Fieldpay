import Foundation
import Combine

@MainActor
class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var selectedInvoice: Invoice?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // In-memory cache for session
    private var invoiceCache: [String: Invoice] = [:]
    private var loadedPages: Set<Int> = []
    private(set) var currentPage: Int = 0
    private let pageSize: Int = 50
    private(set) var hasMore: Bool = true
    
    // Batch detail fetching
    private var detailFetchQueue: [String] = []
    private var isFetchingDetails = false
    private let maxConcurrentDetailFetches = 3
    
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
                    self?.invoices = []
                    self?.errorMessage = nil
                    self?.invoiceCache.removeAll()
                    self?.loadedPages.removeAll()
                    self?.currentPage = 0
                    self?.hasMore = true
                    self?.detailFetchQueue.removeAll()
                    self?.isFetchingDetails = false
                }
            }
            .store(in: &cancellables)
    }
    
    func resetPagination() {
        invoices = []
        invoiceCache.removeAll()
        loadedPages.removeAll()
        currentPage = 0
        hasMore = true
        detailFetchQueue.removeAll()
        isFetchingDetails = false
    }
    
    func loadNextPage(status: String? = nil) async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        let pageToLoad = currentPage
        do {
            let resource = NetSuiteResource.invoices(limit: pageSize, offset: pageToLoad * pageSize, status: status)
            let response: NetSuiteInvoiceListResponse = try await netSuiteAPI.fetch(resource, type: NetSuiteInvoiceListResponse.self)
            let newInvoices = response.items.map { $0.toInvoice() }
            // Cache and append
            for invoice in newInvoices {
                invoiceCache[invoice.id] = invoice
            }
            invoices.append(contentsOf: newInvoices)
            loadedPages.insert(pageToLoad)
            currentPage += 1
            hasMore = newInvoices.count == pageSize
            isLoading = false
            
            // Queue detail fetching for new invoices
            await queueDetailFetching(for: newInvoices.map { $0.id })
        } catch {
            errorMessage = "Failed to load invoices: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Batch Detail Fetching
    
    private func queueDetailFetching(for invoiceIds: [String]) async {
        // Add new IDs to queue
        detailFetchQueue.append(contentsOf: invoiceIds)
        
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
                for invoiceId in batch {
                    group.addTask {
                        await self.fetchInvoiceDetailWithRetry(invoiceId: invoiceId)
                    }
                }
            }
            
            // Throttle between batches to avoid overwhelming the API
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        isFetchingDetails = false
    }
    
    private func fetchInvoiceDetailWithRetry(invoiceId: String, retryCount: Int = 0) async {
        let maxRetries = 2
        let baseDelay: UInt64 = 1_000_000_000 // 1 second
        
        do {
            try await fetchInvoiceDetail(invoiceId: invoiceId)
        } catch {
            if retryCount < maxRetries {
                print("Retrying fetch for invoice \(invoiceId), attempt \(retryCount + 1)")
                let delay = baseDelay * UInt64(pow(2.0, Double(retryCount))) // Exponential backoff
                try? await Task.sleep(nanoseconds: delay)
                await fetchInvoiceDetailWithRetry(invoiceId: invoiceId, retryCount: retryCount + 1)
            } else {
                print("Failed to fetch invoice \(invoiceId) after \(maxRetries + 1) attempts")
            }
        }
    }
    
    private func fetchInvoiceDetail(invoiceId: String) async throws {
        do {
            // First, try the standard REST API approach
            let resource = NetSuiteResource.invoiceDetail(id: invoiceId)
            let detailedInvoice: NetSuiteInvoiceRecord = try await netSuiteAPI.fetch(resource, type: NetSuiteInvoiceRecord.self)
            let invoice = detailedInvoice.toInvoice()
            
            await MainActor.run {
                // Update cache
                self.invoiceCache[invoiceId] = invoice
                
                // Update in published array if present
                if let index = self.invoices.firstIndex(where: { $0.id == invoiceId }) {
                    self.invoices[index] = invoice
                }
            }
        } catch {
            print("Failed to fetch detail for invoice \(invoiceId) via REST API: \(error)")
            
            // Fallback: Try using SuiteQL to get invoice details
            do {
                let suiteQLQuery = "SELECT id, tranid, entity, total, amountremaining, amountpaid, trandate, status, memo FROM invoice WHERE id = '\(invoiceId)' LIMIT 1"
                let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
                let suiteQLResponse: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
                
                if let firstRow = suiteQLResponse.items.first {
                    let customerId = firstRow.values["column2"] ?? ""
                    let customerName = await fetchCustomerName(customerId: customerId)
                    
                    // Create a basic invoice from SuiteQL data
                    let invoice = Invoice(
                        id: firstRow.values["column0"] ?? invoiceId,
                        invoiceNumber: firstRow.values["column1"] ?? "INV-\(invoiceId)",
                        customerId: customerId,
                        customerName: customerName,
                        amount: Decimal(string: firstRow.values["column3"] ?? "0") ?? Decimal(0),
                        balance: Decimal(string: firstRow.values["column4"] ?? "0") ?? Decimal(0),
                        status: Invoice.InvoiceStatus(rawValue: firstRow.values["column7"] ?? "pending") ?? .pending,
                        dueDate: nil, // Not available in this query
                        createdDate: Date(), // Use current date as fallback
                        netSuiteId: invoiceId,
                        items: [],
                        notes: firstRow.values["column8"]
                    )
                    
                    await MainActor.run {
                        // Update cache
                        self.invoiceCache[invoiceId] = invoice
                        
                        // Update in published array if present
                        if let index = self.invoices.firstIndex(where: { $0.id == invoiceId }) {
                            self.invoices[index] = invoice
                        }
                    }
                }
            } catch {
                print("Failed to fetch detail for invoice \(invoiceId) via SuiteQL fallback: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchCustomerName(customerId: String) async -> String {
        guard !customerId.isEmpty else { return "Unknown Customer" }
        
        do {
            let suiteQLQuery = "SELECT entityid, companyname FROM customer WHERE id = '\(customerId)' LIMIT 1"
            let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
            let suiteQLResponse: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
            
            if let firstRow = suiteQLResponse.items.first {
                return firstRow.values["column1"] ?? firstRow.values["column0"] ?? "Customer \(customerId)"
            }
        } catch {
            print("Failed to fetch customer name for \(customerId): \(error)")
        }
        
        return "Customer \(customerId)"
    }
    
    // MARK: - Public Detail Fetching
    
    func loadInvoiceDetail(id: String) async {
        // Check cache first
        if let cachedInvoice = invoiceCache[id] {
            await MainActor.run {
                self.selectedInvoice = cachedInvoice
            }
            return
        }
        
        do {
            try await fetchInvoiceDetail(invoiceId: id)
            
            await MainActor.run {
                self.selectedInvoice = self.invoiceCache[id]
            }
        } catch {
            print("Failed to load invoice detail for \(id): \(error)")
        }
    }
    
    func searchInvoices(query: String) {
        guard !query.isEmpty else {
            resetPagination()
            Task {
                await loadNextPage()
            }
            return
        }
        
        let filteredInvoices = invoices.filter { invoice in
            invoice.invoiceNumber.localizedCaseInsensitiveContains(query) ||
            invoice.customerName.localizedCaseInsensitiveContains(query)
        }
        
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByStatus(_ status: Invoice.InvoiceStatus) {
        let filteredInvoices = invoices.filter { $0.status == status }
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByCustomer(_ customerId: String) {
        let filteredInvoices = invoices.filter { $0.customerId == customerId }
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func getOverdueInvoices() -> [Invoice] {
        let today = Date()
        return invoices.filter { invoice in
            invoice.status == .overdue ||
            (invoice.dueDate != nil && invoice.dueDate! < today && invoice.status == .pending)
        }
    }
    
    func getInvoicesByStatus(_ status: Invoice.InvoiceStatus) -> [Invoice] {
        return invoices.filter { $0.status == status }
    }
    
    func getTotalOutstanding() -> Decimal {
        return invoices
            .filter { $0.status != .paid && $0.status != .cancelled }
            .reduce(0) { $0 + $1.balance }
    }
    
    func getInvoiceById(_ id: String) -> Invoice? {
        return invoices.first { $0.id == id }
    }
    
    func createInvoice(customerId: String, customerName: String, amount: Decimal, items: [Invoice.InvoiceItem], dueDate: Date? = nil) {
        let newInvoice = Invoice(
            invoiceNumber: generateInvoiceNumber(),
            customerId: customerId,
            customerName: customerName,
            amount: amount,
            balance: amount,
            dueDate: dueDate,
            items: items
        )
        
        // In a real app, you would save this to NetSuite
        invoices.append(newInvoice)
    }
    
    func updateInvoice(_ invoice: Invoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        }
        
        // In a real app, you would update this in NetSuite
    }
    
    func markInvoiceAsPaid(_ invoice: Invoice) {
        var updatedInvoice = invoice
        updatedInvoice = Invoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            customerId: invoice.customerId,
            customerName: invoice.customerName,
            amount: invoice.amount,
            balance: 0,
            status: .paid,
            dueDate: invoice.dueDate,
            createdDate: invoice.createdDate,
            netSuiteId: invoice.netSuiteId,
            items: invoice.items,
            notes: invoice.notes
        )
        
        updateInvoice(updatedInvoice)
    }
    
    private func generateInvoiceNumber() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let randomSuffix = String(format: "%04d", Int.random(in: 1...9999))
        return "INV-\(dateString)-\(randomSuffix)"
    }
    
    // MARK: - Debug Methods
    
    func debugInvoiceIds() async {
        print("Debug: InvoiceViewModel - Testing invoice ID formats...")
        
        // Test with a few invoice IDs from the current list
        let testIds = Array(invoices.prefix(3)).map { $0.id }
        
        for invoiceId in testIds {
            print("Debug: InvoiceViewModel - Testing invoice ID: \(invoiceId)")
            await netSuiteAPI.debugIdFormat(customerId: invoiceId) // Reuse the same method
        }
    }
} 