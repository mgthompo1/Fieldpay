import Foundation
import SwiftUI

struct Payment: Identifiable, Codable {
    let id: String
    let amount: Decimal
    let currency: String
    let status: PaymentStatus
    let paymentMethod: PaymentMethodType
    let customerId: String?
    let invoiceId: String?
    let description: String?
    let stripePaymentIntentId: String?
    let netSuitePaymentId: String?
    let createdDate: Date
    let processedDate: Date?
    let failureReason: String?
    
    init(id: String = UUID().uuidString,
         amount: Decimal,
         currency: String = "USD",
         status: PaymentStatus = .pending,
         paymentMethod: PaymentMethodType,
         customerId: String? = nil,
         invoiceId: String? = nil,
         description: String? = nil,
         stripePaymentIntentId: String? = nil,
         netSuitePaymentId: String? = nil,
         createdDate: Date = Date(),
         processedDate: Date? = nil,
         failureReason: String? = nil) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.status = status
        self.paymentMethod = paymentMethod
        self.customerId = customerId
        self.invoiceId = invoiceId
        self.description = description
        self.stripePaymentIntentId = stripePaymentIntentId
        self.netSuitePaymentId = netSuitePaymentId
        self.createdDate = createdDate
        self.processedDate = processedDate
        self.failureReason = failureReason
    }
}

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case succeeded = "succeeded"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .processing: return .blue
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

enum PaymentMethodType: String, Codable, CaseIterable {
    case tapToPay = "tap_to_pay"
    case manualCard = "manual_card"
    case cash = "cash"
    case check = "check"
    case bankTransfer = "bank_transfer"
    case applePay = "apple_pay"
    case googlePay = "google_pay"
    case windcaveTapToPay = "windcave_tap_to_pay"
    
    var displayName: String {
        switch self {
        case .tapToPay: return "Credit/Debit"
        case .manualCard: return "Manual Credit/Debit"
        case .cash: return "Cash"
        case .check: return "Check"
        case .bankTransfer: return "Bank Transfer"
        case .applePay: return "Apple Pay"
        case .googlePay: return "Google Pay"
        case .windcaveTapToPay: return "Tap to Pay (Windcave)"
        }
    }
    
    var icon: String {
        switch self {
        case .tapToPay: return "wave.3.right"
        case .manualCard: return "creditcard"
        case .cash: return "banknote"
        case .check: return "doc.text"
        case .bankTransfer: return "building.columns"
        case .applePay: return "apple.logo"
        case .googlePay: return "g.circle"
        case .windcaveTapToPay: return "wave.3.right"
        }
    }
    
    var usesStripe: Bool {
        switch self {
        case .tapToPay, .manualCard, .applePay, .googlePay:
            return true
        case .cash, .check, .bankTransfer, .windcaveTapToPay:
            return false
        }
    }
    
    // Only show these methods in Quick Payment
    static var quickPaymentMethods: [PaymentMethodType] {
        return [.tapToPay, .manualCard]
    }
    
    // Show all methods in other contexts
    static var allMethods: [PaymentMethodType] {
        return allCases
    }
}

extension Payment {
    func toCustomerPayment() -> CustomerPayment {
        return CustomerPayment(
            id: id,
            paymentNumber: id,
            date: createdDate,
            amount: amount,
            status: status.rawValue,
            memo: description,
            paymentMethod: paymentMethod.rawValue
        )
    }
} 