import Foundation
import Combine

/// Manages incremental sync state for NetSuite data, fetching only records
/// modified since the last successful sync.
final class IncrementalSyncManager: ObservableObject {
    static let shared = IncrementalSyncManager()

    // MARK: - Published State
    @Published private(set) var lastSyncDates: [EntityType: Date] = [:]
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var syncProgress: [EntityType: SyncProgress] = [:]

    // MARK: - Entity Types
    enum EntityType: String, CaseIterable, Codable {
        case invoices
        case customers
        case payments
        case salesOrders

        var displayName: String {
            switch self {
            case .invoices: return "Invoices"
            case .customers: return "Customers"
            case .payments: return "Payments"
            case .salesOrders: return "Sales Orders"
            }
        }

        /// NetSuite table name for SuiteQL
        var tableName: String {
            switch self {
            case .invoices: return "transaction"
            case .customers: return "customer"
            case .payments: return "transaction"
            case .salesOrders: return "transaction"
            }
        }

        /// Filter for transaction type (if applicable)
        var transactionTypeFilter: String? {
            switch self {
            case .invoices: return "CustInvc"
            case .payments: return "CustPymt"
            case .salesOrders: return "SalesOrd"
            case .customers: return nil
            }
        }
    }

    // MARK: - Sync Progress
    struct SyncProgress {
        var status: SyncStatus
        var recordsFetched: Int
        var totalRecords: Int?
        var startTime: Date
        var error: String?

        var duration: TimeInterval {
            Date().timeIntervalSince(startTime)
        }
    }

    enum SyncStatus: String {
        case idle
        case fetching
        case processing
        case completed
        case failed
    }

    // MARK: - Storage Keys
    private let syncDatesKey = "com.fieldpay.incrementalSync.lastDates"
    private let syncVersionKey = "com.fieldpay.incrementalSync.version"
    private let currentSyncVersion = 1

    // MARK: - Configuration
    /// Maximum records to fetch per incremental sync batch
    let maxBatchSize = 500

    /// How far back to look for initial sync (30 days)
    let initialSyncLookbackDays = 30

    private init() {
        loadSyncState()
    }

    // MARK: - Persistence

    private func loadSyncState() {
        // Check sync version - if outdated, reset
        let storedVersion = UserDefaults.standard.integer(forKey: syncVersionKey)
        if storedVersion != currentSyncVersion {
            resetAllSyncState()
            UserDefaults.standard.set(currentSyncVersion, forKey: syncVersionKey)
            return
        }

        // Load last sync dates
        if let data = UserDefaults.standard.data(forKey: syncDatesKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastSyncDates = decoded.compactMapKeys { EntityType(rawValue: $0) }
        }
    }

    private func saveSyncState() {
        let encoded = lastSyncDates.mapKeys { $0.rawValue }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: syncDatesKey)
        }
    }

    /// Reset sync state for a specific entity type
    func resetSyncState(for entityType: EntityType) {
        lastSyncDates.removeValue(forKey: entityType)
        syncProgress.removeValue(forKey: entityType)
        saveSyncState()
    }

    /// Reset all sync state (force full refresh)
    func resetAllSyncState() {
        lastSyncDates.removeAll()
        syncProgress.removeAll()
        UserDefaults.standard.removeObject(forKey: syncDatesKey)
    }

    // MARK: - Sync Date Tracking

    /// Get the date to use for incremental sync query
    func getSyncFromDate(for entityType: EntityType) -> Date {
        if let lastSync = lastSyncDates[entityType] {
            // Subtract 1 minute buffer to avoid missing records due to clock differences
            return lastSync.addingTimeInterval(-60)
        } else {
            // Initial sync: look back N days
            return Calendar.current.date(
                byAdding: .day,
                value: -initialSyncLookbackDays,
                to: Date()
            ) ?? Date()
        }
    }

    /// Mark sync as completed for an entity type
    func markSyncCompleted(for entityType: EntityType, recordCount: Int) {
        lastSyncDates[entityType] = Date()
        syncProgress[entityType] = SyncProgress(
            status: .completed,
            recordsFetched: recordCount,
            totalRecords: recordCount,
            startTime: syncProgress[entityType]?.startTime ?? Date()
        )
        saveSyncState()
    }

    /// Mark sync as failed
    func markSyncFailed(for entityType: EntityType, error: Error) {
        syncProgress[entityType]?.status = .failed
        syncProgress[entityType]?.error = error.localizedDescription
    }

    // MARK: - SuiteQL Query Building

    /// Build an incremental sync query for invoices
    func buildInvoiceSyncQuery(limit: Int = 500, offset: Int = 0) -> String {
        let fromDate = getSyncFromDate(for: .invoices)
        let dateString = formatDateForSuiteQL(fromDate)

        return """
            SELECT
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                t.foreigntotal AS TotalAmount,
                t.foreignamountremaining AS AmountRemaining,
                t.duedate AS DueDate,
                t.lastmodifieddate AS LastModified,
                BUILTIN.DF(t.status) AS StatusDisplay,
                BUILTIN.DF(t.entity) AS CustomerName,
                t.entity AS CustomerID,
                t.memo AS InvoiceMemo
            FROM transaction t
            WHERE t.type = 'CustInvc'
                AND t.lastmodifieddate >= '\(dateString)'
            ORDER BY t.lastmodifieddate DESC
            LIMIT \(limit) OFFSET \(offset)
        """
    }

    /// Build an incremental sync query for customers
    func buildCustomerSyncQuery(limit: Int = 500, offset: Int = 0) -> String {
        let fromDate = getSyncFromDate(for: .customers)
        let dateString = formatDateForSuiteQL(fromDate)

        return """
            SELECT
                id,
                entityid,
                companyname,
                email,
                phone,
                lastmodifieddate,
                BUILTIN.DF(id) AS DisplayName
            FROM customer
            WHERE lastmodifieddate >= '\(dateString)'
            ORDER BY lastmodifieddate DESC
            LIMIT \(limit) OFFSET \(offset)
        """
    }

    /// Build an incremental sync query for payments
    func buildPaymentSyncQuery(limit: Int = 500, offset: Int = 0) -> String {
        let fromDate = getSyncFromDate(for: .payments)
        let dateString = formatDateForSuiteQL(fromDate)

        return """
            SELECT
                t.id AS PaymentID,
                t.tranid AS PaymentNumber,
                t.trandate AS PaymentDate,
                t.foreigntotal AS Amount,
                t.lastmodifieddate AS LastModified,
                BUILTIN.DF(t.status) AS StatusDisplay,
                BUILTIN.DF(t.entity) AS CustomerName,
                t.entity AS CustomerID,
                t.memo AS Memo
            FROM transaction t
            WHERE t.type = 'CustPymt'
                AND t.lastmodifieddate >= '\(dateString)'
            ORDER BY t.lastmodifieddate DESC
            LIMIT \(limit) OFFSET \(offset)
        """
    }

    /// Build an incremental sync query for sales orders
    func buildSalesOrderSyncQuery(limit: Int = 500, offset: Int = 0) -> String {
        let fromDate = getSyncFromDate(for: .salesOrders)
        let dateString = formatDateForSuiteQL(fromDate)

        return """
            SELECT
                t.id AS SalesOrderID,
                t.tranid AS OrderNumber,
                t.trandate AS OrderDate,
                t.foreigntotal AS TotalAmount,
                t.lastmodifieddate AS LastModified,
                BUILTIN.DF(t.status) AS StatusDisplay,
                BUILTIN.DF(t.entity) AS CustomerName,
                t.entity AS CustomerID,
                t.memo AS Memo
            FROM transaction t
            WHERE t.type = 'SalesOrd'
                AND t.lastmodifieddate >= '\(dateString)'
            ORDER BY t.lastmodifieddate DESC
            LIMIT \(limit) OFFSET \(offset)
        """
    }

    /// Get count of records modified since last sync
    func buildCountQuery(for entityType: EntityType) -> String {
        let fromDate = getSyncFromDate(for: entityType)
        let dateString = formatDateForSuiteQL(fromDate)

        switch entityType {
        case .customers:
            return """
                SELECT COUNT(*) AS cnt
                FROM customer
                WHERE lastmodifieddate >= '\(dateString)'
            """
        case .invoices, .payments, .salesOrders:
            guard let typeFilter = entityType.transactionTypeFilter else { return "" }
            return """
                SELECT COUNT(*) AS cnt
                FROM transaction t
                WHERE t.type = '\(typeFilter)'
                    AND t.lastmodifieddate >= '\(dateString)'
            """
        }
    }

    // MARK: - Helpers

    private func formatDateForSuiteQL(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Start tracking a sync operation
    func beginSync(for entityType: EntityType) {
        syncProgress[entityType] = SyncProgress(
            status: .fetching,
            recordsFetched: 0,
            totalRecords: nil,
            startTime: Date()
        )
    }

    /// Update progress during sync
    func updateProgress(for entityType: EntityType, fetched: Int, total: Int? = nil) {
        syncProgress[entityType]?.recordsFetched = fetched
        if let total = total {
            syncProgress[entityType]?.totalRecords = total
        }
        syncProgress[entityType]?.status = .processing
    }

    /// Check if we should do a full sync (never synced or very old)
    func shouldDoFullSync(for entityType: EntityType) -> Bool {
        guard let lastSync = lastSyncDates[entityType] else {
            return true // Never synced
        }

        // If last sync was more than 7 days ago, do full sync
        let daysSinceSync = Calendar.current.dateComponents(
            [.day],
            from: lastSync,
            to: Date()
        ).day ?? 0

        return daysSinceSync > 7
    }

    /// Get human-readable sync status
    func getSyncStatusDescription(for entityType: EntityType) -> String {
        if let progress = syncProgress[entityType] {
            switch progress.status {
            case .idle:
                return "Ready"
            case .fetching:
                return "Fetching..."
            case .processing:
                if let total = progress.totalRecords {
                    return "Processing \(progress.recordsFetched)/\(total)"
                }
                return "Processing \(progress.recordsFetched) records"
            case .completed:
                return "Synced \(progress.recordsFetched) records"
            case .failed:
                return "Failed: \(progress.error ?? "Unknown error")"
            }
        }

        if let lastSync = lastSyncDates[entityType] {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last sync: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        }

        return "Never synced"
    }
}

// MARK: - Dictionary Extension for Key Mapping

private extension Dictionary {
    func compactMapKeys<T>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }

    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
