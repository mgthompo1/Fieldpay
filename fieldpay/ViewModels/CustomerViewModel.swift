import Foundation
import Combine

@MainActor
class CustomerViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let netSuiteAPI = NetSuiteAPI.shared
    private let oAuthManager = OAuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for OAuth authentication state changes
        oAuthManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                print("Debug: CustomerViewModel - OAuth authentication state changed to: \(isAuthenticated)")
                if isAuthenticated {
                    print("Debug: CustomerViewModel - OAuth authenticated, loading customers...")
                    self?.loadCustomers()
                } else {
                    print("Debug: CustomerViewModel - OAuth not authenticated, clearing customers...")
                    self?.customers = []
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func loadCustomers() {
        // Check if OAuth is configured before making API calls
        guard OAuthManager.shared.isAuthenticated else {
            errorMessage = "NetSuite OAuth not authenticated. Please go to Settings > NetSuite Settings and complete the OAuth authorization flow."
            
            // Check if OAuth is configured but not authenticated
            let clientId = UserDefaults.standard.string(forKey: "netsuite_client_id") ?? ""
            let clientSecret = UserDefaults.standard.string(forKey: "netsuite_client_secret") ?? ""
            let accountId = UserDefaults.standard.string(forKey: "netsuite_account_id") ?? ""
            
            if !clientId.isEmpty && !clientSecret.isEmpty && !accountId.isEmpty {
                errorMessage = "NetSuite OAuth credentials are configured but not authenticated. Please go to Settings > NetSuite Settings and tap 'Connect to NetSuite' to complete the authorization."
            } else {
                errorMessage = "NetSuite OAuth not configured. Please go to Settings > NetSuite Settings and enter your Client ID, Client Secret, and Account ID, then tap 'Connect to NetSuite'."
            }
            
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Test connection first
                try await netSuiteAPI.testConnection()
                
                let fetchedCustomers = try await netSuiteAPI.fetchCustomers()
                customers = fetchedCustomers
                isLoading = false
            } catch {
                errorMessage = "Failed to load customers: \(error.localizedDescription)"
                isLoading = false
                print("Debug: CustomerViewModel - Error loading customers: \(error)")
            }
        }
    }
    
    func loadCustomer(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let customer = try await netSuiteAPI.fetchCustomer(id: id)
                selectedCustomer = customer
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func searchCustomers(query: String) {
        guard !query.isEmpty else {
            loadCustomers()
            return
        }
        
        let filteredCustomers = customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(query) ||
            customer.email?.localizedCaseInsensitiveContains(query) == true ||
            customer.companyName?.localizedCaseInsensitiveContains(query) == true
        }
        
        // In a real app, you might want to search on the server side
        customers = filteredCustomers
    }
    
    func createCustomer(name: String, email: String?, phone: String?, companyName: String?) {
        let newCustomer = Customer(
            name: name,
            email: email,
            phone: phone,
            companyName: companyName
        )
        
        // In a real app, you would save this to NetSuite
        customers.append(newCustomer)
    }
    
    func updateCustomer(_ customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index] = customer
        }
        
        // In a real app, you would update this in NetSuite
    }
    
    func deleteCustomer(_ customer: Customer) {
        customers.removeAll { $0.id == customer.id }
        
        // In a real app, you would delete this from NetSuite
    }
    
    func getCustomerById(_ id: String) -> Customer? {
        return customers.first { $0.id == id }
    }
    
    func getCustomersByStatus(isActive: Bool) -> [Customer] {
        return customers.filter { $0.isActive == isActive }
    }
} 