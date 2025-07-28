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
    
    init() {
        loadPayments()
    }
    
    func loadPayments() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Check if NetSuite is configured and connected
                if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                    let fetchedPayments = try await netSuiteAPI.fetchPayments()
                    payments = fetchedPayments
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
            
            // Save to NetSuite if connected
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                let createdPayment = try await netSuiteAPI.createPayment(payment)
                payments.append(createdPayment)
            } else {
                // NetSuite not connected, show error
                errorMessage = "NetSuite not connected. Payment cannot be saved. Please complete OAuth authentication in Settings."
                return
            }
            
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
            
            // Save to NetSuite if connected, otherwise save locally
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                let createdPayment = try await netSuiteAPI.createPayment(payment)
                payments.append(createdPayment)
            } else {
                // Save locally for standalone mode
                let localPayment = Payment(
                    id: UUID().uuidString,
                    amount: payment.amount,
                    currency: payment.currency,
                    status: payment.status,
                    paymentMethod: payment.paymentMethod,
                    customerId: payment.customerId,
                    invoiceId: payment.invoiceId,
                    description: payment.description,
                    stripePaymentIntentId: payment.stripePaymentIntentId,
                    netSuitePaymentId: payment.netSuitePaymentId,
                    createdDate: Date(),
                    processedDate: payment.processedDate,
                    failureReason: payment.failureReason
                )
                payments.append(localPayment)
            }
            
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
            
            // Save to NetSuite if connected
            if let accessToken = netSuiteAPI.accessToken, !accessToken.isEmpty {
                let createdPayment = try await netSuiteAPI.createPayment(payment)
                payments.append(createdPayment)
            } else {
                // NetSuite not connected, show error
                errorMessage = "NetSuite not connected. Payment cannot be saved. Please complete OAuth authentication in Settings."
                return
            }
            
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
} 