import SwiftUI

struct CustomerListView: View {
    @ObservedObject var viewModel: CustomerViewModel
    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var selectedFilter: CustomerFilter = .all
    
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
                        retryAction: { viewModel.loadCustomers() }
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
                                ModernCustomerCard(
                                    customer: customer,
                                    onTap: {
                                        // Navigate to customer detail
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Customers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCustomer = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.loadCustomers() }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddCustomer) {
                AddCustomerView(viewModel: viewModel)
            }
        }
    }
    
    private var filteredCustomers: [Customer] {
        var customers = viewModel.customers
        
        // Apply search filter
        if !searchText.isEmpty {
            customers = customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.email?.localizedCaseInsensitiveContains(searchText) == true ||
                customer.companyName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            return customers
        case .active:
            return customers.filter { $0.isActive }
        case .inactive:
            return customers.filter { !$0.isActive }
        }
    }
}

// MARK: - Modern Components

struct ModernCustomerCard: View {
    let customer: Customer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
        .buttonStyle(PlainButtonStyle())
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
                            // Navigate to invoice creation
                        }
                        
                        ModernQuickActionButton(
                            title: "Process Payment",
                            subtitle: "Accept payment from this customer",
                            icon: "creditcard.fill",
                            color: .green,
                            gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                        ) {
                            // Navigate to payment processing
                        }
                        
                        ModernQuickActionButton(
                            title: "View History",
                            subtitle: "See all invoices and payments",
                            icon: "clock.fill",
                            color: .orange,
                            gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        ) {
                            // Navigate to customer history
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Customer Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditCustomer) {
            EditCustomerView(customer: customer, viewModel: viewModel)
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