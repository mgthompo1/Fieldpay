import SwiftUI

// MARK: - Currency Formatter
struct CurrencyFormatter {
    static let shared = CurrencyFormatter()
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    func format(_ amount: Decimal) -> String {
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

struct InvoiceListView: View {
    @ObservedObject var viewModel: InvoiceViewModel
    @State private var searchText = ""
    @State private var selectedStatus: Invoice.InvoiceStatus?
    @State private var showingAddInvoice = false
    @State private var debouncedSearchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView("Loading invoices...")
                            .scaleEffect(1.2)
                        Text("Please wait while we fetch your invoices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .allowsHitTesting(false)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Unable to Load Invoices")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") {
                            viewModel.loadInvoices()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(filteredInvoices) { invoice in
                            NavigationLink(destination: InvoiceDetailView(invoice: invoice, viewModel: viewModel)) {
                                InvoiceRowView(invoice: invoice)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search invoices")
                    .accessibilityLabel("Search invoices by number or customer name")
                    .onChange(of: searchText) { _, newValue in
                        // Debounce search to avoid excessive API calls
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            if searchText == newValue {
                                await MainActor.run {
                                    debouncedSearchText = newValue
                                    viewModel.searchInvoices(query: newValue)
                                }
                            }
                        }
                    }
                    .overlay {
                        if filteredInvoices.isEmpty && !searchText.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No invoices found")
                                    .font(.headline)
                                Text("Try adjusting your search terms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if filteredInvoices.isEmpty && selectedStatus != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No \(selectedStatus?.displayName.lowercased() ?? "") invoices")
                                    .font(.headline)
                                Text("Try selecting a different status")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    // Performance optimization for large lists
                    .environment(\.defaultMinListRowHeight, 80)
                }
            }
            .navigationTitle("Invoices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInvoice = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new invoice")
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.loadInvoices() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh invoices")
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
                    .accessibilityLabel("Filter invoices by status")
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
        
        if !debouncedSearchText.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(debouncedSearchText) ||
                invoice.customerName.localizedCaseInsensitiveContains(debouncedSearchText)
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
                        .accessibilityLabel("Invoice number")
                    
                    Text(invoice.customerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Customer name")
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(CurrencyFormatter.shared.format((invoice.amount as NSDecimalNumber).decimalValue))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .accessibilityLabel("Invoice amount")
                    
                    Text("Balance: \(CurrencyFormatter.shared.format((invoice.balance as NSDecimalNumber).decimalValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Balance due")
                }
            }
            
            HStack {
                StatusBadge(status: invoice.status)
                    .accessibilityLabel("Invoice status: \(invoice.status.displayName)")
                
                Spacer()
                
                if let dueDate = invoice.dueDate {
                    Text("Due: \(dueDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Due date")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Invoice \(invoice.invoiceNumber) for \(invoice.customerName), amount \(CurrencyFormatter.shared.format((invoice.amount as NSDecimalNumber).decimalValue)), status \(invoice.status.displayName)")
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
                            Text(CurrencyFormatter.shared.format((invoice.amount as NSDecimalNumber).decimalValue))
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Balance Due:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(CurrencyFormatter.shared.format((invoice.balance as NSDecimalNumber).decimalValue))
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
                
                Text("Qty: \(String(format: "%.0f", item.quantity)) × \(CurrencyFormatter.shared.format((item.unitPrice as NSDecimalNumber).decimalValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(CurrencyFormatter.shared.format((item.amount as NSDecimalNumber).decimalValue))
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
    @State private var showingAmountError = false
    @State private var isSaving = false
    
    private var isValidAmount: Bool {
        guard !amount.isEmpty else { return false }
        return Decimal(string: amount) != nil
    }
    
    private var canSave: Bool {
        !customerName.isEmpty && !amount.isEmpty && isValidAmount && !isSaving
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Customer Name", text: $customerName)
                        .textContentType(.name)
                    TextField("Customer ID", text: $customerId)
                        .textContentType(.none)
                }
                
                Section("Invoice Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .onChange(of: amount) { _, newValue in
                            showingAmountError = false
                        }
                    
                    if showingAmountError {
                        Text("Please enter a valid amount")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
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
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createInvoice()
                    }
                    .disabled(!canSave)
                }
            }
            .overlay {
                if isSaving {
                    VStack {
                        ProgressView("Creating invoice...")
                            .scaleEffect(1.2)
                        Text("Please wait")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    private func createInvoice() {
        guard let amountValue = Decimal(string: amount) else {
            showingAmountError = true
            return
        }
        
        isSaving = true
        
        viewModel.createInvoice(
            customerId: customerId,
            customerName: customerName,
            amount: amountValue,
            items: items,
            dueDate: dueDate
        )
        
        // Simulate a brief delay to show the saving state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
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
    @State private var showingAmountError = false
    @State private var isSaving = false
    
    private var isValidAmount: Bool {
        guard !amount.isEmpty else { return false }
        return Decimal(string: amount) != nil
    }
    
    private var canSave: Bool {
        !customerName.isEmpty && !amount.isEmpty && isValidAmount && !isSaving
    }
    
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
                        .textContentType(.name)
                }
                
                Section("Invoice Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .onChange(of: amount) { _, newValue in
                            showingAmountError = false
                        }
                    
                    if showingAmountError {
                        Text("Please enter a valid amount")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
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
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateInvoice()
                    }
                    .disabled(!canSave)
                }
            }
            .overlay {
                if isSaving {
                    VStack {
                        ProgressView("Updating invoice...")
                            .scaleEffect(1.2)
                        Text("Please wait")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    private func updateInvoice() {
        guard let amountValue = Decimal(string: amount) else {
            showingAmountError = true
            return
        }
        
        isSaving = true
        
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
        
        // Simulate a brief delay to show the saving state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
} 