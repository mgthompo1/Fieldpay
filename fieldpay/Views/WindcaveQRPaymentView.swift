import SwiftUI
import CoreImage.CIFilterBuiltins

struct WindcaveQRPaymentView: View {
    let amount: Decimal
    let customer: Customer
    let onPaymentSuccess: (Payment) -> Void
    let onPaymentFailure: (Error) -> Void
    
    @StateObject private var windcaveManager = WindcaveManager.shared
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @State private var hppSession: WindcaveHPPSession?
    @State private var qrCodeImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isMonitoringSession = false
    @State private var sessionPollingTask: Task<Void, Never>?
    @State private var paymentStatus = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Windcave Payment")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder for balance
                Text("")
                    .frame(width: 60)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 30) {
                    // Company Branding and Payment Details
                    VStack(spacing: 20) {
                        // Company Logo (if available)
                        if let logoData = settingsViewModel.companyLogoData,
                           let logoImage = UIImage(data: logoData) {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 80)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                        
                        // Company Name (if available)
                        if !settingsViewModel.companyName.isEmpty {
                            Text(settingsViewModel.companyName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Payment Details Card - More Prominent
                        VStack(spacing: 20) {
                            // Customer Information
                            VStack(spacing: 8) {
                                Text("Payment Request")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Text(customer.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                if let email = customer.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Amount - Very Prominent
                            VStack(spacing: 4) {
                                Text("Amount Due")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Text(formatCurrency(amount))
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    
                    // QR Code Display
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Creating payment session...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                    } else if let qrImage = qrCodeImage {
                        VStack(spacing: 20) {
                            // QR Code Header
                            VStack(spacing: 8) {
                                Text("Scan to Pay")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Point your phone camera at the QR code below")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // QR Code with enhanced styling
                            VStack(spacing: 16) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 220, height: 220)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                Text("Secure payment powered by Windcave")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            
                            // Payment Instructions
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Payment Instructions:")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .top) {
                                        Text("1.")
                                            .fontWeight(.medium)
                                        Text("Open your phone's camera app")
                                    }
                                    HStack(alignment: .top) {
                                        Text("2.")
                                            .fontWeight(.medium)
                                        Text("Point camera at the QR code above")
                                    }
                                    HStack(alignment: .top) {
                                        Text("3.")
                                            .fontWeight(.medium)
                                        Text("Tap the notification to open payment page")
                                    }
                                    HStack(alignment: .top) {
                                        Text("4.")
                                            .fontWeight(.medium)
                                        Text("Enter your card details and confirm")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            // Show monitoring status
                            if isMonitoringSession {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Waiting for payment...")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.red)
                            
                            Text("Error Creating Payment")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                createPaymentSession()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    // Session Status
                    if let session = hppSession {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("Session ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(session.id)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Status:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(paymentStatus.isEmpty ? session.state.capitalized : paymentStatus)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(getStatusColor(session.state))
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("Debug: WindcaveQRPaymentView - View appeared")
            print("Debug: WindcaveQRPaymentView - Amount: \(amount)")
            print("Debug: WindcaveQRPaymentView - Customer: \(customer.name)")
            createPaymentSession()
        }
        .onDisappear {
            // Cancel session monitoring when view disappears
            sessionPollingTask?.cancel()
            sessionPollingTask = nil
        }
    }
    
    private func createPaymentSession() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let merchantReference = "FP-\(UUID().uuidString.prefix(8))"
                let session = try await windcaveManager.createHPPSession(
                    amount: amount,
                    currency: "NZD", // You can make this configurable
                    merchantReference: merchantReference,
                    customerName: customer.name
                )
                
                await MainActor.run {
                    self.hppSession = session
                    self.isLoading = false
                    
                    // Generate QR code
                    if let hppUrl = session.hppUrl {
                        self.qrCodeImage = generateQRCode(from: hppUrl)
                        
                        // Start monitoring session
                        startSessionMonitoring(sessionId: session.id)
                    } else {
                        self.errorMessage = "Failed to get payment URL from session"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("Debug: WindcaveQRPaymentView - Error creating session: \(error)")
                }
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: String.Encoding.ascii) else {
            return nil
        }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        if let outputImage = filter.outputImage {
            // Scale the QR code to make it crisp
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
    
    private func startSessionMonitoring(sessionId: String) {
        guard !isMonitoringSession else { return }
        
        isMonitoringSession = true
        print("Debug: WindcaveQRPaymentView - Starting session monitoring for: \(sessionId)")
        
        // Start polling the session status
        sessionPollingTask = Task {
            while !Task.isCancelled && isMonitoringSession {
                do {
                    let sessionStatus = try await windcaveManager.checkHPPSessionStatus(sessionId: sessionId)
                    
                    await MainActor.run {
                        paymentStatus = sessionStatus.state.capitalized
                        
                        // Enhanced debugging for session status
                        print("Debug: WindcaveQRPaymentView - Session status details:")
                        print("  - State: \(sessionStatus.state)")
                        print("  - Response Code: \(sessionStatus.responseCode ?? "nil")")
                        print("  - Response Text: \(sessionStatus.responseText ?? "nil")")
                        print("  - isCompleted: \(sessionStatus.isCompleted)")
                        print("  - isApproved: \(sessionStatus.isApproved)")
                        
                        // Check if payment is completed
                        if sessionStatus.isCompleted {
                            if sessionStatus.isApproved {
                                print("Debug: WindcaveQRPaymentView - Payment successful!")
                                handlePaymentSuccess(sessionStatus)
                            } else {
                                print("Debug: WindcaveQRPaymentView - Payment failed or declined")
                                handlePaymentFailure(sessionStatus)
                            }
                            isMonitoringSession = false
                            return
                        }
                    }
                    
                    // Wait 3 seconds before next poll
                    try await Task.sleep(for: .seconds(3))
                    
                } catch {
                    print("Debug: WindcaveQRPaymentView - Session monitoring error: \(error)")
                    
                    // Continue monitoring unless it's a critical error
                    if error is WindcaveError {
                        await MainActor.run {
                            paymentStatus = "Error checking status"
                        }
                    }
                    
                    // Wait 5 seconds before retrying on error
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }
    
    private func handlePaymentSuccess(_ sessionStatus: WindcaveHPPSessionStatus) {
        print("Debug: WindcaveQRPaymentView - Processing successful payment")
        
        let payment = Payment(
            amount: amount,
            currency: sessionStatus.currency ?? "NZD",
            status: .succeeded,
            paymentMethod: .windcaveTapToPay,
            customerId: customer.id,
            invoiceId: nil,
            description: "Windcave QR Payment",
            stripePaymentIntentId: nil,
            netSuitePaymentId: sessionStatus.transactionId,
            createdDate: Date(),
            processedDate: Date(),
            failureReason: nil
        )
        
        onPaymentSuccess(payment)
        dismiss()
    }
    
    private func handlePaymentFailure(_ sessionStatus: WindcaveHPPSessionStatus) {
        print("Debug: WindcaveQRPaymentView - Processing failed payment")
        
        let error = NSError(
            domain: "WindcavePayment",
            code: Int(sessionStatus.responseCode ?? "999") ?? 999,
            userInfo: [
                NSLocalizedDescriptionKey: sessionStatus.responseText ?? "Payment failed"
            ]
        )
        
        onPaymentFailure(error)
        dismiss()
    }
    
    private func getStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "init", "pending":
            return .orange
        case "completed":
            return .green
        case "failed", "declined":
            return .red
        case "cancelled":
            return .gray
        default:
            return .blue
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "NZD" // Make this configurable
        formatter.locale = Locale(identifier: "en_NZ")
        return formatter.string(from: amount as NSNumber) ?? "$0.00"
    }
}

#Preview {
    WindcaveQRPaymentView(
        amount: Decimal(25.50),
        customer: Customer(
            id: "1",
            name: "John Smith",
            email: "john.smith@example.com",
            phone: "+64 21 123 4567",
            companyName: "Example Company"
        ),
        onPaymentSuccess: { _ in },
        onPaymentFailure: { _ in }
    )
    .environmentObject(SettingsViewModel())
}