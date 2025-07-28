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
    @State private var loadingTask: String? = nil
    
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
                            DebugButton(
                                title: "Test Connection",
                                isLoading: isLoading && loadingTask == "connection",
                                action: { performAPITest("connection", testConnection) }
                            )
                            DebugButton(
                                title: "Fetch Customers",
                                isLoading: isLoading && loadingTask == "customers",
                                action: { performAPITest("customers", fetchCustomers) }
                            )
                            DebugButton(
                                title: "Fetch Invoices",
                                isLoading: isLoading && loadingTask == "invoices",
                                action: { performAPITest("invoices", fetchInvoices) }
                            )
                            DebugButton(
                                title: "Test Raw Customer API",
                                isLoading: isLoading && loadingTask == "raw_customer",
                                action: { performAPITest("raw_customer", testRawCustomerAPI) }
                            )
                            DebugButton(
                                title: "Test Raw Invoice API",
                                isLoading: isLoading && loadingTask == "raw_invoice",
                                action: { performAPITest("raw_invoice", testRawInvoiceAPI) }
                            )
                            DebugButton(
                                title: "Generate OAuth URL",
                                isLoading: isLoading && loadingTask == "oauth_url",
                                action: { performAPITest("oauth_url", generateOAuthURL) }
                            )
                            DebugButton(
                                title: "Clear Debug Output",
                                isLoading: false,
                                action: clearDebugOutput
                            )
                        }
                    }
                    
                    // Debug Output
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Debug Output")
                                .font(.headline)
                            Spacer()
                            Button("Copy All") {
                                UIPasteboard.general.string = debugOutput
                            }
                            .font(.caption)
                            .disabled(debugOutput.isEmpty)
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
            .overlay(
                // Loading overlay for better UX
                Group {
                    if isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("\(loadingTask?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Loading")...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generic API test wrapper with proper loading state management
    private func performAPITest(_ taskName: String, _ operation: @escaping () async throws -> Void) {
        guard !isLoading else { return } // Prevent multiple simultaneous operations
        
        isLoading = true
        loadingTask = taskName
        
        Task {
            defer {
                // Ensure loading state is always reset, even if task is cancelled
                Task { @MainActor in
                    isLoading = false
                    loadingTask = nil
                }
            }
            
            do {
                try await operation()
            } catch {
                handleError(error, for: taskName)
            }
        }
    }
    
    /// Centralized error handling with detailed error information
    @MainActor
    private func handleError(_ error: Error, for taskName: String) {
        let errorMessage = formatErrorMessage(error, for: taskName)
        log("❌ \(taskName.replacingOccurrences(of: "_", with: " ").capitalized) failed: \(errorMessage)")
        alertMessage = errorMessage
        showingAlert = true
    }
    
    /// Enhanced error formatting with API-specific error details
    private func formatErrorMessage(_ error: Error, for taskName: String) -> String {
        if let netSuiteError = error as? NetSuiteError {
            switch netSuiteError {
            case .notConfigured:
                return "NetSuite API not configured. Please check your account ID and access token."
            case .requestFailed:
                return "API request failed. Check your network connection and API credentials."
            case .invalidResponse:
                return "Invalid response from NetSuite API. The response format may have changed."
            case .authenticationFailed:
                return "Authentication failed. Your access token may be expired or invalid."
            }
        }
        
        // Handle network errors with more detail
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection available."
            case .timedOut:
                return "Request timed out. The server may be slow or unavailable."
            case .cannotFindHost:
                return "Cannot find NetSuite server. Check your account ID configuration."
            case .userAuthenticationRequired:
                return "Unauthorized access. Check your API credentials."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        
        return error.localizedDescription
    }
    
    /// Enhanced logging with better formatting and timestamps
    private func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let formattedMessage = "[\(timestamp)] \(message)"
            debugOutput += formattedMessage + "\n"
            
            // Auto-scroll to bottom for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // This would require a ScrollViewReader in a more complex implementation
                // For now, we'll just append to the output
            }
        }
    }
    
    // MARK: - API Test Methods
    
    private func testConnection() async throws {
        log("🔍 Testing NetSuite connection...")
        try await netSuiteAPIDebug.testConnection()
        log("✅ Connection test successful!")
        await MainActor.run {
            alertMessage = "Connection test successful!"
            showingAlert = true
        }
    }
    
    private func fetchCustomers() async throws {
        log("🔍 Fetching customers...")
        let customers = try await netSuiteAPIDebug.fetchCustomers()
        log("✅ Successfully fetched \(customers.count) customers")
        
        // Log customer details with better formatting
        for (index, customer) in customers.enumerated() {
            log("  📋 \(index + 1). \(customer.name) (ID: \(customer.id))")
        }
        
        await MainActor.run {
            alertMessage = "Successfully fetched \(customers.count) customers"
            showingAlert = true
        }
    }
    
    private func fetchInvoices() async throws {
        log("🔍 Fetching invoices...")
        let invoices = try await netSuiteAPIDebug.fetchInvoices()
        log("✅ Successfully fetched \(invoices.count) invoices")
        
        // Log invoice details with better formatting
        for (index, invoice) in invoices.enumerated() {
            log("  📄 \(index + 1). \(invoice.invoiceNumber) - \(invoice.customerName) ($\(String(format: "%.2f", NSDecimalNumber(decimal: invoice.amount).doubleValue)))")
        }
        
        await MainActor.run {
            alertMessage = "Successfully fetched \(invoices.count) invoices"
            showingAlert = true
        }
    }
    
    private func testRawCustomerAPI() async throws {
        log("🔍 Testing raw customer API...")
        let response = try await netSuiteAPIDebug.testRawAPI(endpoint: "/services/rest/record/v1/customer?limit=5")
        log("✅ Raw customer API response:")
        log(formatJSONResponse(response))
        await MainActor.run {
            alertMessage = "Raw customer API test successful"
            showingAlert = true
        }
    }
    
    private func testRawInvoiceAPI() async throws {
        log("🔍 Testing raw invoice API...")
        let response = try await netSuiteAPIDebug.testRawAPI(endpoint: "/services/rest/record/v1/invoice?limit=5")
        log("✅ Raw invoice API response:")
        log(formatJSONResponse(response))
        await MainActor.run {
            alertMessage = "Raw invoice API test successful"
            showingAlert = true
        }
    }
    
    private func generateOAuthURL() async throws {
        log("🔍 Generating OAuth authorization URL...")
        if let url = oAuthManager.generateAuthorizationURLForDebug() {
            log("✅ Authorization URL: \(url)")
            await MainActor.run {
                alertMessage = "Authorization URL generated successfully"
                showingAlert = true
            }
        } else {
            log("❌ Failed to generate authorization URL")
            await MainActor.run {
                alertMessage = "Failed to generate authorization URL"
                showingAlert = true
            }
        }
    }
    
    /// Format JSON response for better readability in debug output
    private func formatJSONResponse(_ response: String) -> String {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return response
        }
        return prettyString
    }
    
    private func clearDebugOutput() {
        debugOutput = ""
    }
}

struct DebugButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

#Preview {
    NetSuiteDebugView()
} 