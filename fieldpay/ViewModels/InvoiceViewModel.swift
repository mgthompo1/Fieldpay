import Foundation
import Combine

@MainActor
class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var selectedInvoice: Invoice?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let netSuiteAPI = NetSuiteAPI.shared
    private let oAuthManager = OAuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for OAuth authentication state changes
        oAuthManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                print("Debug: InvoiceViewModel - OAuth authentication state changed to: \(isAuthenticated)")
                if isAuthenticated {
                    print("Debug: InvoiceViewModel - OAuth authenticated, loading invoices...")
                    self?.loadInvoices()
                } else {
                    print("Debug: InvoiceViewModel - OAuth not authenticated, clearing invoices...")
                    self?.invoices = []
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func loadInvoices() {
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
                
                let fetchedInvoices = try await netSuiteAPI.fetchInvoices()
                // Sort invoices by createdDate in descending order (newest first)
                invoices = fetchedInvoices.sorted { $0.createdDate > $1.createdDate }
                isLoading = false
            } catch {
                errorMessage = "Failed to load invoices: \(error.localizedDescription)"
                isLoading = false
                print("Debug: InvoiceViewModel - Error loading invoices: \(error)")
            }
        }
    }
    
    func loadInvoice(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let invoice = try await netSuiteAPI.fetchInvoice(id: id)
                selectedInvoice = invoice
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func searchInvoices(query: String) {
        guard !query.isEmpty else {
            loadInvoices()
            return
        }
        
        let filteredInvoices = invoices.filter { invoice in
            invoice.invoiceNumber.localizedCaseInsensitiveContains(query) ||
            invoice.customerName.localizedCaseInsensitiveContains(query)
        }
        
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByStatus(_ status: Invoice.InvoiceStatus) {
        let filteredInvoices = invoices.filter { $0.status == status }
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func filterInvoicesByCustomer(_ customerId: String) {
        let filteredInvoices = invoices.filter { $0.customerId == customerId }
        // Maintain newest-first sorting order
        invoices = filteredInvoices.sorted { $0.createdDate > $1.createdDate }
    }
    
    func getOverdueInvoices() -> [Invoice] {
        let today = Date()
        return invoices.filter { invoice in
            invoice.status == .overdue ||
            (invoice.dueDate != nil && invoice.dueDate! < today && invoice.status == .pending)
        }
    }
    
    func getInvoicesByStatus(_ status: Invoice.InvoiceStatus) -> [Invoice] {
        return invoices.filter { $0.status == status }
    }
    
    func getTotalOutstanding() -> Decimal {
        return invoices
            .filter { $0.status != .paid && $0.status != .cancelled }
            .reduce(0) { $0 + $1.balance }
    }
    
    func getInvoiceById(_ id: String) -> Invoice? {
        return invoices.first { $0.id == id }
    }
    
    func createInvoice(customerId: String, customerName: String, amount: Decimal, items: [Invoice.InvoiceItem], dueDate: Date? = nil) {
        let newInvoice = Invoice(
            invoiceNumber: generateInvoiceNumber(),
            customerId: customerId,
            customerName: customerName,
            amount: amount,
            balance: amount,
            dueDate: dueDate,
            items: items
        )
        
        // In a real app, you would save this to NetSuite
        invoices.append(newInvoice)
    }
    
    func updateInvoice(_ invoice: Invoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        }
        
        // In a real app, you would update this in NetSuite
    }
    
    func markInvoiceAsPaid(_ invoice: Invoice) {
        var updatedInvoice = invoice
        updatedInvoice = Invoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            customerId: invoice.customerId,
            customerName: invoice.customerName,
            amount: invoice.amount,
            balance: 0,
            status: .paid,
            dueDate: invoice.dueDate,
            createdDate: invoice.createdDate,
            netSuiteId: invoice.netSuiteId,
            items: invoice.items,
            notes: invoice.notes
        )
        
        updateInvoice(updatedInvoice)
    }
    
    private func generateInvoiceNumber() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let randomSuffix = String(format: "%04d", Int.random(in: 1...9999))
        return "INV-\(dateString)-\(randomSuffix)"
    }
} 