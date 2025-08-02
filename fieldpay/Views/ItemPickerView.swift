import SwiftUI

struct ItemPickerView: View {
    let invoiceViewModel: InvoiceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedItems: Set<String> = []
    @State private var itemQuantities: [String: Double] = [:]
    @State private var customPrices: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search items...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Items List
                if invoiceViewModel.isLoadingItems {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading items...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No items found")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if !searchText.isEmpty {
                            Text("Try adjusting your search terms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No items available in NetSuite")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems, id: \.id) { item in
                            ItemPickerRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                quantity: itemQuantities[item.id] ?? 1.0,
                                customPrice: customPrices[item.id] ?? "",
                                onToggleSelection: {
                                    toggleSelection(for: item)
                                },
                                onQuantityChanged: { quantity in
                                    itemQuantities[item.id] = quantity
                                },
                                onPriceChanged: { price in
                                    customPrices[item.id] = price
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Bottom Action Bar
                if !selectedItems.isEmpty {
                    VStack(spacing: 12) {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(selectedItems.count) item(s) selected")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Total: \(formatCurrency(calculateSelectedTotal()))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Add to Invoice") {
                                addSelectedItems()
                                dismiss()
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                    }
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        selectedItems.removeAll()
                        itemQuantities.removeAll()
                        customPrices.removeAll()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
        }
        .onAppear {
            // Initialize quantities for all items
            for item in invoiceViewModel.availableItems {
                if itemQuantities[item.id] == nil {
                    itemQuantities[item.id] = 1.0
                }
            }
        }
    }
    
    private var filteredItems: [NetSuiteItem] {
        if searchText.isEmpty {
            return invoiceViewModel.availableItems
        } else {
            return invoiceViewModel.availableItems.filter { item in
                item.displayName.localizedCaseInsensitiveContains(searchText) ||
                item.itemId.localizedCaseInsensitiveContains(searchText) ||
                item.itemDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func toggleSelection(for item: NetSuiteItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func calculateSelectedTotal() -> Decimal {
        var total = Decimal(0)
        
        for itemId in selectedItems {
            guard let item = invoiceViewModel.availableItems.first(where: { $0.id == itemId }) else { continue }
            
            let quantity = itemQuantities[itemId] ?? 1.0
            let price: Double
            
            if let customPriceString = customPrices[itemId],
               !customPriceString.isEmpty,
               let customPrice = Double(customPriceString) {
                price = customPrice
            } else {
                price = item.basePrice
            }
            
            total += Decimal(price * quantity)
        }
        
        return total
    }
    
    private func addSelectedItems() {
        for itemId in selectedItems {
            guard let item = invoiceViewModel.availableItems.first(where: { $0.id == itemId }) else { continue }
            
            let quantity = itemQuantities[itemId] ?? 1.0
            let customPrice: Double?
            
            if let customPriceString = customPrices[itemId],
               !customPriceString.isEmpty,
               let price = Double(customPriceString) {
                customPrice = price
            } else {
                customPrice = nil
            }
            
            invoiceViewModel.addItemToInvoice(
                item: item,
                quantity: quantity,
                customPrice: customPrice
            )
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

struct ItemPickerRow: View {
    let item: NetSuiteItem
    let isSelected: Bool
    let quantity: Double
    let customPrice: String
    let onToggleSelection: () -> Void
    let onQuantityChanged: (Double) -> Void
    let onPriceChanged: (String) -> Void
    
    @State private var quantityText: String
    @State private var priceText: String
    @State private var isExpanded: Bool = false
    
    init(
        item: NetSuiteItem,
        isSelected: Bool,
        quantity: Double,
        customPrice: String,
        onToggleSelection: @escaping () -> Void,
        onQuantityChanged: @escaping (Double) -> Void,
        onPriceChanged: @escaping (String) -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.quantity = quantity
        self.customPrice = customPrice
        self.onToggleSelection = onToggleSelection
        self.onQuantityChanged = onQuantityChanged
        self.onPriceChanged = onPriceChanged
        
        self._quantityText = State(initialValue: String(format: "%.1f", quantity))
        self._priceText = State(initialValue: customPrice.isEmpty ? String(format: "%.2f", item.basePrice) : customPrice)
        self._isExpanded = State(initialValue: isSelected)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: {
                onToggleSelection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = !isExpanded
                }
            }) {
                HStack {
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                    
                    // Item info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(item.itemDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Text("Base Price: \(item.formattedPrice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Type: \(item.itemType)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Expand indicator
                    if isSelected {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details (quantity and price adjustment)
            if isSelected && isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 16) {
                        // Quantity field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quantity")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            TextField("Qty", text: $quantityText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .onSubmit {
                                    if let newQuantity = Double(quantityText), newQuantity > 0 {
                                        onQuantityChanged(newQuantity)
                                    } else {
                                        quantityText = String(format: "%.1f", quantity)
                                    }
                                }
                        }
                        
                        // Custom price field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Price (optional)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            TextField("Price", text: $priceText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .onSubmit {
                                    onPriceChanged(priceText)
                                }
                        }
                        
                        Spacer()
                        
                        // Line total
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Line Total")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(calculateLineTotal())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    private func calculateLineTotal() -> String {
        let qty = Double(quantityText) ?? quantity
        let price: Double
        
        if !priceText.isEmpty, let customPrice = Double(priceText) {
            price = customPrice
        } else {
            price = item.basePrice
        }
        
        let total = price * qty
        return String(format: "$%.2f", total)
    }
}

#Preview {
    ItemPickerView(invoiceViewModel: InvoiceViewModel())
}