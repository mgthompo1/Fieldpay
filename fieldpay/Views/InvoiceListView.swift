import SwiftUI

struct InvoiceListView: View {
    @ObservedObject var viewModel: InvoiceViewModel
    @State private var searchText = ""
    @State private var selectedStatus: Invoice.InvoiceStatus?
    @State private var showingAddInvoice = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading invoices...")
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
                            viewModel.loadInvoices()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredInvoices) { invoice in
                            NavigationLink(destination: InvoiceDetailView(invoice: invoice, viewModel: viewModel)) {
                                InvoiceRowView(invoice: invoice)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search invoices")
                    .onChange(of: searchText) { _, newValue in
                        viewModel.searchInvoices(query: newValue)
                    }
                }
            }
            .navigationTitle("Invoices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInvoice = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.loadInvoices() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Invoices") {
                            selectedStatus = nil
                        }
                        ForEach(Invoice.InvoiceStatus.allCases, id: \.self) { status in
                            Button(status.displayName) {
                                selectedStatus = status
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                AddInvoiceView(viewModel: viewModel)
            }
        }
    }
    
    private var filteredInvoices: [Invoice] {
        var invoices = viewModel.invoices
        
        if let selectedStatus = selectedStatus {
            invoices = invoices.filter { $0.status == selectedStatus }
        }
        
        if !searchText.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(searchText) ||
                invoice.customerName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return invoices
    }
}

struct InvoiceRowView: View {
    let invoice: Invoice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.invoiceNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(invoice.customerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", (invoice.amount as NSDecimalNumber).doubleValue))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Balance: \(String(format: "$%.2f", (invoice.balance as NSDecimalNumber).doubleValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                StatusBadge(status: invoice.status)
                
                Spacer()
                
                if let dueDate = invoice.dueDate {
                    Text("Due: \(dueDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: Invoice.InvoiceStatus
    
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
        case .pending: return .orange
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .gray
        }
    }
}

struct InvoiceDetailView: View {
    let invoice: Invoice
    @ObservedObject var viewModel: InvoiceViewModel
    @State private var showingEditInvoice = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Invoice Header
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(invoice.invoiceNumber)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(invoice.customerName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusBadge(status: invoice.status)
                    }
                    
                    Divider()
                    
                    // Invoice Details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Total Amount:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "$%.2f", (invoice.amount as NSDecimalNumber).doubleValue))
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Balance Due:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "$%.2f", (invoice.balance as NSDecimalNumber).doubleValue))
                                .fontWeight(.bold)
                                .foregroundColor(invoice.balance > 0 ? .red : .green)
                        }
                        
                        if let dueDate = invoice.dueDate {
                            HStack {
                                Text("Due Date:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(dueDate, style: .date)
                            }
                        }
                        
                        HStack {
                            Text("Created:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(invoice.createdDate, style: .date)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Invoice Items
                if !invoice.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(invoice.items, id: \.id) { item in
                                InvoiceItemRow(item: item)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                // Notes
                if let notes = invoice.notes, !notes.isEmpty {
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
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        if invoice.status != .paid && invoice.status != .cancelled {
                            ModernQuickActionButton(
                                title: "Process Payment",
                                subtitle: "Accept payment for this invoice",
                                icon: "creditcard.fill",
                                color: .green,
                                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            ) {
                                // Navigate to payment processing
                            }
                        }
                        
                        if invoice.status == .pending {
                            ModernQuickActionButton(
                                title: "Mark as Paid",
                                subtitle: "Mark invoice as fully paid",
                                icon: "checkmark.circle.fill",
                                color: .blue,
                                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            ) {
                                viewModel.markInvoiceAsPaid(invoice)
                            }
                        }
                        
                        ModernQuickActionButton(
                            title: "Send Invoice",
                            subtitle: "Email invoice to customer",
                            icon: "envelope.fill",
                            color: .orange,
                            gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        ) {
                            // Send invoice functionality
                        }
                        
                        ModernQuickActionButton(
                            title: "Print Invoice",
                            subtitle: "Print or save as PDF",
                            icon: "printer.fill",
                            color: .purple,
                            gradient: LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        ) {
                            // Print functionality
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Invoice Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditInvoice = true
                }
            }
        }
        .sheet(isPresented: $showingEditInvoice) {
            EditInvoiceView(invoice: invoice, viewModel: viewModel)
        }
    }
}

struct InvoiceItemRow: View {
    let item: Invoice.InvoiceItem
    
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
            
            Text(String(format: "$%.2f", (item.amount as NSDecimalNumber).doubleValue))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct AddInvoiceView: View {
    @ObservedObject var viewModel: InvoiceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customerId = ""
    @State private var customerName = ""
    @State private var amount: String = ""
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var items: [Invoice.InvoiceItem] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Customer Name", text: $customerName)
                    TextField("Customer ID", text: $customerId)
                }
                
                Section("Invoice Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Invoice")
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
                        
                        viewModel.createInvoice(
                            customerId: customerId,
                            customerName: customerName,
                            amount: amountValue,
                            items: items,
                            dueDate: dueDate
                        )
                        dismiss()
                    }
                    .disabled(customerName.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

struct EditInvoiceView: View {
    let invoice: Invoice
    @ObservedObject var viewModel: InvoiceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customerName: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var notes: String
    
    init(invoice: Invoice, viewModel: InvoiceViewModel) {
        self.invoice = invoice
        self.viewModel = viewModel
        
        _customerName = State(initialValue: invoice.customerName)
        _amount = State(initialValue: String(describing: invoice.amount))
        _dueDate = State(initialValue: invoice.dueDate ?? Date())
        _notes = State(initialValue: invoice.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Customer Name", text: $customerName)
                }
                
                Section("Invoice Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Invoice")
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
                        
                        let updatedInvoice = Invoice(
                            id: invoice.id,
                            invoiceNumber: invoice.invoiceNumber,
                            customerId: invoice.customerId,
                            customerName: customerName,
                            amount: amountValue,
                            balance: invoice.balance,
                            status: invoice.status,
                            dueDate: dueDate,
                            createdDate: invoice.createdDate,
                            netSuiteId: invoice.netSuiteId,
                            items: invoice.items,
                            notes: notes.isEmpty ? nil : notes
                        )
                        
                        viewModel.updateInvoice(updatedInvoice)
                        dismiss()
                    }
                    .disabled(customerName.isEmpty || amount.isEmpty)
                }
            }
        }
    }
} 