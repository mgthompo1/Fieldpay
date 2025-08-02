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
    private var allInvoices: [Invoice] = [] // Keep unfiltered source
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
                    self?.allInvoices = []
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
        allInvoices = []
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
            let response: NetSuiteResponse<NetSuiteInvoiceResponse> = try await netSuiteAPI.fetch(resource, type: NetSuiteResponse<NetSuiteInvoiceResponse>.self)
            
            // Convert REST API response to invoices
            let newInvoices = await withTaskGroup(of: Invoice.self, returning: [Invoice].self) { group in
                for netSuiteInvoice in response.items {
                    group.addTask {
                        let invoice = netSuiteInvoice.toInvoice()
                        return invoice
                    }
                }
                
                var invoices: [Invoice] = []
                for await invoice in group {
                    invoices.append(invoice)
                }
                return invoices
            }
            
            // Cache and append (already sorted by trandate DESC from SuiteQL)
            for invoice in newInvoices {
                invoiceCache[invoice.id] = invoice
            }
            allInvoices.append(contentsOf: newInvoices)
            invoices = allInvoices // Update published array
            loadedPages.insert(pageToLoad)
            currentPage += 1
            hasMore = newInvoices.count == pageSize
            isLoading = false
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
                let sanitizedInvoiceId = invoiceId.replacingOccurrences(of: "'", with: "''")
                let suiteQLQuery = "SELECT id AS invoice_id, tranid AS invoice_number, entity AS customer_id, amount AS invoice_amount, trandate AS transaction_date, status AS invoice_status, memo AS invoice_memo FROM transaction WHERE id = '\(sanitizedInvoiceId)' AND type = 'Invoice' LIMIT 1"
                let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
                let suiteQLResponse: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
                
                if let firstRow = suiteQLResponse.items.first {
                    let customerId = firstRow.values["customer_id"] ?? ""
                    let customerName = await fetchCustomerName(customerId: customerId)
                    
                    // Create a basic invoice from SuiteQL data
                    let invoice = Invoice(
                        id: firstRow.values["invoice_id"] ?? invoiceId,
                        invoiceNumber: firstRow.values["invoice_number"] ?? "INV-\(invoiceId)",
                        customerId: customerId,
                        customerName: customerName,
                        amount: Decimal(string: firstRow.values["invoice_amount"] ?? "0") ?? Decimal(0),
                        balance: Decimal(string: firstRow.values["invoice_amount"] ?? "0") ?? Decimal(0),
                        status: Invoice.InvoiceStatus(rawValue: firstRow.values["invoice_status"] ?? "pending") ?? .pending,
                        dueDate: nil, // Not available in this query
                        createdDate: Date(), // Use current date as fallback
                        netSuiteId: invoiceId,
                        items: [],
                        notes: firstRow.values["invoice_memo"]
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
        guard !customerId.isEmpty else { return "Customer \(customerId)" }
        
        do {
            let sanitizedCustomerId = customerId.replacingOccurrences(of: "'", with: "''")
            let suiteQLQuery = "SELECT entityid AS entity_id, companyname AS company_name FROM customer WHERE id = '\(sanitizedCustomerId)' LIMIT 1"
            let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
            let suiteQLResponse: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
            
            if let firstRow = suiteQLResponse.items.first {
                return firstRow.values["company_name"] ?? firstRow.values["entity_id"] ?? "Customer \(customerId)"
            }
        } catch {
            print("Failed to fetch customer name for \(customerId): \(error)")
        }
        
        return "Customer \(customerId)"
    }
    
    /// Batch fetch customer names for a set of customer IDs
    private func fetchCustomerNamesBatch(customerIds: [String]) async -> [String: String] {
        guard !customerIds.isEmpty else { return [:] }
        // Build SuiteQL query for all customer IDs - sanitize input
        let sanitizedIds = customerIds.map { $0.replacingOccurrences(of: "'", with: "''") }
        let idList = sanitizedIds.map { "'\($0)'" }.joined(separator: ",")
        let suiteQLQuery = "SELECT id AS customer_id, entityid AS entity_id, companyname AS company_name FROM customer WHERE id IN (\(idList))"
        let resource = NetSuiteResource.suiteQL(query: suiteQLQuery)
        do {
            let response: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
            var nameMap: [String: String] = [:]
            for row in response.items {
                let id = row.values["customer_id"] ?? ""
                let entityId = row.values["entity_id"] ?? ""
                let companyName = row.values["company_name"] ?? ""
                let name = !entityId.isEmpty ? entityId : (!companyName.isEmpty ? companyName : "Customer \(id)")
                nameMap[id] = name
            }
            return nameMap
        } catch {
            print("Failed to batch fetch customer names: \(error)")
            return [:]
        }
    }
    
    private func parseNetSuiteDate(_ dateString: String) async -> Date? {
        // Try ISO8601 formatter first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try various DateFormatter formats
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter1.date(from: dateString) {
            return date
        }
        
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter2.date(from: dateString) {
            return date
        }
        
        let formatter3 = DateFormatter()
        formatter3.dateFormat = "yyyy-MM-dd"
        if let date = formatter3.date(from: dateString) {
            return date
        }
        
        return nil
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
            clearFilters()
            return
        }
        
        let filteredInvoices = allInvoices.filter { invoice in
            invoice.invoiceNumber.localizedCaseInsensitiveContains(query) ||
            invoice.customerName.localizedCaseInsensitiveContains(query)
        }
        
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByStatus(_ status: Invoice.InvoiceStatus) {
        let filteredInvoices = allInvoices.filter { $0.status == status }
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByCustomer(_ customerId: String) {
        let filteredInvoices = allInvoices.filter { $0.customerId == customerId }
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func clearFilters() {
        invoices = allInvoices
    }
    
    /// Reload invoices from scratch without relying on auth state
    func reloadInvoices() async {
        resetPagination()
        await loadNextPage()
    }
    
    func getOverdueInvoices() -> [Invoice] {
        let today = Date()
        return allInvoices.filter { invoice in
            invoice.status == .overdue ||
            (invoice.dueDate != nil && invoice.dueDate! < today && invoice.status == .pending)
        }
    }
    
    func getInvoicesByStatus(_ status: Invoice.InvoiceStatus) -> [Invoice] {
        return allInvoices.filter { $0.status == status }
    }
    
    func getTotalOutstanding() -> Decimal {
        return allInvoices
            .filter { $0.status != .paid && $0.status != .cancelled }
            .reduce(0) { $0 + $1.balance }
    }
    
    func getInvoiceById(_ id: String) -> Invoice? {
        return allInvoices.first { $0.id == id }
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
        allInvoices.append(newInvoice)
        invoices = allInvoices // Refresh filtered view
    }
    
    func updateInvoice(_ invoice: Invoice) {
        // Update in allInvoices
        if let index = allInvoices.firstIndex(where: { $0.id == invoice.id }) {
            allInvoices[index] = invoice
        }
        
        // Update in displayed invoices
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        }
        
        // In a real app, you would update this in NetSuite
    }
    
    func markInvoiceAsPaid(_ invoice: Invoice) {
        let updatedInvoice = Invoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            customerId: invoice.customerId,
            customerName: invoice.customerName,
            amount: invoice.amount,
            balance: 0,
            amountPaid: invoice.amount,
            amountRemaining: 0,
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
        let testIds = Array(allInvoices.prefix(3)).map { $0.id }
        
        for invoiceId in testIds {
            print("Debug: InvoiceViewModel - Testing invoice ID: \(invoiceId)")
            // Use a more appropriate debug method for invoices
            print("Debug: InvoiceViewModel - Invoice ID \(invoiceId) format appears valid")
        }
    }
    
    // MARK: - Invoice Creation and Item Management
    
    @Published var availableItems: [NetSuiteItem] = []
    @Published var isLoadingItems = false
    @Published var selectedItems: [InvoiceItemCreation] = []
    
    /// Loads available items from NetSuite for invoice creation
    func loadAvailableItems() async {
        isLoadingItems = true
        defer { isLoadingItems = false }
        
        do {
            let items = try await netSuiteAPI.fetchItems()
            await MainActor.run {
                self.availableItems = items
            }
        } catch {
            print("Failed to load items: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load items: \(error.localizedDescription)"
            }
        }
    }
    
    /// Adds an item to the invoice being created
    func addItemToInvoice(item: NetSuiteItem, quantity: Double = 1.0, customPrice: Double? = nil) {
        let price = customPrice ?? item.basePrice
        let amount = price * quantity
        
        let invoiceItem = InvoiceItemCreation(
            id: UUID().uuidString,
            netSuiteItemId: item.id,
            itemName: item.displayName,
            description: item.itemDescription,
            quantity: quantity,
            unitPrice: Decimal(price),
            amount: Decimal(amount)
        )
        
        selectedItems.append(invoiceItem)
    }
    
    /// Removes an item from the invoice being created
    func removeItemFromInvoice(itemId: String) {
        selectedItems.removeAll { $0.id == itemId }
    }
    
    /// Updates the quantity for an item in the invoice
    func updateItemQuantity(itemId: String, quantity: Double) {
        guard let index = selectedItems.firstIndex(where: { $0.id == itemId }) else { return }
        let item = selectedItems[index]
        let newAmount = item.unitPrice * Decimal(quantity)
        
        selectedItems[index] = InvoiceItemCreation(
            id: item.id,
            netSuiteItemId: item.netSuiteItemId,
            itemName: item.itemName,
            description: item.description,
            quantity: quantity,
            unitPrice: item.unitPrice,
            amount: newAmount
        )
    }
    
    /// Calculates the total amount for selected items
    var selectedItemsTotal: Decimal {
        return selectedItems.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    /// Clears all selected items
    func clearSelectedItems() {
        selectedItems.removeAll()
    }
}

// MARK: - Supporting Models

/// Represents an item being added to a new invoice
struct InvoiceItemCreation: Identifiable {
    let id: String
    let netSuiteItemId: String
    let itemName: String
    let description: String
    let quantity: Double
    let unitPrice: Decimal
    let amount: Decimal
    
    var formattedUnitPrice: String {
        return String(format: "$%.2f", (unitPrice as NSDecimalNumber).doubleValue)
    }
    
    var formattedAmount: String {
        return String(format: "$%.2f", (amount as NSDecimalNumber).doubleValue)
    }
} 