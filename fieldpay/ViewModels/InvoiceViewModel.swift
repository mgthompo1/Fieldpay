import Foundation
import Combine

// MARK: - Protocols for DI
protocol AuthMonitoring {
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> { get }
}

extension OAuthManager: @preconcurrency AuthMonitoring {
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> { $isAuthenticated.eraseToAnyPublisher() }
}

@MainActor
class InvoiceViewModel: ObservableObject {
    // MARK: - Published UI state
    @Published var invoices: [Invoice] = []
    @Published var selectedInvoice: Invoice?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Data caches & pagination
    private var invoiceCache: [String: Invoice] = [:]
    private var allInvoices: [Invoice] = []                // Unfiltered source
    private var seenIds: Set<String> = []                  // Dedupe guard
    private var loadedPages: Set<Int> = []                 // Optional defensive tracking
    private(set) var currentPage: Int = 0
    private let pageSize: Int = 50
    private(set) var hasMore: Bool = true
    private var activeStatus: String? = nil                // Reset paging when status changes
    
    // MARK: - Detail fetching queue
    private var detailFetchQueue: [String] = []
    private var detailFetchSet: Set<String> = []           // Prevent duplicate enqueues
    private var isFetchingDetails = false
    private let maxConcurrentDetailFetches = 3
    
    // MARK: - Dependencies
    private let api: NetSuiteAPIProtocol
    private let auth: AuthMonitoring
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init(
        api: NetSuiteAPIProtocol = NetSuiteAPI.shared,
        auth: AuthMonitoring = OAuthManager.shared
    ) {
        self.api = api
        self.auth = auth
        
        // React to auth changes
        auth.isAuthenticatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                if isAuthenticated {
                    self.resetPagination()
                    Task { await self.loadNextPage() }
                } else {
                    self.resetPagination()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Paging helpers
    func resetPagination() {
        invoices = []
        allInvoices = []
        invoiceCache.removeAll()
        seenIds.removeAll()
        loadedPages.removeAll()
        currentPage = 0
        hasMore = true
        activeStatus = nil
        detailFetchQueue.removeAll()
        detailFetchSet.removeAll()
        isFetchingDetails = false
        errorMessage = nil
    }

    // MARK: - Incremental Sync

    /// Perform incremental sync - only fetch invoices modified since last sync
    /// Returns the number of new/updated records
    @discardableResult
    func performIncrementalSync() async -> Int {
        let syncManager = IncrementalSyncManager.shared
        syncManager.beginSync(for: .invoices)

        do {
            let query = syncManager.buildInvoiceSyncQuery(limit: syncManager.maxBatchSize)
            let resource = NetSuiteResource.suiteQL(query: query)
            let response: SuiteQLResponse = try await (api as? NetSuiteAPI ?? NetSuiteAPI.shared)
                .fetch(resource, type: SuiteQLResponse.self)

            var updatedCount = 0

            for row in response.items {
                guard let id = row.values["InvoiceID"],
                      let tranId = row.values["InvoiceNumber"],
                      let dateStr = row.values["InvoiceDate"],
                      let totalStr = row.values["TotalAmount"],
                      let status = row.values["StatusDisplay"],
                      let customerName = row.values["CustomerName"] else {
                    continue
                }

                let date = NetSuiteDateParser.parseDate(dateStr) ?? Date()
                let total = Double(totalStr) ?? 0.0
                let remaining = Double(row.values["AmountRemaining"] ?? totalStr) ?? total
                let dueDate = NetSuiteDateParser.parseDate(row.values["DueDate"])
                let customerId = row.values["CustomerID"] ?? ""
                let memo = row.values["InvoiceMemo"]

                let invoice = Invoice(
                    id: id,
                    invoiceNumber: tranId,
                    customerId: customerId,
                    customerName: customerName,
                    amount: Decimal(total),
                    balance: Decimal(remaining),
                    status: parseNetSuiteStatus(status),
                    dueDate: dueDate,
                    createdDate: date,
                    netSuiteId: id,
                    items: [],
                    notes: memo
                )

                // Update or insert
                if let existingIdx = allInvoices.firstIndex(where: { $0.id == id }) {
                    allInvoices[existingIdx] = invoice
                } else {
                    allInvoices.append(invoice)
                    seenIds.insert(id)
                }
                invoiceCache[id] = invoice
                updatedCount += 1

                // Cache customer name
                if !customerId.isEmpty && !customerName.isEmpty {
                    await CustomerNameCache.shared.preload([customerId: customerName])
                }
            }

            // Sort and update UI
            invoices = allInvoices.sorted(by: { $0.createdDate > $1.createdDate })

            syncManager.markSyncCompleted(for: .invoices, recordCount: updatedCount)
            print("InvoiceViewModel: Incremental sync completed - \(updatedCount) records updated")

            return updatedCount

        } catch {
            syncManager.markSyncFailed(for: .invoices, error: error)
            print("InvoiceViewModel: Incremental sync failed - \(error)")
            return 0
        }
    }

    /// Check if we should do incremental or full sync
    func refreshInvoices() async {
        let syncManager = IncrementalSyncManager.shared

        if syncManager.shouldDoFullSync(for: .invoices) {
            // Full sync - reset and load from scratch
            resetPagination()
            await loadNextPage()
        } else {
            // Incremental sync - just get changes
            await performIncrementalSync()
        }
    }

    func loadNextPage(status: String? = nil) async {
        guard !isLoading, hasMore else { return }
        if status != activeStatus { // user changed the filter — restart
            resetPagination()
            activeStatus = status
        }
        isLoading = true
        errorMessage = nil
        let pageToLoad = currentPage

        do {
            // Use server-side pagination via SuiteQL LIMIT/OFFSET
            let offset = pageToLoad * pageSize

            // Cast to get access to the paginated method
            let netSuiteApi = api as? NetSuiteAPI ?? NetSuiteAPI.shared
            let result = try await netSuiteApi.fetchInvoicesWithDisplayValuesPaginated(
                limit: pageSize,
                offset: offset,
                statusFilter: status
            )

            // Convert to domain models - now includes balance, dueDate, and customerId from server
            let mapped = result.invoices.map { record in
                let balance = record.amountRemaining ?? record.total
                let statusParsed = parseNetSuiteStatus(record.status)

                return Invoice(
                    id: record.id,
                    invoiceNumber: record.tranId,
                    customerId: record.customerId ?? "",
                    customerName: record.customerName,
                    amount: Decimal(record.total),
                    balance: Decimal(balance),
                    status: statusParsed,
                    dueDate: record.dueDate,
                    createdDate: record.trandate,
                    netSuiteId: record.id,
                    items: [],
                    notes: record.memo
                )
            }

            // Dedupe & append (server pagination handles filtering)
            let unique = mapped.filter { seenIds.insert($0.id).inserted }
            for inv in unique { invoiceCache[inv.id] = inv }
            allInvoices.append(contentsOf: unique)

            // Keep newest first (by createdDate)
            invoices = allInvoices.sorted(by: { $0.createdDate > $1.createdDate })

            // Update paging info from server response
            hasMore = result.hasMore
            loadedPages.insert(pageToLoad)
            currentPage += 1

            // Queue details for invoices that need additional info (line items)
            // Only fetch details for invoices that don't have complete data
            let incompleteIds = unique.filter { $0.items.isEmpty }.map { $0.id }
            if !incompleteIds.isEmpty {
                await queueDetailFetching(for: incompleteIds)
            }

            isLoading = false
        } catch {
            if let uerr = error as? URLError, uerr.code == .notConnectedToInternet {
                errorMessage = "You're offline. Try again when you're back online."
            } else if (error as? NetSuiteError) == .notConfigured {
                errorMessage = "NetSuite not connected. Authenticate in Settings."
            } else {
                errorMessage = "Failed to load invoices: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    /// Parse NetSuite status display value to AppInvoiceStatus
    private func parseNetSuiteStatus(_ statusDisplay: String) -> AppInvoiceStatus {
        let lowered = statusDisplay.lowercased()
        if lowered.contains("paid") { return .paid }
        if lowered.contains("open") { return .pending }
        if lowered.contains("cancel") || lowered.contains("void") { return .cancelled }
        if lowered.contains("overdue") { return .overdue }
        return .pending
    }
    
    // MARK: - Batch Detail Fetching
    private func queueDetailFetching(for invoiceIds: [String]) async {
        // Add new IDs to queue without duplicates
        for id in invoiceIds where !detailFetchSet.contains(id) {
            detailFetchSet.insert(id)
            detailFetchQueue.append(id)
        }
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
                    group.addTask { [weak self] in
                        await self?.fetchInvoiceDetailWithRetry(invoiceId: invoiceId)
                    }
                }
            }
            
            // Gentle throttle between batches
            try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s
        }
        
        isFetchingDetails = false
    }
    
    private func fetchInvoiceDetailWithRetry(invoiceId: String, retryCount: Int = 0) async {
        let maxRetries = 2
        let baseDelay: UInt64 = 600_000_000 // 0.6s
        do {
            try await fetchInvoiceDetail(invoiceId: invoiceId)
        } catch {
            if retryCount < maxRetries {
                let delay = baseDelay * UInt64(pow(2.0, Double(retryCount)))
                print("Retrying fetch for invoice \(invoiceId), attempt \(retryCount + 1)")
                try? await Task.sleep(nanoseconds: delay)
                await fetchInvoiceDetailWithRetry(invoiceId: invoiceId, retryCount: retryCount + 1)
            } else {
                print("Failed to fetch invoice \(invoiceId) after \(maxRetries + 1) attempts: \(error)")
            }
        }
    }
    
    private func fetchInvoiceDetail(invoiceId: String) async throws {
        do {
            // Try REST detail first
            let resource = NetSuiteResource.invoiceDetail(id: invoiceId)
            let detailed: NetSuiteInvoiceRecord = try await api.fetch(resource, type: NetSuiteInvoiceRecord.self)
            let invoice = detailed.toInvoice()

            // Update cache/UI
            self.invoiceCache[invoiceId] = invoice
            if let idx = self.invoices.firstIndex(where: { $0.id == invoiceId }) {
                self.invoices[idx] = invoice
            }
        } catch {
            print("Failed REST detail for invoice \(invoiceId): \(error). Falling back to SuiteQL…")
            // Fallback via SuiteQL with richer fields - use safe query building
            guard let safeId = SuiteQLHelper.escapeNumericId(invoiceId) else {
                print("Invalid invoice ID format: \(invoiceId)")
                return
            }
            let q = """
                SELECT t.id, t.tranid, t.entity, t.amount, t.trandate, t.status, t.memo, t.duedate, t.amountremaining
                FROM transaction t
                WHERE t.id = '\(safeId)' AND t.type = 'Invoice'
                LIMIT 1
            """
            let resource = NetSuiteResource.suiteQL(query: q)
            let resp: SuiteQLResponse = try await api.fetch(resource, type: SuiteQLResponse.self)
            guard let row = resp.items.first else { return }

            let id = row.values["column0"] ?? invoiceId
            let tranId = row.values["column1"] ?? "INV-\(invoiceId)"
            let customerId = row.values["column2"] ?? ""
            let amount = Decimal(string: row.values["column3"] ?? "0") ?? 0
            let created = InvoiceViewModel.parseNetSuiteDate(row.values["column4"]) ?? Date()
            let statusRaw = row.values["column5"] ?? "pending"
            let memo = row.values["column6"]
            let due = InvoiceViewModel.parseNetSuiteDate(row.values["column7"]) // optional
            let remaining = Decimal(string: row.values["column8"] ?? row.values["column3"] ?? "0") ?? amount
            let customerName = await fetchCustomerName(customerId: customerId)

            let minimal = Invoice(
                id: id,
                invoiceNumber: tranId,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                balance: remaining,
                status: AppInvoiceStatus(rawValue: statusRaw) ?? .pending,
                dueDate: due,
                createdDate: created,
                netSuiteId: id,
                items: [],
                notes: memo
            )

            self.invoiceCache[invoiceId] = minimal
            if let idx = self.invoices.firstIndex(where: { $0.id == invoiceId }) {
                self.invoices[idx] = minimal
            }
        }
    }
    
    // MARK: - Helper Methods (using CustomerNameCache)

    /// Fetch customer name using the global cache
    private func fetchCustomerName(customerId: String) async -> String {
        guard !customerId.isEmpty else { return "Customer \(customerId)" }
        return await CustomerNameCache.shared.getCustomerName(customerId: customerId)
    }

    /// Batch fetch customer names using the global cache
    private func fetchCustomerNamesBatch(customerIds: [String]) async -> [String: String] {
        guard !customerIds.isEmpty else { return [:] }
        return await CustomerNameCache.shared.getCustomerNames(customerIds: customerIds)
    }
    
    private static func parseNetSuiteDate(_ dateString: String?) -> Date? {
        guard let s = dateString, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f1 = DateFormatter(); f1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"; if let d = f1.date(from: s) { return d }
        let f2 = DateFormatter(); f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"; if let d = f2.date(from: s) { return d }
        let f3 = DateFormatter(); f3.dateFormat = "yyyy-MM-dd"; if let d = f3.date(from: s) { return d }
        return nil
    }
    
    // MARK: - Public Detail Fetching
    func loadInvoiceDetail(id: String) async {
        if let cached = invoiceCache[id] {
            self.selectedInvoice = cached
            return
        }
        do {
            try await fetchInvoiceDetail(invoiceId: id)
            self.selectedInvoice = self.invoiceCache[id]
        } catch {
            print("Failed to load invoice detail for \(id): \(error)")
        }
    }
    
    // MARK: - Search / Filter
    func searchInvoices(query: String) {
        guard !query.isEmpty else { clearFilters(); return }
        let filtered = allInvoices.filter { inv in
            inv.invoiceNumber.localizedCaseInsensitiveContains(query) ||
            inv.customerName.localizedCaseInsensitiveContains(query)
        }
        invoices = filtered.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByStatus(_ status: AppInvoiceStatus) {
        let filtered = allInvoices.filter { $0.status == status }
        invoices = filtered.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByCustomer(_ customerId: String) {
        let filtered = allInvoices.filter { $0.customerId == customerId }
        invoices = filtered.sorted { $0.createdDate > $1.createdDate }
    }
    
    func clearFilters() {
        invoices = allInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Reload invoices from scratch without relying on auth state
    func reloadInvoices(status: String? = nil) async {
        resetPagination()
        activeStatus = status
        await loadNextPage(status: status)
    }
    
    // MARK: - Insights / Aggregates
    func getOverdueInvoices() -> [Invoice] {
        let today = Date()
        return allInvoices.filter { inv in
            inv.status == .overdue || (inv.dueDate != nil && inv.dueDate! < today && inv.status == .pending)
        }
    }
    
    func getInvoicesByStatus(_ status: AppInvoiceStatus) -> [Invoice] {
        allInvoices.filter { $0.status == status }
    }
    
    func getTotalOutstanding() -> Decimal {
        allInvoices
            .filter { $0.status != .paid && $0.status != .cancelled }
            .reduce(Decimal(0)) { $0 + $1.balance }
    }
    
    func getInvoiceById(_ id: String) -> Invoice? {
        allInvoices.first { $0.id == id }
    }
    
    // MARK: - Creation with NetSuite Sync
    func createInvoice(customerId: String, customerName: String, amount: Decimal, items: [AppInvoiceItem], dueDate: Date? = nil) async {
        let tempNumber = generateInvoiceNumber()
        let new = Invoice(
            invoiceNumber: tempNumber,
            customerId: customerId,
            customerName: customerName,
            amount: amount,
            balance: amount,
            dueDate: dueDate,
            items: items
        )

        // Add locally first for immediate UI feedback
        allInvoices.append(new)
        invoices = allInvoices.sorted { $0.createdDate > $1.createdDate }

        // Sync to NetSuite in background
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let tranDate = dateFormatter.string(from: Date())

                // Convert AppInvoiceItems to NetSuite format
                let lineItems = items.map { item in
                    NetSuiteInvoiceLineItem(
                        item: EntityReference(id: item.netSuiteItemId, refName: item.description, type: "inventoryItem"),
                        quantity: item.quantity,
                        rate: NSDecimalNumber(decimal: item.unitPrice).doubleValue,
                        amount: NSDecimalNumber(decimal: item.amount).doubleValue,
                        description: item.description,
                        lineNumber: nil
                    )
                }

                let request = NetSuiteInvoiceCreationRequest(
                    entity: EntityReference(id: customerId, refName: customerName, type: "customer"),
                    tranDate: tranDate,
                    memo: nil,
                    itemList: NetSuiteInvoiceItemList(item: lineItems)
                )

                let created = try await NetSuiteAPI.shared.createInvoice(request: request)

                // Update local invoice with NetSuite ID
                await MainActor.run {
                    if let idx = self.allInvoices.firstIndex(where: { $0.invoiceNumber == tempNumber }) {
                        self.allInvoices[idx] = Invoice(
                            id: created.id,
                            invoiceNumber: created.tranId ?? tempNumber,
                            customerId: customerId,
                            customerName: customerName,
                            amount: amount,
                            balance: amount,
                            dueDate: dueDate,
                            netSuiteId: created.id,
                            items: items
                        )
                        self.invoices = self.allInvoices.sorted { $0.createdDate > $1.createdDate }
                    }
                }
                print("Invoice created in NetSuite: \(created.id)")
            } catch {
                print("Failed to create invoice in NetSuite: \(error)")
                // Invoice remains local - will need manual sync later
            }
        }
    }

    func updateInvoice(_ invoice: Invoice) async {
        // Update locally first
        if let i = allInvoices.firstIndex(where: { $0.id == invoice.id }) { allInvoices[i] = invoice }
        if let i = invoices.firstIndex(where: { $0.id == invoice.id }) { invoices[i] = invoice }

        // Sync to NetSuite if we have a NetSuite ID
        guard let netSuiteId = invoice.netSuiteId else {
            print("Invoice has no NetSuite ID - update stored locally only")
            return
        }

        Task {
            do {
                let updates = NetSuiteInvoiceUpdateRequest(
                    memo: invoice.notes,
                    dueDate: invoice.dueDate.map { date in
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        return df.string(from: date)
                    },
                    status: invoice.status.rawValue
                )

                _ = try await NetSuiteAPI.shared.updateInvoice(invoiceId: netSuiteId, updates: updates)
                print("Invoice updated in NetSuite: \(netSuiteId)")
            } catch {
                print("Failed to update invoice in NetSuite: \(error)")
            }
        }
    }

    func markInvoiceAsPaid(_ invoice: Invoice) async {
        let updated = Invoice(
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

        // Update locally
        if let i = allInvoices.firstIndex(where: { $0.id == invoice.id }) { allInvoices[i] = updated }
        if let i = invoices.firstIndex(where: { $0.id == invoice.id }) { invoices[i] = updated }

        // Create payment in NetSuite
        guard let netSuiteId = invoice.netSuiteId else {
            print("Invoice has no NetSuite ID - payment stored locally only")
            return
        }

        Task {
            do {
                _ = try await NetSuiteAPI.shared.markInvoiceAsPaid(
                    invoiceId: netSuiteId,
                    paymentAmount: invoice.amount,
                    customerId: invoice.customerId
                )
                print("Payment created in NetSuite for invoice: \(netSuiteId)")
            } catch {
                print("Failed to create payment in NetSuite: \(error)")
                // Queue for offline sync
                let payment = Payment.createOfflinePayment(
                    amount: invoice.amount,
                    currency: "USD",
                    paymentMethod: .cash,
                    customerId: invoice.customerId,
                    invoiceId: invoice.id,
                    description: "Payment for invoice \(invoice.invoiceNumber)"
                )
                OfflinePaymentQueue.shared.enqueue(payment, customerId: invoice.customerId, invoiceId: invoice.id)
            }
        }
    }
    
    private func generateInvoiceNumber() -> String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let ds = df.string(from: Date())
        let suffix = String(format: "%04d", Int.random(in: 1...9999))
        return "INV-\(ds)-\(suffix)"
    }
    
    // MARK: - Date Range Queries
    
    /// Fetch invoices by date range using the comprehensive SuiteQL query
    func fetchInvoicesByDateRange(fromDate: Date, toDate: Date? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fromDateString = dateFormatter.string(from: fromDate)
            let toDateString = toDate.map { dateFormatter.string(from: $0) }
            
            let dateRangeInvoices = try await api.fetchCustomerInvoicesByDateRangeAsInvoices(
                fromDate: fromDateString,
                toDate: toDateString
            )
            
            // Update the UI with the date range results
            await MainActor.run {
                self.invoices = dateRangeInvoices
                self.allInvoices = dateRangeInvoices
                self.hasMore = false // Date range queries don't support pagination
                self.currentPage = 0
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch invoices by date range: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    /// Reset to normal pagination after date range query
    func resetToNormalPagination() async {
        resetPagination()
        await loadNextPage()
    }
    
    // MARK: - Debug helpers
    func debugInvoiceIds() async {
        print("Debug: InvoiceViewModel - Testing invoice ID formats…")
        let testIds = Array(allInvoices.prefix(3)).map { $0.id }
        for invoiceId in testIds { print("Debug: InvoiceViewModel - Invoice ID: \(invoiceId)") }
    }
    
    // MARK: - Item selection for creation
    @Published var availableItems: [NetSuiteItem] = []
    @Published var isLoadingItems = false
    @Published var selectedItems: [InvoiceItemCreation] = []
    
    func loadAvailableItems() async {
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            let items = try await api.fetchItems()
            self.availableItems = items
        } catch {
            print("Failed to load items: \(error)")
            self.errorMessage = "Failed to load items: \(error.localizedDescription)"
        }
    }
    
    func addItemToInvoice(item: NetSuiteItem, quantity: Double = 1.0, customPrice: Double? = nil) {
        let price = customPrice ?? item.basePrice
        let amount = price * quantity
        let entry = InvoiceItemCreation(
            id: UUID().uuidString,
            netSuiteItemId: item.id,
            itemName: item.displayName,
            description: item.itemDescription,
            quantity: quantity,
            unitPrice: Decimal(price),
            amount: Decimal(amount)
        )
        selectedItems.append(entry)
    }
    
    func removeItemFromInvoice(itemId: String) {
        selectedItems.removeAll { $0.id == itemId }
    }
    
    func updateItemQuantity(itemId: String, quantity: Double) {
        guard let idx = selectedItems.firstIndex(where: { $0.id == itemId }) else { return }
        let item = selectedItems[idx]
        let newAmount = item.unitPrice * Decimal(quantity)
        selectedItems[idx] = InvoiceItemCreation(
            id: item.id,
            netSuiteItemId: item.netSuiteItemId,
            itemName: item.itemName,
            description: item.description,
            quantity: quantity,
            unitPrice: item.unitPrice,
            amount: newAmount
        )
    }
    
    var selectedItemsTotal: Decimal { selectedItems.reduce(Decimal(0)) { $0 + $1.amount } }
    func clearSelectedItems() { selectedItems.removeAll() }
}

// MARK: - Supporting Models
struct InvoiceItemCreation: Identifiable {
    let id: String
    let netSuiteItemId: String
    let itemName: String
    let description: String
    let quantity: Double
    let unitPrice: Decimal
    let amount: Decimal
    
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = .current; return f
    }()
    
    var formattedUnitPrice: String {
        Self.formatter.string(from: unitPrice as NSDecimalNumber) ?? "$0.00"
    }
    var formattedAmount: String {
        Self.formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

