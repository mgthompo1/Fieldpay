import Foundation
import SwiftUI

struct Invoice: Identifiable, Codable {
    let id: String
    let invoiceNumber: String
    let customerId: String
    let customerName: String
    let amount: Decimal
    let balance: Decimal
    let status: InvoiceStatus
    let dueDate: Date?
    let createdDate: Date
    let netSuiteId: String?
    let items: [InvoiceItem]
    let notes: String?
    
    enum InvoiceStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case paid = "paid"
        case overdue = "overdue"
        case cancelled = "cancelled"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .paid: return "Paid"
            case .overdue: return "Overdue"
            case .cancelled: return "Cancelled"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .paid: return .green
            case .overdue: return .red
            case .cancelled: return .gray
            }
        }
    }
    
    struct InvoiceItem: Codable {
        let id: String
        let description: String
        let quantity: Double
        let unitPrice: Decimal
        let amount: Decimal
        let netSuiteItemId: String?
    }
    
    init(id: String = UUID().uuidString,
         invoiceNumber: String,
         customerId: String,
         customerName: String,
         amount: Decimal,
         balance: Decimal,
         status: InvoiceStatus = .pending,
         dueDate: Date? = nil,
         createdDate: Date = Date(),
         netSuiteId: String? = nil,
         items: [InvoiceItem] = [],
         notes: String? = nil) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.customerId = customerId
        self.customerName = customerName
        self.amount = amount
        self.balance = balance
        self.status = status
        self.dueDate = dueDate
        self.createdDate = createdDate
        self.netSuiteId = netSuiteId
        self.items = items
        self.notes = notes
    }
} 