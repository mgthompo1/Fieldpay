//
//  NetSuiteDebugView.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/27/25.
//

import SwiftUI

struct NetSuiteDebugView: View {
    @StateObject private var oAuthManager = OAuthManager.shared
    @StateObject private var netSuiteAPI = NetSuiteAPI.shared
    @StateObject private var netSuiteAPIDebug = NetSuiteAPIDebug.shared
    
    @State private var debugOutput: String = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NetSuite API Debug")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Test and debug NetSuite API integration")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                    
                    // OAuth Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OAuth Status")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(oAuthManager.isAuthenticated ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text(oAuthManager.isAuthenticated ? "Authenticated" : "Not Authenticated")
                                .font(.subheadline)
                        }
                        
                        if let accessToken = oAuthManager.accessToken {
                            Text("Access Token: \(accessToken.prefix(20))...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let accountId = UserDefaults.standard.string(forKey: "netsuite_account_id") {
                            Text("Account ID: \(accountId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Debug Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debug Actions")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            DebugButton(title: "Test Connection", action: testConnection)
                            DebugButton(title: "Fetch Customers", action: fetchCustomers)
                            DebugButton(title: "Fetch Invoices", action: fetchInvoices)
                            DebugButton(title: "Test Raw Customer API", action: testRawCustomerAPI)
                            DebugButton(title: "Test Raw Invoice API", action: testRawInvoiceAPI)
                            DebugButton(title: "Clear Debug Output", action: clearDebugOutput)
                        }
                    }
                    
                    // Debug Output
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Debug Output")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = debugOutput
                            }
                            .font(.caption)
                        }
                        
                        ScrollView {
                            Text(debugOutput.isEmpty ? "No debug output yet. Run a test to see results." : debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .padding()
            }
            .navigationTitle("NetSuite Debug")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Debug Result", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            debugOutput += "[\(timestamp)] \(message)\n"
        }
    }
    
    private func testConnection() {
        isLoading = true
        log("🔍 Testing NetSuite connection...")
        
        Task {
            do {
                try await netSuiteAPIDebug.testConnection()
                log("✅ Connection test successful!")
                await MainActor.run {
                    alertMessage = "Connection test successful!"
                    showingAlert = true
                }
            } catch {
                log("❌ Connection test failed: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "Connection test failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func fetchCustomers() {
        isLoading = true
        log("🔍 Fetching customers...")
        
        Task {
            do {
                let customers = try await netSuiteAPIDebug.fetchCustomers()
                log("✅ Successfully fetched \(customers.count) customers")
                for (index, customer) in customers.enumerated() {
                    log("  \(index + 1). \(customer.name) (ID: \(customer.id))")
                }
                await MainActor.run {
                    alertMessage = "Successfully fetched \(customers.count) customers"
                    showingAlert = true
                }
            } catch {
                log("❌ Failed to fetch customers: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "Failed to fetch customers: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func fetchInvoices() {
        isLoading = true
        log("🔍 Fetching invoices...")
        
        Task {
            do {
                let invoices = try await netSuiteAPIDebug.fetchInvoices()
                log("✅ Successfully fetched \(invoices.count) invoices")
                for (index, invoice) in invoices.enumerated() {
                    log("  \(index + 1). \(invoice.invoiceNumber) - \(invoice.customerName) ($\(invoice.amount))")
                }
                await MainActor.run {
                    alertMessage = "Successfully fetched \(invoices.count) invoices"
                    showingAlert = true
                }
            } catch {
                log("❌ Failed to fetch invoices: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "Failed to fetch invoices: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func testRawCustomerAPI() {
        isLoading = true
        log("🔍 Testing raw customer API...")
        
        Task {
            do {
                let response = try await netSuiteAPIDebug.testRawAPI(endpoint: "/services/rest/record/v1/customer?limit=5")
                log("✅ Raw customer API response:")
                log(response)
                await MainActor.run {
                    alertMessage = "Raw customer API test successful"
                    showingAlert = true
                }
            } catch {
                log("❌ Raw customer API test failed: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "Raw customer API test failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func testRawInvoiceAPI() {
        isLoading = true
        log("🔍 Testing raw invoice API...")
        
        Task {
            do {
                let response = try await netSuiteAPIDebug.testRawAPI(endpoint: "/services/rest/record/v1/invoice?limit=5")
                log("✅ Raw invoice API response:")
                log(response)
                await MainActor.run {
                    alertMessage = "Raw invoice API test successful"
                    showingAlert = true
                }
            } catch {
                log("❌ Raw invoice API test failed: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "Raw invoice API test failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func clearDebugOutput() {
        debugOutput = ""
    }
}

struct DebugButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NetSuiteDebugView()
} 