import SwiftUI

struct PaymentView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @State private var showingPaymentSheet = false
    @State private var selectedPaymentMethod: Payment.PaymentMethod = .tapToPay
    @State private var amount: String = ""
    @State private var customerId: String = ""
    @State private var invoiceId: String = ""
    @State private var description: String = ""
    @State private var showingAmountInput = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payments")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Process payments and view transaction history")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    // Quick Payment Card
                    VStack(spacing: 20) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quick Payment")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Process a new payment")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Amount Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Amount")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 16) {
                                Text("$")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                TextField("0.00", text: $amount)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // Payment Method Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Payment Method")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(Payment.PaymentMethod.quickPaymentMethods, id: \.self) { method in
                                    ModernPaymentMethodButton(
                                        method: method,
                                        isSelected: selectedPaymentMethod == method
                                    ) {
                                        selectedPaymentMethod = method
                                    }
                                }
                            }
                        }
                        
                        // Process Payment Button
                        Button(action: {
                            guard let amountValue = Decimal(string: amount), amountValue > 0 else { return }
                            
                            switch selectedPaymentMethod {
                            case .tapToPay:
                                // Launch Tap to Pay SDK
                                showingPaymentSheet = true
                            case .manualCard:
                                // Launch manual card entry
                                Task {
                                    await viewModel.processManualCardPayment(
                                        amount: amountValue,
                                        customerId: customerId.isEmpty ? nil : customerId,
                                        invoiceId: invoiceId.isEmpty ? nil : invoiceId,
                                        description: description.isEmpty ? nil : description
                                    )
                                }
                            default:
                                // Handle other payment methods
                                Task {
                                    await viewModel.processPayment(
                                        amount: amountValue,
                                        paymentMethod: selectedPaymentMethod,
                                        customerId: customerId.isEmpty ? nil : customerId,
                                        invoiceId: invoiceId.isEmpty ? nil : invoiceId,
                                        description: description.isEmpty ? nil : description
                                    )
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isProcessingPayment {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "creditcard.fill")
                                        .font(.title3)
                                }
                                
                                Text(viewModel.isProcessingPayment ? "Processing..." : "Process Payment")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(amount.isEmpty || viewModel.isProcessingPayment)
                        .opacity(amount.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 20)
                    
                    // Recent Payments Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Payments")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("View All") {
                                // Navigate to full payments list
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        
                        if viewModel.isLoading {
                            ModernLoadingView(message: "Loading payments...")
                        } else if let errorMessage = viewModel.errorMessage {
                            ModernErrorView(
                                message: errorMessage,
                                retryAction: { viewModel.loadPayments() }
                            )
                        } else if viewModel.payments.isEmpty {
                            ModernEmptyStateView(
                                icon: "creditcard",
                                title: "No Payments Yet",
                                subtitle: "Your payment history will appear here"
                            )
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(Array(viewModel.payments.prefix(5)), id: \.id) { payment in
                                    ModernPaymentRow(payment: payment)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.loadPayments() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingPaymentSheet) {
                if let amountValue = Decimal(string: amount) {
                                            PaymentTapToPayView(viewModel: viewModel, amount: amountValue)
                }
            }
        }
    }
}

// MARK: - Modern Components

struct ModernPaymentMethodButton: View {
    let method: Payment.PaymentMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ? 
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(method.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernPaymentRow: View {
    let payment: Payment
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: payment.paymentMethod.icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.paymentMethod.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(payment.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", (payment.amount as NSDecimalNumber).doubleValue))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(payment.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        switch payment.status {
        case .succeeded: return .green
        case .pending: return .orange
        case .processing: return .blue
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}



struct PaymentTapToPayView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @Environment(\.dismiss) private var dismiss
    
    let amount: Decimal
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Tap to Pay Icon
                VStack(spacing: 16) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Tap to Pay")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Hold customer's card near the top of your iPhone")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("$")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.2f", (amount as NSDecimalNumber).doubleValue))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal)
                
                // Process Button
                Button(action: {
                    isProcessing = true
                    
                    Task {
                        await viewModel.processTapToPayPayment(amount: amount)
                        isProcessing = false
                        dismiss()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "creditcard.fill")
                        }
                        Text(isProcessing ? "Processing..." : "Start Payment")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Tap to Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 