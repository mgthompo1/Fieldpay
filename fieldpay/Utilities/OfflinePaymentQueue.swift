import Foundation
import Network
import Combine

/// Manages offline payment queue with automatic sync when connectivity is restored
final class OfflinePaymentQueue: ObservableObject {
    static let shared = OfflinePaymentQueue()

    // MARK: - Published State
    @Published private(set) var pendingPayments: [QueuedPayment] = []
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncError: String?
    @Published private(set) var lastSuccessfulSync: Date?

    // MARK: - Private Properties
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.fieldpay.networkMonitor")
    private let storageKey = "com.fieldpay.offlinePaymentQueue"
    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Retry configuration
    private let maxRetryAttempts = 3
    private let retryDelaySeconds: [Double] = [5, 15, 30] // Exponential backoff

    private init() {
        loadFromDisk()
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
        syncTask?.cancel()
    }

    // MARK: - Public API

    /// Add a payment to the offline queue
    func enqueue(_ payment: Payment, customerId: String?, invoiceId: String?) {
        let queued = QueuedPayment(
            id: UUID().uuidString,
            payment: payment,
            customerId: customerId,
            invoiceId: invoiceId,
            createdAt: Date(),
            retryCount: 0,
            lastError: nil
        )

        pendingPayments.append(queued)
        saveToDisk()

        print("OfflinePaymentQueue: Enqueued payment \(payment.id) - Queue size: \(pendingPayments.count)")

        // Try to sync immediately if online
        if isOnline {
            triggerSync()
        }
    }

    /// Manually trigger a sync attempt
    func triggerSync() {
        guard !isSyncing else {
            print("OfflinePaymentQueue: Sync already in progress")
            return
        }

        guard !pendingPayments.isEmpty else {
            print("OfflinePaymentQueue: No pending payments to sync")
            return
        }

        guard isOnline else {
            print("OfflinePaymentQueue: Cannot sync - offline")
            return
        }

        syncTask?.cancel()
        syncTask = Task { @MainActor in
            await performSync()
        }
    }

    /// Remove a specific payment from the queue (e.g., if cancelled by user)
    func remove(paymentId: String) {
        pendingPayments.removeAll { $0.id == paymentId }
        saveToDisk()
    }

    /// Clear all pending payments (use with caution)
    func clearAll() {
        pendingPayments.removeAll()
        saveToDisk()
    }

    /// Get count of failed payments (exceeded retry attempts)
    var failedPaymentsCount: Int {
        pendingPayments.filter { $0.retryCount >= maxRetryAttempts }.count
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // If we just came back online, trigger sync
                if wasOffline && self?.isOnline == true {
                    print("OfflinePaymentQueue: Network restored - triggering sync")
                    self?.triggerSync()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Logic

    @MainActor
    private func performSync() async {
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        print("OfflinePaymentQueue: Starting sync of \(pendingPayments.count) payments")

        // Get NetSuite API reference
        let netSuiteAPI = NetSuiteAPI.shared

        guard netSuiteAPI.isConfigured() else {
            lastSyncError = "NetSuite not configured"
            print("OfflinePaymentQueue: NetSuite not configured - sync aborted")
            return
        }

        var successCount = 0
        var failCount = 0

        // Process payments one at a time to avoid overwhelming the server
        for index in pendingPayments.indices.reversed() {
            guard isOnline else {
                print("OfflinePaymentQueue: Lost connectivity during sync - pausing")
                break
            }

            let queued = pendingPayments[index]

            // Skip if exceeded max retries
            if queued.retryCount >= maxRetryAttempts {
                print("OfflinePaymentQueue: Payment \(queued.id) exceeded max retries - skipping")
                continue
            }

            do {
                // Attempt to create payment in NetSuite
                let created = try await netSuiteAPI.createPayment(queued.payment)
                print("OfflinePaymentQueue: Successfully synced payment \(queued.id) -> NetSuite ID: \(created.netSuitePaymentId ?? "unknown")")

                // Remove from queue on success
                pendingPayments.remove(at: index)
                successCount += 1

            } catch {
                print("OfflinePaymentQueue: Failed to sync payment \(queued.id): \(error)")

                // Update retry count and last error
                var updated = queued
                updated.retryCount += 1
                updated.lastError = error.localizedDescription
                updated.lastRetryAt = Date()
                pendingPayments[index] = updated

                failCount += 1

                // Add delay between retries to avoid hammering the server
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }

        saveToDisk()

        if successCount > 0 {
            lastSuccessfulSync = Date()
        }

        if failCount > 0 {
            lastSyncError = "Failed to sync \(failCount) payment(s)"
        }

        print("OfflinePaymentQueue: Sync complete - Success: \(successCount), Failed: \(failCount), Remaining: \(pendingPayments.count)")
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(pendingPayments)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("OfflinePaymentQueue: Failed to save to disk: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            pendingPayments = try JSONDecoder().decode([QueuedPayment].self, from: data)
            print("OfflinePaymentQueue: Loaded \(pendingPayments.count) pending payments from disk")
        } catch {
            print("OfflinePaymentQueue: Failed to load from disk: \(error)")
        }
    }
}

// MARK: - Queued Payment Model

struct QueuedPayment: Codable, Identifiable {
    let id: String
    let payment: Payment
    let customerId: String?
    let invoiceId: String?
    let createdAt: Date
    var retryCount: Int
    var lastError: String?
    var lastRetryAt: Date?

    var isFailedPermanently: Bool {
        retryCount >= 3
    }

    var statusDescription: String {
        if isFailedPermanently {
            return "Failed after \(retryCount) attempts"
        } else if retryCount > 0 {
            return "Retry \(retryCount)/3"
        } else {
            return "Pending"
        }
    }
}

// MARK: - Payment Extension for Offline Support

extension Payment {
    /// Create a payment record for offline queueing
    static func createOfflinePayment(
        amount: Decimal,
        currency: String = "USD",
        paymentMethod: PaymentMethodType,
        customerId: String?,
        invoiceId: String?,
        description: String?
    ) -> Payment {
        return Payment(
            amount: amount,
            currency: currency.uppercased(),
            status: .pending,
            paymentMethod: paymentMethod,
            customerId: customerId,
            invoiceId: invoiceId,
            description: description
        )
    }
}
