import SwiftUI

struct StripePaymentView: View {
    let amount: Decimal
    let customer: Customer
    let onPaymentSuccess: (Payment) -> Void
    let onPaymentFailure: (Error) -> Void
    
    @StateObject private var stripeManager = StripeManager.shared
    @State private var cardNumber = ""
    @State private var expiryMonth = ""
    @State private var expiryYear = ""
    @State private var cvv = ""
    @State private var cardholderName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Payment")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder for balance
                Text("")
                    .frame(width: 60)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Payment Summary
                    VStack(spacing: 8) {
                        Text("Payment Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Amount: \(formatCurrency(amount))")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Customer: \(customer.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Card Entry Form
                    VStack(spacing: 16) {
                        // Card Number
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Number")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("1234 5678 9012 3456", text: $cardNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .onChange(of: cardNumber) { _, newValue in
                                    cardNumber = formatCardNumber(newValue)
                                }
                        }
                        
                        // Expiry and CVV
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Expiry Date")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    TextField("MM", text: $expiryMonth)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .onChange(of: expiryMonth) { _, newValue in
                                            expiryMonth = formatExpiryMonth(newValue)
                                        }
                                    
                                    Text("/")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("YY", text: $expiryYear)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .onChange(of: expiryYear) { _, newValue in
                                            expiryYear = formatExpiryYear(newValue)
                                        }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CVV")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("123", text: $cvv)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: cvv) { _, newValue in
                                        cvv = String(newValue.prefix(4))
                                    }
                            }
                        }
                        
                        // Cardholder Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cardholder Name")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("John Doe", text: $cardholderName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textInputAutocapitalization(.words)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Pay Button
                    Button(action: processPayment) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "creditcard.fill")
                            }
                            Text(isLoading ? "Processing..." : "Pay \(formatCurrency(amount))")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("Debug: StripePaymentView - View appeared")
            print("Debug: StripePaymentView - Amount: \(amount)")
            print("Debug: StripePaymentView - Customer: \(customer.name)")
        }
    }
    
    private var isFormValid: Bool {
        !cardNumber.replacingOccurrences(of: " ", with: "").isEmpty &&
        !expiryMonth.isEmpty &&
        !expiryYear.isEmpty &&
        !cvv.isEmpty &&
        !cardholderName.isEmpty &&
        cardNumber.replacingOccurrences(of: " ", with: "").count >= 13 &&
        cvv.count >= 3
    }
    
    private func formatCardNumber(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: " ", with: "")
        let grouped = cleaned.enumerated().map { index, char in
            if index > 0 && index % 4 == 0 {
                return " \(char)"
            }
            return String(char)
        }.joined()
        return String(grouped.prefix(19)) // Max 16 digits + 3 spaces
    }
    
    private func formatExpiryMonth(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let month = Int(cleaned) ?? 0
        if month > 12 {
            return "12"
        }
        return String(cleaned.prefix(2))
    }
    
    private func formatExpiryYear(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return String(cleaned.prefix(2))
    }
    
    private func processPayment() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Convert amount to cents for Stripe
                let amountInCents = Int((amount as NSDecimalNumber).multiplying(by: NSDecimalNumber(value: 100)).intValue)
                
                // Create or get Stripe customer
                let stripeCustomer = try await createOrGetStripeCustomer()
                
                // Create payment intent
                let paymentIntent = try await stripeManager.createPaymentIntent(
                    amount: amountInCents,
                    currency: "usd",
                    customerId: stripeCustomer.id
                )
                
                // Create payment method from card details
                let cardToken = try await createCardToken()
                let paymentMethod = try await stripeManager.createPaymentMethod(
                    type: "card",
                    cardToken: cardToken
                )
                
                // Attach payment method to customer
                try await stripeManager.attachPaymentMethodToCustomer(
                    paymentMethodId: paymentMethod.id,
                    customerId: stripeCustomer.id
                )
                
                // Confirm the payment intent with the payment method
                let confirmedPaymentIntent = try await stripeManager.confirmPaymentIntent(
                    paymentIntentId: paymentIntent.id,
                    paymentMethodId: paymentMethod.id
                )
                
                // Check if payment was successful
                guard confirmedPaymentIntent.status == "succeeded" else {
                    throw StripeError.paymentFailed
                }
                
                await MainActor.run {
                    // Create successful payment record
                    let payment = Payment(
                        id: UUID().uuidString,
                        amount: amount,
                        currency: "USD",
                        status: .succeeded,
                        paymentMethod: .manualCard,
                        customerId: customer.id,
                        invoiceId: nil,
                        description: "Manual card payment via Stripe",
                        stripePaymentIntentId: confirmedPaymentIntent.id
                    )
                    onPaymentSuccess(payment)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func createCardToken() async throws -> String {
        // Create a card token from the form data
        let cleanedCardNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        let expiryMonth = Int(self.expiryMonth) ?? 0
        let expiryYear = Int("20" + self.expiryYear) ?? 0
        
        return try await stripeManager.createCardToken(
            cardNumber: cleanedCardNumber,
            expMonth: expiryMonth,
            expYear: expiryYear,
            cvc: cvv
        )
    }
    
    private func createOrGetStripeCustomer() async throws -> StripeCustomer {
        // For now, create a new customer each time
        // In a real app, you'd want to store and reuse customer IDs
        return try await stripeManager.createCustomer(
            email: customer.email ?? "customer@example.com",
            name: customer.name
        )
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Preview
struct StripePaymentView_Previews: PreviewProvider {
    static var previews: some View {
        StripePaymentView(
            amount: 99.99,
            customer: Customer(
                id: "123",
                name: "John Doe",
                email: "john@example.com",
                phone: nil,
                address: nil,
                companyName: nil,
                createdDate: Date(),
                lastModifiedDate: Date()
            ),
            onPaymentSuccess: { _ in },
            onPaymentFailure: { _ in }
        )
    }
} 