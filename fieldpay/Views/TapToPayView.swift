//
//  TapToPayView.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/27/25.
//

import SwiftUI
// import TapToPaySDK  // Temporarily commented out due to build issues

struct TapToPayView: View {
    @StateObject private var tapToPayManager = TapToPayManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String = ""
    @State private var description: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Tap to Pay")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Accept contactless payments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Status Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: tapToPayManager.isInitialized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(tapToPayManager.isInitialized ? .green : .orange)
                        
                        Text("Status")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Text(tapToPayManager.isInitialized ? "Ready for payments" : "Initializing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Payment Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.headline)
                        
                        HStack {
                            Text("$")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $amount)
                                .font(.title2)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        TextField("Payment description", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Process Payment Button
                Button(action: {
                    guard let amountValue = Decimal(string: amount), amountValue > 0 else {
                        tapToPayManager.errorMessage = "Please enter a valid amount"
                        return
                    }
                    
                    Task {
                        do {
                            let result = try await tapToPayManager.processPayment(
                                amount: amountValue,
                                description: description.isEmpty ? "FieldPay Payment" : description
                            )
                            print("Debug: Payment processed successfully: \(result.transactionId)")
                        } catch {
                            tapToPayManager.errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    HStack {
                        if tapToPayManager.isProcessingPayment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "creditcard.fill")
                        }
                        
                        Text(tapToPayManager.isProcessingPayment ? "Processing..." : "Process Payment")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tapToPayManager.isInitialized ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!tapToPayManager.isInitialized || tapToPayManager.isProcessingPayment)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Tap to Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Payment Result", isPresented: .constant(tapToPayManager.lastPaymentResult != nil)) {
                Button("OK") {
                    tapToPayManager.lastPaymentResult = nil
                    if tapToPayManager.lastPaymentResult?.status == .success {
                        dismiss()
                    }
                }
            } message: {
                if let result = tapToPayManager.lastPaymentResult {
                    switch result.status {
                    case .success:
                        Text("Payment successful! Transaction ID: \(result.transactionId)")
                    case .failed:
                        Text("Payment failed")
                    case .cancelled:
                        Text("Payment cancelled")
                    case .pending:
                        Text("Payment pending")
                    }
                }
            }
            .alert("Error", isPresented: .constant(tapToPayManager.errorMessage != nil)) {
                Button("OK") {
                    tapToPayManager.errorMessage = nil
                }
            } message: {
                if let error = tapToPayManager.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

#Preview {
    TapToPayView()
} 