import Foundation

// MARK: - NetSuite API Response Models

// Generic NetSuite response wrapper
struct NetSuiteResponse<T: Codable>: Codable {
    let links: [NetSuiteLink]?
    let count: Int?
    let hasMore: Bool?
    let offset: Int?
    let totalResults: Int?
    let items: [T]
    
    enum CodingKeys: String, CodingKey {
        case links = "links"
        case count = "count"
        case hasMore = "hasMore"
        case offset = "offset"
        case totalResults = "totalResults"
        case items = "items"
    }
}

struct NetSuiteLink: Codable {
    let rel: String
    let href: String
}

// MARK: - Enhanced Status Enums

enum NetSuiteInvoiceStatus: String, CaseIterable {
    case paid = "paid"
    case overdue = "overdue"
    case cancelled = "cancelled"
    case pending = "pending"
    case draft = "draft"
    case approved = "approved"
    case closed = "closed"
    case unknown = "unknown"
    
    init(rawValue: String?) {
        guard let rawValue = rawValue?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            self = .unknown
            return
        }
        
        switch rawValue {
        case "paid", "payment_received":
            self = .paid
        case "overdue", "past_due":
            self = .overdue
        case "cancelled", "canceled", "void":
            self = .cancelled
        case "pending", "open":
            self = .pending
        case "draft":
            self = .draft
        case "approved":
            self = .approved
        case "closed":
            self = .closed
        default:
            self = .unknown
        }
    }
}

// MARK: - Enhanced Date Parsing

struct NetSuiteDateParser {
    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let iso8601WithFractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !dateString.isEmpty else {
            return nil
        }
        
        // Try ISO8601 formatters first
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        if let date = iso8601WithFractionalSecondsFormatter.date(from: dateString) {
            return date
        }
        
        // Try DateFormatter formats
        if let date = fullDateFormatter.date(from: dateString) {
            return date
        }
        
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        
        // Log parsing failure for debugging
        print("⚠️ DEBUG: NetSuiteDateParser - Failed to parse date: '\(dateString)'")
        return nil
    }
    
    static func parseDateWithFallback(_ dateString: String?, fallback: Date = Date()) -> Date {
        return parseDate(dateString) ?? fallback
    }
}

// MARK: - Enhanced Customer Response Model

struct NetSuiteCustomerResponse: Codable {
    let id: String
    let entityId: String?
    let companyName: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let addressbookList: NetSuiteAddressBookList?
    let isInactive: Bool?
    let dateCreated: String?
    let lastModifiedDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case entityId = "entityId"
        case companyName = "companyName"
        case firstName = "firstName"
        case lastName = "lastName"
        case email = "email"
        case phone = "phone"
        case addressbookList = "addressbookList"
        case isInactive = "isInactive"
        case dateCreated = "dateCreated"
        case lastModifiedDate = "lastModifiedDate"
    }
}

struct NetSuiteAddressBookList: Codable {
    let addressbook: [NetSuiteAddress]?
}

struct NetSuiteAddress: Codable {
    let addr1: String?
    let addr2: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
    let isResidential: Bool?
    let isDefaultBilling: Bool?
    let isDefaultShipping: Bool?
    
    var isDefault: Bool {
        return isDefaultBilling == true || isDefaultShipping == true
    }
    
    var fullAddress: String {
        let components = [addr1, addr2, city, state, zip, country].compactMap { $0 }
        return components.joined(separator: ", ")
    }
}

// MARK: - Enhanced Invoice Response Model

struct NetSuiteInvoiceResponse: Codable {
    let id: String
    let tranId: String?
    let entity: NetSuiteEntityReference?
    let tranDate: String?
    let dueDate: String?
    let total: Double?
    let amountRemaining: Double?
    let memo: String?
    let status: NetSuiteStatus?
    let item: NetSuiteItemReference?
    let createdDate: String?
    let lastModifiedDate: String?
    let amountPaid: Double?
    let billAddress: String?
    let shipAddress: String?
    let email: String?
    let customForm: NetSuiteEntityReference?
    let location: NetSuiteEntityReference?
    let subsidiary: NetSuiteEntityReference?
    let terms: NetSuiteEntityReference?
    let currency: NetSuiteEntityReference?
    let postingPeriod: NetSuiteEntityReference?
    let source: NetSuiteEntityReference?
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
        case id = "id"
        case tranId = "tranId"
        case entity = "entity"
        case tranDate = "tranDate"
        case dueDate = "dueDate"
        case total = "total"
        case amountRemaining = "amountRemaining"
        case memo = "memo"
        case status = "status"
        case item = "item"
        case createdDate = "createdDate"
        case lastModifiedDate = "lastModifiedDate"
        case amountPaid = "amountPaid"
        case billAddress = "billAddress"
        case shipAddress = "shipAddress"
        case email = "email"
        case customForm = "customForm"
        case location = "location"
        case subsidiary = "subsidiary"
        case terms = "terms"
        case currency = "currency"
        case postingPeriod = "postingPeriod"
        case source = "source"
        case originator = "originator"
        case toBeEmailed = "toBeEmailed"
        case toBeFaxed = "toBeFaxed"
        case toBePrinted = "toBePrinted"
        case shipDate = "shipDate"
        case shipIsResidential = "shipIsResidential"
        case shipOverride = "shipOverride"
        case estGrossProfit = "estGrossProfit"
        case estGrossProfitPercent = "estGrossProfitPercent"
        case exchangeRate = "exchangeRate"
        case totalCostEstimate = "totalCostEstimate"
        case subtotal = "subtotal"
    }
}

struct NetSuiteStatus: Codable {
    let id: String?
    let refName: String?
}

struct NetSuiteItemReference: Codable {
    let links: [NetSuiteLink]?
}

struct NetSuiteEntityReference: Codable {
    let id: String?
    let refName: String?
}

struct NetSuiteItemList: Codable {
    let item: [NetSuiteInvoiceItem]?
}

struct NetSuiteInvoiceItem: Codable {
    let item: NetSuiteEntityReference?
    let description: String?
    let quantity: Double?
    let rate: Double?
    let amount: Double?
    let grossAmount: Double?
    
    // Enhanced null safety with validation
    var validatedQuantity: Double {
        guard let quantity = quantity, quantity > 0 else {
            print("⚠️ DEBUG: NetSuiteInvoiceItem - Invalid quantity: \(quantity ?? 0), using 1.0")
            return 1.0
        }
        return quantity
    }
    
    var validatedRate: Double {
        guard let rate = rate, rate >= 0 else {
            print("⚠️ DEBUG: NetSuiteInvoiceItem - Invalid rate: \(rate ?? 0), using 0.0")
            return 0.0
        }
        return rate
    }
    
    var validatedAmount: Double {
        guard let amount = amount, amount >= 0 else {
            print("⚠️ DEBUG: NetSuiteInvoiceItem - Invalid amount: \(amount ?? 0), calculating from quantity * rate")
            return validatedQuantity * validatedRate
        }
        return amount
    }
}

// MARK: - Enhanced Conversion Extensions

extension NetSuiteCustomerResponse {
    func toCustomer() -> Customer {
        // Enhanced name handling
        let fullName = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
        let displayName = fullName.isEmpty ? (companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Customer") : fullName
        
        // Enhanced address handling with multiple address support
        let addresses = addressbookList?.addressbook ?? []
        let primaryAddress = addresses.first { $0.isDefault } ?? addresses.first
        
        let address = primaryAddress.map { addr in
            Customer.Address(
                street: [addr.addr1, addr.addr2]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " "),
                city: addr.city?.trimmingCharacters(in: .whitespacesAndNewlines),
                state: addr.state?.trimmingCharacters(in: .whitespacesAndNewlines),
                zipCode: addr.zip?.trimmingCharacters(in: .whitespacesAndNewlines),
                country: addr.country?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        // Enhanced date parsing with fallbacks
        let createdDate = NetSuiteDateParser.parseDateWithFallback(dateCreated)
        let modifiedDate = NetSuiteDateParser.parseDateWithFallback(lastModifiedDate, fallback: createdDate)
        
        // Enhanced email validation
        let validatedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? email : nil
        
        // Enhanced phone validation
        let validatedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? phone : nil
        
        return Customer(
            id: id, // Use NetSuite ID directly for consistency
            name: displayName,
            email: validatedEmail,
            phone: validatedPhone,
            address: address,
            netSuiteId: entityId,
            companyName: companyName?.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: !(isInactive ?? false),
            createdDate: createdDate,
            lastModifiedDate: modifiedDate
        )
    }
}

extension NetSuiteInvoiceResponse {
    func toInvoice() -> Invoice {
        // Enhanced date parsing with fallbacks
        let createdDate = NetSuiteDateParser.parseDateWithFallback(createdDate)
        let _ = NetSuiteDateParser.parseDateWithFallback(lastModifiedDate, fallback: createdDate)
        let dueDate = NetSuiteDateParser.parseDate(dueDate)
        
        // For now, we'll create empty items since the item structure is different
        // TODO: Implement proper item parsing when we have the correct structure
        let items: [Invoice.InvoiceItem] = []
        
        // Enhanced status mapping using enum
        let statusString = status?.id ?? status?.refName ?? "unknown"
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
        
        // Enhanced amount validation using the correct field names
        let validatedTotal = max(0, total ?? 0)
        let validatedBalance = max(0, amountRemaining ?? validatedTotal)
        
        // Enhanced invoice number generation
        let invoiceNumber = tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? tranId! 
            : "INV-\(id)"
        
        // Enhanced customer information
        let customerId = entity?.id ?? ""
        let customerName = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Customer"
        
        return Invoice(
            id: id, // Use NetSuite ID directly for consistency
            invoiceNumber: invoiceNumber,
            customerId: customerId,
            customerName: customerName,
            amount: Decimal(validatedTotal),
            balance: Decimal(validatedBalance),
            status: invoiceStatus,
            dueDate: dueDate,
            createdDate: createdDate,
            netSuiteId: id,
            items: items,
            notes: memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

// MARK: - Error Handling Extensions

extension NetSuiteCustomerResponse {
    /// Validates the customer response and returns any issues found
    func validate() -> [String] {
        var issues: [String] = []
        
        if id.isEmpty {
            issues.append("Customer ID is empty")
        }
        
        if [firstName, lastName, companyName].allSatisfy({ $0?.isEmpty != false }) {
            issues.append("No customer name provided (firstName, lastName, or companyName)")
        }
        
        if let email = email, !email.isEmpty {
            // Basic email validation
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            if email.range(of: emailRegex, options: .regularExpression) == nil {
                issues.append("Invalid email format: \(email)")
            }
        }
        
        return issues
    }
}

extension NetSuiteInvoiceResponse {
    /// Validates the invoice response and returns any issues found
    func validate() -> [String] {
        var issues: [String] = []
        
        if id.isEmpty {
            issues.append("Invoice ID is empty")
        }
        
        if let total = total, total < 0 {
            issues.append("Invoice total is negative: \(total)")
        }
        
        if let amountRemaining = amountRemaining, amountRemaining < 0 {
            issues.append("Invoice amount remaining is negative: \(amountRemaining)")
        }
        
        // Note: Item validation is temporarily disabled since we changed the item structure
        // TODO: Re-implement item validation when we have the correct item structure
        
        return issues
    }
} 

// MARK: - Invoice List Response
struct NetSuiteInvoiceListResponse: Codable {
    let links: [Link]
    let count: Int
    let hasMore: Bool
    let items: [InvoiceItem]
    let offset: Int?
    let totalResults: Int?
}

struct InvoiceItem: Codable {
    let links: [Link]
    let id: String
    let tranId: String?
    let entity: EntityReference?
    let amount: Double?
    let status: String?
    let trandate: String?
    let duedate: String?
    
    /// Extracts the UUID from the self link href for detail API calls
    var detailId: String {
        if let selfLink = links.first(where: { $0.rel == "self" }),
           let url = URL(string: selfLink.href),
           let lastPathComponent = url.pathComponents.last {
            print("Debug: InvoiceItem - Extracted UUID from href: \(lastPathComponent) (original id: \(id))")
            return lastPathComponent
        }
        print("Debug: InvoiceItem - Failed to extract UUID from href, using original id: \(id)")
        return id // Fallback to simple id if href parsing fails
    }
    
    func toInvoice() -> Invoice {
        return Invoice(
            id: detailId, // Use the UUID from href for consistency
            invoiceNumber: tranId ?? "INV-\(detailId)",
            customerId: entity?.id ?? "",
            customerName: entity?.refName ?? "Unknown Customer",
            amount: Decimal(amount ?? 0.0),
            balance: Decimal(amount ?? 0.0),
            dueDate: parseDate(duedate),
            createdDate: parseDate(trandate) ?? Date(),
            netSuiteId: detailId,
            items: []
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}

// MARK: - Customer List Response
struct NetSuiteCustomerListResponse: Codable {
    let links: [Link]
    let count: Int
    let hasMore: Bool
    let items: [CustomerItem]
    let offset: Int?
    let totalResults: Int?
}

struct CustomerItem: Codable {
    let links: [Link]
    let id: String
    let entityId: String?
    let companyName: String?
    let email: String?
    let phone: String?
    let isInactive: Bool?
    
    /// Extracts the UUID from the self link href for detail API calls
    var detailId: String {
        if let selfLink = links.first(where: { $0.rel == "self" }),
           let url = URL(string: selfLink.href),
           let lastPathComponent = url.pathComponents.last {
            print("Debug: CustomerItem - Extracted UUID from href: \(lastPathComponent) (original id: \(id))")
            return lastPathComponent
        }
        print("Debug: CustomerItem - Failed to extract UUID from href, using original id: \(id)")
        return id // Fallback to simple id if href parsing fails
    }
    
    func toCustomer() -> Customer {
        return Customer(
            id: detailId, // Use the UUID from href for consistency
            name: companyName ?? entityId ?? "Unknown Customer",
            email: email,
            phone: phone,
            address: nil,
            netSuiteId: detailId,
            companyName: companyName,
            isActive: !(isInactive ?? false)
        )
    }
}

// MARK: - Common Types
struct Link: Codable {
    let rel: String
    let href: String
}

// MARK: - Payment List Response
struct NetSuitePaymentListResponse: Codable {
    let links: [Link]
    let count: Int
    let hasMore: Bool
    let items: [PaymentItem]
    let offset: Int?
    let totalResults: Int?
}

struct PaymentItem: Codable {
    let links: [Link]
    let id: String
    let tranId: String?
    let entity: EntityReference?
    let amount: Double?
    let status: String?
    let trandate: String?
    
    /// Extracts the UUID from the self link href for detail API calls
    var detailId: String {
        if let selfLink = links.first(where: { $0.rel == "self" }),
           let url = URL(string: selfLink.href),
           let lastPathComponent = url.pathComponents.last {
            print("Debug: PaymentItem - Extracted UUID from href: \(lastPathComponent) (original id: \(id))")
            return lastPathComponent
        }
        print("Debug: PaymentItem - Failed to extract UUID from href, using original id: \(id)")
        return id // Fallback to simple id if href parsing fails
    }
    
    func toPayment() -> Payment {
        return Payment(
            id: detailId, // Use the UUID from href for consistency
            amount: Decimal(amount ?? 0.0),
            status: Payment.PaymentStatus(rawValue: status ?? "pending") ?? .pending,
            paymentMethod: .cash,
            customerId: entity?.id,
            invoiceId: nil,
            description: "Payment from NetSuite",
            netSuitePaymentId: detailId,
            createdDate: parseDate(trandate) ?? Date()
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
} 

// MARK: - SuiteQL Response Models

struct SuiteQLResponse: Codable {
    let links: [Link]
    let count: Int
    let hasMore: Bool
    let items: [SuiteQLItem]
    let offset: Int?
    let totalResults: Int?
}

struct SuiteQLItem: Codable {
    let values: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case values
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let valuesArray = try container.decode([String].self, forKey: .values)
        
        // Convert array to dictionary with column names
        // This is a simplified approach - in practice, you'd need to know the column names
        var dict: [String: String] = [:]
        for (index, value) in valuesArray.enumerated() {
            dict["column\(index)"] = value
        }
        self.values = dict
    }
}

// MARK: - SuiteQL Query Builder

enum SuiteQLQuery {
    case customerTransactionHistory(customerId: String)
    case customerPaymentHistory(customerId: String)
    case customerInvoiceHistory(customerId: String)
    case custom(String)
    
    var query: String {
        switch self {
        case .customerTransactionHistory(let customerId):
            return """
            SELECT 
                t.id,
                t.tranid,
                t.trandate,
                t.total,
                t.type,
                t.status,
                t.memo
            FROM transaction t
            WHERE t.entity = '\(customerId)'
            ORDER BY t.trandate DESC
            LIMIT 50
            """
            
        case .customerPaymentHistory(let customerId):
            return """
            SELECT 
                t.id,
                t.tranid,
                t.trandate,
                t.total,
                t.status,
                t.memo,
                t.paymentmethod
            FROM customerpayment t
            WHERE t.customer = '\(customerId)'
            ORDER BY t.trandate DESC
            LIMIT 50
            """
            
        case .customerInvoiceHistory(let customerId):
            return """
            SELECT 
                t.id,
                t.tranid,
                t.trandate,
                t.total,
                t.status,
                t.memo,
                t.entity
            FROM invoice t
            WHERE t.entity = '\(customerId)'
            ORDER BY t.trandate DESC
            LIMIT 50
            """
            
        case .custom(let query):
            return query
        }
    }
}

// MARK: - Customer Transaction Models

struct CustomerTransactionResponse: Codable {
    let links: [Link]
    let count: Int
    let hasMore: Bool
    let items: [TransactionItem]
    let offset: Int?
    let totalResults: Int?
}

struct TransactionItem: Codable {
    let links: [Link]
    let id: String
    let tranId: String?
    let trandate: String?
    let amount: Double?
    let type: String?
    let status: String?
    let memo: String?
    
    func toTransaction() -> CustomerTransaction {
        return CustomerTransaction(
            id: id,
            transactionNumber: tranId ?? "TXN-\(id)",
            date: parseDate(trandate) ?? Date(),
            amount: Decimal(amount ?? 0.0),
            type: type ?? "Unknown",
            status: status ?? "Unknown",
            memo: memo
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Customer Payment Models

struct CustomerPaymentResponse: Codable {
    let links: [Link]
    let count: Int
    let hasMore: Bool
    let items: [CustomerPaymentItem]
    let offset: Int?
    let totalResults: Int?
}

struct CustomerPaymentItem: Codable {
    let links: [Link]
    let id: String
    let tranId: String?
    let trandate: String?
    let amount: Double?
    let status: String?
    let memo: String?
    let paymentMethod: String?
    
    func toPayment() -> CustomerPayment {
        return CustomerPayment(
            id: id,
            paymentNumber: tranId ?? "PAY-\(id)",
            date: parseDate(trandate) ?? Date(),
            amount: Decimal(amount ?? 0.0),
            status: status ?? "Unknown",
            memo: memo,
            paymentMethod: paymentMethod
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Customer Transaction and Payment Models

struct CustomerTransaction: Identifiable, Codable {
    let id: String
    let transactionNumber: String
    let date: Date
    let amount: Decimal
    let type: String
    let status: String
    let memo: String?
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct CustomerPayment: Identifiable, Codable {
    let id: String
    let paymentNumber: String
    let date: Date
    let amount: Decimal
    let status: String
    let memo: String?
    let paymentMethod: String?
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
} 

// MARK: - Helper Functions

func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString)
} 