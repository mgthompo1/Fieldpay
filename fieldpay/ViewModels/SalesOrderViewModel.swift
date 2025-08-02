import Foundation
import Combine

@MainActor
class SalesOrderViewModel: ObservableObject {
    @Published var salesOrders: [SalesOrder] = []
    @Published var selectedSalesOrder: SalesOrder?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let netSuiteAPI = NetSuiteAPI.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Don't load sales orders immediately - wait for OAuth to be configured
        // loadSalesOrders()
    }
    
    func loadSalesOrders() {
        // Check if NetSuite is configured before making API calls
        guard netSuiteAPI.isConfigured() else {
            errorMessage = "Please configure NetSuite OAuth first"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedSalesOrders = try await netSuiteAPI.fetchSalesOrders()
                salesOrders = fetchedSalesOrders
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func loadSalesOrdersForCustomer(_ customerId: String) {
        // Check if NetSuite is configured before making API calls
        guard netSuiteAPI.isConfigured() else {
            errorMessage = "Please configure NetSuite OAuth first"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedSalesOrders = try await netSuiteAPI.fetchCustomerSalesOrders(for: customerId)
                salesOrders = fetchedSalesOrders
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func loadSalesOrder(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let salesOrder = try await netSuiteAPI.fetchSalesOrder(id: id)
                selectedSalesOrder = salesOrder
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func searchSalesOrders(query: String) {
        guard !query.isEmpty else {
            loadSalesOrders()
            return
        }
        
        let filteredSalesOrders = salesOrders.filter { salesOrder in
            salesOrder.orderNumber.localizedCaseInsensitiveContains(query) ||
            salesOrder.customerName.localizedCaseInsensitiveContains(query)
        }
        
        salesOrders = filteredSalesOrders
    }
    
    func filterSalesOrdersByStatus(_ status: SalesOrder.SalesOrderStatus) {
        let filteredSalesOrders = salesOrders.filter { $0.status == status }
        salesOrders = filteredSalesOrders
    }
    
    func filterSalesOrdersByCustomer(_ customerId: String) {
        let filteredSalesOrders = salesOrders.filter { $0.customerId == customerId }
        salesOrders = filteredSalesOrders
    }
    
    func getSalesOrdersByStatus(_ status: SalesOrder.SalesOrderStatus) -> [SalesOrder] {
        return salesOrders.filter { $0.status == status }
    }
    
    func getPendingApprovalOrders() -> [SalesOrder] {
        return salesOrders.filter { $0.status == .pendingApproval }
    }
    
    func getInProgressOrders() -> [SalesOrder] {
        return salesOrders.filter { $0.status == .inProgress }
    }
    
    func getShippedOrders() -> [SalesOrder] {
        return salesOrders.filter { $0.status == .shipped }
    }
    
    func getDeliveredOrders() -> [SalesOrder] {
        return salesOrders.filter { $0.status == .delivered }
    }
    
    func getTotalSales(for dateRange: DateInterval? = nil) -> Decimal {
        let ordersToSum = dateRange != nil ? 
            getSalesOrdersByDateRange(from: dateRange!.start, to: dateRange!.end) :
            salesOrders
        
        return ordersToSum
            .filter { $0.status != .cancelled }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getSalesOrdersByDateRange(from: Date, to: Date) -> [SalesOrder] {
        return salesOrders.filter { salesOrder in
            salesOrder.orderDate >= from && salesOrder.orderDate <= to
        }
    }
    
    func getSalesOrderById(_ id: String) -> SalesOrder? {
        return salesOrders.first { $0.id == id }
    }
    
    func createSalesOrder(customerId: String, 
                         customerName: String, 
                         amount: Decimal, 
                         items: [SalesOrder.SalesOrderItem],
                         expectedShipDate: Date? = nil) {
        let newSalesOrder = SalesOrder(
            orderNumber: generateOrderNumber(),
            customerId: customerId,
            customerName: customerName,
            amount: amount,
            status: .pendingApproval,
            expectedShipDate: expectedShipDate,
            items: items
        )
        
        // In a real app, you would save this to NetSuite
        salesOrders.append(newSalesOrder)
    }
    
    func updateSalesOrder(_ salesOrder: SalesOrder) {
        if let index = salesOrders.firstIndex(where: { $0.id == salesOrder.id }) {
            salesOrders[index] = salesOrder
        }
        
        // In a real app, you would update this in NetSuite
    }
    
    func approveSalesOrder(_ salesOrder: SalesOrder) {
        var updatedSalesOrder = salesOrder
        updatedSalesOrder = SalesOrder(
            id: salesOrder.id,
            orderNumber: salesOrder.orderNumber,
            customerId: salesOrder.customerId,
            customerName: salesOrder.customerName,
            amount: salesOrder.amount,
            status: .approved,
            orderDate: salesOrder.orderDate,
            expectedShipDate: salesOrder.expectedShipDate,
            netSuiteId: salesOrder.netSuiteId,
            items: salesOrder.items,
            notes: salesOrder.notes
        )
        
        updateSalesOrder(updatedSalesOrder)
    }
    
    func markAsInProgress(_ salesOrder: SalesOrder) {
        var updatedSalesOrder = salesOrder
        updatedSalesOrder = SalesOrder(
            id: salesOrder.id,
            orderNumber: salesOrder.orderNumber,
            customerId: salesOrder.customerId,
            customerName: salesOrder.customerName,
            amount: salesOrder.amount,
            status: .inProgress,
            orderDate: salesOrder.orderDate,
            expectedShipDate: salesOrder.expectedShipDate,
            netSuiteId: salesOrder.netSuiteId,
            items: salesOrder.items,
            notes: salesOrder.notes
        )
        
        updateSalesOrder(updatedSalesOrder)
    }
    
    func markAsShipped(_ salesOrder: SalesOrder) {
        var updatedSalesOrder = salesOrder
        updatedSalesOrder = SalesOrder(
            id: salesOrder.id,
            orderNumber: salesOrder.orderNumber,
            customerId: salesOrder.customerId,
            customerName: salesOrder.customerName,
            amount: salesOrder.amount,
            status: .shipped,
            orderDate: salesOrder.orderDate,
            expectedShipDate: salesOrder.expectedShipDate,
            netSuiteId: salesOrder.netSuiteId,
            items: salesOrder.items,
            notes: salesOrder.notes
        )
        
        updateSalesOrder(updatedSalesOrder)
    }
    
    func markAsDelivered(_ salesOrder: SalesOrder) {
        var updatedSalesOrder = salesOrder
        updatedSalesOrder = SalesOrder(
            id: salesOrder.id,
            orderNumber: salesOrder.orderNumber,
            customerId: salesOrder.customerId,
            customerName: salesOrder.customerName,
            amount: salesOrder.amount,
            status: .delivered,
            orderDate: salesOrder.orderDate,
            expectedShipDate: salesOrder.expectedShipDate,
            netSuiteId: salesOrder.netSuiteId,
            items: salesOrder.items,
            notes: salesOrder.notes
        )
        
        updateSalesOrder(updatedSalesOrder)
    }
    
    func cancelSalesOrder(_ salesOrder: SalesOrder) {
        var updatedSalesOrder = salesOrder
        updatedSalesOrder = SalesOrder(
            id: salesOrder.id,
            orderNumber: salesOrder.orderNumber,
            customerId: salesOrder.customerId,
            customerName: salesOrder.customerName,
            amount: salesOrder.amount,
            status: .cancelled,
            orderDate: salesOrder.orderDate,
            expectedShipDate: salesOrder.expectedShipDate,
            netSuiteId: salesOrder.netSuiteId,
            items: salesOrder.items,
            notes: salesOrder.notes
        )
        
        updateSalesOrder(updatedSalesOrder)
    }
    
    private func generateOrderNumber() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let randomSuffix = String(format: "%04d", Int.random(in: 1...9999))
        return "SO-\(dateString)-\(randomSuffix)"
    }
} 