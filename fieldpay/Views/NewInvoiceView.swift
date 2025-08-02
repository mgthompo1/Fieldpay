import SwiftUI
import Combine

struct NewInvoiceView: View {
    @StateObject private var invoiceViewModel = InvoiceViewModel()
    @StateObject private var customerViewModel = CustomerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCustomer: Customer?
    @State private var showingCustomerPicker = false
    @State private var invoiceNumber = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var showingItemPicker = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create New Invoice")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Add items and customer details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 20) {
                        // Customer Selection
                        customerSelectionSection
                        
                        // Invoice Details
                        invoiceDetailsSection
                        
                        // Selected Items
                        selectedItemsSection
                        
                        // Add Items Button
                        addItemsButton
                        
                        // Total Section
                        totalSection
                        
                        // Create Invoice Button
                        createInvoiceButton
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCustomerPicker) {
                InvoiceCustomerPickerView(selectedCustomer: $selectedCustomer)
            }
            .sheet(isPresented: $showingItemPicker) {
                ItemPickerView(invoiceViewModel: invoiceViewModel)
            }
            .onAppear {
                generateInvoiceNumber()
                Task {
                    await invoiceViewModel.loadAvailableItems()
                }
            }
        }
    }
    
    // MARK: - Customer Selection Section
    
    private var customerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customer")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if selectedCustomer != nil {
                    Button("Change") {
                        showingCustomerPicker = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            if let customer = selectedCustomer {
                CustomerCard(customer: customer)
            } else {
                Button(action: {
                    showingCustomerPicker = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Customer")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Choose a customer for this invoice")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Invoice Details Section
    
    private var invoiceDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invoice Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Invoice #")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("Invoice Number", text: $invoiceNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Due Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .leading)
                    
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Add notes for this invoice", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Selected Items Section
    
    private var selectedItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Line Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(invoiceViewModel.selectedItems.count) item(s)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if invoiceViewModel.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No items added yet")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Tap 'Add Items' to select products or services")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(invoiceViewModel.selectedItems) { item in
                        SelectedItemRow(
                            item: item,
                            onQuantityChanged: { newQuantity in
                                invoiceViewModel.updateItemQuantity(itemId: item.id, quantity: newQuantity)
                            },
                            onRemove: {
                                invoiceViewModel.removeItemFromInvoice(itemId: item.id)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Add Items Button
    
    private var addItemsButton: some View {
        Button(action: {
            showingItemPicker = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                
                Text("Add Items")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(invoiceViewModel.isLoadingItems)
    }
    
    // MARK: - Total Section
    
    private var totalSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack {
                Text("Total Amount")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(formatCurrency(invoiceViewModel.selectedItemsTotal))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Create Invoice Button
    
    private var createInvoiceButton: some View {
        Button(action: createInvoice) {
            HStack {
                if invoiceViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                }
                
                Text(invoiceViewModel.isLoading ? "Creating Invoice..." : "Create Invoice")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreateInvoice ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreateInvoice || invoiceViewModel.isLoading)
    }
    
    // MARK: - Helper Properties
    
    private var canCreateInvoice: Bool {
        selectedCustomer != nil &&
        !invoiceNumber.isEmpty &&
        !invoiceViewModel.selectedItems.isEmpty &&
        invoiceViewModel.selectedItemsTotal > 0
    }
    
    // MARK: - Helper Methods
    
    private func generateInvoiceNumber() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        invoiceNumber = "INV-\(dateString)-\(Int.random(in: 1000...9999))"
    }
    
    private func createInvoice() {
        guard let customer = selectedCustomer else { return }
        
        // TODO: Implement actual invoice creation with NetSuite API
        // This would involve creating the invoice record with line items
        
        Task {
            // Simulate creation process
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                // Clear form
                invoiceViewModel.clearSelectedItems()
                selectedCustomer = nil
                generateInvoiceNumber()
                notes = ""
                
                // Show success and dismiss
                dismiss()
            }
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Supporting Views

struct CustomerCard: View {
    let customer: Customer
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let company = customer.companyName, !company.isEmpty {
                    Text(company)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let email = customer.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
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
        self._quantityText = State(initialValue: String(format: "%.1f", item.quantity))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.itemName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Qty", text: $quantityText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .onSubmit {
                            if let quantity = Double(quantityText), quantity > 0 {
                                onQuantityChanged(quantity)
                            } else {
                                quantityText = String(format: "%.1f", item.quantity)
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.formattedUnitPrice)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.formattedAmount)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NewInvoiceView()
}