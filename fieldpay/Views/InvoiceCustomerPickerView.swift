import SwiftUI

struct InvoiceCustomerPickerView: View {
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
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading customers...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredCustomers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No customers found")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if !searchText.isEmpty {
                            Text("Try adjusting your search terms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Add customers in the Customers tab")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredCustomers, id: \.id) { customer in
                        CustomerPickerRow(
                            customer: customer,
                            isSelected: selectedCustomer?.id == customer.id
                        ) {
                            selectedCustomer = customer
                            dismiss()
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadCustomers()
            }
        }
        .onChange(of: searchText) { _ in
            Task {
                await loadCustomers(searchQuery: searchText)
            }
        }
    }
    
    private var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customerViewModel.customers
        } else {
            return customerViewModel.customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.companyName?.localizedCaseInsensitiveContains(searchText) == true ||
                customer.email?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    private func loadCustomers(searchQuery: String = "") async {
        do {
            let customers = try await customerViewModel.searchCustomers(query: searchQuery)
            await MainActor.run {
                customerViewModel.customers = customers
            }
        } catch {
            print("Failed to load customers: \(error)")
        }
    }
}

struct CustomerPickerRow: View {
    let customer: Customer
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
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
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    InvoiceCustomerPickerView(selectedCustomer: .constant(nil))
}