import Foundation

// MARK: - Common Types (unified across the app)

public struct Link: Codable { public let rel: String; public let href: String }

/// Generic reference model for NetSuite entities
public struct Reference: Codable {
    public let id: String?
    public let refName: String?
    public let type: String?
}

public typealias EntityReference = Reference
public typealias CurrencyReference = Reference
public typealias LocationReference = Reference

// MARK: - Generic NetSuite response wrapper (use this everywhere)

public struct NetSuiteResponse<T: Codable>: Codable {
    public let links: [Link]?
    public let count: Int?
    public let hasMore: Bool?
    public let offset: Int?
    public let totalResults: Int?
    public let items: [T]
}

// Convenience aliases for existing call sites
public typealias NetSuiteInvoiceListResponse = NetSuiteResponse<InvoiceItem>
public typealias NetSuiteCustomerListResponse = NetSuiteResponse<CustomerItem>
public typealias NetSuitePaymentListResponse  = NetSuiteResponse<PaymentItem>
public typealias CustomerTransactionResponse = NetSuiteResponse<TransactionItem>
public typealias CustomerPaymentResponse     = NetSuiteResponse<NetSuiteCustomerPaymentRecord>

// MARK: - Helpers

/// Decode numbers that may arrive as JSON number or string
enum LooseNumber {
    static func double<T: CodingKey>(_ c: KeyedDecodingContainer<T>, _ key: T) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }
}

// MARK: - Date Parsing (shared)

public struct NetSuiteDateParser {
    private static let iso = ISO8601DateFormatter()
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let dateOnly: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current; return f
    }()
    private static let full: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"; f.timeZone = .current; return f
    }()
    private static let nsShort: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "M/d/yyyy"; f.timeZone = .current; return f
    }()
    private static let nsMedium: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; f.timeZone = .current; return f
    }()
    private static let nsDateTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "M/d/yyyy h:mm a"; f.timeZone = .current; return f
    }()
    private static let nsDateTimeFull: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "M/d/yyyy HH:mm:ss"; f.timeZone = .current; return f
    }()

    public static func parseDate(_ s: String?) -> Date? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if let d = iso.date(from: s) { return d }
        if let d = isoFrac.date(from: s) { return d }
        if let d = full.date(from: s) { return d }
        if let d = dateOnly.date(from: s) { return d }
        if let d = nsShort.date(from: s) { return d }
        if let d = nsMedium.date(from: s) { return d }
        if let d = nsDateTime.date(from: s) { return d }
        if let d = nsDateTimeFull.date(from: s) { return d }
        print("⚠️ DEBUG: NetSuiteDateParser - Failed to parse date: '\(s)'")
        return nil
    }

    public static func parseDateWithFallback(_ s: String?, fallback: Date = Date()) -> Date { parseDate(s) ?? fallback }
}

// MARK: - Customer Models

public struct NetSuiteCustomerResponse: Codable {
    public let id: String
    public let entityId: String?
    public let companyName: String?
    public let firstName: String?
    public let lastName: String?
    public let email: String?
    public let phone: String?
    public let addressbookList: NetSuiteAddressBookList?
    public let isInactive: Bool?
    public let dateCreated: String?
    public let lastModifiedDate: String?
}

public struct NetSuiteAddressBookList: Codable { public let addressbook: [NetSuiteAddress]? }

public struct NetSuiteAddress: Codable {
    public let addr1: String?
    public let addr2: String?
    public let city: String?
    public let state: String?
    public let zip: String?
    public let country: String?
    public let isResidential: Bool?
    public let isDefaultBilling: Bool?
    public let isDefaultShipping: Bool?

    public var isDefault: Bool { isDefaultBilling == true || isDefaultShipping == true }
    public var fullAddress: String { [addr1, addr2, city, state, zip, country].compactMap{ $0 }.joined(separator: ", ") }
}

extension NetSuiteCustomerResponse {
    func toCustomer() -> Customer {
        let f = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let co = companyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ent = entityId?.trimmingCharacters(in: .whitespacesAndNewlines)

        let displayName: String = {
            if let f = f, let l = l, !f.isEmpty, !l.isEmpty { return "\(f) \(l)" }
            if let f = f, !f.isEmpty { return f }
            if let l = l, !l.isEmpty { return l }
            if let co = co, !co.isEmpty { return co }
            if let ent = ent, !ent.isEmpty { return ent }
            return "Customer \(id)"
        }()

        let addresses = addressbookList?.addressbook ?? []
        let primary = addresses.first { $0.isDefault } ?? addresses.first
        let address = primary.map { a in
            Customer.Address(
                street: [a.addr1, a.addr2].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter{ !$0.isEmpty }.joined(separator: " "),
                city: a.city?.trimmingCharacters(in: .whitespacesAndNewlines),
                state: a.state?.trimmingCharacters(in: .whitespacesAndNewlines),
                zipCode: a.zip?.trimmingCharacters(in: .whitespacesAndNewlines),
                country: a.country?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let created = NetSuiteDateParser.parseDateWithFallback(dateCreated)
        let modified = NetSuiteDateParser.parseDateWithFallback(lastModifiedDate, fallback: created)

        let emailClean = (email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? email : nil
        let phoneClean = (phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? phone : nil

        return Customer(
            id: id,
            name: displayName,
            email: emailClean,
            phone: phoneClean,
            address: address,
            netSuiteId: entityId,
            companyName: co,
            isActive: !(isInactive ?? false),
            createdDate: created,
            lastModifiedDate: modified
        )
    }
}

// MARK: - Invoice (Record) Response Model (lightweight)

public struct NetSuiteStatus: Codable { public let id: String?; public let refName: String? }

public struct NetSuiteInvoiceResponse: Codable {
    public let id: String
    public let tranId: String?
    public let entity: EntityReference?
    public let tranDate: String?
    public let dueDate: String?
    public let total: Double?
    public let amountRemaining: Double?
    public let memo: String?
    public let status: NetSuiteStatus?
    let item: ItemList? // preferred; falls back from links-only shape in init
    public let createdDate: String?
    public let lastModifiedDate: String?
    public let amountPaid: Double?
    public let billAddress: String?
    public let shipAddress: String?
    public let email: String?
    public let customForm: EntityReference?
    public let location: EntityReference?
    public let subsidiary: EntityReference?
    public let terms: EntityReference?
    public let currency: EntityReference?
    public let postingPeriod: EntityReference?
    public let source: EntityReference?
    public let originator: String?
    public let toBeEmailed: Bool?
    public let toBeFaxed: Bool?
    public let toBePrinted: Bool?
    public let shipDate: String?
    public let shipIsResidential: Bool?
    public let shipOverride: Bool?
    public let estGrossProfit: Double?
    public let estGrossProfitPercent: Double?
    public let exchangeRate: Double?
    public let totalCostEstimate: Double?
    public let subtotal: Double?

    enum CodingKeys: String, CodingKey {
        case id, tranId, entity, tranDate, dueDate, total, amountRemaining, memo, status, item, createdDate, lastModifiedDate, amountPaid, billAddress, shipAddress, email, customForm, location, subsidiary, terms, currency, postingPeriod, source, originator, toBeEmailed, toBeFaxed, toBePrinted, shipDate, shipIsResidential, shipOverride, estGrossProfit, estGrossProfitPercent, exchangeRate, totalCostEstimate, subtotal
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        tranId = try c.decodeIfPresent(String.self, forKey: .tranId)
        entity = try c.decodeIfPresent(EntityReference.self, forKey: .entity)
        tranDate = try c.decodeIfPresent(String.self, forKey: .tranDate)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        total = LooseNumber.double(c, .total)
        amountRemaining = LooseNumber.double(c, .amountRemaining)
        memo = try c.decodeIfPresent(String.self, forKey: .memo)
        status = try c.decodeIfPresent(NetSuiteStatus.self, forKey: .status)
        createdDate = try c.decodeIfPresent(String.self, forKey: .createdDate)
        lastModifiedDate = try c.decodeIfPresent(String.self, forKey: .lastModifiedDate)
        amountPaid = LooseNumber.double(c, .amountPaid)
        billAddress = try c.decodeIfPresent(String.self, forKey: .billAddress)
        shipAddress = try c.decodeIfPresent(String.self, forKey: .shipAddress)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        customForm = try c.decodeIfPresent(EntityReference.self, forKey: .customForm)
        location = try c.decodeIfPresent(EntityReference.self, forKey: .location)
        subsidiary = try c.decodeIfPresent(EntityReference.self, forKey: .subsidiary)
        terms = try c.decodeIfPresent(EntityReference.self, forKey: .terms)
        currency = try c.decodeIfPresent(EntityReference.self, forKey: .currency)
        postingPeriod = try c.decodeIfPresent(EntityReference.self, forKey: .postingPeriod)
        source = try c.decodeIfPresent(EntityReference.self, forKey: .source)
        originator = try c.decodeIfPresent(String.self, forKey: .originator)
        toBeEmailed = try c.decodeIfPresent(Bool.self, forKey: .toBeEmailed)
        toBeFaxed = try c.decodeIfPresent(Bool.self, forKey: .toBeFaxed)
        toBePrinted = try c.decodeIfPresent(Bool.self, forKey: .toBePrinted)
        shipDate = try c.decodeIfPresent(String.self, forKey: .shipDate)
        shipIsResidential = try c.decodeIfPresent(Bool.self, forKey: .shipIsResidential)
        shipOverride = try c.decodeIfPresent(Bool.self, forKey: .shipOverride)
        estGrossProfit = LooseNumber.double(c, .estGrossProfit)
        estGrossProfitPercent = LooseNumber.double(c, .estGrossProfitPercent)
        exchangeRate = LooseNumber.double(c, .exchangeRate)
        totalCostEstimate = LooseNumber.double(c, .totalCostEstimate)
        subtotal = LooseNumber.double(c, .subtotal)

        // Try to decode lines. Sometimes REST returns an object with just links; ignore that shape.
        if let list = try? c.decode(ItemList.self, forKey: .item) {
            item = list
        } else {
            _ = try? c.decode(NetSuiteItemReference.self, forKey: .item) // discard links-only shape
            item = nil
        }
    }
}

public struct NetSuiteItemReference: Codable { public let links: [Link]? }

extension NetSuiteInvoiceResponse {
    func toInvoice() -> Invoice {
        let created = NetSuiteDateParser.parseDateWithFallback(createdDate)
        let due = NetSuiteDateParser.parseDate(dueDate)

        let statusRaw = status?.refName ?? status?.id
        // Uses InvoiceStatus.parse from your InvoiceRecord file
        let parsed = InvoiceStatus.parse(statusRaw)
        let appStatus: AppInvoiceStatus
        switch parsed {
        case .paidInFull: appStatus = .paid
        case .closed: appStatus = .cancelled
        case .partiallyPaid:
            if let d = due, d < Date() { appStatus = .overdue } else { appStatus = .pending }
        default: appStatus = .pending
        }

        let rawTotal = total ?? 0
        let rawRemain = amountRemaining ?? rawTotal
        let safeTotal = rawTotal.isFinite ? max(0, rawTotal) : 0
        let safeRemain = rawRemain.isFinite ? max(0, rawRemain) : 0

        let number = (tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? tranId! : "INV-\(id)"
        let customerName = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Customer \(id)"

        // NOTE: If you need line items, prefer NetSuiteInvoiceRecord which models them fully.
        return Invoice(
            id: id,
            invoiceNumber: number,
            customerId: entity?.id ?? "",
            customerName: customerName,
            amount: Decimal(safeTotal),
            balance: Decimal(safeRemain),
            status: appStatus,
            dueDate: due,
            createdDate: created,
            netSuiteId: id,
            items: [],
            notes: memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

// MARK: - List Item Models (Invoices / Customers / Payments)

public struct InvoiceItem: Codable {
    public let links: [Link]
    public let id: String
    public let tranId: String?
    public let entity: EntityReference?
    public let amount: Double?
    public let status: String?
    public let trandate: String?
    public let duedate: String?

    enum CodingKeys: String, CodingKey { case links, id, tranId, entity, amount, status, trandate, duedate }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        links = try c.decode([Link].self, forKey: .links)
        id = try c.decode(String.self, forKey: .id)
        tranId = try c.decodeIfPresent(String.self, forKey: .tranId)
        entity = try c.decodeIfPresent(EntityReference.self, forKey: .entity)
        amount = LooseNumber.double(c, .amount)
        trandate = try c.decodeIfPresent(String.self, forKey: .trandate)
        duedate = try c.decodeIfPresent(String.self, forKey: .duedate)

        // status can be a string or an object { id, refName }
        if let s = try? c.decode(String.self, forKey: .status) {
            status = s
        } else if let o = try? c.decode(NetSuiteStatus.self, forKey: .status) {
            status = o.refName ?? o.id
        } else { status = nil }
    }

    public init(links: [Link], id: String, tranId: String?, entity: EntityReference?, amount: Double?, status: String?, trandate: String?, duedate: String?) {
        self.links = links; self.id = id; self.tranId = tranId; self.entity = entity; self.amount = amount; self.status = status; self.trandate = trandate; self.duedate = duedate
    }

    /// Extract the last path component as the detail id
    public var detailId: String {
        if let selfLink = links.first(where: { $0.rel == "self" }), let url = URL(string: selfLink.href), let last = url.pathComponents.last { return last }
        return id
    }

    func toInvoice() -> Invoice {
        let safeAmount = (amount ?? 0).isFinite ? max(0, amount ?? 0) : 0
        return Invoice(
            id: detailId,
            invoiceNumber: tranId ?? "INV-\(detailId)",
            customerId: entity?.id ?? "",
            customerName: entity?.refName ?? "Customer \(id)",
            amount: Decimal(safeAmount),
            balance: Decimal(safeAmount),
            dueDate: NetSuiteDateParser.parseDate(duedate),
            createdDate: NetSuiteDateParser.parseDate(trandate) ?? Date(),
            netSuiteId: detailId,
            items: []
        )
    }
}

public struct CustomerItem: Codable {
    public let links: [Link]
    public let id: String
    public let entityId: String?
    public let companyName: String?
    public let email: String?
    public let phone: String?
    public let isInactive: Bool?

    public var detailId: String {
        if let selfLink = links.first(where: { $0.rel == "self" }), let url = URL(string: selfLink.href), let last = url.pathComponents.last { return last }
        return id
    }

    func toCustomer() -> Customer {
        Customer(
            id: id,
            name: companyName ?? entityId ?? "Customer \(id)",
            email: email,
            phone: phone,
            address: nil,
            netSuiteId: id,
            companyName: companyName,
            isActive: !(isInactive ?? false)
        )
    }
}

public struct PaymentItem: Codable {
    public let links: [Link]
    public let id: String
    public let tranId: String?
    public let entity: EntityReference?
    public let amount: Double?
    public let status: String?
    public let trandate: String?

    enum CodingKeys: String, CodingKey { case links, id, tranId, entity, amount, status, trandate }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        links = try c.decode([Link].self, forKey: .links)
        id = try c.decode(String.self, forKey: .id)
        tranId = try c.decodeIfPresent(String.self, forKey: .tranId)
        entity = try c.decodeIfPresent(EntityReference.self, forKey: .entity)
        amount = LooseNumber.double(c, .amount)
        trandate = try c.decodeIfPresent(String.self, forKey: .trandate)
        if let s = try? c.decode(String.self, forKey: .status) { status = s }
        else if let o = try? c.decode(NetSuiteStatus.self, forKey: .status) { status = o.refName ?? o.id }
        else { status = nil }
    }

    public init(links: [Link], id: String, tranId: String?, entity: EntityReference?, amount: Double?, status: String?, trandate: String?) {
        self.links = links; self.id = id; self.tranId = tranId; self.entity = entity; self.amount = amount; self.status = status; self.trandate = trandate
    }

    public var detailId: String {
        if let selfLink = links.first(where: { $0.rel == "self" }), let url = URL(string: selfLink.href), let last = url.pathComponents.last { return last }
        return id
    }

    func toPayment() -> Payment {
        Payment(
            id: detailId,
            amount: Decimal((amount ?? 0).isFinite ? max(0, amount ?? 0) : 0),
            status: PaymentStatus(rawValue: status ?? "pending") ?? .pending,
            paymentMethod: .cash,
            customerId: entity?.id,
            invoiceId: nil,
            description: "Payment from NetSuite",
            netSuitePaymentId: detailId,
            createdDate: NetSuiteDateParser.parseDate(trandate) ?? Date()
        )
    }
}

// MARK: - Transaction (mixed types)

public struct TransactionItem: Codable {
    public let links: [Link]
    public let id: String
    public let tranId: String?
    public let trandate: String?
    public let amount: Double?
    public let type: String?
    public let status: String?
    public let memo: String?

    enum CodingKeys: String, CodingKey { case links, id, tranId, trandate, amount, type, status, memo }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        links = try c.decode([Link].self, forKey: .links)
        id = try c.decode(String.self, forKey: .id)
        tranId = try c.decodeIfPresent(String.self, forKey: .tranId)
        trandate = try c.decodeIfPresent(String.self, forKey: .trandate)
        amount = LooseNumber.double(c, .amount)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        memo = try c.decodeIfPresent(String.self, forKey: .memo)
        if let s = try? c.decode(String.self, forKey: .status) { status = s }
        else if let o = try? c.decode(NetSuiteStatus.self, forKey: .status) { status = o.refName ?? o.id }
        else { status = nil }
    }

    public func toTransaction() -> CustomerTransaction {
        CustomerTransaction(
            id: id,
            transactionNumber: tranId ?? "TXN-\(id)",
            date: NetSuiteDateParser.parseDate(trandate) ?? Date(),
            amount: Decimal((amount ?? 0).isFinite ? max(0, amount ?? 0) : 0),
            type: type ?? "Unknown",
            status: status ?? "Unknown",
            memo: memo
        )
    }
}

// MARK: - SuiteQL

public struct SuiteQLResponse: Codable {
    public let count: Int
    public let hasMore: Bool
    public let items: [SuiteQLItem]
    public let offset: Int
    public let totalResults: Int
}

// MARK: - Date Range Invoice Response
public struct DateRangeInvoiceResponse: Codable {
    public let count: Int
    public let hasMore: Bool
    public let items: [DateRangeInvoiceItem]
    public let offset: Int
    public let totalResults: Int
}

public struct DateRangeInvoiceItem: Codable {
    public let invoice: String
    public let invoiceNumber: String
    public let invoiceDate: String
    public let customer: String
    public let customerName: String
    public let customerPONumber: String?
    public let salesOrder: String?
    public let soNumber: String?
    public let salesRep: String?
    public let salesRepName: String?
    public let totalAmount: Double?
    public let status: String
    public let balanceDue: Double?
    public let dueDate: String?
    
    enum CodingKeys: String, CodingKey {
        case invoice = "Invoice"
        case invoiceNumber = "InvoiceNumber"
        case invoiceDate = "InvoiceDate"
        case customer = "Customer"
        case customerName = "CustomerName"
        case customerPONumber = "CustomerPONumber"
        case salesOrder = "SalesOrder"
        case soNumber = "SONumber"
        case salesRep = "SalesRep"
        case salesRepName = "SalesRepName"
        case totalAmount = "TotalAmount"
        case status = "Status"
        case balanceDue = "BalanceDue"
        case dueDate = "DueDate"
    }
}

// MARK: - Display Value Models (using BUILTIN.DF)

/// Transaction with display values from BUILTIN.DF
public struct NetSuiteTransactionWithDisplay: Codable, Identifiable {
    public let id: String
    public let tranId: String
    public let trandate: Date
    public let amount: Double
    public let type: String
    public let status: String
    public let customerName: String
    public let memo: String?
    
    public init(id: String, tranId: String, trandate: Date, amount: Double, type: String, status: String, customerName: String, memo: String?) {
        self.id = id
        self.tranId = tranId
        self.trandate = trandate
        self.amount = amount
        self.type = type
        self.status = status
        self.customerName = customerName
        self.memo = memo
    }
}

/// Invoice with display values from BUILTIN.DF
public struct NetSuiteInvoiceWithDisplay: Codable, Identifiable {
    public let id: String
    public let tranId: String
    public let trandate: Date
    public let total: Double
    public let amountRemaining: Double?
    public let dueDate: Date?
    public let status: String
    public let customerName: String
    public let customerId: String?
    public let memo: String?

    public init(
        id: String,
        tranId: String,
        trandate: Date,
        total: Double,
        amountRemaining: Double? = nil,
        dueDate: Date? = nil,
        status: String,
        customerName: String,
        customerId: String? = nil,
        memo: String?
    ) {
        self.id = id
        self.tranId = tranId
        self.trandate = trandate
        self.total = total
        self.amountRemaining = amountRemaining
        self.dueDate = dueDate
        self.status = status
        self.customerName = customerName
        self.customerId = customerId
        self.memo = memo
    }
}

/// Payment with display values from BUILTIN.DF
public struct NetSuitePaymentWithDisplay: Codable, Identifiable {
    public let id: String
    public let tranId: String
    public let trandate: Date
    public let total: Double
    public let status: String
    public let customerName: String
    public let memo: String?
    
    public init(id: String, tranId: String, trandate: Date, total: Double, status: String, customerName: String, memo: String?) {
        self.id = id
        self.tranId = tranId
        self.trandate = trandate
        self.total = total
        self.status = status
        self.customerName = customerName
        self.memo = memo
    }
}

/// Sales Order with display values from BUILTIN.DF
public struct NetSuiteSalesOrderWithDisplay: Codable, Identifiable {
    public let id: String
    public let tranId: String
    public let trandate: Date
    public let status: String
    public let customerName: String
    public let memo: String?
    
    public init(id: String, tranId: String, trandate: Date, status: String, customerName: String, memo: String?) {
        self.id = id
        self.tranId = tranId
        self.trandate = trandate
        self.status = status
        self.customerName = customerName
        self.memo = memo
    }
}

public struct SuiteQLItem: Codable {
    public let values: [String: String]

    // Direct fields (best-effort when present)
    public let id: String?
    public let tranid: String?
    public let trandate: String?
    public let amount: String?
    public let status: String?
    public let memo: String?
    public let paymentmethod: String?
    public let entity: String?
    public let type: String?
    public let links: [Link]?

    enum CodingKeys: String, CodingKey { case id, tranid, trandate, amount, status, memo, paymentmethod, entity, type, links }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        tranid = try c.decodeIfPresent(String.self, forKey: .tranid)
        trandate = try c.decodeIfPresent(String.self, forKey: .trandate)
        amount = try c.decodeIfPresent(String.self, forKey: .amount)
        memo = try c.decodeIfPresent(String.self, forKey: .memo)
        paymentmethod = try c.decodeIfPresent(String.self, forKey: .paymentmethod)
        entity = try c.decodeIfPresent(String.self, forKey: .entity)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        links = try c.decodeIfPresent([Link].self, forKey: .links) ?? []

        // status may be string or object; try string first
        if let s = try? c.decode(String.self, forKey: .status) {
            status = s
        } else if let o = try? c.decode(NetSuiteStatus.self, forKey: .status) {
            status = o.refName ?? o.id
        } else { status = nil }

        var dict: [String: String] = [:]
        if let id = id { dict["id"] = id }
        if let t = tranid { dict["tranid"] = t }
        if let d = trandate { dict["trandate"] = d }
        if let a = amount { dict["amount"] = a }
        if let s = status { dict["status"] = s }
        if let m = memo { dict["memo"] = m }
        if let pm = paymentmethod { dict["paymentmethod"] = pm }
        if let e = entity { dict["entity"] = e }
        if let ty = type { dict["type"] = ty }
        values = dict
    }
}

public enum SuiteQLQuery {
    case customerTransactionHistory(customerId: String)
    case customerPaymentHistory(customerId: String)
    case customerInvoiceHistory(customerId: String)
    case paymentsWithDateFilter(fromDate: String)
    case paymentsWithDateFilterAndCustomer(fromDate: String, customerId: String)
    case customerTransactions(customerId: String)
    case customerPayments(customerId: String)
    case customerInvoices(customerId: String)
    case salesOrders
    case customerSalesOrders(customerId: String)
    case salesOrder(id: String)
    case customers
    case allCustomers
    case invoices
    case allInvoices
    case inventoryItems(limit: Int)
    case locations(limit: Int)
    case custom(String)
    case invoicesWithStatusFilter(statusFilter: String)
    case paymentsWithStatusFilter(statusFilter: String)
    case transactionsWithStatusFilter(statusFilter: String)
    case transactionsWithDisplayValues
    case invoicesWithDisplayValues
    case paymentsWithDisplayValues
    case salesOrdersWithDisplayValues
    case itemsWithDisplayValues
    case transactionsWithItemDisplayValues
    case transactionsWithLocationDisplayValues
    case testSalesOrderTypes
    case testAllSalesOrders
    case customerInvoicesByDateRange(fromDate: String, toDate: String?)
    case invoicesWithLineItems(customerId: String?)
    case comprehensivePayments
    case customerDeposits(customerId: String)
    case allCustomerDeposits
    case allCustomerPayments
    case depositsWithDateFilter(fromDate: String)
    case salesOrderLineItems(salesOrderId: String)
    case salesOrderWithPaymentInfo(customerId: String)
    case salesOrderWithDeposits(customerId: String)
    case salesOrderWithLineItems(customerId: String)
    case salesOrdersComprehensive(customerId: String)

    public var query: String {
        switch self {
        case .customerTransactionHistory(let cid):
            let id = Self.sanitize(cid)
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.foreigntotal as total, 
                t.type, 
                t.status, 
                t.memo,
                c.companyname as customer_name,
                t.otherrefnum as customer_po
            FROM transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE c.id = '\(id)'
            AND t.type IN ('CustPymt', 'CustInvc', 'CustCred', 'SOrd')
            ORDER BY t.trandate DESC
            """
        case .customerPaymentHistory(let cid):
            let id = Self.sanitize(cid)
            return """
            SELECT 
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                c.companyname AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS Memo,
                t.voided AS Voided,
                t.otherrefnum AS OtherRefNum
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
            WHERE 
                t.entity = '\(id)' 
                AND t.type = 'CustPymt'
                AND t.voided = 'F'
            ORDER BY 
                t.tranid DESC
            """
                case .customerInvoiceHistory(let cid):
            let id = Self.sanitize(cid)
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
            INNER JOIN customer c ON t.entity = c.id
            INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.type = 'CustInvc'
                AND t.entity = \(id)
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .paymentsWithDateFilter(let fromDate):
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                c.companyname AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS Memo,
                t.voided AS Voided,
                t.otherrefnum AS OtherRefNum
            FROM
                transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE
                t.type = 'CustPymt'
                AND t.trandate >= '\(fromDate)'
                AND t.voided = 'F'
            ORDER BY
                t.trandate DESC
            """
        case .paymentsWithDateFilterAndCustomer(let fromDate, let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                c.companyname AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS Memo,
                t.voided AS Voided,
                t.otherrefnum AS OtherRefNum
            FROM
                transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE
                t.type = 'CustPymt'
                AND t.trandate >= '\(fromDate)'
                AND t.entity = '\(id)'
                AND t.voided = 'F'
            ORDER BY
                t.tranid DESC
            """
        
        case .comprehensivePayments:
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                c.companyname AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS Memo,
                t.voided AS Voided,
                t.otherrefnum AS OtherRefNum
            FROM
                transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE
                t.type = 'CustPymt'
                AND t.voided = 'F'

            ORDER BY
                t.tranid DESC
            """
        
        case .customerDeposits(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                c.companyname AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                t.paymentmethod AS PaymentMethodID,
                BUILTIN.DF(t.paymentmethod) AS PaymentMethodName,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.voided AS Voided
            FROM 
                transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE 
                t.type = 'CustDep' 
                AND t.entity = '\(id)'
                AND t.voided = 'F'
            ORDER BY
                t.trandate DESC
            """
        
        case .allCustomerDeposits:
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                BUILTIN.DF(t.entity) AS Customer,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.paymentmethod) AS PaymentMethod,
                t.otherrefnum AS OtherRefNum,
                BUILTIN.DF(t.status) AS Status
            FROM
                transaction t
            WHERE
                t.type = 'CustDep'
                AND t.voided = 'F'
            ORDER BY
                t.tranid DESC
            LIMIT 100
            """
        
        case .allCustomerPayments:
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                c.companyname AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS Memo,
                t.voided AS Voided,
                t.otherrefnum AS OtherRefNum
            FROM
                transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE
                t.type = 'CustPymt'
                AND t.voided = 'F'

            ORDER BY
                t.trandate DESC
            """
        
        case .depositsWithDateFilter(let fromDate):
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                BUILTIN.DF(t.entity) AS Customer,
                t.foreigntotal AS ForeignTotal,
                BUILTIN.DF(t.paymentmethod) AS PaymentMethod,
                BUILTIN.DF(t.status) AS Status
            FROM
                Transaction t
            WHERE
                t.type = 'CustDep'
                AND t.trandate >= '\(fromDate)'
            ORDER BY
                t.trandate DESC
            LIMIT 100
            """
        
        case .inventoryItems(_):
            return """
            SELECT i.id, i.itemid, i.displayname, i.description, i.isinactive, i.itemtype
            FROM item i
            WHERE i.itemtype IN ('InvtPart', 'NonInvtPart', 'Service')
            ORDER BY i.displayname
            """
        case .locations(let limit):
            return """
            SELECT l.id, l.name, l.isinactive
            FROM location l
            ORDER BY l.name
            LIMIT \(limit)
            """
        case .customerTransactions(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT t.id, t.total, t.trandate
            FROM transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE c.id = '\(id)' AND t.type IN ('CustPymt', 'CustInvc', 'CustCred')
            ORDER BY t.trandate DESC
            """
        case .customerPayments(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT
                t.id AS Transaction,
                t.tranid AS TranID,
                t.trandate AS TranDate,
                t.entity AS CustomerID,
                BUILTIN.DF(t.entity) AS CustomerName,
                t.foreigntotal AS ForeignTotal,
                t.status AS StatusDisplay,
                t.memo AS Memo
            FROM
                Transaction t
            WHERE
                t.type = 'CustPymt'
                AND t.entity = '\(id)'
            ORDER BY
                t.trandate DESC
            """
        case .customerInvoices(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.entity = '\(id)' 
                AND t.type = 'CustInvc'
                AND t.voided = 'F'
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .salesOrders:
            return """
            SELECT 
                id, 
                tranid, 
                trandate, 
                status,
                BUILTIN.DF(status) AS StatusName,
                entity,
                BUILTIN.DF(entity) AS CustomerName,
                memo,
                otherrefnum,
                foreigntotal,
                duedate,
                createddate,
                lastmodifieddate
            FROM Transaction
            WHERE Type = 'SalesOrd'
            ORDER BY trandate DESC
            """
        case .customerSalesOrders(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT 
                s.id, 
                s.tranid, 
                s.trandate, 
                s.status,
                BUILTIN.DF(s.status) AS StatusName,
                s.entity,
                BUILTIN.DF(s.entity) AS CustomerName,
                s.foreigntotal AS total,
                s.memo,
                s.otherrefnum,
                s.duedate,
                s.createddate,
                s.lastmodifieddate
            FROM Transaction s
            WHERE s.Type = 'SalesOrd' AND s.entity = '\(id)'
            ORDER BY s.trandate DESC
            """
        case .salesOrder(let id):
            let sanitizedId = Self.sanitize(id)
            return """
            SELECT 
                s.id, 
                s.tranid, 
                s.trandate, 
                s.status,
                BUILTIN.DF(s.status) AS StatusName,
                s.entity,
                BUILTIN.DF(s.entity) AS CustomerName,
                s.foreigntotal,
                s.memo,
                s.otherrefnum,
                s.duedate,
                s.createddate,
                s.lastmodifieddate
            FROM Transaction s
            WHERE s.Type = 'SalesOrd' AND s.id = '\(sanitizedId)'
            """
        case .salesOrderLineItems(let salesOrderId):
            let sanitizedId = Self.sanitize(salesOrderId)
            return """
            SELECT
                tl.transaction AS SalesOrderID,
                tl.item AS ItemID,
                BUILTIN.DF(tl.item) AS ItemName,
                tl.rate AS UnitPrice,
                tl.quantity AS Quantity,
                tl.netamount AS LineAmount,
                tl.memo AS LineMemo
            FROM 
                TransactionLine tl
            WHERE 
                tl.transaction = '\(sanitizedId)'
            ORDER BY
                tl.id
            """
        case .salesOrderWithPaymentInfo(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT
                t.id,
                t.tranid,
                t.trandate,
                t.status,
                BUILTIN.DF(t.status) AS StatusName,
                t.entity,
                BUILTIN.DF(t.entity) AS CustomerName,
                t.foreigntotal AS OrderTotal,
                t.amountunbilled,
                t.foreignamountpaid,
                t.foreignamountunpaid,
                t.paymenthold,
                t.paymentmethod,
                BUILTIN.DF(t.paymentmethod) AS PaymentMethodName
            FROM 
                Transaction t
            WHERE 
                t.Type = 'SalesOrd' AND t.entity = '\(id)'
            ORDER BY
                t.trandate DESC
            """
        case .salesOrderWithDeposits(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT
                so.id AS SalesOrderID,
                so.tranid AS OrderNumber,
                so.trandate AS OrderDate,
                so.status AS OrderStatus,
                BUILTIN.DF(so.status) AS OrderStatusName,
                so.entity AS CustomerID,
                BUILTIN.DF(so.entity) AS CustomerName,
                so.foreigntotal AS OrderTotal,
                so.amountunbilled,
                so.paymentmethod AS OrderPaymentMethod,
                BUILTIN.DF(so.paymentmethod) AS OrderPaymentMethodName,
                so.memo AS PONumber,
                d.id AS DepositID,
                d.tranid AS DepositNumber,
                d.trandate AS DepositDate,
                d.foreigntotal AS DepositAmount,
                d.paymentmethod AS DepositPaymentMethod,
                BUILTIN.DF(d.paymentmethod) AS DepositPaymentMethodName,
                d.status AS DepositStatus,
                BUILTIN.DF(d.status) AS DepositStatusName
            FROM 
                Transaction so
            LEFT JOIN Transaction d ON d.entity = so.entity AND d.type = 'CustDep'
            WHERE 
                so.Type = 'SalesOrd' AND so.entity = '\(id)'
            ORDER BY
                so.trandate DESC, d.trandate DESC
            """
        case .salesOrderWithLineItems(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT
                t.id AS sales_order_id,
                t.tranid AS order_number,
                t.trandate AS order_date,
                t.duedate AS due_date,
                t.foreigntotal AS order_total,
                t.memo AS po_number,
                t.otherrefnum AS customer_po,
                t.status AS status_id,
                BUILTIN.DF(t.status) AS status_display,
                t.entity AS customer_id,
                c.companyname AS customer_name,
                c.email AS customer_email,
                c.phone AS customer_phone,
                t.createdby AS created_by_id,
                BUILTIN.DF(t.createdby) AS created_by_name,
                t.lastmodifiedby AS modified_by_id,
                BUILTIN.DF(t.lastmodifiedby) AS modified_by_name,
                t.paymentmethod AS payment_method_id,
                BUILTIN.DF(t.paymentmethod) AS payment_method_name,
                t.amountunbilled AS amount_unbilled,
                t.foreignamountpaid AS amount_paid,
                t.foreignamountunpaid AS amount_unpaid,
                t.paymenthold AS payment_hold,
                t.createddate AS created_date,
                t.lastmodifieddate AS last_modified_date,
                tl.id AS line_item_id,
                tl.linesequencenumber AS line_sequence,
                tl.item AS item_id,
                BUILTIN.DF(tl.item) AS item_name,
                tl.quantity AS quantity,
                tl.rate AS unit_price,
                tl.netamount AS line_amount,
                tl.memo AS line_memo
            FROM Transaction t
            INNER JOIN customer c ON t.entity = c.id
            INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE t.Type = 'SalesOrd'
            AND t.voided = 'F'
            AND t.entity = '\(id)'
            ORDER BY t.trandate DESC, tl.linesequencenumber
            """
        case .salesOrdersComprehensive(let customerId):
            let id = Self.sanitize(customerId)
            return """
            SELECT 
                -- Sales Order Header Information
                t.id AS sales_order_id,
                t.tranid AS order_number,
                t.trandate AS order_date,
                t.duedate AS due_date,
                t.foreigntotal AS order_total,
                t.memo AS po_number,
                t.otherrefnum AS customer_po,
                
                -- Status Information
                t.status AS status_id,
                BUILTIN.DF(t.status) AS status_display,
                
                -- Customer Information
                t.entity AS customer_id,
                c.companyname AS customer_name,
                c.email AS customer_email,
                c.phone AS customer_phone,
                
                -- Staff Member Information
                t.createdby AS created_by_id,
                BUILTIN.DF(t.createdby) AS created_by_name,
                t.lastmodifiedby AS modified_by_id,
                BUILTIN.DF(t.lastmodifiedby) AS modified_by_name,
                
                -- Payment Information
                t.paymentmethod AS payment_method_id,
                BUILTIN.DF(t.paymentmethod) AS payment_method_name,
                t.amountunbilled AS amount_unbilled,
                t.foreignamountpaid AS amount_paid,
                t.foreignamountunpaid AS amount_unpaid,
                t.paymenthold AS payment_hold,
                
                -- Dates
                t.createddate AS created_date,
                t.lastmodifieddate AS last_modified_date,
                
                -- Line Item Information (All Confirmed Working Fields)
                tl.id AS line_item_id,
                tl.linesequencenumber AS line_sequence,
                tl.item AS item_id,
                BUILTIN.DF(tl.item) AS item_name,
                tl.quantity AS quantity,
                tl.rate AS unit_price,
                tl.netamount AS line_amount,
                tl.memo AS line_memo
                
            FROM Transaction t
            INNER JOIN customer c ON t.entity = c.id
            INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE t.Type = 'SalesOrd'
            AND t.voided = 'F'
            AND t.entity = '\(id)'
            ORDER BY t.trandate DESC, tl.linesequencenumber
            """

        case .customers:
            return """
            SELECT c.id, c.entityid, c.companyname, c.email, c.phone, c.isinactive
            FROM customer c
            ORDER BY c.companyname
            LIMIT 100
            """
        case .allCustomers:
            return """
            SELECT c.id, c.entityid, c.companyname, c.email, c.phone, c.isinactive
            FROM customer c
            ORDER BY c.companyname
            """
        case .invoices:
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.type = 'CustInvc'
                AND t.voided = 'F'
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .allInvoices:
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.type = 'CustInvc'
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .custom(let q):
            return q
        case .testSalesOrderTypes:
            return """
            SELECT DISTINCT type, COUNT(*) as count
            FROM transaction
            WHERE type LIKE '%Ord%' OR type LIKE '%SO%'
            GROUP BY type
            ORDER BY count DESC
            """
        case .testAllSalesOrders:
            return """
            SELECT id, tranid, trandate, entity, type
            FROM transaction
            WHERE type = 'SOrd'
            ORDER BY trandate DESC
            LIMIT 10
            """
        case .customerInvoicesByDateRange(let fromDate, let toDate):
            let sanitizedFromDate = Self.sanitize(fromDate)
            let dateFilter: String
            if let toDate = toDate, !toDate.isEmpty {
                let sanitizedToDate = Self.sanitize(toDate)
                dateFilter = "AND ( transaction.trandate >= '\(sanitizedFromDate)' AND transaction.trandate <= '\(sanitizedToDate)' )"
            } else {
                // Use relative date range if no toDate specified
                dateFilter = "AND ( transaction.trandate >= BUILTIN.RELATIVE_RANGES( 'DAGO30', 'START' ) )"
            }
            
            return """
            SELECT
                t.id AS InvoiceID,			
                t.tranid AS InvoiceNumber,	
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM
                transaction t		
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE
                t.type = 'CustInvc'
                \(dateFilter)
                AND t.voided = 'F'
                AND ( RowNum <= 20 )
            ORDER BY			
                t.id, tl.linesequencenumber
            """
        case .invoicesWithLineItems(let customerId):
            let customerFilter = customerId.map { "AND t.entity = '\(Self.sanitize($0))'" } ?? ""
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.type = 'CustInvc'
                \(customerFilter)
                AND t.voided = 'F'
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .invoicesWithStatusFilter(let statusFilter):
            let sanitizedFilter = Self.sanitize(statusFilter)
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.type = 'CustInvc' 
                AND t.status = '\(sanitizedFilter)'
                AND t.voided = 'F'
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .paymentsWithStatusFilter(let statusFilter):
            let sanitizedFilter = Self.sanitize(statusFilter)
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.foreigntotal as total, 
                t.entity as entity, 
                t.status, 
                t.memo,
                c.companyname as customer_name,
                t.checknum as check_number,
                t.applied as amount_applied,
                t.unapplied as amount_unapplied,
                t.paymentmethod as payment_method_id,
                pm.name as payment_method_name,
                l.name as location_name,
                d.name as department_name,
                cl.name as class_name,
                t.voided,
                t.tobeemailed,
                t.tobeprinted
            FROM transaction t
            INNER JOIN customer c ON t.customer = c.id
            LEFT JOIN paymentmethod pm ON t.paymentmethod = pm.id
            LEFT JOIN location l ON t.location = l.id
            LEFT JOIN department d ON t.department = d.id
            LEFT JOIN classification cl ON t.class = cl.id
            WHERE t.type = 'CustPymt' AND t.status = '\(sanitizedFilter)'
            ORDER BY t.trandate DESC
            """
        case .transactionsWithStatusFilter(let statusFilter):
            let sanitizedFilter = Self.sanitize(statusFilter)
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.totalaftertaxes as total, 
                t.type, 
                t.entity, 
                t.status, 
                t.memo,
                c.companyname as customer_name,
                t.otherrefnum as customer_po,

            FROM transaction t
            INNER JOIN customer c ON t.entity = c.id
            WHERE t.status = '\(sanitizedFilter)'
            ORDER BY t.trandate DESC
            """
        case .transactionsWithDisplayValues:
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.foreigntotal as total, 
                t.type, 
                t.status,
                c.companyname as customer_name,
                t.memo,
                t.otherrefnum as customer_po
            FROM transaction t
            INNER JOIN customer c ON t.entity = c.id
            ORDER BY t.trandate DESC
            LIMIT 100
            """
        case .invoicesWithDisplayValues:
            return """
            SELECT 
                t.id AS InvoiceID,
                t.tranid AS InvoiceNumber,
                t.trandate AS InvoiceDate,
                c.companyname AS CustomerName,
                t.foreigntotal AS TotalAmount,
                BUILTIN.DF(t.status) AS StatusDisplay,
                t.memo AS InvoiceMemo,
                tl.linesequencenumber AS LineNumber,
                tl.quantity AS Quantity,
                tl.rate AS Rate,
                (tl.quantity * tl.rate) AS LineAmount,
                tl.memo AS LineMemo,
                tl.item AS ItemID
            FROM 
                transaction t
                INNER JOIN customer c ON t.entity = c.id
                INNER JOIN transactionline tl ON t.id = tl.transaction
            WHERE 
                t.type = 'CustInvc'
                AND t.voided = 'F'
                AND ( RowNum <= 20 )
            ORDER BY 
                t.id, tl.linesequencenumber
            """
        case .paymentsWithDisplayValues:
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.foreigntotal as total, 
                BUILTIN.DF(t.status) as status,
                c.companyname as customer_name,
                t.memo,
                t.checknum as check_number,
                t.applied as amount_applied,
                t.unapplied as amount_unapplied,
                t.paymentmethod as payment_method_id,
                pm.name as payment_method_name,
                l.name as location_name,
                d.name as department_name,
                cl.name as class_name,
                t.voided,
                t.tobeemailed,
                t.tobeprinted
            FROM transaction t
            INNER JOIN customer c ON t.entity = c.id
            LEFT JOIN paymentmethod pm ON t.paymentmethod = pm.id
            WHERE t.type = 'CustPymt'
            AND t.voided = 'F'
            ORDER BY t.trandate DESC
            LIMIT 100
            """
        case .salesOrdersWithDisplayValues:
            return """
            SELECT 
                s.id, 
                s.tranid, 
                s.trandate, 
                s.status,
                c.companyname as customer_name,
                s.memo,
                s.otherrefnum as customer_po,
                s.foreigntotal as total
            FROM transaction s
            INNER JOIN customer c ON s.entity = c.id
            WHERE s.type = 'SOrd'
            ORDER BY s.trandate DESC
            LIMIT 100
            """
        case .itemsWithDisplayValues:
            return """
            SELECT 
                i.id, 
                i.itemid, 
                i.displayname, 
                i.description, 
                i.isinactive, 
                i.itemtype
            FROM item i
            ORDER BY i.displayname
            LIMIT 100
            """
        case .transactionsWithItemDisplayValues:
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.total, 
                t.type, 
                BUILTIN.CF(t.status) as status,
                BUILTIN.DF(t.entity) as item_name,
                t.memo
            FROM transaction t
            WHERE t.type IN ('CustInvc', 'CustCred')
            ORDER BY t.trandate DESC
            LIMIT 100
            """
        case .transactionsWithLocationDisplayValues:
            return """
            SELECT 
                t.id, 
                t.tranid, 
                t.trandate, 
                t.total, 
                t.type, 
                BUILTIN.CF(t.status) as status,
                BUILTIN.DF(t.entity) as location_name,
                t.memo
            FROM transaction t
            WHERE t.type = 'SOrd'
            ORDER BY t.trandate DESC
            LIMIT 100
            """
        }
    }

    private static func sanitize(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }
}

// MARK: - To-domain models (kept as in your project)

public struct CustomerTransaction: Identifiable, Codable {
    public let id: String
    public let transactionNumber: String
    public let date: Date
    public let amount: Decimal
    public let type: String
    public let status: String
    public let memo: String?

    public var formattedAmount: String {
        if amount.isNaN || amount.isInfinite || amount > Decimal(1_000_000_000) { return "$0.00" }
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    public var formattedDate: String { let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date) }
}

public struct CustomerPayment: Identifiable, Codable {
    public let id: String
    public let paymentNumber: String
    public let date: Date
    public let amount: Decimal
    public let status: String
    public let memo: String?
    public let paymentMethod: String?

    public var formattedAmount: String {
        if amount.isNaN || amount.isInfinite || amount > Decimal(1_000_000_000) { return "$0.00" }
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    public var formattedDate: String { let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date) }
}

// MARK: - NetSuite Items (for invoice creation UI)

public struct NetSuiteItem: Codable, Identifiable {
    public let id: String
    public let itemId: String
    public let displayName: String
    public let basePrice: Double
    public let description: String?
    public let itemType: String

    public var formattedPrice: String { String(format: "$%.2f", basePrice) }
    public var itemDescription: String { (description?.isEmpty == false ? description! : displayName) }
}

// MARK: - Invoice Creation models

public struct NetSuiteInvoiceTemplate: Codable, Identifiable {
    public let id: String
    public let name: String?
    public let isInactive: Bool
    public let customForm: EntityReference
    public let subsidiary: EntityReference?
    public let requiredFields: [String]?
}

public struct NetSuiteLocation: Codable, Identifiable {
    public let id: String
    public let name: String
    public let isInactive: Bool
    public let subsidiary: EntityReference?
    public let address: NetSuiteAddress?
}

public struct NetSuiteLocationReference: Codable { public let id: String; public let refName: String?; public let type: String? }

public struct NetSuiteCustomerPaymentRecord: Codable {
    public let entity: EntityReference
    public let amount: Double
    public let paymentMethod: EntityReference
    public let memo: String?
    public let tranDate: String?
    public let subsidiary: EntityReference?
    public let location: EntityReference?
    public let currency: EntityReference?
    public let exchangeRate: Double?
    public let customFieldList: NetSuiteCustomFieldList?

    init(payment: Payment) {
        self.entity = EntityReference(id: payment.customerId, refName: nil, type: nil)
        self.amount = NSDecimalNumber(decimal: payment.amount).doubleValue
        self.paymentMethod = EntityReference(id: "1", refName: "Cash", type: nil) // default
        self.memo = payment.description
        self.tranDate = ISO8601DateFormatter().string(from: payment.createdDate)
        self.subsidiary = nil
        self.location = nil
        self.currency = EntityReference(id: "1", refName: "USD", type: nil) // default
        self.exchangeRate = 1.0
        self.customFieldList = nil
    }
}

public struct NetSuiteCustomerPaymentResponse: Codable {
    public let id: String
    public let tranId: String?
    public let entity: EntityReference?
    public let amount: Double?
    public let paymentMethod: EntityReference?
    public let memo: String?
    public let tranDate: String?
    public let status: NetSuiteStatus?
    public let createdDate: String?
    public let lastModifiedDate: String?

    func toPayment() -> Payment {
        Payment(
            id: id,
            amount: Decimal((amount ?? 0).isFinite ? max(0, amount ?? 0) : 0),
            paymentMethod: .cash,
            customerId: entity?.id,
            invoiceId: nil,
            description: memo,
            netSuitePaymentId: id,
            createdDate: NetSuiteDateParser.parseDate(tranDate) ?? Date()
        )
    }
}

public struct NetSuiteCustomerPaymentListResponse: Codable {
    public let items: [NetSuiteCustomerPaymentResponse]
    public let hasMore: Bool?
    public let offset: Int?
    public let count: Int?
}

public struct NetSuiteInvoiceCreationRequest: Codable {
    public let entity: EntityReference
    public let tranDate: String
    public let memo: String?
    public let itemList: NetSuiteInvoiceItemList
    public let customForm: EntityReference?
    public let location: NetSuiteLocationReference?
    public let subsidiary: EntityReference?
    public let terms: EntityReference?
    public let currency: EntityReference?
    public let exchangeRate: Double?
    public let customFieldList: NetSuiteCustomFieldList?

    public init(
        entity: EntityReference,
        tranDate: String,
        memo: String?,
        itemList: NetSuiteInvoiceItemList,
        customForm: EntityReference? = nil,
        location: NetSuiteLocationReference? = nil,
        subsidiary: EntityReference? = nil,
        terms: EntityReference? = nil,
        currency: EntityReference? = nil,
        exchangeRate: Double? = 1.0,
        customFieldList: NetSuiteCustomFieldList? = nil
    ) {
        self.entity = entity
        self.tranDate = tranDate
        self.memo = memo
        self.itemList = itemList
        self.customForm = customForm
        self.location = location
        self.subsidiary = subsidiary
        self.terms = terms
        self.currency = currency
        self.exchangeRate = exchangeRate
        self.customFieldList = customFieldList
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "entity": [
                "id": entity.id,
                "refName": entity.refName,
                "type": entity.type
            ],
            "tranDate": tranDate,
            "itemList": [
                "item": itemList.item.map { item in
                    [
                        "item": [
                            "id": item.item.id,
                            "refName": item.item.refName,
                            "type": item.item.type
                        ],
                        "quantity": item.quantity,
                        "rate": item.rate,
                        "amount": item.amount,
                        "description": item.description as Any,
                        "lineNumber": item.lineNumber as Any
                    ]
                }
            ]
        ]
        
        if let memo = memo {
            dict["memo"] = memo
        }
        
        if let customForm = customForm {
            dict["customForm"] = [
                "id": customForm.id,
                "refName": customForm.refName,
                "type": customForm.type
            ]
        }
        
        if let location = location {
            dict["location"] = [
                "id": location.id,
                "refName": location.refName,
                "type": location.type
            ]
        }
        
        if let subsidiary = subsidiary {
            dict["subsidiary"] = [
                "id": subsidiary.id,
                "refName": subsidiary.refName,
                "type": subsidiary.type
            ]
        }
        
        if let terms = terms {
            dict["terms"] = [
                "id": terms.id,
                "refName": terms.refName,
                "type": terms.type
            ]
        }
        
        if let currency = currency {
            dict["currency"] = [
                "id": currency.id,
                "refName": currency.refName,
                "type": currency.type
            ]
        }
        
        if let exchangeRate = exchangeRate {
            dict["exchangeRate"] = exchangeRate
        }
        
        return dict
    }
}

public struct NetSuiteInvoiceItemList: Codable { public let item: [NetSuiteInvoiceLineItem] }

public struct NetSuiteInvoiceLineItem: Codable {
    public let item: EntityReference
    public let quantity: Double
    public let rate: Double
    public let amount: Double
    public let description: String?
    public let lineNumber: Int?
}

public struct NetSuiteCustomFieldList: Codable { }

// MARK: - Invoice Update Request

/// Request model for updating an existing invoice in NetSuite
public struct NetSuiteInvoiceUpdateRequest: Codable {
    public let memo: String?
    public let dueDate: String?
    public let status: String?
    public let itemList: NetSuiteInvoiceItemList?

    public init(
        memo: String? = nil,
        dueDate: String? = nil,
        status: String? = nil,
        itemList: NetSuiteInvoiceItemList? = nil
    ) {
        self.memo = memo
        self.dueDate = dueDate
        self.status = status
        self.itemList = itemList
    }

    enum CodingKeys: String, CodingKey {
        case memo
        case dueDate
        case status
        case itemList = "item"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode non-nil values
        if let memo = memo { try container.encode(memo, forKey: .memo) }
        if let dueDate = dueDate { try container.encode(dueDate, forKey: .dueDate) }
        if let status = status { try container.encode(status, forKey: .status) }
        if let itemList = itemList { try container.encode(itemList, forKey: .itemList) }
    }
}

// MARK: - NetSuite Types

struct NetSuiteTransaction: Codable, Identifiable {
    let id: String
    let amount: Double
    let date: Date
    let customerId: String
    let type: String
    let status: String
    let memo: String?
    
    func toCustomerTransaction() -> CustomerTransaction {
        return CustomerTransaction(
            id: id,
            transactionNumber: id,
            date: date,
            amount: Decimal(amount),
            type: type,
            status: status,
            memo: memo
        )
    }
}

struct NetSuiteCustomer: Codable, Identifiable {
    let id: String
    let name: String
}

struct NetSuiteInvoice: Codable, Identifiable {
    let id: String
    let amount: Double
}

struct NetSuiteTemplate: Codable, Identifiable {
    let id: String
    let name: String
}

// MARK: - NetSuite Errors
enum NetSuiteError: Error, LocalizedError {
    case notConfigured
    case requestFailed
    case invalidResponse
    case authenticationFailed
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "NetSuite is not configured. Please set account ID and tokens."
        case .requestFailed:
            return "NetSuite API request failed."
        case .invalidResponse:
            return "Invalid response from NetSuite API."
        case .authenticationFailed:
            return "NetSuite authentication failed."
        case .rateLimited:
            return "NetSuite API rate limit exceeded."
        }
    }
}

// MARK: - Customer Data Model for Batch Operations

struct CustomerData: Codable {
    let invoices: [Invoice]
    let payments: [Payment]
    let transactions: [NetSuiteTransaction]
    
    init(invoices: [Invoice], payments: [Payment], transactions: [NetSuiteTransaction]) {
        self.invoices = invoices
        self.payments = payments
        self.transactions = transactions
    }
}

// MARK: - Customer Summary Model

public struct CustomerSummary: Codable {
    public let totalTransactions: Int
    public let totalAmount: Decimal
    public let lastTransactionDate: Date?
    public let firstTransactionDate: Date?
    
    public init(totalTransactions: Int, totalAmount: Decimal, lastTransactionDate: Date?, firstTransactionDate: Date?) {
        self.totalTransactions = totalTransactions
        self.totalAmount = totalAmount
        self.lastTransactionDate = lastTransactionDate
        self.firstTransactionDate = firstTransactionDate
    }
}

// MARK: - Customer with Sales Rep Model

public struct CustomerWithSalesRep: Codable {
    public let customerId: String
    public let companyName: String
    public let email: String?
    public let phone: String?
    public let salesRep: String
    public let salesRepEmail: String
    
    public init(customerId: String, companyName: String, email: String?, phone: String?, salesRep: String, salesRepEmail: String) {
        self.customerId = customerId
        self.companyName = companyName
        self.email = email
        self.phone = phone
        self.salesRep = salesRep
        self.salesRepEmail = salesRepEmail
    }
}

// MARK: - Invoice with Details Model

public struct InvoiceWithDetails: Codable {
    public let invoiceId: String
    public let invoiceNumber: String
    public let invoiceDate: Date?
    public let invoiceAmount: Decimal
    public let invoiceStatus: String
    public let customerName: String
    public let customerEmail: String?
    public let lineItemCount: Int
    public let lineItemTotal: Decimal
    
    public init(invoiceId: String, invoiceNumber: String, invoiceDate: Date?, invoiceAmount: Decimal, invoiceStatus: String, customerName: String, customerEmail: String?, lineItemCount: Int, lineItemTotal: Decimal) {
        self.invoiceId = invoiceId
        self.invoiceNumber = invoiceNumber
        self.invoiceDate = invoiceDate
        self.invoiceAmount = invoiceAmount
        self.invoiceStatus = invoiceStatus
        self.customerName = customerName
        self.customerEmail = customerEmail
        self.lineItemCount = lineItemCount
        self.lineItemTotal = lineItemTotal
    }
}

// MARK: - New Models for Enhanced Sales Order Functionality

public struct NetSuiteLineItem: Identifiable, Codable {
    public let id: String
    public let itemName: String
    public let unitPrice: Decimal
    public let quantity: Double
    public let lineAmount: Decimal
    public let memo: String?
    
    public var formattedUnitPrice: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: unitPrice as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedLineAmount: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: lineAmount as NSDecimalNumber) ?? "$0.00"
    }
}

public struct NetSuiteSalesOrderWithPayment: Identifiable, Codable {
    public let id: String
    public let orderNumber: String
    public let orderDate: Date
    public let status: String
    public let statusName: String
    public let customerId: String
    public let customerName: String
    public let orderTotal: Decimal
    public let amountUnbilled: Decimal
    public let foreignAmountPaid: Decimal
    public let foreignAmountUnpaid: Decimal
    public let paymentHold: Bool
    public let paymentMethod: String
    public let paymentMethodName: String
    
    public var formattedOrderTotal: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: orderTotal as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedAmountUnbilled: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: amountUnbilled as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: orderDate)
    }
}

public struct NetSuiteCustomerDeposit: Identifiable, Codable {
    public let id: String
    public let tranId: String
    public let tranDate: Date
    public let entity: String
    public let customerName: String
    public let foreignTotal: Decimal
    public let paymentMethod: String
    public let paymentMethodName: String
    public let status: String
    public let statusName: String
    
    public var formattedAmount: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: foreignTotal as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: tranDate)
    }
}

public struct NetSuiteSalesOrderWithDeposit: Identifiable, Codable {
    public let id: String
    public let salesOrderId: String
    public let orderNumber: String
    public let orderDate: Date
    public let orderStatus: String
    public let orderStatusName: String
    public let customerId: String
    public let customerName: String
    public let orderTotal: Decimal
    public let amountUnbilled: Decimal
    public let orderPaymentMethod: String
    public let orderPaymentMethodName: String
    public let poNumber: String?
    public let depositId: String?
    public let depositNumber: String?
    public let depositDate: Date?
    public let depositAmount: Decimal
    public let depositPaymentMethod: String?
    public let depositPaymentMethodName: String?
    public let depositStatus: String?
    public let depositStatusName: String?
    
    public var formattedOrderTotal: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: orderTotal as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedAmountUnbilled: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: amountUnbilled as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedDepositAmount: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: depositAmount as NSDecimalNumber) ?? "$0.00"
    }
    
    public var formattedOrderDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: orderDate)
    }
    
    public var formattedDepositDate: String {
        guard let depositDate = depositDate else { return "N/A" }
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: depositDate)
    }
}

