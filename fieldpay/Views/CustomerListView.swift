import SwiftUI

// MARK: - Customer Filter Enum
enum CustomerFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"
    
    var icon: String {
        switch self {
        case .all: return "person.2.fill"
        case .active: return "checkmark.circle.fill"
        case .inactive: return "xmark.circle.fill"
        }
    }
}

struct CustomerListView: View {
    @ObservedObject var viewModel: CustomerViewModel
    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var selectedFilter: CustomerFilter = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Search and Filters
                VStack(spacing: 16) {
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
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CustomerFilter.allCases, id: \.self) { filter in
                                ModernFilterPill(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .background(Color(.systemGroupedBackground))
                
                // Customer List
                if viewModel.isLoading {
                    ModernLoadingView(message: "Loading customers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    ModernErrorView(
                        message: errorMessage,
                        retryAction: { 
                            viewModel.resetPagination()
                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredCustomers.isEmpty {
                    ModernEmptyStateView(
                        icon: "person.2",
                        title: searchText.isEmpty ? "No Customers Yet" : "No Results Found",
                        subtitle: searchText.isEmpty ? "Add your first customer to get started" : "Try adjusting your search or filters"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredCustomers) { customer in
                                NavigationLink(destination: CustomerDetailView(customer: customer, viewModel: viewModel)) {
                                    ModernCustomerCard(customer: customer)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onTapGesture {
                                    print("Debug: CustomerListView - Tapped customer: \(customer.name) (ID: \(customer.id))")
                                }
                            }
                            
                            // Load more button
                            if viewModel.hasMore && !viewModel.isLoading {
                                Button(action: {
                                    Task {
                                        await viewModel.loadNextPage()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle")
                                        Text("Load More Customers")
                                    }
                                    .foregroundColor(.blue)
                                    .padding()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Customers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCustomer = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCustomer) {
                // Add customer sheet would go here
                Text("Add Customer")
            }
            .onAppear {
                // Automatically load customers when the view appears if not already loaded
                if viewModel.customers.isEmpty && !viewModel.isLoading {
                    print("Debug: CustomerListView - View appeared, loading customers automatically")
                    Task {
                        await viewModel.loadNextPage()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCustomers: [Customer] {
        return viewModel.filteredCustomers(searchText: searchText, selectedFilter: selectedFilter)
    }
}

// MARK: - Modern Components

struct ModernCustomerCard: View {
    let customer: Customer
    
    var body: some View {
        HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(customer.name.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                // Customer Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(customer.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Status Badge
                        Text(customer.isActive ? "Active" : "Inactive")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(customer.isActive ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (customer.isActive ? Color.green : Color.red).opacity(0.1)
                            )
                            .clipShape(Capsule())
                    }
                    
                    if let companyName = customer.companyName {
                        Text(companyName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let email = customer.email {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let phone = customer.phone {
                        HStack(spacing: 4) {
                            Image(systemName: "phone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(phone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}



struct CustomerRowView: View {
    let customer: Customer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let companyName = customer.companyName {
                        Text(companyName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if customer.isActive {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                } else {
                    Text("Inactive")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                }
            }
            
            if let email = customer.email {
                HStack {
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let phone = customer.phone {
                HStack {
                    Image(systemName: "phone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CustomerDetailView: View {
    let customer: Customer
    @ObservedObject var viewModel: CustomerViewModel
    @State private var showingEditCustomer = false
    @State private var selectedTab = 0
    
    // Navigation state for quick actions
    @State private var showingCreateInvoice = false
    @State private var showingProcessPayment = false
    @State private var showingCustomerHistory = false
    
    init(customer: Customer, viewModel: CustomerViewModel) {
        self.customer = customer
        self.viewModel = viewModel
        print("Debug: CustomerDetailView - Initialized with customer: \(customer.name) (ID: \(customer.id))")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Customer Info Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let companyName = customer.companyName {
                                Text(companyName)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            showingEditCustomer = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    // Contact Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact Information")
                            .font(.headline)
                        
                        if let email = customer.email {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.blue)
                                Text(email)
                            }
                        }
                        
                        if let phone = customer.phone {
                            HStack {
                                Image(systemName: "phone")
                                    .foregroundColor(.blue)
                                Text(phone)
                            }
                        }
                    }
                    
                    // Address
                    if let address = customer.address {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Address")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let street = address.street {
                                    Text(street)
                                }
                                
                                HStack {
                                    if let city = address.city {
                                        Text(city)
                                    }
                                    if let state = address.state {
                                        Text(state)
                                    }
                                    if let zipCode = address.zipCode {
                                        Text(zipCode)
                                    }
                                }
                                
                                if let country = address.country {
                                    Text(country)
                                }
                            }
                        }
                    }
                    
                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(customer.isActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(customer.isActive ? "Active" : "Inactive")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ModernQuickActionButton(
                            title: "Create Invoice",
                            subtitle: "Generate new invoice for this customer",
                            icon: "doc.text.fill",
                            color: .blue,
                            gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                        ) {
                            print("Debug: CustomerDetailView - Create Invoice tapped for customer: \(customer.name)")
                            showingCreateInvoice = true
                        }
                        
                        ModernQuickActionButton(
                            title: "Process Payment",
                            subtitle: "Accept payment from this customer",
                            icon: "creditcard.fill",
                            color: .green,
                            gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                        ) {
                            print("Debug: CustomerDetailView - Process Payment tapped for customer: \(customer.name)")
                            showingProcessPayment = true
                        }
                        
                        ModernQuickActionButton(
                            title: "View History",
                            subtitle: "See all invoices and payments",
                            icon: "clock.fill",
                            color: .orange,
                            gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        ) {
                            print("Debug: CustomerDetailView - View History tapped for customer: \(customer.name)")
                            showingCustomerHistory = true
                        }
                    }
                }
                .padding(.horizontal)
                
                // Recent Activity Tabs
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Tab Picker
                    Picker("Activity Type", selection: $selectedTab) {
                        Text("Transactions").tag(0)
                        Text("Payments").tag(1)
                        Text("Invoices").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        // Transactions Tab
                        TransactionsTabView(
                            transactions: viewModel.customerTransactions,
                            isLoading: viewModel.isLoadingTransactions,
                            errorMessage: viewModel.errorMessage
                        )
                        .tag(0)
                        
                        // Payments Tab
                        PaymentsTabView(
                            payments: viewModel.customerPayments,
                            isLoading: viewModel.isLoadingPayments,
                            errorMessage: viewModel.errorMessage
                        )
                        .tag(1)
                        
                        // Invoices Tab
                        InvoicesTabView(
                            invoices: viewModel.customerInvoices,
                            isLoading: viewModel.isLoadingInvoices,
                            errorMessage: viewModel.errorMessage
                        )
                        .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 400)
                }
            }
            .padding()
        }
        .navigationTitle("Customer Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditCustomer) {
            EditCustomerView(customer: customer, viewModel: viewModel)
        }
        .sheet(isPresented: $showingCreateInvoice) {
            CreateInvoiceView(customer: customer)
        }
        .sheet(isPresented: $showingProcessPayment) {
            ProcessPaymentView(customer: customer)
        }
        .sheet(isPresented: $showingCustomerHistory) {
            CustomerHistoryView(customer: customer, viewModel: viewModel)
        }
        .onAppear {
            print("Debug: CustomerDetailView - View appeared for customer: \(customer.name) (ID: \(customer.id))")
            print("Debug: CustomerDetailView - Customer details: name=\(customer.name), email=\(customer.email ?? "nil"), phone=\(customer.phone ?? "nil"), company=\(customer.companyName ?? "nil")")
            
            // Load customer detail data (transactions, payments, invoices) when view appears
            Task {
                await viewModel.loadCustomerDetail(id: customer.id)
            }
        }
    }
}

struct AddCustomerView: View {
    @ObservedObject var viewModel: CustomerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var companyName = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var country = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Company Name", text: $companyName)
                }
                
                Section("Address") {
                    TextField("Street", text: $street)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("ZIP Code", text: $zipCode)
                    TextField("Country", text: $country)
                }
            }
            .navigationTitle("Add Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.createCustomer(
                            name: name,
                            email: email.isEmpty ? nil : email,
                            phone: phone.isEmpty ? nil : phone,
                            companyName: companyName.isEmpty ? nil : companyName
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct EditCustomerView: View {
    let customer: Customer
    @ObservedObject var viewModel: CustomerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var companyName: String
    @State private var street: String
    @State private var city: String
    @State private var state: String
    @State private var zipCode: String
    @State private var country: String
    
    init(customer: Customer, viewModel: CustomerViewModel) {
        self.customer = customer
        self.viewModel = viewModel
        
        _name = State(initialValue: customer.name)
        _email = State(initialValue: customer.email ?? "")
        _phone = State(initialValue: customer.phone ?? "")
        _companyName = State(initialValue: customer.companyName ?? "")
        _street = State(initialValue: customer.address?.street ?? "")
        _city = State(initialValue: customer.address?.city ?? "")
        _state = State(initialValue: customer.address?.state ?? "")
        _zipCode = State(initialValue: customer.address?.zipCode ?? "")
        _country = State(initialValue: customer.address?.country ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Company Name", text: $companyName)
                }
                
                Section("Address") {
                    TextField("Street", text: $street)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("ZIP Code", text: $zipCode)
                    TextField("Country", text: $country)
                }
            }
            .navigationTitle("Edit Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let address = Customer.Address(
                            street: street.isEmpty ? nil : street,
                            city: city.isEmpty ? nil : city,
                            state: state.isEmpty ? nil : state,
                            zipCode: zipCode.isEmpty ? nil : zipCode,
                            country: country.isEmpty ? nil : country
                        )
                        
                        let updatedCustomer = Customer(
                            id: customer.id,
                            name: name,
                            email: email.isEmpty ? nil : email,
                            phone: phone.isEmpty ? nil : phone,
                            address: address,
                            netSuiteId: customer.netSuiteId,
                            companyName: companyName.isEmpty ? nil : companyName,
                            isActive: customer.isActive,
                            createdDate: customer.createdDate,
                            lastModifiedDate: Date()
                        )
                        
                        viewModel.updateCustomer(updatedCustomer)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
} 

// MARK: - Tab View Components

struct TransactionsTabView: View {
    let transactions: [CustomerTransaction]
    let isLoading: Bool
    let errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ModernLoadingView(message: "Loading transactions...")
            } else if let errorMessage = errorMessage, !errorMessage.isEmpty {
                ModernErrorView(message: errorMessage, retryAction: {})
            } else if transactions.isEmpty {
                ModernEmptyStateView(
                    icon: "doc.text",
                    title: "No Transactions",
                    subtitle: "This customer has no recent transactions."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(transactions) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            print("Debug: TransactionsTabView - Displaying \(transactions.count) transactions")
            print("Debug: TransactionsTabView - Loading state: \(isLoading)")
            print("Debug: TransactionsTabView - Error message: \(errorMessage ?? "none")")
            print("Debug: TransactionsTabView - Transactions data: \(transactions)")
        }
    }
}

struct PaymentsTabView: View {
    let payments: [CustomerPayment]
    let isLoading: Bool
    let errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ModernLoadingView(message: "Loading payments...")
            } else if let errorMessage = errorMessage, !errorMessage.isEmpty {
                ModernErrorView(message: errorMessage, retryAction: {})
            } else if payments.isEmpty {
                ModernEmptyStateView(
                    icon: "creditcard",
                    title: "No Payments",
                    subtitle: "This customer has no recent payments."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(payments) { payment in
                            NavigationLink(destination: PaymentDetailView(payment: payment)) {
                                PaymentRowView(payment: payment)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            print("Debug: PaymentsTabView - Displaying \(payments.count) payments")
            print("Debug: PaymentsTabView - Loading state: \(isLoading)")
            print("Debug: PaymentsTabView - Error message: \(errorMessage ?? "none")")
            print("Debug: PaymentsTabView - Payments data: \(payments)")
        }
    }
}

struct InvoicesTabView: View {
    let invoices: [Invoice]
    let isLoading: Bool
    let errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ModernLoadingView(message: "Loading invoices...")
            } else if let errorMessage = errorMessage, !errorMessage.isEmpty {
                ModernErrorView(message: errorMessage, retryAction: {})
            } else if invoices.isEmpty {
                ModernEmptyStateView(
                    icon: "doc.text.fill",
                    title: "No Invoices",
                    subtitle: "This customer has no recent invoices."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(invoices) { invoice in
                            NavigationLink(destination: InvoiceDetailView(invoice: invoice, viewModel: InvoiceViewModel(), customerViewModel: CustomerViewModel())) {
                                InvoiceDetailCard(invoice: invoice)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            print("Debug: InvoicesTabView - Displaying \(invoices.count) invoices")
            print("Debug: InvoicesTabView - Loading state: \(isLoading)")
            print("Debug: InvoicesTabView - Error message: \(errorMessage ?? "none")")
            print("Debug: InvoicesTabView - Invoices data: \(invoices)")
        }
    }
}

// MARK: - Row View Components

struct TransactionRowView: View {
    let transaction: CustomerTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.transactionNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(transaction.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.amount >= 0 ? .green : .red)
                    
                    Text(transaction.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let memo = transaction.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(transaction.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "pending": return .orange
        case "approved", "completed": return .green
        case "cancelled", "failed": return .red
        default: return .gray
        }
    }
}

struct PaymentRowView: View {
    let payment: CustomerPayment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(payment.paymentNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let paymentMethod = payment.paymentMethod {
                        Text(paymentMethod)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(payment.formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text(payment.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let memo = payment.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(payment.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch payment.status.lowercased() {
        case "pending": return .orange
        case "approved", "completed": return .green
        case "cancelled", "failed": return .red
        default: return .gray
        }
    }
}

// MARK: - Payment Detail View

struct PaymentDetailView: View {
    let payment: CustomerPayment
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Payment Header
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(payment.paymentNumber)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Payment")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(payment.status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    Divider()
                    
                    // Payment Details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Amount:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(formatCurrency(payment.amount))
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Date:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(payment.date, style: .date)
                        }
                        
                        if let paymentMethod = payment.paymentMethod {
                            HStack {
                                Text("Payment Method:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(paymentMethod)
                            }
                        }
                        
                        HStack {
                            Text("Status:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(payment.status)
                                .foregroundColor(statusColor)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Notes
                if let memo = payment.memo, !memo.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(memo)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            .padding()
        }
        .navigationTitle("Payment Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var statusColor: Color {
        switch payment.status.lowercased() {
        case "pending": return .orange
        case "approved", "completed": return .green
        case "cancelled", "failed": return .red
        default: return .gray
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Invoice Detail Components

struct InvoiceDetailCard: View {
    let invoice: Invoice
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Invoice Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.invoiceNumber)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Invoice #\(invoice.invoiceNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(invoice.amount))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Balance: \(formatCurrency(invoice.balance))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    // Status Badge
                    Text(invoice.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let dueDate = invoice.dueDate {
                        Text("Due: \(formatDate(dueDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Line Items Section
            if !invoice.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Line Items")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: { isExpanded.toggle() }) {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "Hide" : "Show")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    if isExpanded {
                        VStack(spacing: 8) {
                            ForEach(invoice.items, id: \.id) { item in
                                InvoiceLineItemRow(item: item)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            // Notes Section
            if let notes = invoice.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        switch invoice.status {
        case .pending: return .orange
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .gray
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        // Validate the amount to prevent NaN errors
        if amount.isNaN || amount.isInfinite {
            return "$0.00"
        }
        
        // Handle extremely large numbers
        if amount > Decimal(1_000_000_000) {
            return "$0.00"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct InvoiceLineItemRow: View {
    let item: Invoice.InvoiceItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Item Description
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("Qty: \(String(format: "%.1f", item.quantity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("@ \(formatCurrency(item.unitPrice))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Item Amount
            Text(formatCurrency(item.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        // Validate the amount to prevent NaN errors
        if amount.isNaN || amount.isInfinite {
            return "$0.00"
        }
        
        // Handle extremely large numbers
        if amount > Decimal(1_000_000_000) {
            return "$0.00"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
} 

// MARK: - Create Invoice View
struct CreateInvoiceView: View {
    let customer: Customer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateInvoiceViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                // Customer Information Section
                Section("Customer Information") {
                    HStack {
                        Text("Customer")
                        Spacer()
                        Text(customer.name)
                            .foregroundColor(.secondary)
                    }
                    
                    if let companyName = customer.companyName {
                        HStack {
                            Text("Company")
                            Spacer()
                            Text(companyName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Invoice Template Section - Temporarily commented out
                /*
                Section {
                    if viewModel.isLoadingTemplates {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading templates...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Template", selection: $viewModel.selectedTemplate) {
                            Text("Select Template").tag(nil as NetSuiteInvoiceTemplate?)
                            ForEach(viewModel.invoiceTemplates, id: \.id) { template in
                                Text(template.name ?? "Unknown Template").tag(template as NetSuiteInvoiceTemplate?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                } header: {
                    Text("Invoice Template")
                }
                */
                
                // Location Section (if required by template) - Temporarily commented out
                /*
                if viewModel.selectedTemplate != nil && viewModel.isLocationRequired {
                    Section("Location") {
                        if viewModel.isLoadingLocations {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading locations...")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Picker("Location", selection: $viewModel.selectedLocation) {
                                Text("Select Location").tag(nil as NetSuiteLocation?)
                                ForEach(viewModel.locations, id: \.id) { location in
                                    Text(location.name ?? "Unknown Location").tag(location as NetSuiteLocation?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                */
                
                // Invoice Details Section - Temporarily commented out
                /*
                Section("Invoice Details") {
                    TextField("Invoice Number", text: $viewModel.invoiceNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    DatePicker("Transaction Date", selection: $viewModel.transactionDate, displayedComponents: .date)
                    
                    DatePicker("Due Date", selection: $viewModel.dueDate, displayedComponents: .date)
                    
                    TextField("Memo", text: $viewModel.memo, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                */
                
                // Line Items Section - Temporarily commented out
                /*
                Section("Line Items") {
                    if viewModel.isLoadingInventory {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading inventory items...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Add Item Button
                        Button(action: {
                            viewModel.showingAddItem = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Item")
                            }
                            .foregroundColor(.blue)
                        }
                        
                        // Line Items List
                        ForEach(viewModel.lineItems.indices, id: \.self) { index in
                            LineItemRow(
                                lineItem: $viewModel.lineItems[index],
                                onDelete: {
                                    viewModel.lineItems.remove(at: index)
                                }
                            )
                        }
                        
                        // Total
                        if !viewModel.lineItems.isEmpty {
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                Spacer()
                                Text("$\(viewModel.totalAmount, specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                */
                
                // Error Section
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.createInvoice(for: customer)
                            if viewModel.isSuccess {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canCreateInvoice || viewModel.isCreating)
                }
            }
            .sheet(isPresented: $viewModel.showingAddItem) {
                AddLineItemView(
                    inventoryItems: viewModel.inventoryItems,
                    onAddItem: { item in
                        viewModel.addLineItem(item)
                    }
                )
            }
            .onAppear {
                Task {
                    await viewModel.loadData()
                }
            }
        }
    }
}

// MARK: - Create Invoice ViewModel
@MainActor
class CreateInvoiceViewModel: ObservableObject {
    @Published var invoiceNumber = ""
    @Published var transactionDate = Date()
    @Published var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @Published var memo = ""
    
    @Published var invoiceTemplates: [NetSuiteInvoiceTemplate] = []
    @Published var selectedTemplate: NetSuiteInvoiceTemplate?
    @Published var isLoadingTemplates = false
    
    @Published var locations: [NetSuiteLocation] = []
    @Published var selectedLocation: NetSuiteLocation?
    @Published var isLoadingLocations = false
    
    @Published var inventoryItems: [NetSuiteInventoryItem] = []
    @Published var isLoadingInventory = false
    
    @Published var lineItems: [InvoiceLineItem] = []
    @Published var showingAddItem = false
    
    @Published var isCreating = false
    @Published var isSuccess = false
    @Published var errorMessage: String?
    
    private let netSuiteAPI = NetSuiteAPI.shared
    
    var isLocationRequired: Bool {
        // Check if selected template requires location
        return selectedTemplate?.requiredFields?.contains("location") == true
    }
    
    var totalAmount: Double {
        return lineItems.reduce(0) { $0 + $1.amount }
    }
    
    var canCreateInvoice: Bool {
        return !invoiceNumber.isEmpty && 
               !lineItems.isEmpty && 
               selectedTemplate != nil &&
               (!isLocationRequired || selectedLocation != nil)
    }
    
    func loadData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadInvoiceTemplates() }
            group.addTask { await self.loadLocations() }
            group.addTask { await self.loadInventoryItems() }
        }
    }
    
    private func loadInvoiceTemplates() async {
        isLoadingTemplates = true
        errorMessage = nil
        
        do {
            invoiceTemplates = try await netSuiteAPI.fetchInvoiceTemplates()
            if !invoiceTemplates.isEmpty {
                selectedTemplate = invoiceTemplates.first
            }
        } catch {
            errorMessage = "Failed to load invoice templates: \(error.localizedDescription)"
        }
        
        isLoadingTemplates = false
    }
    
    private func loadLocations() async {
        isLoadingLocations = true
        
        do {
            locations = try await netSuiteAPI.fetchLocations()
        } catch {
            print("Debug: CreateInvoiceViewModel - Failed to load locations: \(error)")
        }
        
        isLoadingLocations = false
    }
    
    private func loadInventoryItems() async {
        isLoadingInventory = true
        
        do {
            inventoryItems = try await netSuiteAPI.fetchInventoryItems()
        } catch {
            errorMessage = "Failed to load inventory items: \(error.localizedDescription)"
        }
        
        isLoadingInventory = false
    }
    
    func addLineItem(_ inventoryItem: NetSuiteInventoryItem) {
        let lineItem = InvoiceLineItem(
            item: inventoryItem,
            quantity: 1.0,
            rate: inventoryItem.basePrice ?? 0.0,
            amount: inventoryItem.basePrice ?? 0.0,
            description: inventoryItem.description ?? inventoryItem.displayName ?? "Unknown Item",
            lineNumber: lineItems.count + 1
        )
        lineItems.append(lineItem)
    }
    
    func createInvoice(for customer: Customer) async {
        guard canCreateInvoice else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Create line items for the request
            let requestLineItems = lineItems.map { lineItem in
                NetSuiteInvoiceLineItem(
                    item: lineItem.item,
                    quantity: lineItem.quantity,
                    rate: lineItem.rate,
                    amount: lineItem.amount,
                    description: lineItem.description,
                    lineNumber: lineItem.lineNumber
                )
            }
            
            // Create the invoice request
            let request = NetSuiteInvoiceCreationRequest(
                entity: NetSuiteEntityReference(id: customer.id, refName: customer.name),
                tranDate: formatDate(transactionDate),
                dueDate: formatDate(dueDate),
                memo: memo.isEmpty ? nil : memo,
                customForm: selectedTemplate?.customForm,
                location: selectedLocation.map { NetSuiteLocationReference(id: $0.id, refName: $0.name, type: nil) },
                subsidiary: nil,
                item: requestLineItems
            )
            
            let createdInvoice = try await netSuiteAPI.createInvoice(request: request)
            
            print("Debug: CreateInvoiceViewModel - Successfully created invoice: \(createdInvoice.tranId ?? "Unknown")")
            isSuccess = true
            
        } catch {
            errorMessage = "Failed to create invoice: \(error.localizedDescription)"
            print("Debug: CreateInvoiceViewModel - Invoice creation failed: \(error)")
        }
        
        isCreating = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Models and Views
struct InvoiceLineItem: Identifiable {
    let id = UUID()
    var item: NetSuiteInventoryItem
    var quantity: Double
    var rate: Double
    var amount: Double
    var description: String
    var lineNumber: Int
    
    mutating func updateAmount() {
        amount = quantity * rate
    }
}

struct LineItemRow: View {
    @Binding var lineItem: InvoiceLineItem
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lineItem.description)
                    .font(.headline)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("Qty:")
                TextField("Quantity", value: $lineItem.quantity, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .onChange(of: lineItem.quantity) { _, _ in
                        lineItem.updateAmount()
                    }
                
                Text("@")
                TextField("Rate", value: $lineItem.rate, format: .currency(code: "USD"))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                    .onChange(of: lineItem.rate) { _, _ in
                        lineItem.updateAmount()
                    }
                
                Spacer()
                
                Text("$\(lineItem.amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddLineItemView: View {
    let inventoryItems: [NetSuiteInventoryItem]
    let onAddItem: (NetSuiteInventoryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredItems: [NetSuiteInventoryItem] {
        if searchText.isEmpty {
            return inventoryItems
        } else {
            return inventoryItems.filter { item in
                (item.displayName?.localizedCaseInsensitiveContains(searchText) == true) ||
                (item.description?.localizedCaseInsensitiveContains(searchText) == true) ||
                (item.itemId?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search items...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                
                // Items List
                List(filteredItems, id: \.id) { item in
                    Button(action: {
                        onAddItem(item)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName ?? "Unknown Item")
                                .font(.headline)
                            
                            if let description = item.description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                if let itemId = item.itemId {
                                    Text("ID: \(itemId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let price = item.basePrice {
                                    Text("$\(price, specifier: "%.2f")")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Add Item")
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

struct ProcessPaymentView: View {
    let customer: Customer
    @Environment(\.dismiss) private var dismiss
    @State private var paymentAmount = ""
    @State private var paymentMethod = "Credit Card"
    @State private var referenceNumber = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let paymentMethods = ["Credit Card", "Cash", "Check", "Bank Transfer", "Tap to Pay"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    HStack {
                        Text("Customer")
                        Spacer()
                        Text(customer.name)
                            .foregroundColor(.secondary)
                    }
                    
                    if let companyName = customer.companyName {
                        HStack {
                            Text("Company")
                            Spacer()
                            Text(companyName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Payment Details") {
                    TextField("Payment Amount", text: $paymentAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                    
                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    
                    TextField("Reference Number", text: $referenceNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Process Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Process") {
                        processPayment()
                    }
                    .disabled(paymentAmount.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func processPayment() {
        guard let amountValue = Double(paymentAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement actual payment processing with NetSuite API
        print("Debug: ProcessPaymentView - Processing payment for customer: \(customer.name)")
        print("Debug: ProcessPaymentView - Payment details: amount=\(amountValue), method=\(paymentMethod), reference=\(referenceNumber)")
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            dismiss()
        }
    }
}



struct CustomerHistoryView: View {
    let customer: Customer
    @ObservedObject var viewModel: CustomerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("History Type", selection: $selectedTab) {
                    Text("Invoices").tag(0)
                    Text("Payments").tag(1)
                    Text("Transactions").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    InvoicesTabView(
                        invoices: viewModel.customerInvoices,
                        isLoading: viewModel.isLoadingInvoices,
                        errorMessage: viewModel.errorMessage
                    )
                    .tag(0)
                    
                    PaymentsTabView(
                        payments: viewModel.customerPayments,
                        isLoading: viewModel.isLoadingPayments,
                        errorMessage: viewModel.errorMessage
                    )
                    .tag(1)
                    
                    TransactionsTabView(
                        transactions: viewModel.customerTransactions,
                        isLoading: viewModel.isLoadingTransactions,
                        errorMessage: viewModel.errorMessage
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Customer History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await viewModel.refreshCustomerPayments(customerId: customer.id)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func statusColor(for status: Invoice.InvoiceStatus) -> Color {
        switch status {
        case .paid:
            return .green
        case .overdue:
            return .red
        case .cancelled:
            return .gray
        case .pending:
            return .orange
        }
    }
} 