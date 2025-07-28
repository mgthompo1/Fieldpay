import Foundation
import SwiftUI

struct SalesOrder: Identifiable, Codable {
    let id: String
    let orderNumber: String
    let customerId: String
    let customerName: String
    let amount: Decimal
    let status: SalesOrderStatus
    let orderDate: Date
    let expectedShipDate: Date?
    let netSuiteId: String?
    let items: [SalesOrderItem]
    let notes: String?
    
    enum SalesOrderStatus: String, Codable, CaseIterable {
        case pendingApproval = "pending_approval"
        case approved = "approved"
        case inProgress = "in_progress"
        case shipped = "shipped"
        case delivered = "delivered"
        case cancelled = "cancelled"
        
        var displayName: String {
            switch self {
            case .pendingApproval: return "Pending Approval"
            case .approved: return "Approved"
            case .inProgress: return "In Progress"
            case .shipped: return "Shipped"
            case .delivered: return "Delivered"
            case .cancelled: return "Cancelled"
            }
        }
        
        var color: Color {
            switch self {
            case .pendingApproval: return .orange
            case .approved: return .blue
            case .inProgress: return .purple
            case .shipped: return .green
            case .delivered: return .green
            case .cancelled: return .red
            }
        }
    }
    
    struct SalesOrderItem: Codable {
        let id: String
        let description: String
        let quantity: Double
        let unitPrice: Decimal
        let amount: Decimal
        let netSuiteItemId: String?
        let isShipped: Bool
    }
    
    init(id: String = UUID().uuidString,
         orderNumber: String,
         customerId: String,
         customerName: String,
         amount: Decimal,
         status: SalesOrderStatus = .pendingApproval,
         orderDate: Date = Date(),
         expectedShipDate: Date? = nil,
         netSuiteId: String? = nil,
         items: [SalesOrderItem] = [],
         notes: String? = nil) {
        self.id = id
        self.orderNumber = orderNumber
        self.customerId = customerId
        self.customerName = customerName
        self.amount = amount
        self.status = status
        self.orderDate = orderDate
        self.expectedShipDate = expectedShipDate
        self.netSuiteId = netSuiteId
        self.items = items
        self.notes = notes
    }
} 