import SwiftUI

struct SalesOrderListView: View {
    @ObservedObject var viewModel: SalesOrderViewModel
    @StateObject private var customerViewModel = CustomerViewModel()
    @State private var selectedCustomer: Customer?
    @State private var showingCustomerPicker = false
    @State private var selectedStatus: SalesOrder.SalesOrderStatus?
    @State private var showingAddOrder = false
    @State private var selectedSalesOrder: SalesOrder?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Customer Selection Header
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sales Orders")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if selectedCustomer == nil {
                            Text("Select a customer to view their sales orders")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Customer Selection Button
                    Button(action: { showingCustomerPicker = true }) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundColor(selectedCustomer != nil ? .blue : .gray)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedCustomer?.name ?? "Select Customer")
                                    .font(.headline)
                                    .foregroundColor(selectedCustomer != nil ? .primary : .secondary)
                                
                                if let customer = selectedCustomer {
                                    Text("ID: \(customer.id)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Status Filter (only show when customer is selected)
                    if selectedCustomer != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                StatusFilterChip(
                                    title: "All Orders",
                                    count: viewModel.salesOrders.count,
                                    isSelected: selectedStatus == nil
                                ) {
                                    selectedStatus = nil
                                }
                                
                                ForEach(SalesOrder.SalesOrderStatus.allCases, id: \.self) { status in
                                    let count = viewModel.salesOrders.filter { $0.status == status }.count
                                    StatusFilterChip(
                                        title: status.displayName,
                                        count: count,
                                        isSelected: selectedStatus == status
                                    ) {
                                        selectedStatus = status
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Content Area
                if selectedCustomer == nil {
                    // Empty state - no customer selected
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Select a Customer")
                            .font(.headline)
                        
                        Text("Choose a customer from the list to view their sales orders, order status, line items, and related payments.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Select Customer") {
                            showingCustomerPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if viewModel.isLoading {
                    ProgressView("Loading sales orders...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            loadSalesOrdersForSelectedCustomer()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Sales Orders List
                    List {
                        ForEach(filteredSalesOrders) { salesOrder in
                            Button(action: {
                                selectedSalesOrder = salesOrder
                            }) {
                                EnhancedSalesOrderRowView(salesOrder: salesOrder)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCustomerPicker) {
                CustomerPickerForSalesOrdersView(selectedCustomer: $selectedCustomer)
            }
            .sheet(item: $selectedSalesOrder) { salesOrder in
                EnhancedSalesOrderDetailView(salesOrder: salesOrder, customer: selectedCustomer, viewModel: viewModel)
            }
            .onChange(of: selectedCustomer) { _, newCustomer in
                if newCustomer != nil {
                    loadSalesOrdersForSelectedCustomer()
                }
            }
        }
    }
    
    private var filteredSalesOrders: [SalesOrder] {
        var salesOrders = viewModel.salesOrders
        
        if let selectedStatus = selectedStatus {
            salesOrders = salesOrders.filter { $0.status == selectedStatus }
        }
        
        return salesOrders
    }
    
    private func loadSalesOrdersForSelectedCustomer() {
        guard let customer = selectedCustomer else { return }
        viewModel.loadSalesOrdersForCustomer(customer.id)
    }
}

struct StatusFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomerPickerForSalesOrdersView: View {
    @Binding var selectedCustomer: Customer?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customerViewModel = CustomerViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search customers...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Customer List
                if customerViewModel.isLoading {
                    ProgressView("Loading customers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredCustomers) { customer in
                            Button(action: {
                                selectedCustomer = customer
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(customer.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("ID: \(customer.id)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let email = customer.email {
                                            Text(email)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
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
        .onAppear {
            if customerViewModel.customers.isEmpty {
                Task {
                    await customerViewModel.loadNextPage()
                }
            }
        }
        .onChange(of: searchText) { _, _ in
            Task {
                do {
                    _ = try await customerViewModel.searchCustomers(query: searchText)
                } catch {
                    print("Search error: \(error)")
                }
            }
        }
    }
    
    private var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customerViewModel.customers
        } else {
            return customerViewModel.customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.id.localizedCaseInsensitiveContains(searchText) ||
                (customer.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

struct EnhancedSalesOrderRowView: View {
    let salesOrder: SalesOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(salesOrder.orderNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(salesOrder.orderDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", (salesOrder.amount as NSDecimalNumber).doubleValue))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    SalesOrderStatusBadge(status: salesOrder.status)
                }
            }
            
            // Progress indicators and details
            VStack(alignment: .leading, spacing: 8) {
                // Line items preview
                if !salesOrder.items.isEmpty {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("\(salesOrder.items.count) item\(salesOrder.items.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let expectedShipDate = salesOrder.expectedShipDate {
                            HStack(spacing: 4) {
                                Image(systemName: "shippingbox")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Text("Ship: \(expectedShipDate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Progress bar for order status
                OrderProgressView(status: salesOrder.status)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct OrderProgressView: View {
    let status: SalesOrder.SalesOrderStatus
    
    private var progress: Double {
        switch status {
        case .pendingApproval: return 0.1
        case .approved: return 0.3
        case .inProgress: return 0.6
        case .shipped: return 0.8
        case .delivered: return 1.0
        case .cancelled: return 0.0
        }
    }
    
    private var progressColor: Color {
        switch status {
        case .cancelled: return .red
        case .delivered: return .green
        default: return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Order Progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(status.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(progressColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

struct SalesOrderRowView: View {
    let salesOrder: SalesOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(salesOrder.orderNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(salesOrder.customerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", (salesOrder.amount as NSDecimalNumber).doubleValue))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(salesOrder.orderDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                SalesOrderStatusBadge(status: salesOrder.status)
                
                Spacer()
                
                if let expectedShipDate = salesOrder.expectedShipDate {
                    Text("Ship: \(expectedShipDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SalesOrderStatusBadge: View {
    let status: SalesOrder.SalesOrderStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pendingApproval: return .orange
        case .approved: return .blue
        case .inProgress: return .purple
        case .shipped: return .green
        case .delivered: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Enhanced Sales Order Detail View

struct EnhancedSalesOrderDetailView: View {
    let salesOrder: SalesOrder
    let customer: Customer?
    @ObservedObject var viewModel: SalesOrderViewModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var customerViewModel = CustomerViewModel()
    @State private var relatedPayments: [CustomerPayment] = []
    @State private var isLoadingPayments = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Order Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(salesOrder.orderNumber)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                if let customer = customer {
                                    Text(customer.name)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            SalesOrderStatusBadge(status: salesOrder.status)
                        }
                        
                        OrderProgressView(status: salesOrder.status)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Total Amount:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(String(format: "$%.2f", (salesOrder.amount as NSDecimalNumber).doubleValue))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Order Date:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(salesOrder.orderDate, style: .date)
                            }
                            
                            if let expectedShipDate = salesOrder.expectedShipDate {
                                HStack {
                                    Text("Expected Ship Date:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(expectedShipDate, style: .date)
                                        .foregroundColor(expectedShipDate < Date() ? .orange : .primary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Line Items Section
                    if !salesOrder.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Line Items")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(salesOrder.items.count) items")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                            
                            VStack(spacing: 1) {
                                ForEach(salesOrder.items, id: \.id) { item in
                                    EnhancedSalesOrderItemRow(item: item)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    
                    // Related Payments Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Related Payments")
                                .font(.headline)
                            
                            Spacer()
                            
                            if isLoadingPayments {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        if relatedPayments.isEmpty && !isLoadingPayments {
                            VStack(spacing: 8) {
                                Image(systemName: "creditcard")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                
                                Text("No payments found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Payments made against this order will appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        } else {
                            VStack(spacing: 1) {
                                ForEach(relatedPayments, id: \.id) { payment in
                                    RelatedPaymentRow(payment: payment)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadRelatedPayments()
        }
    }
    
    private func loadRelatedPayments() {
        guard let customer = customer else { return }
        
        isLoadingPayments = true
        Task {
            await customerViewModel.loadCustomerPayments(customerId: customer.id)
            await MainActor.run {
                relatedPayments = customerViewModel.customerPayments
                isLoadingPayments = false
            }
        }
    }
}

struct EnhancedSalesOrderItemRow: View {
    let item: SalesOrder.SalesOrderItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(item.isShipped ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("Qty: \(String(format: "%.0f", item.quantity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Unit: \(String(format: "$%.2f", (item.unitPrice as NSDecimalNumber).doubleValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if item.isShipped {
                    Text("Shipped")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Text(String(format: "$%.2f", (item.amount as NSDecimalNumber).doubleValue))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct RelatedPaymentRow: View {
    let payment: CustomerPayment
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: paymentMethodIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.paymentNumber)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(payment.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let paymentMethod = payment.paymentMethod {
                    Text(paymentMethod)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", (payment.amount as NSDecimalNumber).doubleValue))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                PaymentStatusBadge(status: payment.status)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var paymentMethodIcon: String {
        guard let method = payment.paymentMethod?.lowercased() else {
            return "questionmark.circle"
        }
        
        if method.contains("cash") {
            return "banknote"
        } else if method.contains("card") || method.contains("credit") || method.contains("debit") {
            return "creditcard"
        } else if method.contains("check") {
            return "doc.text"
        } else if method.contains("transfer") || method.contains("bank") {
            return "building.columns"
        } else {
            return "questionmark.circle"
        }
    }
}

struct PaymentStatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "pending", "draft":
            return .orange
        case "completed", "paid", "approved":
            return .green
        case "failed", "declined", "rejected":
            return .red
        case "cancelled", "canceled":
            return .gray
        default:
            return .blue
        }
    }
}

// Legacy views for backward compatibility

struct SalesOrderDetailView: View {
    let salesOrder: SalesOrder
    @ObservedObject var viewModel: SalesOrderViewModel
    @State private var showingEditOrder = false
    
    var body: some View {
        EnhancedSalesOrderDetailView(salesOrder: salesOrder, customer: nil, viewModel: viewModel)
    }
}

struct SalesOrderItemRow: View {
    let item: SalesOrder.SalesOrderItem
    
    var body: some View {
        EnhancedSalesOrderItemRow(item: item)
    }
}

struct AddSalesOrderView: View {
    @ObservedObject var viewModel: SalesOrderViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customerId = ""
    @State private var customerName = ""
    @State private var amount: String = ""
    @State private var expectedShipDate = Date()
    @State private var notes = ""
    @State private var items: [SalesOrder.SalesOrderItem] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Customer Name", text: $customerName)
                    TextField("Customer ID", text: $customerId)
                }
                
                Section("Order Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Expected Ship Date", selection: $expectedShipDate, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Sales Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let amountValue = Decimal(string: amount) else { return }
                        
                        viewModel.createSalesOrder(
                            customerId: customerId,
                            customerName: customerName,
                            amount: amountValue,
                            items: items,
                            expectedShipDate: expectedShipDate
                        )
                        dismiss()
                    }
                    .disabled(customerName.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

struct EditSalesOrderView: View {
    let salesOrder: SalesOrder
    @ObservedObject var viewModel: SalesOrderViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customerName: String
    @State private var amount: String
    @State private var expectedShipDate: Date
    @State private var notes: String
    
    init(salesOrder: SalesOrder, viewModel: SalesOrderViewModel) {
        self.salesOrder = salesOrder
        self.viewModel = viewModel
        
        _customerName = State(initialValue: salesOrder.customerName)
        _amount = State(initialValue: String(describing: salesOrder.amount))
        _expectedShipDate = State(initialValue: salesOrder.expectedShipDate ?? Date())
        _notes = State(initialValue: salesOrder.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Customer Name", text: $customerName)
                }
                
                Section("Order Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Expected Ship Date", selection: $expectedShipDate, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Sales Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let amountValue = Decimal(string: amount) else { return }
                        
                        let updatedSalesOrder = SalesOrder(
                            id: salesOrder.id,
                            orderNumber: salesOrder.orderNumber,
                            customerId: salesOrder.customerId,
                            customerName: customerName,
                            amount: amountValue,
                            status: salesOrder.status,
                            orderDate: salesOrder.orderDate,
                            expectedShipDate: expectedShipDate,
                            netSuiteId: salesOrder.netSuiteId,
                            items: salesOrder.items,
                            notes: notes.isEmpty ? nil : notes
                        )
                        
                        viewModel.updateSalesOrder(updatedSalesOrder)
                        dismiss()
                    }
                    .disabled(customerName.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}