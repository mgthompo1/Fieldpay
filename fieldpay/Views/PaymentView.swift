import SwiftUI

struct PaymentView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var showingPaymentSheet = false
    @State private var showingStripePayment = false
    @State private var showingWindcavePayment = false
    @State private var selectedPaymentMethod: Payment.PaymentMethod = .tapToPay
    @State private var amount: String = ""
    @State private var selectedCustomer: Customer?
    @State private var invoiceId: String = ""
    @State private var description: String = ""
    @State private var showingAmountInput = false
    @State private var showingCustomerPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    PaymentHeaderView()
                    QuickPaymentCardView(
                        amount: $amount,
                        selectedCustomer: $selectedCustomer,
                        selectedPaymentMethod: $selectedPaymentMethod,
                        showingCustomerPicker: $showingCustomerPicker,
                        onProcessPayment: processPayment
                    )
                    RecentPaymentsSectionView(viewModel: viewModel)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPaymentSheet) {
                if let amountValue = Decimal(string: amount) {
                    PaymentTapToPayView(viewModel: viewModel, amount: amountValue)
                }
            }
            .sheet(isPresented: $showingStripePayment) {
                if let amountValue = Decimal(string: amount), let customer = selectedCustomer {
                    StripeQRPaymentView(
                        amount: amountValue,
                        customer: customer,
                        onPaymentSuccess: { payment in
                            // Handle successful payment
                            Task {
                                await viewModel.processPayment(
                                    amount: payment.amount,
                                    paymentMethod: payment.paymentMethod,
                                    customerId: payment.customerId,
                                    invoiceId: payment.invoiceId,
                                    description: payment.description
                                )
                            }
                        },
                        onPaymentFailure: { error in
                            // Handle payment failure
                            print("Stripe payment failed: \(error)")
                        }
                    )
                    .environmentObject(settingsViewModel)
                } else {
                    Text("Error: Invalid amount or customer")
                }
            }
            .sheet(isPresented: $showingWindcavePayment) {
                if let amountValue = Decimal(string: amount), let customer = selectedCustomer {
                    WindcaveQRPaymentView(
                        amount: amountValue,
                        customer: customer,
                        onPaymentSuccess: { payment in
                            // Handle successful payment
                            Task {
                                await viewModel.processPayment(
                                    amount: payment.amount,
                                    paymentMethod: payment.paymentMethod,
                                    customerId: payment.customerId,
                                    invoiceId: payment.invoiceId,
                                    description: payment.description
                                )
                            }
                        },
                        onPaymentFailure: { error in
                            // Handle payment failure
                            print("Windcave payment failed: \(error)")
                        }
                    )
                    .environmentObject(settingsViewModel)
                } else {
                    Text("Error: Invalid amount or customer")
                }
            }
            .sheet(isPresented: $showingCustomerPicker) {
                CustomerPickerView(
                    customers: customerViewModel.customers,
                    selectedCustomer: $selectedCustomer,
                    isLoading: customerViewModel.isLoading,
                    onLoadMore: {
                        Task {
                            await customerViewModel.loadNextPage()
                        }
                    }
                )
            }
            .onChange(of: selectedCustomer) { _ in
                // Load payments for selected customer
                if let customer = selectedCustomer {
                    Task {
                        await viewModel.loadPaymentsForCustomer(customerId: customer.id)
                    }
                }
            }
            .onAppear {
                // Connect PaymentViewModel to CustomerViewModel for local payment storage
                viewModel.setCustomerViewModel(customerViewModel)
            }
        }
    }
    
    private func processPayment() {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { 
            print("Debug: PaymentView - Invalid amount: \(amount)")
            return 
        }
        guard let customer = selectedCustomer else { 
            print("Debug: PaymentView - No customer selected")
            return 
        }
        
        print("Debug: PaymentView - Processing payment for method: \(selectedPaymentMethod.displayName)")
        
        switch selectedPaymentMethod {
        case .tapToPay:
            // Launch Tap to Pay SDK
            print("Debug: PaymentView - Showing Tap to Pay sheet")
            showingPaymentSheet = true
        case .manualCard:
            // Check which payment system is configured and route accordingly
            switch settingsViewModel.selectedPaymentSystem {
            case .stripe:
                print("Debug: PaymentView - Showing Stripe QR payment")
                showingStripePayment = true
            case .windcave:
                print("Debug: PaymentView - Showing Windcave QR payment")
                showingWindcavePayment = true
            case .none:
                print("Debug: PaymentView - No payment system configured")
                // You could show an alert here asking user to configure payment system
            }
        default:
            // Handle other payment methods
            print("Debug: PaymentView - Processing other payment method")
            Task {
                await viewModel.processPayment(
                    amount: amountValue,
                    paymentMethod: selectedPaymentMethod,
                    customerId: customer.id,
                    invoiceId: invoiceId.isEmpty ? nil : invoiceId,
                    description: description.isEmpty ? nil : description
                )
            }
        }
    }
}

// MARK: - Payment Header View
struct PaymentHeaderView: View {
    var body: some View {
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
    }
}

// MARK: - Quick Payment Card View
struct QuickPaymentCardView: View {
    @Binding var amount: String
    @Binding var selectedCustomer: Customer?
    @Binding var selectedPaymentMethod: Payment.PaymentMethod
    @Binding var showingCustomerPicker: Bool
    let onProcessPayment: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            QuickPaymentHeaderView()
            CustomerSelectionView(
                selectedCustomer: $selectedCustomer,
                showingCustomerPicker: $showingCustomerPicker
            )
            AmountInputView(amount: $amount)
            PaymentMethodSelectionView(selectedPaymentMethod: $selectedPaymentMethod)
            ProcessPaymentButtonView(
                amount: amount,
                selectedCustomer: selectedCustomer,
                onProcessPayment: onProcessPayment
            )
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

// MARK: - Quick Payment Header
struct QuickPaymentHeaderView: View {
    var body: some View {
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
    }
}

// MARK: - Customer Selection View
struct CustomerSelectionView: View {
    @Binding var selectedCustomer: Customer?
    @Binding var showingCustomerPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showingCustomerPicker = true
            }) {
                HStack {
                    if let customer = selectedCustomer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if let companyName = customer.companyName {
                                Text(companyName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Select Customer")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Amount Input View
struct AmountInputView: View {
    @Binding var amount: String
    
    var body: some View {
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
    }
}

// MARK: - Payment Method Selection View
struct PaymentMethodSelectionView: View {
    @Binding var selectedPaymentMethod: Payment.PaymentMethod
    
    var body: some View {
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
    }
}

// MARK: - Process Payment Button View
struct ProcessPaymentButtonView: View {
    let amount: String
    let selectedCustomer: Customer?
    let onProcessPayment: () -> Void
    
    var body: some View {
        Button(action: onProcessPayment) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                
                Text("Process Payment")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(amount.isEmpty || selectedCustomer == nil)
        .opacity((amount.isEmpty || selectedCustomer == nil) ? 0.6 : 1.0)
    }
}

// MARK: - Recent Payments Section View
struct RecentPaymentsSectionView: View {
    @ObservedObject var viewModel: PaymentViewModel
    
    var body: some View {
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
}

// MARK: - Modern Payment Row
struct ModernPaymentRow: View {
    let payment: Payment
    
    var body: some View {
        HStack(spacing: 16) {
            // Payment Icon
            Circle()
                .fill(
                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: payment.paymentMethod.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                )
            
            // Payment Details
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.paymentMethod.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(payment.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount and Status
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

// MARK: - Modern Payment Method Button
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

// MARK: - Customer Picker View
struct CustomerPickerView: View {
    let customers: [Customer]
    @Binding var selectedCustomer: Customer?
    let isLoading: Bool
    let onLoadMore: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customers
        } else {
            return customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.email?.localizedCaseInsensitiveContains(searchText) == true ||
                customer.companyName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search customers...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Customer List
                if isLoading && customers.isEmpty {
                    ModernLoadingView(message: "Loading customers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredCustomers.isEmpty {
                    ModernEmptyStateView(
                        icon: "person.2",
                        title: searchText.isEmpty ? "No Customers" : "No Results Found",
                        subtitle: searchText.isEmpty ? "No customers available" : "Try adjusting your search"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredCustomers) { customer in
                                Button(action: {
                                    selectedCustomer = customer
                                    dismiss()
                                }) {
                                    HStack(spacing: 16) {
                                        // Avatar
                                        Circle()
                                            .fill(
                                                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Text(customer.name.prefix(1).uppercased())
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                        
                                        // Customer Info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(customer.name)
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            
                                            if let companyName = customer.companyName {
                                                Text(companyName)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            if let email = customer.email {
                                                Text(email)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Checkmark if selected
                                        if selectedCustomer?.id == customer.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Load more indicator
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more customers...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .onAppear {
                                    onLoadMore()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Payment Tap to Pay View
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