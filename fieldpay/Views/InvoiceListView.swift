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
        let nsDecimal = NSDecimalNumber(decimal: amount)
        if nsDecimal == NSDecimalNumber.notANumber {
            return "$0.00"
        }
        return formatter.string(from: nsDecimal) ?? "$0.00"
    }

    func format(_ amount: Double) -> String {
        guard amount.isFinite else { return "$0.00" }
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct InvoiceListView: View {
    @ObservedObject var viewModel: InvoiceViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @State private var searchText = ""
    @State private var selectedStatus: AppInvoiceStatus?
    @State private var showingAddInvoice = false
    @State private var debouncedSearchText = ""
    @State private var showingCustomerSearch = false
    @State private var selectedCustomerForSearch: Customer?
    @State private var searchTask: Task<Void, Never>? // cancelable debounce

    var body: some View {
        NavigationView {
            ZStack {
                FieldPayBackground()
                
                VStack {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView("Loading invoices...")
                            .scaleEffect(1.2)
                        Text("Please wait while we fetch your invoices")
                            .font(FieldPayFont.caption)
                            .foregroundColor(FieldPayTheme.inkMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fieldPayCard(padding: 24, cornerRadius: 18)
                    .allowsHitTesting(false)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(FieldPayTheme.highlight)
                        Text("Unable to Load Invoices")
                            .font(FieldPayFont.title2)
                            .foregroundColor(FieldPayTheme.ink)
                        Text(errorMessage)
                            .font(FieldPayFont.body)
                            .foregroundColor(FieldPayTheme.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") {
                            viewModel.resetPagination()
                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fieldPayCard(padding: 24, cornerRadius: 18)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Show active filters
                            if selectedStatus != nil || selectedCustomerForSearch != nil {
                                HStack {
                                    if let status = selectedStatus {
                                        HStack {
                                            Text(status.displayName)
                                                .font(FieldPayFont.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(FieldPayTheme.accent.opacity(0.2))
                                                .foregroundColor(FieldPayTheme.accent)
                                                .clipShape(Capsule())

                                            Button(action: {
                                                selectedStatus = nil
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(FieldPayTheme.accent)
                                            }
                                        }
                                    }

                                    if let customer = selectedCustomerForSearch {
                                        HStack {
                                            Text("Customer: \(customer.name)")
                                                .font(FieldPayFont.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(FieldPayTheme.success.opacity(0.2))
                                                .foregroundColor(FieldPayTheme.success)
                                                .clipShape(Capsule())

                                            Button(action: {
                                                selectedCustomerForSearch = nil
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(FieldPayTheme.success)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Button("Clear All") {
                                        selectedStatus = nil
                                        selectedCustomerForSearch = nil
                                    }
                                    .font(FieldPayFont.caption)
                                    .foregroundColor(FieldPayTheme.inkMuted)
                                }
                                .padding(.horizontal)
                            }

                            ForEach(filteredInvoices) { invoice in
                                NavigationLink(destination: InvoiceDetailView(invoice: invoice, viewModel: viewModel, customerViewModel: customerViewModel)) {
                                    InvoiceRowView(invoice: invoice)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            // Load more indicator
                            if viewModel.hasMore && !viewModel.isLoading {
                                Button(action: {
                                    Task { await viewModel.loadNextPage() }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle")
                                        Text("Load More")
                                    }
                                    .foregroundColor(FieldPayTheme.accent)
                                    .padding()
                                }
                            }

                            // Loading indicator for pagination
                            if viewModel.isLoading && !filteredInvoices.isEmpty {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more invoices...")
                                        .font(FieldPayFont.caption)
                                        .foregroundColor(FieldPayTheme.inkMuted)
                                }
                                .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                    .searchable(text: $searchText, prompt: "Search invoices")
                    .accessibilityLabel("Search invoices by number or customer name")
                    .onChange(of: searchText) { _, newValue in
                        // Cancel previous debounce, start a new one
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s debounce
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                debouncedSearchText = newValue
                                viewModel.searchInvoices(query: newValue)
                            }
                        }
                    }
                    .onAppear {
                        if filteredInvoices.isEmpty && !viewModel.isLoading {
                            Task { await viewModel.loadNextPage() }
                        }
                    }
                    .onDisappear { searchTask?.cancel() }
                    .overlay {
                        if filteredInvoices.isEmpty && !searchText.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(FieldPayTheme.inkMuted)
                                Text("No invoices found")
                                    .font(FieldPayFont.headline)
                                    .foregroundColor(FieldPayTheme.ink)
                                Text("Try adjusting your search terms")
                                    .font(FieldPayFont.caption)
                                    .foregroundColor(FieldPayTheme.inkMuted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if filteredInvoices.isEmpty && selectedStatus != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 32))
                                    .foregroundColor(FieldPayTheme.inkMuted)
                                Text("No \(selectedStatus?.displayName.lowercased() ?? "") invoices")
                                    .font(FieldPayFont.headline)
                                    .foregroundColor(FieldPayTheme.ink)
                                Text("Try selecting a different status")
                                    .font(FieldPayFont.caption)
                                    .foregroundColor(FieldPayTheme.inkMuted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if filteredInvoices.isEmpty && selectedCustomerForSearch != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 32))
                                    .foregroundColor(FieldPayTheme.inkMuted)
                                Text("No invoices for \(selectedCustomerForSearch?.name ?? "this customer")")
                                    .font(FieldPayFont.headline)
                                    .foregroundColor(FieldPayTheme.ink)
                                Text("Try selecting a different customer")
                                    .font(FieldPayFont.caption)
                                    .foregroundColor(FieldPayTheme.inkMuted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Invoices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInvoice = true }) { Image(systemName: "plus") }
                        .accessibilityLabel("Add new invoice")
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.resetPagination()
                        Task { await viewModel.loadNextPage() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh invoices")
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Invoices") {
                            selectedStatus = nil
                            selectedCustomerForSearch = nil
                        }
                        ForEach(AppInvoiceStatus.allCases, id: \.self) { status in
                            Button(status.displayName) { selectedStatus = status }
                        }
                        Divider()
                        Button("Search by Customer") { showingCustomerSearch = true }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter invoices by status or search by customer")
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                NewInvoiceView(invoiceViewModel: viewModel, customerViewModel: customerViewModel)
            }
            .sheet(isPresented: $showingCustomerSearch) {
                CustomerSearchView(
                    customerViewModel: customerViewModel,
                    onCustomerSelected: { customer in
                        selectedCustomerForSearch = customer
                        viewModel.filterInvoicesByCustomer(customer.id)
                        showingCustomerSearch = false
                    }
                )
            }
        }
    }

    }

    private var filteredInvoices: [Invoice] {
        var invoices = viewModel.invoices

        if let selectedStatus = selectedStatus {
            invoices = invoices.filter { $0.status == selectedStatus }
        }

        if let selectedCustomer = selectedCustomerForSearch {
            invoices = invoices.filter { $0.customerId == selectedCustomer.id }
        }

        if !debouncedSearchText.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(debouncedSearchText) ||
                invoice.customerName.localizedCaseInsensitiveContains(debouncedSearchText)
            }
        }

        // Always sort by createdDate in descending order (newest first)
        return invoices.sorted { $0.createdDate > $1.createdDate }
    }
}

struct CustomerSearchView: View {
    @ObservedObject var customerViewModel: CustomerViewModel
    let onCustomerSelected: (Customer) -> Void
    @State private var searchText = ""
    @State private var customers: [Customer] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>? // cancelable debounce
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading customers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredCustomers) { customer in
                        Button(action: {
                            onCustomerSelected(customer)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(customer.name)
                                    .font(.headline)
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
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .searchable(text: $searchText, prompt: "Search customers")
                    .onChange(of: searchText) { _, newValue in
                        // cancel previous debounce
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            guard !Task.isCancelled else { return }
                            await loadCustomers(searchQuery: newValue)
                        }
                    }
                }
            }
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { Task { await loadCustomers() } }
            .onDisappear { searchTask?.cancel() }
        }
    }

    private var filteredCustomers: [Customer] {
        if searchText.isEmpty { return customers }
        return customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(searchText) ||
            customer.companyName?.localizedCaseInsensitiveContains(searchText) == true ||
            customer.email?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private func loadCustomers(searchQuery: String = "") async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedCustomers = try await customerViewModel.searchCustomers(query: searchQuery)
            await MainActor.run { self.customers = loadedCustomers }
        } catch {
            print("Failed to load customers: \(error)")
        }
    }
}

struct InvoiceRowView: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.invoiceNumber)
                        .font(FieldPayFont.headline)
                        .foregroundColor(FieldPayTheme.ink)
                        .accessibilityLabel("Invoice number")

                    Text(invoice.customerName)
                        .font(FieldPayFont.callout)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .accessibilityLabel("Customer name")
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(CurrencyFormatter.shared.format(invoice.amount))
                        .font(FieldPayFont.headline)
                        .foregroundColor(FieldPayTheme.ink)
                        .accessibilityLabel("Invoice amount")

                    Text("Balance: \(CurrencyFormatter.shared.format(invoice.balance))")
                        .font(FieldPayFont.caption)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .accessibilityLabel("Balance due")
                }
            }

            HStack {
                StatusBadge(status: invoice.status)
                    .accessibilityLabel("Invoice status: \(invoice.status.displayName)")

                Spacer()

                if let dueDate = invoice.dueDate {
                    Text("Due: \(dueDate, style: .date)")
                        .font(FieldPayFont.caption)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .accessibilityLabel("Due date")
                }
            }
        }
        .fieldPayCard(padding: 16, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Invoice \(invoice.invoiceNumber) for \(invoice.customerName), amount \(CurrencyFormatter.shared.format(invoice.amount)), status \(invoice.status.displayName)")
    }
}

struct StatusBadge: View {
    let status: AppInvoiceStatus

    var body: some View {
        Text(status.displayName)
            .font(FieldPayFont.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .pending: return FieldPayTheme.highlight
        case .paid: return FieldPayTheme.success
        case .overdue: return FieldPayTheme.danger
        case .cancelled: return FieldPayTheme.inkMuted
        }
    }
}

struct InvoiceDetailView: View {
    let invoice: Invoice
    @ObservedObject var viewModel: InvoiceViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @State private var showingEditInvoice = false
    @State private var showingPaymentSheet = false

    private var currentInvoice: Invoice { viewModel.getInvoiceById(invoice.id) ?? invoice }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Invoice Header
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentInvoice.invoiceNumber)
                                .font(FieldPayFont.title)
                                .foregroundColor(FieldPayTheme.ink)

                            Text(currentInvoice.customerName)
                                .font(FieldPayFont.callout)
                                .foregroundColor(FieldPayTheme.inkMuted)
                        }

                        Spacer()

                        StatusBadge(status: currentInvoice.status)
                    }

                    Divider()

                    // Invoice Details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Total Amount:")
                                .font(FieldPayFont.callout)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(currentInvoice.amount))
                                .font(FieldPayFont.headline)
                        }

                        HStack {
                            Text("Balance Due:")
                                .font(FieldPayFont.callout)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(currentInvoice.balance))
                                .font(FieldPayFont.headline)
                                .foregroundColor(currentInvoice.balance > 0 ? FieldPayTheme.danger : FieldPayTheme.success)
                        }

                        if let dueDate = currentInvoice.dueDate {
                            HStack {
                                Text("Due Date:")
                                    .font(FieldPayFont.callout)
                                Spacer()
                                Text(dueDate, style: .date)
                            }
                        }

                        HStack {
                            Text("Created:")
                                .font(FieldPayFont.callout)
                            Spacer()
                            Text(currentInvoice.createdDate, style: .date)
                        }
                    }
                }
                .fieldPayCard(padding: 20, cornerRadius: 20)

                // Invoice Items
                if !currentInvoice.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(FieldPayFont.headline)

                        VStack(spacing: 8) {
                            ForEach(currentInvoice.items, id: \.id) { item in
                                InvoiceItemRow(item: item)
                            }
                        }
                    }
                    .fieldPayCard(padding: 20, cornerRadius: 20)
                }

                // Notes
                if let notes = currentInvoice.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(FieldPayFont.headline)

                        Text(notes)
                            .font(FieldPayFont.body)
                            .foregroundColor(FieldPayTheme.inkMuted)
                    }
                    .fieldPayCard(padding: 20, cornerRadius: 20)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(FieldPayFont.headline)

                    VStack(spacing: 8) {
                        if currentInvoice.status != .paid && currentInvoice.status != .cancelled {
                            ModernQuickActionButton(
                                title: "Process Payment",
                                subtitle: "Accept payment for this invoice",
                                icon: "creditcard.fill",
                                color: .green,
                                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            ) {
                                showingPaymentSheet = true
                            }
                        }

                        if currentInvoice.status == .pending {
                            ModernQuickActionButton(
                                title: "Mark as Paid",
                                subtitle: "Mark invoice as fully paid",
                                icon: "checkmark.circle.fill",
                                color: .blue,
                                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            ) {
                                Task {
                                    await viewModel.markInvoiceAsPaid(currentInvoice)
                                }
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
                Button("Edit") { showingEditInvoice = true }
            }
        }
        .sheet(isPresented: $showingEditInvoice) {
            // Minimal placeholder to satisfy build; replace with actual editor if needed
            Text("Edit Invoice coming soon")
        }
        .sheet(isPresented: $showingPaymentSheet) {
            InvoicePaymentView(invoice: currentInvoice, customerViewModel: customerViewModel, onPaymentSuccess: {
                Task { await viewModel.loadInvoiceDetail(id: currentInvoice.id) }
            })
        }
    }
}

struct InvoicePaymentView: View {
    let invoice: Invoice
    let onPaymentSuccess: (() -> Void)?
    let customerViewModel: CustomerViewModel

    @StateObject private var paymentViewModel = PaymentViewModel()
    @Environment(\.dismiss) private var dismiss

    init(invoice: Invoice, customerViewModel: CustomerViewModel, onPaymentSuccess: (() -> Void)? = nil) {
        self.invoice = invoice
        self.customerViewModel = customerViewModel
        self.onPaymentSuccess = onPaymentSuccess
    }

    @State private var selectedPaymentMethod: PaymentMethodType = .tapToPay
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var showingAmountInput = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Process Payment")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Invoice #\(invoice.invoiceNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Invoice Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invoice Amount")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text("Customer: \(invoice.customerName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(CurrencyFormatter.shared.format(invoice.amount))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Text("Balance: \(CurrencyFormatter.shared.format(invoice.balance))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        // Payment Method Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Payment Method")
                                .font(.headline)
                                .fontWeight(.semibold)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(PaymentMethodType.quickPaymentMethods, id: \.self) { method in
                                    ModernPaymentMethodButton(
                                        method: method,
                                        isSelected: selectedPaymentMethod == method
                                    ) { selectedPaymentMethod = method }
                                }
                            }
                        }

                        // Amount Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Payment Amount")
                                .font(.headline)
                                .fontWeight(.semibold)

                            HStack {
                                Text("$")
                                    .font(.title2)
                                    .foregroundColor(.secondary)

                                TextField("0.00", text: $amount)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .keyboardType(.decimalPad)
                                    .onAppear {
                                        // Pre-fill with invoice balance
                                        amount = String(format: "%.2f", (invoice.balance as NSDecimalNumber).doubleValue)
                                    }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Description Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (Optional)")
                                .font(.headline)
                                .fontWeight(.semibold)

                            TextField("Payment for invoice #\(invoice.invoiceNumber)", text: $description)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onAppear {
                                    description = "Payment for invoice #\(invoice.invoiceNumber)"
                                }
                        }

                        // Process Payment Button
                        Button(action: {
                            guard let amountValue = Decimal(string: amount), amountValue > 0 else { return }

                            Task {
                                await paymentViewModel.processPayment(
                                    amount: amountValue,
                                    paymentMethod: selectedPaymentMethod,
                                    customerId: invoice.customerId,
                                    invoiceId: invoice.id,
                                    description: description.isEmpty ? "Payment for invoice #\(invoice.invoiceNumber)" : description
                                )

                                // Close the sheet after successful payment
                                if paymentViewModel.errorMessage == nil {
                                    onPaymentSuccess?()
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                if paymentViewModel.isProcessingPayment {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "creditcard.fill")
                                        .font(.title3)
                                }

                                Text(paymentViewModel.isProcessingPayment ? "Processing..." : "Process Payment")
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
                        .disabled(amount.isEmpty || paymentViewModel.isProcessingPayment)
                        .opacity(amount.isEmpty ? 0.6 : 1.0)

                        // Error Message
                        if let errorMessage = paymentViewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .onAppear { paymentViewModel.setCustomerViewModel(customerViewModel) }
        }
    }
}

struct InvoiceItemRow: View {
    let item: AppInvoiceItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Qty: \(String(format: "%.0f", item.quantity)) × \(CurrencyFormatter.shared.format(item.unitPrice))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.shared.format(item.amount))
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
    @State private var items: [AppInvoiceItem] = []
    @State private var showingAmountError = false
    @State private var isSaving = false

    private var isValidAmount: Bool {
        guard !amount.isEmpty else { return false }
        return Decimal(string: amount) != nil
    }

    private var canSave: Bool { !customerName.isEmpty && !amount.isEmpty && isValidAmount && !isSaving }

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
                        .onChange(of: amount) { _, _ in showingAmountError = false }

                    if showingAmountError {
                        Text("Please enter a valid amount")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }

                Section("Notes") { TextEditor(text: $notes).frame(minHeight: 100) }
            }
            .navigationTitle("Add Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save logic would go here
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
