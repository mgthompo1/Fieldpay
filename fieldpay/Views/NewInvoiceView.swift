import SwiftUI
import Combine

/// New Invoice creation screen – wired to create an invoice via InvoiceViewModel
struct NewInvoiceView: View {
    // Inject existing view models; do NOT create new ones here, or you'll be writing to a different store
    @ObservedObject var invoiceViewModel: InvoiceViewModel
    @ObservedObject var customerViewModel: CustomerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCustomer: Customer?
    @State private var showingCustomerPicker = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showingItemPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    header
                        .padding(.horizontal, 20)

                    VStack(spacing: 20) {
                        customerSelectionSection
                        invoiceDetailsSection
                        selectedItemsSection
                        addItemsButton
                        totalSection
                        createInvoiceButton
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCustomerPicker) {
                // Reuse the existing customer search sheet we already have in the app
                CustomerSearchView(
                    customerViewModel: customerViewModel,
                    onCustomerSelected: { customer in
                        selectedCustomer = customer
                        showingCustomerPicker = false
                    }
                )
            }
            .sheet(isPresented: $showingItemPicker) {
                ItemPickerView(invoiceViewModel: invoiceViewModel)
            }
            .onAppear {
                Task { await invoiceViewModel.loadAvailableItems() }
            }
            .overlay(alignment: .bottom) {
                if let error = errorMessage ?? invoiceViewModel.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Create New Invoice")
                .font(.largeTitle).fontWeight(.bold)
            Text("Add items and customer details")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var customerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customer").font(.headline).fontWeight(.semibold)
                Spacer()
                if selectedCustomer != nil {
                    Button("Change") { showingCustomerPicker = true }
                        .font(.subheadline).foregroundColor(.blue)
                }
            }

            if let customer = selectedCustomer {
                CustomerCard(customer: customer)
            } else {
                Button(action: { showingCustomerPicker = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus").font(.title2).foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Customer").font(.headline).foregroundColor(.primary)
                            Text("Choose a customer for this invoice").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var invoiceDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invoice Details").font(.headline).fontWeight(.semibold)
            VStack(spacing: 12) {
                HStack {
                    Text("Due Date").font(.subheadline).fontWeight(.medium).frame(width: 100, alignment: .leading)
                    DatePicker("", selection: $dueDate, displayedComponents: .date).datePickerStyle(CompactDatePickerStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)").font(.subheadline).fontWeight(.medium)
                    TextField("Add notes for this invoice", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var selectedItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Line Items").font(.headline).fontWeight(.semibold)
                Spacer()
                Text("\(invoiceViewModel.selectedItems.count) item(s)")
                    .font(.subheadline).foregroundColor(.secondary)
            }

            if invoiceViewModel.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.below.ecg").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("No items added yet").font(.headline).fontWeight(.medium).foregroundColor(.secondary)
                    Text("Tap 'Add Items' to select products or services").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(invoiceViewModel.selectedItems) { item in
                        SelectedItemRow(
                            item: item,
                            onQuantityChanged: { q in invoiceViewModel.updateItemQuantity(itemId: item.id, quantity: q) },
                            onRemove: { invoiceViewModel.removeItemFromInvoice(itemId: item.id) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var addItemsButton: some View {
        Button(action: { showingItemPicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text("Add Items").font(.headline).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(invoiceViewModel.isLoadingItems)
    }

    private var totalSection: some View {
        VStack(spacing: 16) {
            Divider()
            HStack {
                Text("Total Amount").font(.title2).fontWeight(.bold)
                Spacer()
                Text(CurrencyFormatter.shared.format(invoiceViewModel.selectedItemsTotal))
                    .font(.title2).fontWeight(.bold).foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var createInvoiceButton: some View {
        Button(action: createInvoice) {
            HStack {
                if isSubmitting { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.9) }
                else { Image(systemName: "doc.badge.plus").font(.title3) }
                Text(isSubmitting ? "Creating Invoice..." : "Create Invoice").font(.headline).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreateInvoice ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreateInvoice || isSubmitting)
    }

    // MARK: - Helpers

    private var canCreateInvoice: Bool {
        selectedCustomer != nil && !invoiceViewModel.selectedItems.isEmpty && invoiceViewModel.selectedItemsTotal > 0
    }

    private func createInvoice() {
        guard let customer = selectedCustomer else { return }
        isSubmitting = true
        errorMessage = nil

        // Map UI selections (InvoiceItemCreation) into domain AppInvoiceItem
        let items: [AppInvoiceItem] = invoiceViewModel.selectedItems.map { sel in
            AppInvoiceItem(
                id: sel.id,
                description: sel.description,
                quantity: sel.quantity,
                unitPrice: sel.unitPrice,
                amount: sel.amount,
                netSuiteItemId: sel.netSuiteItemId
            )
        }

        let total = invoiceViewModel.selectedItemsTotal

        // Use the VM's create method so the list updates and (if implemented) NetSuite call runs
        invoiceViewModel.createInvoice(
            customerId: customer.id,
            customerName: customer.name,
            amount: total,
            items: items,
            dueDate: dueDate
        )

        // Minimal UX: clear and dismiss (if you later add async NetSuite creation, move this into completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isSubmitting = false
            invoiceViewModel.clearSelectedItems()
            selectedCustomer = nil
            notes = ""
            dismiss()
        }
    }
}

// MARK: - Reused components from your project (CustomerCard, SelectedItemRow)

struct CustomerCard: View {
    let customer: Customer
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name).font(.headline).fontWeight(.semibold)
                if let company = customer.companyName, !company.isEmpty { Text(company).font(.subheadline).foregroundColor(.secondary) }
                if let email = customer.email, !email.isEmpty { Text(email).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct SelectedItemRow: View {
    let item: InvoiceItemCreation
    let onQuantityChanged: (Double) -> Void
    let onRemove: () -> Void

    @State private var quantityText: String

    init(item: InvoiceItemCreation, onQuantityChanged: @escaping (Double) -> Void, onRemove: @escaping () -> Void) {
        self.item = item
        self.onQuantityChanged = onQuantityChanged
        self.onRemove = onRemove
        _quantityText = State(initialValue: String(format: "%.1f", item.quantity))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.itemName).font(.headline).fontWeight(.semibold)
                    Text(item.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                Button(action: onRemove) { Image(systemName: "trash").font(.title3).foregroundColor(.red) }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity").font(.caption).foregroundColor(.secondary)
                    TextField("Qty", text: $quantityText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .onSubmit {
                            if let q = Double(quantityText), q > 0 { onQuantityChanged(q) }
                            else { quantityText = String(format: "%.1f", item.quantity) }
                        }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit Price").font(.caption).foregroundColor(.secondary)
                    Text(item.formattedUnitPrice).font(.subheadline).fontWeight(.medium)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Amount").font(.caption).foregroundColor(.secondary)
                    Text(item.formattedAmount).font(.headline).fontWeight(.bold).foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    // Dummy preview using local VMs; in app, pass real @ObservedObject instances
    NewInvoiceView(invoiceViewModel: InvoiceViewModel(), customerViewModel: CustomerViewModel())
}

