import Foundation

// MARK: - Protocol Abstractions for Dependency Injection

protocol StripeManaging {
    func setupTapToPay() async throws
    func processTapToPayPayment(amount: Int, currency: String) async throws -> PaymentIntent
    func createPaymentIntent(amount: Int, currency: String, customerId: String?) async throws -> PaymentIntent
}

protocol WindcaveManaging {
    func initializeTapToPay() async throws -> TapToPaySession
    func processTapToPayPayment(amount: Int, currency: String, sessionId: String) async throws -> TapToPayTransaction
}

protocol NetSuiteAPIProtocol {
    var isConnected: Bool { get }
    func fetchRecentPayments(fromDate: Date) async throws -> [Payment]
    func fetchCustomerPaymentsFiltered(customerId: String, fromDate: Date) async throws -> [Payment]
    func createPayment(_ payment: Payment) async throws -> Payment
    func fetch<T: Decodable>(_ resource: NetSuiteResource, type: T.Type) async throws -> T
    func fetchItems() async throws -> [NetSuiteItem]
    func fetchAllInvoicesWithResponse(limit: Int, offset: Int, status: String?) async throws -> NetSuiteResponse<NetSuiteInvoiceResponse>
    func fetchInvoicesWithDisplayValues() async throws -> [NetSuiteInvoiceWithDisplay]
    func fetchCustomerInvoicesByDateRangeAsInvoices(fromDate: String, toDate: String?) async throws -> [Invoice]
    func fetchCustomerInvoicesByDateRange(fromDate: String, toDate: String?) async throws -> [DateRangeInvoiceItem]
}

protocol CustomerManaging {
    @MainActor func storeLocalPayment(_ payment: CustomerPayment, for customerId: String)
}

// MARK: - Payment Error Types
enum PaymentError: LocalizedError {
    case gatewayUnavailable(String)
    case cardDeclined(String)
    case networkUnavailable
    case invalidAmount
    case netSuiteNotConnected
    case customerNotFound
    
    var errorDescription: String? {
        switch self {
        case .gatewayUnavailable(let gateway):
            return "Payment gateway \(gateway) is currently unavailable. Please try again later."
        case .cardDeclined(let reason):
            return "Card declined: \(reason)"
        case .networkUnavailable:
            return "Network connection unavailable. Please check your connection and try again."
        case .invalidAmount:
            return "Please enter a valid payment amount."
        case .netSuiteNotConnected:
            return "NetSuite not connected. Please complete OAuth authentication in Settings."
        case .customerNotFound:
            return "Customer information not found."
        }
    }
}

@MainActor
class PaymentViewModel: ObservableObject {
    // MARK: - Published state
    @Published var payments: [Payment] = []
    @Published var selectedPayment: Payment?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isProcessingPayment = false
    
    // MARK: - Dependencies
    private let stripeManager: StripeManaging
    private let windcaveManager: WindcaveManaging?
    private let netSuiteAPI: NetSuiteAPIProtocol
    private var customerViewModel: CustomerManaging?
    
    // Prevent overlapping loads
    private var loadTask: Task<Void, Never>?
    
    // Currency helpers
    private let zeroDecimalCurrencies: Set<String> = [
        "BIF","CLP","DJF","GNF","JPY","KRW","KMF","MGA","PYG","RWF","UGX","VND","VUV","XAF","XOF","XPF"
    ]
    
    init(
        stripeManager: StripeManaging = StripeManager.shared,
        windcaveManager: WindcaveManaging? = WindcaveManager.shared,
        netSuiteAPI: NetSuiteAPIProtocol = NetSuiteAPI.shared,
        customerViewModel: CustomerManaging? = nil
    ) {
        self.stripeManager = stripeManager
        self.windcaveManager = windcaveManager
        self.netSuiteAPI = netSuiteAPI
        self.customerViewModel = customerViewModel
        loadPayments()
    }
    
    /// Set the CustomerViewModel reference for storing local payments (backward compatibility)
    func setCustomerViewModel(_ viewModel: CustomerViewModel) {
        self.customerViewModel = viewModel
    }
    
    // MARK: - Loading
    
    private func fetchAndSortPayments(using fetcher: @escaping (Date) async throws -> [Payment]) async {
        // Don't cancel the loadTask here - it's the current task!
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // 6 months lookback
            let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            let fetchedPayments = try await fetcher(cutoff)
            payments = fetchedPayments.sorted { ($0.processedDate ?? $0.createdDate) > ($1.processedDate ?? $1.createdDate) }
        } catch {
            if let uerr = error as? URLError {
                if uerr.code == .notConnectedToInternet {
                    errorMessage = PaymentError.networkUnavailable.errorDescription
                } else if uerr.code == .cancelled {
                    // Don't show error for cancellations
                    return
                }
            } else if (error as? NetSuiteError) == .notConfigured {
                errorMessage = PaymentError.netSuiteNotConnected.errorDescription
            } else {
                errorMessage = (error as? PaymentError)?.errorDescription ?? error.localizedDescription
            }
            payments = []
        }
    }
    
    func loadPayments() {
        // Only cancel if there's an existing task that's not completed
        if let existingTask = loadTask, !existingTask.isCancelled {
            existingTask.cancel()
        }
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchAndSortPayments { cutoffDate in
                return try await self.netSuiteAPI.fetchRecentPayments(fromDate: cutoffDate)
            }
        }
    }
    
    func loadPaymentsForCustomer(customerId: String) {
        // Only cancel if there's an existing task that's not completed
        if let existingTask = loadTask, !existingTask.isCancelled {
            existingTask.cancel()
        }
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchAndSortPayments { cutoffDate in
                return try await self.netSuiteAPI.fetchCustomerPaymentsFiltered(customerId: customerId, fromDate: cutoffDate)
            }
        }
    }
    
    // MARK: - Payment Orchestration
    
    func processPayment(
        amount: Decimal,
        currency: String = "USD",
        paymentMethod: PaymentMethodType,
        customerId: String? = nil,
        invoiceId: String? = nil,
        description: String? = nil
    ) async {
        isProcessingPayment = true
        errorMessage = nil
        defer { isProcessingPayment = false }
        
        do {
            guard amount > 0 else { throw PaymentError.invalidAmount }
            
            // Build initial payment record (pending)
            let payment = Payment(
                amount: amount,
                currency: currency.uppercased(),
                status: .processing,
                paymentMethod: paymentMethod,
                customerId: customerId,
                invoiceId: invoiceId,
                description: description
            )
            
            // Process via selected gateway -> returns external intent/txn ID
            let externalId = try await processPaymentViaGateway(payment)
            
            // Mark success
            let successful = Payment(
                id: payment.id,
                amount: payment.amount,
                currency: payment.currency,
                status: .succeeded,
                paymentMethod: payment.paymentMethod,
                customerId: payment.customerId,
                invoiceId: payment.invoiceId,
                description: payment.description,
                stripePaymentIntentId: payment.paymentMethod.usesStripe ? externalId : nil,
                netSuitePaymentId: payment.netSuitePaymentId,
                createdDate: payment.createdDate,
                processedDate: Date(),
                failureReason: nil
            )
            
            payments.append(successful)
            await persistPayment(successful)
        } catch {
            let pe = error as? PaymentError
            errorMessage = pe?.errorDescription ?? error.localizedDescription
        }
    }
    
    private func processPaymentViaGateway(_ payment: Payment) async throws -> String {
        let amountMinor = try toMinorUnits(payment.amount, currency: payment.currency)
        switch payment.paymentMethod {
        case .tapToPay:
            try await stripeManager.setupTapToPay()
            let intent = try await stripeManager.processTapToPayPayment(amount: amountMinor, currency: payment.currency.lowercased())
            return intent.id
        case .manualCard, .applePay, .googlePay:
            let intent = try await stripeManager.createPaymentIntent(amount: amountMinor, currency: payment.currency.lowercased(), customerId: payment.customerId)
            return intent.id
        case .windcaveTapToPay:
            guard let windcaveManager else { throw PaymentError.gatewayUnavailable("Windcave") }
            let session = try await windcaveManager.initializeTapToPay()
            let txn = try await windcaveManager.processTapToPayPayment(amount: amountMinor, currency: payment.currency, sessionId: session.sessionId)
            return txn.transactionId
        case .cash, .check, .bankTransfer:
            return "MANUAL-\(payment.id.prefix(8))"
        }
    }
    
    // Convert Decimal to minor currency units precisely (2dp by default; 0dp for zero-decimal currencies)
    private func toMinorUnits(_ amount: Decimal, currency: String) throws -> Int {
        let code = currency.uppercased()
        let scale = zeroDecimalCurrencies.contains(code) ? 0 : 2
        var value = amount
        var scaled = Decimal()
        NSDecimalMultiplyByPowerOf10(&scaled, &value, Int16(scale), .plain)
        guard scaled >= 0 else { throw PaymentError.invalidAmount }
        return NSDecimalNumber(decimal: scaled).intValue
    }
    
    /// Save to NetSuite (if connected) and store locally for customer context
    func persistPayment(_ payment: Payment) async {
        if netSuiteAPI.isConnected {
            print("Debug: PaymentViewModel - Creating customer payment in NetSuite")
            do {
                let created = try await netSuiteAPI.createPayment(payment)
                if let idx = payments.firstIndex(where: { $0.id == payment.id }) {
                    payments[idx] = created
                }
                print("Debug: PaymentViewModel - NetSuite payment created: \(created.netSuitePaymentId ?? "unknown")")
            } catch {
                print("Debug: PaymentViewModel - Failed to save payment to NetSuite: \(error)")
            }
        } else {
            print("Debug: PaymentViewModel - NetSuite not connected, payment stored locally only")
        }
        await storePaymentLocally(payment)
    }
    
    // MARK: - Convenience wrappers
    
    func processManualCardPayment(
        amount: Decimal,
        currency: String = "USD",
        customerId: String? = nil,
        invoiceId: String? = nil,
        description: String? = nil
    ) async {
        await processPayment(amount: amount, currency: currency, paymentMethod: PaymentMethodType.manualCard, customerId: customerId, invoiceId: invoiceId, description: description)
    }
    
    func processTapToPayPayment(amount: Decimal, currency: String = "USD") async {
        await processPayment(amount: amount, currency: currency, paymentMethod: PaymentMethodType.tapToPay, customerId: nil, invoiceId: nil, description: nil)
    }
    
    // MARK: - Payment Recording
    
    /// Record a payment that was already processed successfully by an external gateway
    func recordSuccessfulPayment(_ payment: Payment) async {
        print("Debug: PaymentViewModel - Recording successful payment: \(payment.id)")
        print("Debug: PaymentViewModel - Payment details: \(payment.amount) \(payment.currency) for customer \(payment.customerId ?? "unknown")")
        
        // Add to payments array
        payments.append(payment)
        
        // Persist to NetSuite and local storage
        await persistPayment(payment)
        
        print("Debug: PaymentViewModel - Successfully recorded payment: \(payment.id)")
        print("Debug: PaymentViewModel - Payment now in array: \(payments.count) total payments")
    }
    
    // MARK: - Queries
    
    func getPaymentsByStatus(_ status: PaymentStatus) -> [Payment] {
        payments.filter { $0.status == status }
    }
    
    func getPaymentsByCustomer(_ customerId: String) -> [Payment] {
        payments.filter { $0.customerId == customerId }
    }
    
    func getPaymentsByDateRange(from: Date, to: Date) -> [Payment] {
        payments.filter { p in (p.processedDate ?? p.createdDate) >= from && (p.processedDate ?? p.createdDate) <= to }
    }
    
    func getTotalPayments(for dateRange: DateInterval? = nil) -> Decimal {
        let paymentsToSum = dateRange != nil ? getPaymentsByDateRange(from: dateRange!.start, to: dateRange!.end) : payments
        return paymentsToSum.filter { $0.status == .succeeded }.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    func getPaymentById(_ id: String) -> Payment? {
        payments.first { $0.id == id }
    }
    
    func refundPayment(_ payment: Payment, amount: Decimal? = nil) async {
        let refundAmount = amount ?? payment.amount
        print("Processing refund for payment \(payment.id): \(refundAmount)")
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[index] = Payment(
                id: payment.id,
                amount: payment.amount,
                currency: payment.currency,
                status: .cancelled,
                paymentMethod: payment.paymentMethod,
                customerId: payment.customerId,
                invoiceId: payment.invoiceId,
                description: payment.description,
                stripePaymentIntentId: payment.stripePaymentIntentId,
                netSuitePaymentId: payment.netSuitePaymentId,
                createdDate: payment.createdDate,
                processedDate: payment.processedDate,
                failureReason: "Refunded: \(refundAmount)"
            )
        }
    }
    
    // MARK: - Local storage plumbing
    private func storePaymentLocally(_ payment: Payment) async {
        guard let customerId = payment.customerId else {
            print("Debug: PaymentViewModel - Payment processed successfully but no customer ID provided - skipping local storage")
            return
        }
        guard let customerViewModel = customerViewModel else {
            print("Debug: PaymentViewModel - CustomerViewModel not available for local storage")
            return
        }
        let local = CustomerPayment(
            id: payment.id,
            paymentNumber: "LOCAL-\(payment.id.prefix(8))",
            date: payment.processedDate ?? payment.createdDate,
            amount: payment.amount,
            status: payment.status.rawValue,
            memo: payment.description,
            paymentMethod: payment.paymentMethod.rawValue
        )
        customerViewModel.storeLocalPayment(local, for: customerId)
        print("Debug: PaymentViewModel - Stored payment locally for customer \(customerId)")
    }
}

// MARK: - Protocol Conformance Extensions

extension StripeManager: StripeManaging {}

extension WindcaveManager: WindcaveManaging {}

extension NetSuiteAPI: NetSuiteAPIProtocol {
    var isConnected: Bool { self.isConfigured() }
}

