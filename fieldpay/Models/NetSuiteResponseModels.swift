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
    
    // Add NetSuite common date formats
    private static let netSuiteShortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"  // 2/28/2018
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static let netSuiteMediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"  // 02/28/2018
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static let netSuiteDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm a"  // 2/28/2018 3:30 PM
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static let netSuiteDateTimeFullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy HH:mm:ss"  // 2/28/2018 15:30:00
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
        
        // Try standard DateFormatter formats
        if let date = fullDateFormatter.date(from: dateString) {
            return date
        }
        
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        
        // Try NetSuite specific formats
        if let date = netSuiteShortDateFormatter.date(from: dateString) {
            return date
        }
        
        if let date = netSuiteMediumDateFormatter.date(from: dateString) {
            return date
        }
        
        if let date = netSuiteDateTimeFormatter.date(from: dateString) {
            return date
        }
        
        if let date = netSuiteDateTimeFullFormatter.date(from: dateString) {
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
        // Enhanced name handling with better fallback logic
        let trimmedFirstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompanyName = companyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEntityId = entityId?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Build display name with priority: firstName + lastName > companyName > entityId > fallback
        let displayName: String
        if let firstName = trimmedFirstName, let lastName = trimmedLastName, !firstName.isEmpty, !lastName.isEmpty {
            displayName = "\(firstName) \(lastName)"
        } else if let firstName = trimmedFirstName, !firstName.isEmpty {
            displayName = firstName
        } else if let lastName = trimmedLastName, !lastName.isEmpty {
            displayName = lastName
        } else if let companyName = trimmedCompanyName, !companyName.isEmpty {
            displayName = companyName
        } else if let entityId = trimmedEntityId, !entityId.isEmpty {
            displayName = entityId
        } else {
            displayName = "Customer \(id)"
        }
        
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
        
        // Enhanced amount validation with NaN protection
        let rawTotal = total ?? 0
        let rawBalance = amountRemaining ?? rawTotal
        
        // Check for NaN or infinite values and handle large numbers safely
        let validatedTotal: Double
        if rawTotal.isNaN || rawTotal.isInfinite {
            validatedTotal = 0
        } else if rawTotal > 1_000_000_000 { // Handle extremely large numbers
            validatedTotal = 0
        } else {
            validatedTotal = max(0, rawTotal)
        }
        
        let validatedBalance: Double
        if rawBalance.isNaN || rawBalance.isInfinite {
            validatedBalance = 0
        } else if rawBalance > 1_000_000_000 { // Handle extremely large numbers
            validatedBalance = 0
        } else {
            validatedBalance = max(0, rawBalance)
        }
        
        // Enhanced invoice number generation
        let invoiceNumber = tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? tranId! 
            : "INV-\(id)"
        
        // Enhanced customer information
        let customerId = entity?.id ?? ""
        let customerName = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Customer \(id)"
        
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

// MARK: - NetSuite Item Models

/// Represents an item/product from NetSuite for invoice creation
struct NetSuiteItem: Codable, Identifiable {
    let id: String
    let itemId: String
    let displayName: String
    let basePrice: Double
    let description: String?
    let itemType: String
    
    var formattedPrice: String {
        return String(format: "$%.2f", basePrice)
    }
    
    var itemDescription: String {
        return description?.isEmpty == false ? description! : displayName
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
    
    // Custom decoding to handle status field that can be either string or object
    enum CodingKeys: String, CodingKey {
        case links, id, tranId, entity, amount, status, trandate, duedate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        links = try container.decode([Link].self, forKey: .links)
        id = try container.decode(String.self, forKey: .id)
        tranId = try container.decodeIfPresent(String.self, forKey: .tranId)
        entity = try container.decodeIfPresent(EntityReference.self, forKey: .entity)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        trandate = try container.decodeIfPresent(String.self, forKey: .trandate)
        duedate = try container.decodeIfPresent(String.self, forKey: .duedate)
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            status = statusObject.id
        } else {
            status = nil
        }
    }
    
    init(links: [Link], id: String, tranId: String?, entity: EntityReference?, amount: Double?, status: String?, trandate: String?, duedate: String?) {
        self.links = links
        self.id = id
        self.tranId = tranId
        self.entity = entity
        self.amount = amount
        self.status = status
        self.trandate = trandate
        self.duedate = duedate
    }
    
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
        // Validate and sanitize numeric values to prevent NaN
        let safeAmount = Double(amount ?? 0.0)
        let safeBalance = Double(amount ?? 0.0) // Using amount as balance for now
        
        let validatedAmount = safeAmount.isNaN || safeAmount.isInfinite ? 0.0 : safeAmount
        let validatedBalance = safeBalance.isNaN || safeBalance.isInfinite ? 0.0 : safeBalance
        
        return Invoice(
            id: detailId,
            invoiceNumber: tranId ?? "INV-\(detailId)",
            customerId: entity?.id ?? "",
            customerName: entity?.refName ?? "Customer \(id)",
            amount: Decimal(validatedAmount),
            balance: Decimal(validatedBalance),
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
            id: id, // Use the original id for consistency with NetSuite API
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
    
    // Custom decoding to handle status field that can be either string or object
    enum CodingKeys: String, CodingKey {
        case links, id, tranId, entity, amount, status, trandate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        links = try container.decode([Link].self, forKey: .links)
        id = try container.decode(String.self, forKey: .id)
        tranId = try container.decodeIfPresent(String.self, forKey: .tranId)
        entity = try container.decodeIfPresent(EntityReference.self, forKey: .entity)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        trandate = try container.decodeIfPresent(String.self, forKey: .trandate)
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            status = statusObject.id
        } else {
            status = nil
        }
    }
    
    init(links: [Link], id: String, tranId: String?, entity: EntityReference?, amount: Double?, status: String?, trandate: String?) {
        self.links = links
        self.id = id
        self.tranId = tranId
        self.entity = entity
        self.amount = amount
        self.status = status
        self.trandate = trandate
    }
    
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
    
    // Direct properties from NetSuite response
    let id: String?
    let tranid: String?
    let trandate: String?
    let amount: String?
    let status: String?
    let memo: String?
    let paymentmethod: String?
    let entity: String?
    let type: String?
    let links: [Link]?
    
    enum CodingKeys: String, CodingKey {
        case id, tranid, trandate, amount, status, memo, paymentmethod, entity, type, links
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode direct properties
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.tranid = try container.decodeIfPresent(String.self, forKey: .tranid)
        self.trandate = try container.decodeIfPresent(String.self, forKey: .trandate)
        self.amount = try container.decodeIfPresent(String.self, forKey: .amount)
        self.memo = try container.decodeIfPresent(String.self, forKey: .memo)
        self.paymentmethod = try container.decodeIfPresent(String.self, forKey: .paymentmethod)
        self.entity = try container.decodeIfPresent(String.self, forKey: .entity)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.links = try container.decodeIfPresent([Link].self, forKey: .links) ?? []
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            self.status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            self.status = statusObject.id
        } else {
            self.status = nil
        }
        
        // Create values dictionary for backward compatibility
        var dict: [String: String] = [:]
        if let id = id { dict["id"] = id }
        if let tranid = tranid { dict["tranid"] = tranid }
        if let trandate = trandate { dict["trandate"] = trandate }
        if let amount = amount { dict["amount"] = amount }
        if let status = status { dict["status"] = status }
        if let memo = memo { dict["memo"] = memo }
        if let paymentmethod = paymentmethod { dict["paymentmethod"] = paymentmethod }
        if let entity = entity { dict["entity"] = entity }
        if let type = type { dict["type"] = type }
        
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
                t.amount,
                t.type,
                t.status,
                t.memo
            FROM transaction t
            WHERE t.entity = '\(customerId)'
            ORDER BY t.trandate DESC
            """
            
        case .customerPaymentHistory(let customerId):
            return """
            SELECT 
                t.id,
                t.tranid,
                t.trandate,
                t.payment,
                t.status,
                t.memo,
                t.paymentmethod
            FROM transaction t
            WHERE t.entity = '\(customerId)' AND t.type = 'CustPymt'
            ORDER BY t.trandate DESC
            """
            
        case .customerInvoiceHistory(let customerId):
            return """
            SELECT 
                t.id,
                t.tranid,
                t.trandate,
                t.amount,
                t.status,
                t.memo,
                t.entity
            FROM transaction t
            WHERE t.entity = '\(customerId)' AND t.type = 'Invoice'
            ORDER BY t.trandate DESC
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
    
    // Custom decoding to handle status field that can be either string or object
    enum CodingKeys: String, CodingKey {
        case links, id, tranId, trandate, amount, type, status, memo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        links = try container.decode([Link].self, forKey: .links)
        id = try container.decode(String.self, forKey: .id)
        tranId = try container.decodeIfPresent(String.self, forKey: .tranId)
        trandate = try container.decodeIfPresent(String.self, forKey: .trandate)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            status = statusObject.id
        } else {
            status = nil
        }
    }
    
    init(links: [Link], id: String, tranId: String?, trandate: String?, amount: Double?, type: String?, status: String?, memo: String?) {
        self.links = links
        self.id = id
        self.tranId = tranId
        self.trandate = trandate
        self.amount = amount
        self.type = type
        self.status = status
        self.memo = memo
    }
    
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
    
    // Custom decoding to handle status field that can be either string or object
    enum CodingKeys: String, CodingKey {
        case links, id, tranId, trandate, amount, status, memo, paymentMethod
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        links = try container.decode([Link].self, forKey: .links)
        id = try container.decode(String.self, forKey: .id)
        tranId = try container.decodeIfPresent(String.self, forKey: .tranId)
        trandate = try container.decodeIfPresent(String.self, forKey: .trandate)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            status = statusObject.id
        } else {
            status = nil
        }
    }
    
    init(links: [Link], id: String, tranId: String?, trandate: String?, amount: Double?, status: String?, memo: String?, paymentMethod: String?) {
        self.links = links
        self.id = id
        self.tranId = tranId
        self.trandate = trandate
        self.amount = amount
        self.status = status
        self.memo = memo
        self.paymentMethod = paymentMethod
    }
    
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
        // Validate the amount to prevent NaN errors
        if amount.isNaN || amount.isInfinite {
            return "$0.00"
        }
        
        // Handle extremely large numbers
        if amount > Decimal(1_000_000_000) {
            return "$0.00"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
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
        // Validate the amount to prevent NaN errors
        if amount.isNaN || amount.isInfinite {
            return "$0.00"
        }
        
        // Handle extremely large numbers
        if amount > Decimal(1_000_000_000) {
            return "$0.00"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
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

// MARK: - NetSuite Customer Payment Record Models

struct NetSuiteCustomerPaymentRecord: Codable {
    let id: String?
    let tranId: String?
    let entity: EntityReference?
    let amount: Double
    let status: String
    let trandate: String
    let memo: String?
    let paymentMethod: String?
    let applied: [AppliedPayment]?
    
    init(payment: Payment) {
        self.id = nil // NetSuite will assign the ID
        self.tranId = nil // NetSuite will assign the transaction ID
        self.entity = payment.customerId != nil ? EntityReference(id: payment.customerId!, refName: nil, type: "CUSTOMER") : nil
        self.amount = (payment.amount as NSDecimalNumber).doubleValue
        self.status = payment.status.rawValue
        self.trandate = ISO8601DateFormatter().string(from: payment.createdDate)
        self.memo = payment.description
        self.paymentMethod = mapPaymentMethodToNetSuite(payment.paymentMethod)
        self.applied = payment.invoiceId != nil ? [AppliedPayment(invoiceId: payment.invoiceId!, amount: payment.amount)] : nil
    }
}

struct AppliedPayment: Codable {
    let doc: String
    let amount: Double
    let apply: Bool
    
    init(invoiceId: String, amount: Decimal) {
        self.doc = invoiceId
        self.amount = (amount as NSDecimalNumber).doubleValue
        self.apply = true
    }
}

struct NetSuiteCustomerPaymentResponse: Codable {
    let links: [Link]
    let id: String
    let tranId: String?
    let entity: EntityReference?
    let amount: Double?
    let status: String?
    let trandate: String?
    let memo: String?
    let paymentMethod: String?
    
    // Custom decoding to handle status field that can be either string or object
    enum CodingKeys: String, CodingKey {
        case links, id, tranId, entity, amount, status, trandate, memo, paymentMethod
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        links = try container.decode([Link].self, forKey: .links)
        id = try container.decode(String.self, forKey: .id)
        tranId = try container.decodeIfPresent(String.self, forKey: .tranId)
        entity = try container.decodeIfPresent(EntityReference.self, forKey: .entity)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        trandate = try container.decodeIfPresent(String.self, forKey: .trandate)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            status = statusObject.id
        } else {
            status = nil
        }
    }
    
    init(links: [Link], id: String, tranId: String?, entity: EntityReference?, amount: Double?, status: String?, trandate: String?, memo: String?, paymentMethod: String?) {
        self.links = links
        self.id = id
        self.tranId = tranId
        self.entity = entity
        self.amount = amount
        self.status = status
        self.trandate = trandate
        self.memo = memo
        self.paymentMethod = paymentMethod
    }
    
    func toPayment() -> Payment {
        return Payment(
            id: id,
            amount: Decimal(amount ?? 0.0),
            status: Payment.PaymentStatus(rawValue: status ?? "pending") ?? .pending,
            paymentMethod: mapNetSuitePaymentMethodToApp(paymentMethod ?? ""),
            customerId: entity?.id,
            invoiceId: nil,
            description: memo,
            netSuitePaymentId: id,
            createdDate: parseDate(trandate) ?? Date()
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}



// MARK: - Payment Method Mapping Functions

func mapPaymentMethodToNetSuite(_ method: Payment.PaymentMethod) -> String {
    switch method {
    case .tapToPay, .manualCard, .applePay, .googlePay:
        return "CREDIT_CARD"
    case .cash:
        return "CASH"
    case .check:
        return "CHECK"
    case .bankTransfer:
        return "BANK_TRANSFER"
    case .windcaveTapToPay:
        return "CREDIT_CARD"
    }
}

func mapNetSuitePaymentMethodToApp(_ method: String) -> Payment.PaymentMethod {
    switch method.uppercased() {
    case "CREDIT_CARD":
        return .tapToPay
    case "CASH":
        return .cash
    case "CHECK":
        return .check
    case "BANK_TRANSFER":
        return .bankTransfer
    default:
        return .tapToPay
    }
} 

// MARK: - Inventory and Invoice Creation Models

// MARK: - Inventory Item Models
struct NetSuiteInventoryItem: Codable {
    let id: String
    let itemId: String?
    let displayName: String?
    let description: String?
    let basePrice: Double?
    let isInactive: Bool?
    let itemType: String?
    let location: NetSuiteLocationReference?
    let subsidiary: NetSuiteEntityReference?
    let customFieldList: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case itemId = "itemId"
        case displayName = "displayName"
        case description = "description"
        case basePrice = "basePrice"
        case isInactive = "isInactive"
        case itemType = "itemType"
        case location = "location"
        case subsidiary = "subsidiary"
        case customFieldList = "customFieldList"
    }
}

struct NetSuiteInventoryItemListResponse: Codable {
    let links: [NetSuiteLink]?
    let count: Int?
    let hasMore: Bool?
    let offset: Int?
    let totalResults: Int?
    let items: [NetSuiteInventoryItem]
}

// MARK: - Invoice Template Models
struct NetSuiteInvoiceTemplate: Codable {
    let id: String
    let name: String?
    let isInactive: Bool?
    let customForm: NetSuiteEntityReference?
    let subsidiary: NetSuiteEntityReference?
    let requiredFields: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case isInactive = "isInactive"
        case customForm = "customForm"
        case subsidiary = "subsidiary"
        case requiredFields = "requiredFields"
    }
}

struct NetSuiteInvoiceTemplateListResponse: Codable {
    let links: [NetSuiteLink]?
    let count: Int?
    let hasMore: Bool?
    let offset: Int?
    let totalResults: Int?
    let items: [NetSuiteInvoiceTemplate]
}

// MARK: - Location Models
struct NetSuiteLocation: Codable {
    let id: String
    let name: String?
    let isInactive: Bool?
    let subsidiary: NetSuiteEntityReference?
    let address: NetSuiteAddress?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case isInactive = "isInactive"
        case subsidiary = "subsidiary"
        case address = "address"
    }
}

struct NetSuiteLocationReference: Codable {
    let id: String?
    let refName: String?
    let type: String?
}

struct NetSuiteLocationListResponse: Codable {
    let links: [NetSuiteLink]?
    let count: Int?
    let hasMore: Bool?
    let offset: Int?
    let totalResults: Int?
    let items: [NetSuiteLocation]
}

// MARK: - Invoice Line Item Models
struct NetSuiteInvoiceLineItem: Codable {
    let item: NetSuiteInventoryItem?
    let quantity: Double?
    let rate: Double?
    let amount: Double?
    let description: String?
    let lineNumber: Int?
    
    enum CodingKeys: String, CodingKey {
        case item = "item"
        case quantity = "quantity"
        case rate = "rate"
        case amount = "amount"
        case description = "description"
        case lineNumber = "lineNumber"
    }
}

// MARK: - Invoice Creation Request Models
struct NetSuiteInvoiceCreationRequest: Codable {
    let entity: NetSuiteEntityReference
    let tranDate: String?
    let dueDate: String?
    let memo: String?
    let customForm: NetSuiteEntityReference?
    let location: NetSuiteLocationReference?
    let subsidiary: NetSuiteEntityReference?
    let item: [NetSuiteInvoiceLineItem]?
    
    enum CodingKeys: String, CodingKey {
        case entity = "entity"
        case tranDate = "tranDate"
        case dueDate = "dueDate"
        case memo = "memo"
        case customForm = "customForm"
        case location = "location"
        case subsidiary = "subsidiary"
        case item = "item"
    }
}

// MARK: - Conversion Extensions
extension NetSuiteInventoryItem {
    func toInvoiceItem() -> Invoice.InvoiceItem {
        return Invoice.InvoiceItem(
            id: id,
            description: description ?? displayName ?? "Unknown Item",
            quantity: 1.0,
            unitPrice: Decimal(basePrice ?? 0.0),
            amount: Decimal(basePrice ?? 0.0),
            netSuiteItemId: itemId
        )
    }
}

// MARK: - SuiteQL Queries for Invoice Creation
extension SuiteQLQuery {
    static func inventoryItems(limit: Int = 100) -> SuiteQLQuery {
        return .custom("""
            SELECT 
                id,
                itemid,
                displayname,
                description,
                isinactive,
                itemtype
            FROM item 
            WHERE isinactive = 'F' AND itemtype IN ('InvtPart', 'NonInvtPart', 'Service')
            ORDER BY displayname
            """)
    }
    
    // IMPORTANT: Form records are NOT queryable via SuiteQL in NetSuite
    // SuiteQL is limited to transaction tables, entity records (customer, item, employee), etc.
    // UI-level constructs like "forms" are not part of the SuiteQL data model.
    //
    // Alternatives for getting invoice forms:
    // 1. Use REST Record Service: /services/rest/record/v1/customform
    // 2. Use static configuration in your app if forms don't change often
    // 3. Create a custom record in NetSuite that lists form names/IDs and query that
    // 4. Query actual invoice records to see what forms are being used in practice
    static func invoiceTemplates(limit: Int = 50) -> SuiteQLQuery {
        // This query will intentionally fail - form table is not supported in SuiteQL
        // Kept for reference but should use REST Record API instead
        return .custom("""
            -- This query is NOT supported in SuiteQL and will fail
            -- Use REST Record API /services/rest/record/v1/customform instead
            SELECT 
                id,
                name,
                isinactive
            FROM customform 
            WHERE recordtype = 'invoice' AND isinactive = 'F'
            ORDER BY name
            """)
    }
    
    static func locations(limit: Int = 50) -> SuiteQLQuery {
        return .custom("""
            SELECT 
                id,
                name,
                isinactive
            FROM location 
            WHERE isinactive = 'F'
            ORDER BY name
            """)
    }
} 

// MARK: - SuiteQL-Specific Models for Customer Data

// Generic SuiteQL Response wrapper for new models (matches feedback structure)
struct SuiteQLGenericResponse<T: Codable>: Codable {
    let count: Int
    let hasMore: Bool?
    let items: [T]
}

// SuiteQL Invoice Record for customer-specific queries
struct SuiteQLInvoiceRecord: Codable, Identifiable {
    let id: String
    let tranid: String
    let trandate: String
    let status: String?
    let memo: String?
    let entity: EntityRef?
    
    struct EntityRef: Codable {
        let id: String
        let refName: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, tranid, trandate, status, memo, entity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.tranid = try container.decode(String.self, forKey: .tranid)
        self.trandate = try container.decode(String.self, forKey: .trandate)
        self.memo = try container.decodeIfPresent(String.self, forKey: .memo)
        
        // Handle entity field that can be either string or object
        if let entityString = try? container.decode(String.self, forKey: .entity) {
            self.entity = EntityRef(id: entityString, refName: nil)
        } else if let entityObject = try? container.decode(EntityRef.self, forKey: .entity) {
            self.entity = entityObject
        } else {
            self.entity = nil
        }
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            self.status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            self.status = statusObject.refName
        } else {
            self.status = nil
        }
    }
    
    // Helper struct for when status is an object
    private struct StatusObject: Codable {
        let refName: String
    }
    
    // Convert to our app's Invoice model
    func toInvoice() -> Invoice {
        return Invoice(
            id: id,
            invoiceNumber: tranid,
            customerId: entity?.id ?? "",
            customerName: entity?.refName ?? "Unknown Customer",
            amount: Decimal(0), // SuiteQL doesn't provide amount
            balance: Decimal(0), // SuiteQL doesn't provide balance
            status: Invoice.InvoiceStatus(rawValue: status ?? "pending") ?? .pending,
            dueDate: NetSuiteDateParser.parseDate(trandate), // SuiteQL doesn't provide dueDate
            createdDate: NetSuiteDateParser.parseDate(trandate) ?? Date(),
            netSuiteId: id,
            items: [],
            notes: memo
        )
    }
}

// SuiteQL Payment Record for customer-specific queries
struct SuiteQLPaymentRecord: Codable, Identifiable {
    let id: String
    let tranid: String
    let trandate: String
    let status: String?
    let memo: String?
    let entity: EntityRef?
    let paymentmethod: String?
    
    struct EntityRef: Codable {
        let id: String
        let refName: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, tranid, trandate, status, memo, entity, paymentmethod
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.tranid = try container.decode(String.self, forKey: .tranid)
        self.trandate = try container.decode(String.self, forKey: .trandate)
        self.memo = try container.decodeIfPresent(String.self, forKey: .memo)
        self.paymentmethod = try container.decodeIfPresent(String.self, forKey: .paymentmethod)
        
        // Handle entity field that can be either string or object
        if let entityString = try? container.decode(String.self, forKey: .entity) {
            self.entity = EntityRef(id: entityString, refName: nil)
        } else if let entityObject = try? container.decode(EntityRef.self, forKey: .entity) {
            self.entity = entityObject
        } else {
            self.entity = nil
        }
        
        // Handle status field that can be either string or object
        if let statusString = try? container.decode(String.self, forKey: .status) {
            self.status = statusString
        } else if let statusObject = try? container.decode(StatusObject.self, forKey: .status) {
            self.status = statusObject.refName
        } else {
            self.status = nil
        }
    }
    
    // Helper struct for when status is an object
    private struct StatusObject: Codable {
        let refName: String
    }
    
    // Convert to our app's CustomerPayment model
    func toCustomerPayment() -> CustomerPayment {
        return CustomerPayment(
            id: id,
            paymentNumber: tranid,
            date: NetSuiteDateParser.parseDate(trandate) ?? Date(),
            amount: Decimal(0), // SuiteQL doesn't provide amount
            status: status ?? "Unknown",
            memo: memo,
            paymentMethod: paymentmethod
        )
    }
} 