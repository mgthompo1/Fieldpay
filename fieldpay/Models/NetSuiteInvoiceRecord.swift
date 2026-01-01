import Foundation

// MARK: - Invoice Status Enum (robust parsing)
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

    /// Accepts either display names (e.g., "Paid In Full") or object ids (e.g., "paidInFull").
    static func parse(_ value: String?) -> InvoiceStatus {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return .unknown }
        switch raw.lowercased() {
        case "pending approval": return .pendingApproval
        case "pending fulfillment", "pendingfulfillment": return .pendingFulfillment
        case "pending billing", "pendingbilling": return .pendingBilling
        case "pending billing part fulfilled", "pendingbillingpartfulfilled": return .pendingBillingPartFulfilled
        case "billing approved", "billingapproved": return .billingApproved
        case "closed": return .closed
        case "paid in full", "paidinfull", "paid": return .paidInFull
        case "partially paid", "partiallypaid", "partial": return .partiallyPaid
        case "pending receipt", "pendingreceipt": return .pendingReceipt
        default: return .unknown
        }
    }
    
    /// Convert NetSuite status to app status
    func toAppStatus() -> AppInvoiceStatus {
        switch self {
        case .paidInFull:
            return .paid
        case .closed:
            return .cancelled
        case .partiallyPaid:
            return .pending
        case .pendingApproval, .pendingFulfillment, .pendingBilling, .pendingBillingPartFulfilled, .billingApproved, .pendingReceipt:
            return .pending
        case .unknown:
            return .pending
        }
    }
}

// Helper struct for status object returned by REST
struct StatusObject: Codable { let id: String; let refName: String? }

// MARK: - Reference Models
// Using Reference struct from NetSuiteResponseModels.swift

// MARK: - Line Item Models
struct ItemList: Codable { let item: [LineItem]? }

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

    var formattedQuantity: String { String(format: "%.2f", quantity ?? 0.0) }
    var formattedRate: String { String(format: "%.2f", rate ?? 0.0) }
    var formattedAmount: String { String(format: "%.2f", amount ?? 0.0) }
}

// MARK: - Custom Field Models
struct CustomField: Codable {
    let scriptId: String
    let value: CustomFieldValue?
}

enum CustomFieldValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { throw DecodingError.typeMismatch(CustomFieldValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unknown custom field value type")) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }

    var stringValue: String? {
        switch self { case .string(let s): return s; case .number(let n): return String(n); case .bool(let b): return String(b); case .null: return nil }
    }
    var numberValue: Double? {
        switch self { case .string(let s): return Double(s); case .number(let n): return n; case .bool(let b): return b ? 1.0 : 0.0; case .null: return nil }
    }
    var boolValue: Bool? {
        switch self { case .string(let s): return s.lowercased() == "true"; case .number(let n): return n != 0; case .bool(let b): return b; case .null: return nil }
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
    let customFieldList: [String: String]? // keep lightweight; adjust if you need full structure
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

    enum CodingKeys: String, CodingKey {
        case id, tranId, entity, tranDate, dueDate, status, total, currency, createdDate, lastModifiedDate, memo, balance, location, customFieldList, item, amountRemaining, amountPaid, billAddress, shipAddress, email, customForm, subsidiary, terms, postingPeriod, source, originator, toBeEmailed, toBeFaxed, toBePrinted, shipDate, shipIsResidential, shipOverride, estGrossProfit, estGrossProfitPercent, exchangeRate, totalCostEstimate, subtotal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func decodeDouble(_ key: CodingKeys) -> Double? {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
            return nil
        }

        id = try c.decode(String.self, forKey: .id)
        tranId = try c.decodeIfPresent(String.self, forKey: .tranId)
        entity = try c.decodeIfPresent(EntityReference.self, forKey: .entity)
        tranDate = try c.decodeIfPresent(String.self, forKey: .tranDate)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        total = decodeDouble(.total)
        currency = try c.decodeIfPresent(Reference.self, forKey: .currency)
        createdDate = try c.decodeIfPresent(String.self, forKey: .createdDate)
        lastModifiedDate = try c.decodeIfPresent(String.self, forKey: .lastModifiedDate)
        memo = try c.decodeIfPresent(String.self, forKey: .memo)
        balance = decodeDouble(.balance)
        location = try c.decodeIfPresent(Reference.self, forKey: .location)
        customFieldList = nil // parse later if needed
        item = try c.decodeIfPresent(ItemList.self, forKey: .item)
        amountRemaining = decodeDouble(.amountRemaining)
        amountPaid = decodeDouble(.amountPaid)
        billAddress = try c.decodeIfPresent(String.self, forKey: .billAddress)
        shipAddress = try c.decodeIfPresent(String.self, forKey: .shipAddress)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        customForm = try c.decodeIfPresent(Reference.self, forKey: .customForm)
        subsidiary = try c.decodeIfPresent(Reference.self, forKey: .subsidiary)
        terms = try c.decodeIfPresent(Reference.self, forKey: .terms)
        postingPeriod = try c.decodeIfPresent(Reference.self, forKey: .postingPeriod)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        originator = try c.decodeIfPresent(String.self, forKey: .originator)
        toBeEmailed = try c.decodeIfPresent(Bool.self, forKey: .toBeEmailed)
        toBeFaxed = try c.decodeIfPresent(Bool.self, forKey: .toBeFaxed)
        toBePrinted = try c.decodeIfPresent(Bool.self, forKey: .toBePrinted)
        shipDate = try c.decodeIfPresent(String.self, forKey: .shipDate)
        shipIsResidential = try c.decodeIfPresent(Bool.self, forKey: .shipIsResidential)
        shipOverride = try c.decodeIfPresent(Bool.self, forKey: .shipOverride)
        estGrossProfit = decodeDouble(.estGrossProfit)
        estGrossProfitPercent = decodeDouble(.estGrossProfitPercent)
        exchangeRate = decodeDouble(.exchangeRate)
        totalCostEstimate = decodeDouble(.totalCostEstimate)
        subtotal = decodeDouble(.subtotal)

        // Status can be a string or an object
        if let statusString = try? c.decode(String.self, forKey: .status) {
            status = InvoiceStatus.parse(statusString)
        } else if let statusObject = try? c.decode(StatusObject.self, forKey: .status) {
            status = InvoiceStatus.parse(statusObject.refName ?? statusObject.id)
        } else {
            status = nil
        }
    }
    
    // Custom initializer for manual creation (for BUILTIN.CF queries)
    init(id: String, tranId: String, trandate: Date, total: Double, entity: String, status: String, memo: String) {
        self.id = id
        self.tranId = tranId
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.tranDate = formatter.string(from: trandate)
        self.total = total
        self.entity = EntityReference(id: entity, refName: nil, type: nil)
        self.status = InvoiceStatus.parse(status)
        self.memo = memo
        self.dueDate = nil
        self.currency = nil
        self.createdDate = nil
        self.lastModifiedDate = nil
        self.balance = nil
        self.location = nil
        self.customFieldList = nil
        self.item = nil
        self.amountRemaining = nil
        self.amountPaid = nil
        self.billAddress = nil
        self.shipAddress = nil
        self.email = nil
        self.customForm = nil
        self.subsidiary = nil
        self.terms = nil
        self.postingPeriod = nil
        self.source = nil
        self.originator = nil
        self.toBeEmailed = nil
        self.toBeFaxed = nil
        self.toBePrinted = nil
        self.shipDate = nil
        self.shipIsResidential = nil
        self.shipOverride = nil
        self.estGrossProfit = nil
        self.estGrossProfitPercent = nil
        self.exchangeRate = nil
        self.totalCostEstimate = nil
        self.subtotal = nil
    }

    /// Extended initializer for consolidated SuiteQL queries with line items and customer name
    init(id: String, tranId: String, trandate: Date, total: Double, entity: String, status: String, memo: String?, lineItems: [LineItem], customerName: String) {
        self.id = id
        self.tranId = tranId
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.tranDate = formatter.string(from: trandate)
        self.total = total
        // Store customer name in the entity reference's refName field
        self.entity = EntityReference(id: entity, refName: customerName, type: nil)
        self.status = InvoiceStatus.parse(status)
        self.memo = memo
        // Store line items
        self.item = ItemList(item: lineItems)
        self.dueDate = nil
        self.currency = nil
        self.createdDate = nil
        self.lastModifiedDate = nil
        self.balance = nil
        self.location = nil
        self.customFieldList = nil
        self.amountRemaining = nil
        self.amountPaid = nil
        self.billAddress = nil
        self.shipAddress = nil
        self.email = nil
        self.customForm = nil
        self.subsidiary = nil
        self.terms = nil
        self.postingPeriod = nil
        self.source = nil
        self.originator = nil
        self.toBeEmailed = nil
        self.toBeFaxed = nil
        self.toBePrinted = nil
        self.shipDate = nil
        self.shipIsResidential = nil
        self.shipOverride = nil
        self.estGrossProfit = nil
        self.estGrossProfitPercent = nil
        self.exchangeRate = nil
        self.totalCostEstimate = nil
        self.subtotal = nil
    }
}

// MARK: - Convenience Extensions
extension NetSuiteInvoiceRecord {
    func toInvoice() -> Invoice {
        let created = NetSuiteDateParser.parseDateWithFallback(createdDate)
        let due = NetSuiteDateParser.parseDate(dueDate)

        let itemsMapped: [AppInvoiceItem] = item?.item?.map { li in
            AppInvoiceItem(
                id: String(li.line ?? 0),
                description: li.description ?? "",
                quantity: li.quantity ?? 0,
                unitPrice: Decimal(li.rate ?? 0),
                amount: Decimal(li.amount ?? 0),
                netSuiteItemId: li.item?.id
            )
        } ?? []

        let resolvedStatus = status ?? .unknown
        let invoiceStatus: AppInvoiceStatus
        switch resolvedStatus {
        case .paidInFull: invoiceStatus = .paid
        case .closed: invoiceStatus = .cancelled
        case .partiallyPaid:
            if let d = due, d < Date() { invoiceStatus = .overdue } else { invoiceStatus = .pending }
        default: invoiceStatus = .pending
        }

        // Prefer provided tranId, fall back to generated
        let number = (tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? tranId! : "INV-\(id)"

        // Amounts -> Decimal for domain model
        let amountDec = Decimal(total ?? 0)
        let balanceDec = Decimal(balance ?? total ?? 0)

        return Invoice(
            id: id,
            invoiceNumber: number,
            customerId: entity?.id ?? "",
            customerName: customerName,
            amount: amountDec,
            balance: balanceDec,
            status: invoiceStatus,
            dueDate: due,
            createdDate: created,
            netSuiteId: id,
            items: itemsMapped,
            notes: memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var lineItemsSummary: String {
        guard let items = item?.item, !items.isEmpty else { return "No line items" }
        let count = items.count
        let total = items.reduce(0.0) { $0 + ($1.amount ?? 0) }
        return "\(count) line item(s) - Total: $\(String(format: "%.2f", total))"
    }

    var hasLineItems: Bool { item?.item?.isEmpty == false }

    var customerName: String {
        if let name = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        if let custId = entity?.id, !custId.isEmpty { return "Customer \(custId)" }
        return "Customer"
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = .current; return f
    }()

    var formattedTotal: String {
        let n = NSDecimalNumber(value: total ?? 0)
        return Self.currencyFormatter.string(from: n) ?? "$0.00"
    }

    var formattedBalance: String {
        let n = NSDecimalNumber(value: balance ?? total ?? 0)
        return Self.currencyFormatter.string(from: n) ?? "$0.00"
    }

    var isPaid: Bool {
        if let rem = amountRemaining ?? balance { return rem <= 0 }
        return status == .paidInFull
    }

    var daysUntilDue: Int? {
        guard let d = NetSuiteDateParser.parseDate(dueDate) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }
}

extension LineItem {
    var summary: String {
        let desc = description ?? "No description"
        let qty = String(format: "%.2f", quantity ?? 0)
        let rate = String(format: "$%.2f", rate ?? 0)
        let amount = String(format: "$%.2f", amount ?? 0)
        return "\(desc) - Qty: \(qty) @ \(rate) = \(amount)"
    }
}

