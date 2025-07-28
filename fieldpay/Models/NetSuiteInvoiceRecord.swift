import Foundation

// MARK: - Enhanced NetSuite Invoice Record Models

/// Complete NetSuite Invoice record with all fields and line items
struct NetSuiteInvoiceRecord: Codable {
    let id: String
    let tranId: String?
    let entity: EntityReference?
    let tranDate: String?
    let dueDate: String?
    let status: String?
    let total: Double?
    let currency: CurrencyReference?
    let createdDate: String?
    let lastModifiedDate: String?
    let memo: String?
    let balance: Double?
    let location: LocationReference?
    let customFieldList: [CustomField]?
    
    // Line items
    let item: LineItemList?
    
    // Additional fields
    let amountRemaining: Double?
    let amountPaid: Double?
    let billAddress: String?
    let shipAddress: String?
    let email: String?
    let customForm: Reference?
    let subsidiary: Reference?
    let terms: Reference?
    let postingPeriod: Reference?
    let source: Reference?
    let originator: String?
    let toBeEmailed: Bool?
    let toBeFaxed: Bool?
    let toBePrinted: Bool?
    let shipDate: String?
    let shipIsResidential: Bool?
    let shipOverride: Bool?
    let estGrossProfit: Double?
    let estGrossProfitPercent: Double?
    let exchangeRate: Double?
    let totalCostEstimate: Double?
    let subtotal: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, tranId, entity, tranDate, dueDate, status, total, currency
        case createdDate, lastModifiedDate, memo, balance, location, customFieldList
        case item, amountRemaining, amountPaid, billAddress, shipAddress, email
        case customForm, subsidiary, terms, postingPeriod, source, originator
        case toBeEmailed, toBeFaxed, toBePrinted, shipDate, shipIsResidential
        case shipOverride, estGrossProfit, estGrossProfitPercent, exchangeRate
        case totalCostEstimate, subtotal
    }
}

// MARK: - Line Item Models

/// Container for line items
struct LineItemList: Codable {
    let item: [LineItem]?
}

/// Individual line item in an invoice
struct LineItem: Codable {
    let line: Int?
    let description: String?
    let item: Reference?
    let quantity: Double?
    let rate: Double?
    let amount: Double?
    let taxCode: Reference?
    let grossAmt: Double?
    let netAmount: Double?
    let taxAmount: Double?
    let taxRate1: Double?
    let taxRate2: Double?
    let customFieldList: [CustomField]?
    
    // Computed properties for convenience
    var formattedQuantity: String {
        return String(format: "%.2f", quantity ?? 0.0)
    }
    
    var formattedRate: String {
        return String(format: "%.2f", rate ?? 0.0)
    }
    
    var formattedAmount: String {
        return String(format: "%.2f", amount ?? 0.0)
    }
}

// MARK: - Reference Models

/// Generic reference model for NetSuite entities
struct Reference: Codable {
    let id: String
    let refName: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case id, refName, type
    }
}

// Type aliases for specific reference types
typealias EntityReference = Reference
typealias CurrencyReference = Reference
typealias LocationReference = Reference

// MARK: - Custom Field Models

/// Custom field with flexible value types
struct CustomField: Codable {
    let scriptId: String
    let value: CustomFieldValue?
    
    enum CodingKeys: String, CodingKey {
        case scriptId, value
    }
}

/// Flexible custom field value that can be string, number, or boolean
enum CustomFieldValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.typeMismatch(
                CustomFieldValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown custom field value type"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .number(let num):
            try container.encode(num)
        case .bool(let b):
            try container.encode(b)
        case .null:
            try container.encodeNil()
        }
    }
    
    // Convenience accessors
    var stringValue: String? {
        switch self {
        case .string(let str): return str
        case .number(let num): return String(num)
        case .bool(let b): return String(b)
        case .null: return nil
        }
    }
    
    var numberValue: Double? {
        switch self {
        case .string(let str): return Double(str)
        case .number(let num): return num
        case .bool(let b): return b ? 1.0 : 0.0
        case .null: return nil
        }
    }
    
    var boolValue: Bool? {
        switch self {
        case .string(let str): return str.lowercased() == "true"
        case .number(let num): return num != 0
        case .bool(let b): return b
        case .null: return nil
        }
    }
}

// MARK: - Convenience Extensions

extension NetSuiteInvoiceRecord {
    /// Convert to your existing Invoice model
    func toInvoice() -> Invoice {
        let createdDate = NetSuiteDateParser.parseDateWithFallback(createdDate)
        let dueDate = NetSuiteDateParser.parseDate(dueDate)
        
        // Convert line items
        let items = self.item?.item?.map { lineItem in
            Invoice.InvoiceItem(
                id: String(lineItem.line ?? 0),
                description: lineItem.description ?? "",
                quantity: lineItem.quantity ?? 0,
                unitPrice: Decimal(lineItem.rate ?? 0),
                amount: Decimal(lineItem.amount ?? 0),
                netSuiteItemId: lineItem.item?.id
            )
        } ?? []
        
        // Determine status
        let statusString = status ?? "unknown"
        let netSuiteStatus = NetSuiteInvoiceStatus(rawValue: statusString)
        let invoiceStatus: Invoice.InvoiceStatus
        
        switch netSuiteStatus {
        case .paid:
            invoiceStatus = .paid
        case .overdue:
            invoiceStatus = .overdue
        case .cancelled:
            invoiceStatus = .cancelled
        case .pending, .draft, .approved, .closed, .unknown:
            invoiceStatus = .pending
        case .none:
            invoiceStatus = .pending
        }
        
        // Enhanced invoice number generation
        let invoiceNumber = tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? tranId! 
            : "INV-\(id)"
        
        // Enhanced customer information
        let customerId = entity?.id ?? ""
        let customerName = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Customer"
        
        return Invoice(
            id: id,
            invoiceNumber: invoiceNumber,
            customerId: customerId,
            customerName: customerName,
            amount: Decimal(total ?? 0),
            balance: Decimal(balance ?? total ?? 0),
            status: invoiceStatus,
            dueDate: dueDate,
            createdDate: createdDate,
            netSuiteId: id,
            items: items,
            notes: memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    /// Get formatted line items summary
    var lineItemsSummary: String {
        guard let items = item?.item, !items.isEmpty else {
            return "No line items"
        }
        
        let itemCount = items.count
        let totalAmount = items.reduce(0) { $0 + ($1.amount ?? 0) }
        
        return "\(itemCount) line item(s) - Total: $\(String(format: "%.2f", totalAmount))"
    }
    
    /// Check if invoice has line items
    var hasLineItems: Bool {
        return item?.item?.isEmpty == false
    }
    
    /// Get customer name safely
    var customerName: String {
        return entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Customer"
    }
    
    /// Get formatted total amount
    var formattedTotal: String {
        return String(format: "$%.2f", total ?? 0.0)
    }
    
    /// Get formatted balance
    var formattedBalance: String {
        return String(format: "$%.2f", balance ?? total ?? 0.0)
    }
    
    /// Check if invoice is paid
    var isPaid: Bool {
        return (balance ?? 0) <= 0 || status?.lowercased() == "paid"
    }
    
    /// Get days until due (negative if overdue)
    var daysUntilDue: Int? {
        guard let dueDate = NetSuiteDateParser.parseDate(dueDate) else { return nil }
        let calendar = Calendar.current
        let today = Date()
        return calendar.dateComponents([.day], from: today, to: dueDate).day
    }
}

extension LineItem {
    /// Get formatted line item summary
    var summary: String {
        let desc = description ?? "No description"
        let qty = String(format: "%.2f", quantity ?? 0)
        let rate = String(format: "$%.2f", rate ?? 0)
        let amount = String(format: "$%.2f", amount ?? 0)
        
        return "\(desc) - Qty: \(qty) @ \(rate) = \(amount)"
    }
} 