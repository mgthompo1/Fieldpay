import Foundation
import Combine

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var payments: [Payment] = []
    @Published var selectedPayment: Payment?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isProcessingPayment = false
    
    private let stripeManager = StripeManager.shared
    private let netSuiteAPI = NetSuiteAPI.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Reference to CustomerViewModel for storing local payments
    private var customerViewModel: CustomerViewModel?
    
    init() {
        loadPayments()
    }
    
    /// Set the CustomerViewModel reference for storing local payments
    func setCustomerViewModel(_ viewModel: CustomerViewModel) {
        self.customerViewModel = viewModel
    }
    
    func loadPayments() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Check if NetSuite is configured and connected
                if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                    // Calculate date 6 months ago for general payment loading too
                    let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                    
                    // Fetch only recent payments (last 6 months) to avoid performance issues
                    let fetchedPayments = try await netSuiteAPI.fetchRecentPayments(fromDate: sixMonthsAgo)
                    payments = fetchedPayments.sorted { $0.createdDate > $1.createdDate }
                    
                    print("Debug: PaymentViewModel - Loaded \(payments.count) recent payments from last 6 months")
                } else {
                    // NetSuite not connected, show error
                    errorMessage = "NetSuite not connected. Please complete OAuth authentication in Settings."
                    payments = []
                }
                isLoading = false
            } catch {
                // If NetSuite fails, show error instead of mock data
                errorMessage = "Failed to load payments: \(error.localizedDescription)"
                payments = []
                isLoading = false
            }
        }
    }
    
    func loadPaymentsForCustomer(customerId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if NetSuite is configured and connected
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                // Calculate date 6 months ago
                let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                
                // Fetch payments ONLY for the specific customer with date filtering
                let fetchedPayments = try await netSuiteAPI.fetchCustomerPaymentsFiltered(
                    customerId: customerId, 
                    fromDate: sixMonthsAgo
                )
                
                // Sort by most recent
                payments = fetchedPayments.sorted { $0.createdDate > $1.createdDate }
                
                print("Debug: PaymentViewModel - Loaded \(payments.count) payments for customer \(customerId) from last 6 months")
            } else {
                // NetSuite not connected, show error
                errorMessage = "NetSuite not connected. Please complete OAuth authentication in Settings."
                payments = []
            }
            isLoading = false
        } catch {
            // If NetSuite fails, show error instead of mock data
            errorMessage = "Failed to load payments for customer: \(error.localizedDescription)"
            payments = []
            isLoading = false
        }
    }
    

    
    func processPayment(amount: Decimal, 
                       currency: String = "USD",
                       paymentMethod: Payment.PaymentMethod,
                       customerId: String? = nil,
                       invoiceId: String? = nil,
                       description: String? = nil) async {
        isProcessingPayment = true
        errorMessage = nil
        
        do {
            // Create payment record
            let payment = Payment(
                amount: amount,
                currency: currency,
                status: .processing,
                paymentMethod: paymentMethod,
                customerId: customerId,
                invoiceId: invoiceId,
                description: description
            )
            
            // Process payment based on method
            switch paymentMethod {
            case .tapToPay:
                try await processTapToPayPaymentMethod(payment)
            case .manualCard:
                try await processManualCardPaymentGateway(payment)
            case .applePay, .googlePay:
                try await processCardPayment(payment)
            case .windcaveTapToPay:
                try await processWindcaveTapToPayPayment(payment)
            case .cash, .check, .bankTransfer:
                try await processManualPayment(payment)
            }
            
            // Update payment status to succeeded after successful processing
            let successfulPayment = Payment(
                id: payment.id,
                amount: payment.amount,
                currency: payment.currency,
                status: .succeeded,
                paymentMethod: payment.paymentMethod,
                customerId: payment.customerId,
                invoiceId: payment.invoiceId,
                description: payment.description,
                stripePaymentIntentId: payment.stripePaymentIntentId,
                netSuitePaymentId: payment.netSuitePaymentId,
                createdDate: payment.createdDate,
                processedDate: Date(),
                failureReason: nil
            )
            
            // Add to local payments array
            payments.append(successfulPayment)
            
            // Save to NetSuite if connected
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                print("Debug: PaymentViewModel - Creating customer payment in NetSuite")
                do {
                    let createdPayment = try await netSuiteAPI.createPayment(successfulPayment)
                    // Update the payment with NetSuite ID
                    if let index = payments.firstIndex(where: { $0.id == successfulPayment.id }) {
                        payments[index] = createdPayment
                    }
                    print("Debug: PaymentViewModel - Successfully created customer payment in NetSuite with ID: \(createdPayment.netSuitePaymentId ?? "unknown")")
                } catch {
                    print("Debug: PaymentViewModel - Failed to save payment to NetSuite: \(error)")
                    // Payment is already stored locally, just log the error
                }
            } else {
                print("Debug: PaymentViewModel - NetSuite not connected, payment stored locally only")
            }
            
            // Always store locally for customer view
            await storePaymentLocally(successfulPayment)
            
            isProcessingPayment = false
            
        } catch {
            errorMessage = error.localizedDescription
            isProcessingPayment = false
        }
    }
    
    private func processTapToPayPaymentMethod(_ payment: Payment) async throws {
        // Setup Tap to Pay if needed
        try await stripeManager.setupTapToPay()
        
        // Convert amount to cents
        let amountInCents = Int((payment.amount as NSDecimalNumber).doubleValue * 100)
        
        // Process payment through Tap to Pay SDK
        let paymentIntent = try await stripeManager.processTapToPayPayment(
            amount: amountInCents,
            currency: payment.currency.lowercased()
        )
        
        print("Tap to Pay payment processed: \(paymentIntent.id)")
    }
    
    private func processCardPayment(_ payment: Payment) async throws {
        // Convert amount to cents for Stripe
        let amountInCents = Int((payment.amount as NSDecimalNumber).doubleValue * 100)
        
        // Create payment intent with Stripe
        let paymentIntent = try await stripeManager.createPaymentIntent(
            amount: amountInCents,
            currency: payment.currency.lowercased(),
            customerId: payment.customerId
        )
        
        // In a real app, you would integrate with Stripe's payment sheet or custom UI
        // For now, we'll simulate a successful payment
        print("Payment intent created: \(paymentIntent.id)")
    }
    
    private func processWindcaveTapToPayPayment(_ payment: Payment) async throws {
        // Initialize Tap to Pay session
        let session = try await WindcaveManager.shared.initializeTapToPay()
        
        // Convert amount to cents for Windcave (typically in NZD)
        let amountInCents = Int((payment.amount as NSDecimalNumber).doubleValue * 100)
        
        // Process the payment through Windcave Tap to Pay
        let transaction = try await WindcaveManager.shared.processTapToPayPayment(
            amount: amountInCents,
            currency: payment.currency,
            sessionId: session.sessionId
        )
        
        print("Windcave Tap to Pay transaction completed: \(transaction.transactionId)")
    }
    
    private func processManualPayment(_ payment: Payment) async throws {
        // For manual payments (cash, check, bank transfer), we just record them
        // No external processing needed
        print("Manual payment recorded: \(payment.amount) \(payment.currency)")
    }
    
    func processManualCardPayment(amount: Decimal, 
                                 currency: String = "USD",
                                 customerId: String? = nil,
                                 invoiceId: String? = nil,
                                 description: String? = nil) async {
        isProcessingPayment = true
        errorMessage = nil
        
        do {
            // Create payment record
            let payment = Payment(
                amount: amount,
                currency: currency,
                status: .processing,
                paymentMethod: .manualCard,
                customerId: customerId,
                invoiceId: invoiceId,
                description: description
            )
            
            // Process manual card payment through payment gateway
            try await processManualCardPaymentGateway(payment)
            
            // Update payment status to succeeded after successful processing
            let successfulPayment = Payment(
                id: payment.id,
                amount: payment.amount,
                currency: payment.currency,
                status: .succeeded,
                paymentMethod: payment.paymentMethod,
                customerId: payment.customerId,
                invoiceId: payment.invoiceId,
                description: payment.description,
                stripePaymentIntentId: payment.stripePaymentIntentId,
                netSuitePaymentId: payment.netSuitePaymentId,
                createdDate: payment.createdDate,
                processedDate: Date(),
                failureReason: nil
            )
            
            // Add to local payments array
            payments.append(successfulPayment)
            
            // Save to NetSuite if connected
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                print("Debug: PaymentViewModel - Creating customer payment in NetSuite")
                do {
                    let createdPayment = try await netSuiteAPI.createPayment(successfulPayment)
                    // Update the payment with NetSuite ID
                    if let index = payments.firstIndex(where: { $0.id == successfulPayment.id }) {
                        payments[index] = createdPayment
                    }
                    print("Debug: PaymentViewModel - Successfully created customer payment in NetSuite with ID: \(createdPayment.netSuitePaymentId ?? "unknown")")
                } catch {
                    print("Debug: PaymentViewModel - Failed to save payment to NetSuite: \(error)")
                    // Payment is already stored locally, just log the error
                }
            } else {
                print("Debug: PaymentViewModel - NetSuite not connected, payment stored locally only")
            }
            
            // Always store locally for customer view
            await storePaymentLocally(successfulPayment)
            
            isProcessingPayment = false
            
        } catch {
            errorMessage = error.localizedDescription
            isProcessingPayment = false
        }
    }
    
    private func processManualCardPaymentGateway(_ payment: Payment) async throws {
        // Convert amount to cents for payment gateway
        let amountInCents = Int((payment.amount as NSDecimalNumber).doubleValue * 100)
        
        // Process manual card entry through the activated payment gateway
        // This would typically involve presenting a card entry form
        // and processing through Stripe, Windcave, or other gateway
        let paymentIntent = try await stripeManager.createPaymentIntent(
            amount: amountInCents,
            currency: payment.currency.lowercased(),
            customerId: payment.customerId
        )
        
        print("Manual card payment processed: \(paymentIntent.id)")
    }
    
    func processTapToPayPayment(amount: Decimal, currency: String = "USD") async {
        isProcessingPayment = true
        errorMessage = nil
        
        do {
            // Setup Tap to Pay if needed
            try await stripeManager.setupTapToPay()
            
            // Convert amount to cents
            let amountInCents = Int((amount as NSDecimalNumber).doubleValue * 100)
            
            // Process payment
            let paymentIntent = try await stripeManager.processTapToPayPayment(
                amount: amountInCents,
                currency: currency.lowercased()
            )
            
            // Create payment record
            let payment = Payment(
                amount: amount,
                currency: currency,
                status: .succeeded,
                paymentMethod: .tapToPay,
                stripePaymentIntentId: paymentIntent.id
            )
            
            // Add to local payments array
            payments.append(payment)
            
            // Save to NetSuite if connected
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                print("Debug: PaymentViewModel - Creating customer payment in NetSuite")
                do {
                    let createdPayment = try await netSuiteAPI.createPayment(payment)
                    // Update the payment with NetSuite ID
                    if let index = payments.firstIndex(where: { $0.id == payment.id }) {
                        payments[index] = createdPayment
                    }
                    print("Debug: PaymentViewModel - Successfully created customer payment in NetSuite with ID: \(createdPayment.netSuitePaymentId ?? "unknown")")
                } catch {
                    print("Debug: PaymentViewModel - Failed to save payment to NetSuite: \(error)")
                    // Payment is already stored locally, just log the error
                }
            } else {
                print("Debug: PaymentViewModel - NetSuite not connected, payment stored locally only")
            }
            
            // Always store locally for customer view
            await storePaymentLocally(payment)
            
            isProcessingPayment = false
            
        } catch {
            errorMessage = error.localizedDescription
            isProcessingPayment = false
        }
    }
    
    func getPaymentsByStatus(_ status: Payment.PaymentStatus) -> [Payment] {
        return payments.filter { $0.status == status }
    }
    
    func getPaymentsByCustomer(_ customerId: String) -> [Payment] {
        return payments.filter { $0.customerId == customerId }
    }
    
    func getPaymentsByDateRange(from: Date, to: Date) -> [Payment] {
        return payments.filter { payment in
            payment.createdDate >= from && payment.createdDate <= to
        }
    }
    
    func getTotalPayments(for dateRange: DateInterval? = nil) -> Decimal {
        let paymentsToSum = dateRange != nil ? 
            getPaymentsByDateRange(from: dateRange!.start, to: dateRange!.end) :
            payments
        
        return paymentsToSum
            .filter { $0.status == .succeeded }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getPaymentById(_ id: String) -> Payment? {
        return payments.first { $0.id == id }
    }
    
    func refundPayment(_ payment: Payment, amount: Decimal? = nil) async {
        // In a real app, you would process the refund through Stripe
        // and update the payment record
        let refundAmount = amount ?? payment.amount
        
        print("Processing refund for payment \(payment.id): \(refundAmount)")
        
        // Update payment status
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            // In a real app, you would create a refund record
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
    
    /// Store payment locally in CustomerViewModel
    private func storePaymentLocally(_ payment: Payment) async {
        guard let customerId = payment.customerId else {
            print("Debug: PaymentViewModel - Cannot store payment locally: no customer ID")
            return
        }
        
        // Convert Payment to CustomerPayment for local storage
        let customerPayment = CustomerPayment(
            id: payment.id,
            paymentNumber: "LOCAL-\(payment.id.prefix(8))",
            date: payment.processedDate ?? payment.createdDate,
            amount: payment.amount,
            status: payment.status.rawValue,
            memo: payment.description,
            paymentMethod: payment.paymentMethod.rawValue
        )
        
        // Store in CustomerViewModel
        customerViewModel?.storeLocalPayment(customerPayment, for: customerId)
        print("Debug: PaymentViewModel - Stored payment locally for customer \(customerId)")
    }
} 