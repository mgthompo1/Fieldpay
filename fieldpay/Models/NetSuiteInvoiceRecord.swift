import Foundation

// MARK: - Invoice Status Enum
enum InvoiceStatus: String, Codable {
    case pendingApproval = "Pending Approval"
    case pendingFulfillment = "Pending Fulfillment"
    case pendingBilling = "Pending Billing"
    case pendingBillingPartFulfilled = "Pending Billing Part Fulfilled"
    case billingApproved = "Billing Approved"
    case closed = "Closed"
    case paidInFull = "Paid In Full"
    case partiallyPaid = "Partially Paid"
    case pendingReceipt = "Pending Receipt"
    case unknown = "Unknown"
    
    init(rawValue: String) {
        switch rawValue {
        case "Pending Approval": self = .pendingApproval
        case "Pending Fulfillment": self = .pendingFulfillment
        case "Pending Billing": self = .pendingBilling
        case "Pending Billing Part Fulfilled": self = .pendingBillingPartFulfilled
        case "Billing Approved": self = .billingApproved
        case "Closed": self = .closed
        case "Paid In Full": self = .paidInFull
        case "Partially Paid": self = .partiallyPaid
        case "Pending Receipt": self = .pendingReceipt
        default: self = .unknown
        }
    }
}

// MARK: - NetSuite Invoice Record
struct NetSuiteInvoiceRecord: Codable {
    let id: String
    let tranId: String?
    let entity: EntityReference?
    let tranDate: String?
    let dueDate: String?
    let status: InvoiceStatus?
    let total: Double?
    let currency: Reference?
    let createdDate: String?
    let lastModifiedDate: String?
    let memo: String?
    let balance: Double?
    let location: Reference?
    let customFieldList: [String: String]?
    let item: ItemList?
    let amountRemaining: Double?
    let amountPaid: Double?
    let billAddress: String?
    let shipAddress: String?
    let email: String?
    let customForm: Reference?
    let subsidiary: Reference?
    let terms: Reference?
    let postingPeriod: Reference?
    let source: String?
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
    
    // Custom decoding to handle status field that can be either string or object
    enum CodingKeys: String, CodingKey {
        case id, tranId, entity, tranDate, dueDate, status, total, currency, createdDate, lastModifiedDate, memo, balance, location, customFieldList, item, amountRemaining, amountPaid, billAddress, shipAddress, email, customForm, subsidiary, terms, postingPeriod, source, originator, toBeEmailed, toBeFaxed, toBePrinted, shipDate, shipIsResidential, shipOverride, estGrossProfit, estGrossProfitPercent, exchangeRate, totalCostEstimate, subtotal
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        tranId = try container.decodeIfPresent(String.self, forKey: .tranId)
        entity = try container.decodeIfPresent(EntityReference.self, forKey: .entity)
        tranDate = try container.decodeIfPresent(String.self, forKey: .tranDate)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        total = try container.decodeIfPresent(Double.self, forKey: .total)
        currency = try container.decodeIfPresent(Reference.self, forKey: .currency)
        createdDate = try container.decodeIfPresent(String.self, forKey: .createdDate)
        lastModifiedDate = try container.decodeIfPresent(String.self, forKey: .lastModifiedDate)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        balance = try container.decodeIfPresent(Double.self, forKey: .balance)
        location = try container.decodeIfPresent(Reference.self, forKey: .location)
        customFieldList = nil // Skip custom fields for now
        item = try container.decodeIfPresent(ItemList.self, forKey: .item)
        amountRemaining = try container.decodeIfPresent(Double.self, forKey: .amountRemaining)
        amountPaid = try container.decodeIfPresent(Double.self, forKey: .amountPaid)
        billAddress = try container.decodeIfPresent(String.self, forKey: .billAddress)
        shipAddress = try container.decodeIfPresent(String.self, forKey: .shipAddress)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        customForm = try container.decodeIfPresent(Reference.self, forKey: .customForm)
        subsidiary = try container.decodeIfPresent(Reference.self, forKey: .subsidiary)
        terms = try container.decodeIfPresent(Reference.self, forKey: .terms)
        postingPeriod = try container.decodeIfPresent(Reference.self, forKey: .postingPeriod)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        originator = try container.decodeIfPresent(String.self, forKey: .originator)
        toBeEmailed = try container.decodeIfPresent(Bool.self, forKey: .toBeEmailed)
        toBeFaxed = try container.decodeIfPresent(Bool.self, forKey: .toBeFaxed)
        toBePrinted = try container.decodeIfPresent(Bool.self, forKey: .toBePrinted)
        shipDate = try container.decodeIfPresent(String.self, forKey: .shipDate)
        shipIsResidential = try container.decodeIfPresent(Bool.self, forKey: .shipIsResidential)
        shipOverride = try container.decodeIfPresent(Bool.self, forKey: .shipOverride)
        estGrossProfit = try container.decodeIfPresent(Double.self, forKey: .estGrossProfit)
        estGrossProfitPercent = try container.decodeIfPresent(Double.self, forKey: .estGrossProfitPercent)
        exchangeRate = try container.decodeIfPresent(Double.self, forKey: .exchangeRate)
        totalCostEstimate = try container.decodeIfPresent(Double.self, forKey: .totalCostEstimate)
        subtotal = try container.decodeIfPresent(Double.self, forKey: .subtotal)
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = InvoiceStatus(rawValue: statusString)
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            status = InvoiceStatus(rawValue: statusObject.id)
        } else {
            status = nil
        }
    }
    
    // Custom initializer for SuiteQL fallback
    init(id: String, tranId: String?, entity: EntityReference?, tranDate: String?, dueDate: String?, status: String?, total: Double?, currency: Reference?, createdDate: String?, lastModifiedDate: String?, memo: String?, balance: Double?, location: Reference?, customFieldList: [String: String]?, item: ItemList?, amountRemaining: Double?, amountPaid: Double?, billAddress: String?, shipAddress: String?, email: String?, customForm: Reference?, subsidiary: Reference?, terms: Reference?, postingPeriod: Reference?, source: String?, originator: String?, toBeEmailed: Bool?, toBeFaxed: Bool?, toBePrinted: Bool?, shipDate: String?, shipIsResidential: Bool?, shipOverride: Bool?, estGrossProfit: Double?, estGrossProfitPercent: Double?, exchangeRate: Double?, totalCostEstimate: Double?, subtotal: Double?) {
        self.id = id
        self.tranId = tranId
        self.entity = entity
        self.tranDate = tranDate
        self.dueDate = dueDate
        self.status = status != nil ? InvoiceStatus(rawValue: status!) : nil
        self.total = total
        self.currency = currency
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.memo = memo
        self.balance = balance
        self.location = location
        self.customFieldList = customFieldList
        self.item = item
        self.amountRemaining = amountRemaining
        self.amountPaid = amountPaid
        self.billAddress = billAddress
        self.shipAddress = shipAddress
        self.email = email
        self.customForm = customForm
        self.subsidiary = subsidiary
        self.terms = terms
        self.postingPeriod = postingPeriod
        self.source = source
        self.originator = originator
        self.toBeEmailed = toBeEmailed
        self.toBeFaxed = toBeFaxed
        self.toBePrinted = toBePrinted
        self.shipDate = shipDate
        self.shipIsResidential = shipIsResidential
        self.shipOverride = shipOverride
        self.estGrossProfit = estGrossProfit
        self.estGrossProfitPercent = estGrossProfitPercent
        self.exchangeRate = exchangeRate
        self.totalCostEstimate = totalCostEstimate
        self.subtotal = subtotal
    }
}

// Helper struct for status object
struct StatusObject: Codable {
    let id: String
    let refName: String?
}

// MARK: - Line Item Models

/// Container for line items
struct ItemList: Codable {
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
        let statusString = status?.rawValue ?? "unknown"
        let netSuiteStatus = InvoiceStatus(rawValue: statusString)
        let invoiceStatus: Invoice.InvoiceStatus
        
        switch netSuiteStatus {
        case .paidInFull:
            invoiceStatus = .paid
        case .pendingApproval, .pendingFulfillment, .pendingBilling, .pendingBillingPartFulfilled, .billingApproved, .pendingReceipt:
            invoiceStatus = .pending
        case .closed:
            invoiceStatus = .cancelled
        case .partiallyPaid:
            // Check if overdue based on due date
            if let parsedDueDate = dueDate, parsedDueDate < Date() {
                invoiceStatus = .overdue
            } else {
                invoiceStatus = .pending
            }
        case .unknown:
            invoiceStatus = .pending
        }
        
        // Enhanced invoice number generation
        let invoiceNumber = tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? tranId! 
            : "INV-\(id)"
        
        // Enhanced customer information
        let customerId = entity?.id ?? ""
        let customerName = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Customer \(id)"
        
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
        return entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Customer \(id)"
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
        return (balance ?? 0) <= 0 || status?.rawValue.lowercased() == "paid"
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