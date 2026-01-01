import SwiftUI

struct PaymentView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var showingPaymentSheet = false
    @State private var showingStripePayment = false
    @State private var showingWindcavePayment = false
    @State private var selectedPaymentMethod: PaymentMethodType = .tapToPay
    @State private var amount: String = ""
    @State private var selectedCustomer: Customer?
    @State private var invoiceId: String = ""
    @State private var description: String = ""
    @State private var showingAmountInput = false
    @State private var showingCustomerPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                FieldPayBackground()
                
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
                        RecentPaymentsSectionView(viewModel: viewModel, customerViewModel: customerViewModel, selectedCustomer: $selectedCustomer)
                    }
                    .padding(.vertical, 24)
                }
                .navigationBarTitleDisplayMode(.inline)
            }
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
                            // Handle successful payment - record it, don't process again
                            Task {
                                await viewModel.recordSuccessfulPayment(payment)
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
                            // Handle successful payment - record it, don't process again
                            Task {
                                await viewModel.recordSuccessfulPayment(payment)
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
            .onChange(of: selectedCustomer) {
                // Customer payments will be loaded automatically by the RecentPaymentsSectionView
                // when it detects a selected customer
            }
            .onAppear {
                // Connect PaymentViewModel to CustomerViewModel for local payment storage
                viewModel.setCustomerViewModel(customerViewModel)
                
                // Don't load all payments - we'll load customer-specific payments when a customer is selected
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
                .font(FieldPayFont.display)
                .foregroundColor(FieldPayTheme.ink)
            
            Text("Process payments and view transaction history")
                .font(FieldPayFont.callout)
                .foregroundColor(FieldPayTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - Quick Payment Card View
struct QuickPaymentCardView: View {
    @Binding var amount: String
    @Binding var selectedCustomer: Customer?
    @Binding var selectedPaymentMethod: PaymentMethodType
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
        .fieldPayCard(padding: 22, cornerRadius: 22)
        .padding(.horizontal, 20)
    }
}

// MARK: - Quick Payment Header
struct QuickPaymentHeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "creditcard.fill")
                .font(FieldPayFont.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(FieldPayTheme.successGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Payment")
                    .font(FieldPayFont.title)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text("Process a new payment")
                    .font(FieldPayFont.callout)
                    .foregroundColor(FieldPayTheme.inkMuted)
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
                .font(FieldPayFont.headline)
            
            Button(action: {
                showingCustomerPicker = true
            }) {
                HStack {
                    if let customer = selectedCustomer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.name)
                                .font(FieldPayFont.headline)
                                .foregroundColor(FieldPayTheme.ink)
                            
                            if let companyName = customer.companyName {
                                Text(companyName)
                                    .font(FieldPayFont.callout)
                                    .foregroundColor(FieldPayTheme.inkMuted)
                            }
                        }
                    } else {
                        Text("Select Customer")
                            .font(FieldPayFont.headline)
                            .foregroundColor(FieldPayTheme.inkMuted)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FieldPayFont.caption)
                        .foregroundColor(FieldPayTheme.inkMuted)
                }
                .fieldPaySoftCard(padding: 16, cornerRadius: 16)
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
                .font(FieldPayFont.headline)
            
            HStack(spacing: 16) {
                Text("$")
                    .font(FieldPayFont.title)
                    .foregroundColor(FieldPayTheme.ink)
                
                TextField("0.00", text: $amount)
                    .font(FieldPayFont.title)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .fieldPaySoftCard(padding: 16, cornerRadius: 16)
        }
    }
}

// MARK: - Payment Method Selection View
struct PaymentMethodSelectionView: View {
    @Binding var selectedPaymentMethod: PaymentMethodType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Method")
                .font(FieldPayFont.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PaymentMethodType.quickPaymentMethods, id: \.self) { method in
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
                    .font(FieldPayFont.headline)
                
                Text("Process Payment")
                    .font(FieldPayFont.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                FieldPayTheme.accentGradient
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: FieldPayTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(amount.isEmpty || selectedCustomer == nil)
        .opacity((amount.isEmpty || selectedCustomer == nil) ? 0.6 : 1.0)
    }
}

// MARK: - Recent Payments Section View
struct RecentPaymentsSectionView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @Binding var selectedCustomer: Customer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Payments")
                    .font(FieldPayFont.title2)
                    .foregroundColor(FieldPayTheme.ink)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full payments list
                }
                .font(FieldPayFont.callout)
                .foregroundColor(FieldPayTheme.accent)
            }
            .padding(.horizontal, 20)
            
            if selectedCustomer == nil {
                // No customer selected - show message
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(FieldPayTheme.inkMuted)
                    
                    Text("Select a Customer")
                        .font(FieldPayFont.headline)
                        .foregroundColor(FieldPayTheme.ink)
                    
                    Text("Choose a customer to view their recent payments")
                        .font(FieldPayFont.callout)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
            } else if customerViewModel.isLoadingPayments {
                ModernLoadingView(message: "Loading payments...")
            } else if let errorMessage = customerViewModel.paymentsError {
                ModernErrorView(
                    message: errorMessage,
                    retryAction: {
                        if let customer = selectedCustomer {
                            Task {
                                await customerViewModel.loadCustomerPayments(customerId: customer.id)
                            }
                        }
                    }
                )
            } else if customerViewModel.customerPayments.isEmpty {
                ModernEmptyStateView(
                    icon: "creditcard",
                    title: "No Payments Found",
                    subtitle: "This customer has no payment history yet"
                )
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(customerViewModel.customerPayments.prefix(5)), id: \.id) { payment in
                        ModernCustomerPaymentRow(payment: payment)
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
                .fill(FieldPayTheme.successGradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: payment.paymentMethod.icon)
                        .font(FieldPayFont.headline)
                        .foregroundColor(.white)
                )
            
            // Payment Details
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.paymentMethod.displayName)
                    .font(FieldPayFont.headline)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(payment.createdDate, style: .date)
                    .font(FieldPayFont.caption)
                    .foregroundColor(FieldPayTheme.inkMuted)
            }
            
            Spacer()
            
            // Amount and Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", (payment.amount as NSDecimalNumber).doubleValue))
                    .font(FieldPayFont.headline)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(payment.status.displayName)
                    .font(FieldPayFont.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .fieldPaySoftCard(padding: 16, cornerRadius: 16)
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
    let method: PaymentMethodType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(FieldPayFont.title2)
                    .foregroundColor(isSelected ? .white : FieldPayTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ? 
                        FieldPayTheme.accentGradient :
                        LinearGradient(colors: [FieldPayTheme.surfaceSoft, FieldPayTheme.surfaceSoft], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(method.displayName)
                    .font(FieldPayFont.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? FieldPayTheme.accent : FieldPayTheme.ink)
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
                    .foregroundColor(FieldPayTheme.inkMuted)
                
                TextField("Search customers...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(FieldPayTheme.inkMuted)
                        }
                    }
                }
                .fieldPaySoftCard(padding: 14, cornerRadius: 16)
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
                                            .fill(FieldPayTheme.accentGradient)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Text(customer.name.prefix(1).uppercased())
                                                    .font(FieldPayFont.headline)
                                                    .foregroundColor(.white)
                                            )
                                        
                                        // Customer Info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(customer.name)
                                                .font(FieldPayFont.headline)
                                                .foregroundColor(FieldPayTheme.ink)
                                            
                                            if let companyName = customer.companyName {
                                                Text(companyName)
                                                    .font(FieldPayFont.callout)
                                                    .foregroundColor(FieldPayTheme.inkMuted)
                                            }
                                            
                                            if let email = customer.email {
                                                Text(email)
                                                    .font(FieldPayFont.caption)
                                                    .foregroundColor(FieldPayTheme.inkMuted)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Checkmark if selected
                                        if selectedCustomer?.id == customer.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(FieldPayTheme.accent)
                                                .font(.title2)
                                        }
                                    }
                                    .fieldPaySoftCard(padding: 16, cornerRadius: 16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Load more indicator
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more customers...")
                                        .font(FieldPayFont.caption)
                                        .foregroundColor(FieldPayTheme.inkMuted)
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
                        .foregroundColor(FieldPayTheme.accent)
                    
                    Text("Tap to Pay")
                        .font(FieldPayFont.title)
                    
                    Text("Hold customer's card near the top of your iPhone")
                        .font(FieldPayFont.callout)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .multilineTextAlignment(.center)
                }
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(FieldPayFont.headline)
                    
                    HStack {
                        Text("$")
                            .font(FieldPayFont.title)
                            .foregroundColor(FieldPayTheme.inkMuted)
                        
                        Text(String(format: "%.2f", (amount as NSDecimalNumber).doubleValue))
                            .font(FieldPayFont.title)
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
                            .font(FieldPayFont.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FieldPayTheme.successGradient)
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

// MARK: - Modern Customer Payment Row
struct ModernCustomerPaymentRow: View {
    let payment: CustomerPayment
    
    var body: some View {
        HStack(spacing: 16) {
            // Payment Icon
            Circle()
                .fill(FieldPayTheme.successGradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "creditcard.fill")
                        .font(FieldPayFont.headline)
                        .foregroundColor(.white)
                )
            
            // Payment Details
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.paymentNumber)
                    .font(FieldPayFont.headline)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(payment.date, style: .date)
                    .font(FieldPayFont.caption)
                    .foregroundColor(FieldPayTheme.inkMuted)
                
                if let memo = payment.memo, !memo.isEmpty {
                    Text(memo)
                        .font(FieldPayFont.caption)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Amount and Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", (payment.amount as NSDecimalNumber).doubleValue))
                    .font(FieldPayFont.headline)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(payment.status)
                    .font(FieldPayFont.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .fieldPaySoftCard(padding: 16, cornerRadius: 16)
    }
    
    private var statusColor: Color {
        // Map NetSuite status to colors
        let status = payment.status.lowercased()
        if status.contains("deposited") || status.contains("paid") {
            return .green
        } else if status.contains("not deposited") || status.contains("open") {
            return .orange
        } else if status.contains("pending") {
            return .blue
        } else if status.contains("failed") || status.contains("void") {
            return .red
        } else {
            return .gray
        }
    }
} 
