import SwiftUI

struct SalesOrderListView: View {
    @ObservedObject var viewModel: SalesOrderViewModel
    @State private var searchText = ""
    @State private var selectedStatus: SalesOrder.SalesOrderStatus?
    @State private var showingAddOrder = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading sales orders...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.loadSalesOrders()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSalesOrders) { salesOrder in
                            NavigationLink(destination: SalesOrderDetailView(salesOrder: salesOrder, viewModel: viewModel)) {
                                SalesOrderRowView(salesOrder: salesOrder)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search orders")
                    .onChange(of: searchText) { _, newValue in
                        viewModel.searchSalesOrders(query: newValue)
                    }
                }
            }
            .navigationTitle("Sales Orders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddOrder = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.loadSalesOrders() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Orders") {
                            selectedStatus = nil
                        }
                        ForEach(SalesOrder.SalesOrderStatus.allCases, id: \.self) { status in
                            Button(status.displayName) {
                                selectedStatus = status
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddOrder) {
                AddSalesOrderView(viewModel: viewModel)
            }
        }
    }
    
    private var filteredSalesOrders: [SalesOrder] {
        var salesOrders = viewModel.salesOrders
        
        if let selectedStatus = selectedStatus {
            salesOrders = salesOrders.filter { $0.status == selectedStatus }
        }
        
        if !searchText.isEmpty {
            salesOrders = salesOrders.filter { salesOrder in
                salesOrder.orderNumber.localizedCaseInsensitiveContains(searchText) ||
                salesOrder.customerName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return salesOrders
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

struct SalesOrderDetailView: View {
    let salesOrder: SalesOrder
    @ObservedObject var viewModel: SalesOrderViewModel
    @State private var showingEditOrder = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Order Header
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(salesOrder.orderNumber)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(salesOrder.customerName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        SalesOrderStatusBadge(status: salesOrder.status)
                    }
                    
                    Divider()
                    
                    // Order Details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Total Amount:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "$%.2f", (salesOrder.amount as NSDecimalNumber).doubleValue))
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
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Order Items
                if !salesOrder.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(salesOrder.items, id: \.id) { item in
                                SalesOrderItemRow(item: item)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                // Notes
                if let notes = salesOrder.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                // Status Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order Actions")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        if salesOrder.status == .pendingApproval {
                            ModernQuickActionButton(
                                title: "Approve Order",
                                subtitle: "Approve this sales order",
                                icon: "checkmark.circle.fill",
                                color: .green,
                                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            ) {
                                viewModel.approveSalesOrder(salesOrder)
                            }
                        }
                        
                        if salesOrder.status == .approved {
                            ModernQuickActionButton(
                                title: "Mark In Progress",
                                subtitle: "Start processing this order",
                                icon: "play.circle.fill",
                                color: .blue,
                                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            ) {
                                viewModel.markAsInProgress(salesOrder)
                            }
                        }
                        
                        if salesOrder.status == .inProgress {
                            ModernQuickActionButton(
                                title: "Mark Shipped",
                                subtitle: "Mark order as shipped",
                                icon: "shippingbox.fill",
                                color: .orange,
                                gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                            ) {
                                viewModel.markAsShipped(salesOrder)
                            }
                        }
                        
                        if salesOrder.status == .shipped {
                            ModernQuickActionButton(
                                title: "Mark Delivered",
                                subtitle: "Mark order as delivered",
                                icon: "checkmark.shield.fill",
                                color: .green,
                                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            ) {
                                viewModel.markAsDelivered(salesOrder)
                            }
                        }
                        
                        if salesOrder.status != .delivered && salesOrder.status != .cancelled {
                            ModernQuickActionButton(
                                title: "Cancel Order",
                                subtitle: "Cancel this sales order",
                                icon: "xmark.circle.fill",
                                color: .red,
                                gradient: LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
                            ) {
                                viewModel.cancelSalesOrder(salesOrder)
                            }
                        }
                        
                        ModernQuickActionButton(
                            title: "Create Invoice",
                            subtitle: "Generate invoice for this order",
                            icon: "doc.text.fill",
                            color: .purple,
                            gradient: LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                        ) {
                            // Navigate to invoice creation
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditOrder = true
                }
            }
        }
        .sheet(isPresented: $showingEditOrder) {
            EditSalesOrderView(salesOrder: salesOrder, viewModel: viewModel)
        }
    }
}

struct SalesOrderItemRow: View {
    let item: SalesOrder.SalesOrderItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Qty: \(String(format: "%.0f", item.quantity)) × \(String(format: "$%.2f", (item.unitPrice as NSDecimalNumber).doubleValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", (item.amount as NSDecimalNumber).doubleValue))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if item.isShipped {
                    Text("Shipped")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
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