import Foundation
import SwiftUI

struct Invoice: Identifiable, Codable {
    let id: String
    let invoiceNumber: String
    let customerId: String
    let customerName: String
    let amount: Decimal
    let balance: Decimal
    let amountPaid: Decimal  // NEW: Track amount paid
    let amountRemaining: Decimal  // NEW: Track amount remaining
    let status: AppInvoiceStatus
    let dueDate: Date?
    let createdDate: Date
    let netSuiteId: String?
    var items: [AppInvoiceItem]
    let notes: String?
    
    init(id: String = UUID().uuidString,
         invoiceNumber: String,
         customerId: String,
         customerName: String,
         amount: Decimal,
         balance: Decimal,
         amountPaid: Decimal = Decimal(0),
         amountRemaining: Decimal? = nil,
         status: AppInvoiceStatus = .pending,
         dueDate: Date? = nil,
         createdDate: Date = Date(),
         netSuiteId: String? = nil,
         items: [AppInvoiceItem] = [],
         notes: String? = nil) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.customerId = customerId
        self.customerName = customerName
        // Validate and sanitize amount and balance to prevent NaN values
        self.amount = amount.isNaN || amount.isInfinite ? Decimal(0) : amount
        self.balance = balance.isNaN || balance.isInfinite ? Decimal(0) : balance
        self.amountPaid = amountPaid.isNaN || amountPaid.isInfinite ? Decimal(0) : amountPaid
        // If amountRemaining not provided, calculate it
        self.amountRemaining = amountRemaining ?? (amount - amountPaid)
        self.status = status
        self.dueDate = dueDate
        self.createdDate = createdDate
        self.netSuiteId = netSuiteId
        self.items = items
        self.notes = notes
    }
}

enum AppInvoiceStatus: String, Codable, CaseIterable {
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

struct AppInvoiceItem: Codable {
    let id: String
    let line: Int?  // NEW: Line number from NetSuite
    let item: String?  // NEW: Item reference/name
    let description: String
    let quantity: Double
    let unitPrice: Decimal  // This is 'rate' in NetSuite
    let amount: Decimal
    let netSuiteItemId: String?
    
    init(id: String = UUID().uuidString,
         line: Int? = nil,
         item: String? = nil,
         description: String,
         quantity: Double,
         unitPrice: Decimal,
         amount: Decimal,
         netSuiteItemId: String? = nil) {
        self.id = id
        self.line = line
        self.item = item
        self.description = description
        // Validate and sanitize numeric values to prevent NaN
        self.quantity = quantity.isNaN || quantity.isInfinite ? 0.0 : quantity
        self.unitPrice = unitPrice.isNaN || unitPrice.isInfinite ? Decimal(0) : unitPrice
        self.amount = amount.isNaN || amount.isInfinite ? Decimal(0) : amount
        self.netSuiteItemId = netSuiteItemId
    }
}

extension Invoice {
    func toInvoice() -> NetSuiteInvoiceRecord {
        // Convert AppInvoiceItems to NetSuite LineItems
        let lineItems = items.map { item in
            LineItem(
                line: item.line,
                description: item.description,
                item: nil, // We don't have the NetSuite item reference
                quantity: item.quantity,
                rate: NSDecimalNumber(decimal: item.unitPrice).doubleValue,
                amount: NSDecimalNumber(decimal: item.amount).doubleValue,
                taxCode: nil,
                grossAmt: nil,
                netAmount: nil,
                taxAmount: nil,
                taxRate1: nil,
                taxRate2: nil,
                customFieldList: nil
            )
        }
        
        let _ = ItemList(item: lineItems)
        
        return NetSuiteInvoiceRecord(
            id: id,
            tranId: invoiceNumber,
            trandate: createdDate,
            total: NSDecimalNumber(decimal: amount).doubleValue,
            entity: customerId,
            status: status.rawValue,
            memo: notes ?? ""
        )
    }
} 