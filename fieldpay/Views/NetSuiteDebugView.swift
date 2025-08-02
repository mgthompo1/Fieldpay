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
                                title: "Check Data Status",
                                isLoading: isLoading && loadingTask == "data_status",
                                action: { performAPITest("data_status", checkDataStatus) }
                            )
                            DebugButton(
                                title: "Test Real NetSuite Data",
                                isLoading: isLoading && loadingTask == "real_data",
                                action: { performAPITest("real_data", testRealNetSuiteData) }
                            )
                            DebugButton(
                                title: "Check Keychain Status",
                                isLoading: isLoading && loadingTask == "keychain",
                                action: { performAPITest("keychain", checkKeychainStatus) }
                            )
                            DebugButton(
                                title: "Test Enhanced Pagination",
                                isLoading: isLoading && loadingTask == "enhanced_pagination",
                                action: { performAPITest("enhanced_pagination", testEnhancedPagination) }
                            )
                            DebugButton(
                                title: "Test Detailed Invoice Fetching",
                                isLoading: isLoading && loadingTask == "detailed_invoices",
                                action: { performAPITest("detailed_invoices", testDetailedInvoiceFetching) }
                            )
                            DebugButton(
                                title: "Test Detailed Customer Fetching",
                                isLoading: isLoading && loadingTask == "detailed_customers",
                                action: { performAPITest("detailed_customers", testDetailedCustomerFetching) }
                            )
                            DebugButton(
                                title: "Test SuiteQL Queries",
                                isLoading: isLoading && loadingTask == "suiteql_queries",
                                action: { performAPITest("suiteql_queries", testSuiteQLQueries) }
                            )
                            DebugButton(
                                title: "Discover Transaction Columns",
                                isLoading: isLoading && loadingTask == "discover_columns",
                                action: { performAPITest("discover_columns", discoverTransactionColumns) }
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
            case .invalidURL:
                return "Invalid URL for NetSuite API request. Check your account ID configuration."
            case .unauthorizedRequest:
                return "Request unauthorized (401). Token has been refreshed automatically."
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
    
    private func checkDataStatus() async throws {
        log("🔍 Checking NetSuite data status...")
        let customerCount = try await netSuiteAPIDebug.getCustomerCount()
        let invoiceCount = try await netSuiteAPIDebug.getInvoiceCount()
        log("✅ NetSuite Data Status:")
        log("  • Customers: \(customerCount)")
        log("  • Invoices: \(invoiceCount)")
        await MainActor.run {
            alertMessage = "NetSuite Data Status checked. Customers: \(customerCount), Invoices: \(invoiceCount)"
            showingAlert = true
        }
    }
    
    private func testRealNetSuiteData() async throws {
        log("🔍 Testing real NetSuite data fetch...")
        
        // Test raw API responses first
        log("📡 Testing raw API responses...")
        
        do {
            let rawCustomerResponse = try await netSuiteAPIDebug.testRawAPI(endpoint: "/services/rest/record/v1/customer?limit=3")
            log("📋 Raw Customer API Response:")
            log(String(rawCustomerResponse.prefix(1000)))
            
            let rawInvoiceResponse = try await netSuiteAPIDebug.testRawAPI(endpoint: "/services/rest/record/v1/invoice?limit=3")
            log("📄 Raw Invoice API Response:")
            log(String(rawInvoiceResponse.prefix(1000)))
        } catch {
            log("❌ Raw API test failed: \(error.localizedDescription)")
        }
        
        // Test parsed data
        log("🔄 Testing parsed data...")
        let customers = try await netSuiteAPI.fetchCustomers()
        let invoices = try await netSuiteAPI.fetchInvoices()
        
        log("✅ Parsed NetSuite Data:")
        log("  • Fetched \(customers.count) customers")
        for (index, customer) in customers.enumerated() {
            log("    📋 \(index + 1). \(customer.name) (ID: \(customer.id))")
            if customer.name == "Unknown Customer" {
                log("    ⚠️  WARNING: Customer has 'Unknown Customer' name - possible parsing issue")
            }
        }
        log("  • Fetched \(invoices.count) invoices")
        for (index, invoice) in invoices.enumerated() {
            log("    📄 \(index + 1). \(invoice.invoiceNumber) - \(invoice.customerName) ($\(String(format: "%.2f", NSDecimalNumber(decimal: invoice.amount).doubleValue)))")
            if invoice.customerName == "Unknown Customer" {
                log("    ⚠️  WARNING: Invoice has 'Unknown Customer' - possible parsing issue")
            }
        }
        
        // Check for dummy data indicators
        let hasDummyData = customers.contains { $0.name == "Unknown Customer" } || 
                          invoices.contains { $0.customerName == "Unknown Customer" }
        
        if hasDummyData {
            log("🚨 ALERT: Found 'Unknown Customer' entries - this indicates parsing issues or dummy data")
        } else {
            log("✅ No dummy data detected - all entries have proper names")
        }
        
        await MainActor.run {
            alertMessage = "Real NetSuite Data fetched. Customers: \(customers.count), Invoices: \(invoices.count)"
            showingAlert = true
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
    
    private func checkKeychainStatus() async throws {
        log("🔍 Checking Keychain status for NetSuite credentials...")
        
        let keychain = KeychainWrapper.shared
        
        // Check configuration
        let config = keychain.loadNetSuiteConfiguration()
        log("📋 NetSuite Configuration Status:")
        log("  • Account ID: \(config.accountId != nil ? "✅ Stored" : "❌ Not found")")
        log("  • Client ID: \(config.clientId != nil ? "✅ Stored" : "❌ Not found")")
        log("  • Client Secret: \(config.clientSecret != nil ? "✅ Stored" : "❌ Not found")")
        log("  • Redirect URI: \(config.redirectUri != nil ? "✅ Stored" : "❌ Not found")")
        
        // Check tokens
        let tokens = keychain.loadNetSuiteTokens()
        log("🔐 NetSuite Token Status:")
        log("  • Access Token: \(tokens.accessToken != nil ? "✅ Stored" : "❌ Not found")")
        log("  • Refresh Token: \(tokens.refreshToken != nil ? "✅ Stored" : "❌ Not found")")
        log("  • Token Expiry: \(tokens.expiryDate != nil ? "✅ Stored" : "❌ Not found")")
        
        // Display actual values (masked for security)
        if let accountId = config.accountId {
            log("  📝 Account ID: \(accountId)")
        }
        
        if let clientId = config.clientId {
            let maskedClientId = String(clientId.prefix(8)) + "..." + String(clientId.suffix(4))
            log("  📝 Client ID: \(maskedClientId)")
        }
        
        if let clientSecret = config.clientSecret {
            let maskedSecret = String(clientSecret.prefix(4)) + "..." + String(clientSecret.suffix(4))
            log("  📝 Client Secret: \(maskedSecret)")
        }
        
        if let redirectUri = config.redirectUri {
            log("  📝 Redirect URI: \(redirectUri)")
        }
        
        if let accessToken = tokens.accessToken {
            let maskedToken = String(accessToken.prefix(10)) + "..." + String(accessToken.suffix(10))
            log("  📝 Access Token: \(maskedToken)")
        }
        
        if let refreshToken = tokens.refreshToken {
            let maskedToken = String(refreshToken.prefix(10)) + "..." + String(refreshToken.suffix(10))
            log("  📝 Refresh Token: \(maskedToken)")
        }
        
        if let expiryDate = tokens.expiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            log("  📝 Token Expiry: \(formatter.string(from: expiryDate))")
            
            // Check if token is expired
            if expiryDate < Date() {
                log("  ⚠️  WARNING: Access token has expired!")
            } else {
                let timeRemaining = expiryDate.timeIntervalSince(Date())
                let hoursRemaining = timeRemaining / 3600
                log("  ✅ Token is valid for \(String(format: "%.1f", hoursRemaining)) more hours")
            }
        }
        
        // Summary
        let hasConfig = config.accountId != nil && config.clientId != nil && config.clientSecret != nil
        let hasTokens = tokens.accessToken != nil && tokens.refreshToken != nil
        
        log("📊 Summary:")
        log("  • Configuration Complete: \(hasConfig ? "✅ Yes" : "❌ No")")
        log("  • Tokens Available: \(hasTokens ? "✅ Yes" : "❌ No")")
        
        if hasConfig && hasTokens {
            log("  🎉 Keychain is properly configured and ready for NetSuite API calls!")
        } else if hasConfig && !hasTokens {
            log("  🔄 Configuration is set up but tokens are missing - OAuth flow needed")
        } else if !hasConfig && hasTokens {
            log("  ⚠️  Tokens exist but configuration is missing - incomplete setup")
        } else {
            log("  ❌ No NetSuite credentials found in Keychain - complete setup required")
        }
        
        await MainActor.run {
            alertMessage = "Keychain status checked. Configuration: \(hasConfig ? "Complete" : "Incomplete"), Tokens: \(hasTokens ? "Available" : "Missing")"
            showingAlert = true
        }
    }
    
    private func testEnhancedPagination() async throws {
        log("🔍 Testing enhanced pagination for invoices...")
        
        // Test the new fetchAllInvoices method
        let invoices = try await netSuiteAPI.fetchAllInvoices()
        
        log("✅ Enhanced pagination test successful!")
        log("📊 Results:")
        log("  • Total invoices fetched: \(invoices.count)")
        
        // Show some sample data
        for (index, invoice) in invoices.prefix(5).enumerated() {
            log("  📄 \(index + 1). \(invoice.invoiceNumber) - \(invoice.customerName) ($\(String(format: "%.2f", NSDecimalNumber(decimal: invoice.amount).doubleValue)))")
        }
        
        if invoices.count > 5 {
            log("  ... and \(invoices.count - 5) more invoices")
        }
        
        await MainActor.run {
            alertMessage = "Enhanced pagination test successful! Fetched \(invoices.count) invoices"
            showingAlert = true
        }
    }
    
    private func testDetailedInvoiceFetching() async throws {
        log("🔍 Testing detailed invoice fetching with Codable models...")
        
        // First get some invoice IDs
        let invoices = try await netSuiteAPI.fetchAllInvoices()
        
        if invoices.isEmpty {
            log("❌ No invoices found to test detailed fetching")
            await MainActor.run {
                alertMessage = "No invoices found to test detailed fetching"
                showingAlert = true
            }
            return
        }
        
        // Take first 3 invoices for detailed fetching
        let invoiceIds = Array(invoices.prefix(3).map { $0.id })
        log("📋 Fetching detailed data for \(invoiceIds.count) invoices: \(invoiceIds.joined(separator: ", "))")
        
        // Fetch detailed invoices using new Codable models
        let detailedInvoices = try await netSuiteAPI.fetchDetailedInvoices(for: invoiceIds, concurrentLimit: 3)
        
        log("✅ Detailed invoice fetching test successful!")
        log("📊 Results:")
        log("  • Detailed invoices fetched: \(detailedInvoices.count)")
        
        // Show some sample detailed data using the new Codable models
        for (index, detailedInvoice) in detailedInvoices.enumerated() {
            log("  📄 Detailed Invoice \(index + 1):")
            
            // Using the new Codable model properties
            log("    • Transaction ID: \(detailedInvoice.tranId ?? "N/A")")
            log("    • Customer: \(detailedInvoice.customerName)")
            log("    • Total Amount: \(detailedInvoice.formattedTotal)")
            log("    • Balance: \(detailedInvoice.formattedBalance)")
            log("    • Status: \(detailedInvoice.status?.rawValue ?? "N/A")")
            log("    • Line Items: \(detailedInvoice.lineItemsSummary)")
            
            // Check if paid
            if detailedInvoice.isPaid {
                log("    • ✅ Invoice is paid")
            } else {
                log("    • ⚠️ Invoice has outstanding balance")
            }
            
            // Show days until due
            if let daysUntilDue = detailedInvoice.daysUntilDue {
                if daysUntilDue < 0 {
                    log("    • 🔴 Overdue by \(abs(daysUntilDue)) days")
                } else if daysUntilDue == 0 {
                    log("    • 🟡 Due today")
                } else {
                    log("    • 🟢 Due in \(daysUntilDue) days")
                }
            }
            
            // Show line items details
            if detailedInvoice.hasLineItems {
                log("    📋 Line Items Details:")
                for (lineIndex, lineItem) in (detailedInvoice.item?.item ?? []).enumerated() {
                    log("      \(lineIndex + 1). \(lineItem.summary)")
                }
            }
        }
        
        // Test conversion to existing Invoice model
        log("🔄 Testing conversion to existing Invoice model...")
        for (index, detailedInvoice) in detailedInvoices.enumerated() {
            let convertedInvoice = detailedInvoice.toInvoice()
            log("  📄 Converted Invoice \(index + 1): \(convertedInvoice.invoiceNumber) - \(convertedInvoice.customerName)")
            log("    • Items count: \(convertedInvoice.items.count)")
        }
        
        await MainActor.run {
            alertMessage = "Detailed invoice fetching test successful! Fetched \(detailedInvoices.count) detailed invoices with Codable models"
            showingAlert = true
        }
    }
    
    private func testDetailedCustomerFetching() async throws {
        log("🔍 Testing detailed customer fetching with Codable models...")
        
        // First get some customer IDs
        let customers = try await netSuiteAPI.fetchAllCustomers()
        
        if customers.isEmpty {
            log("❌ No customers found to test detailed fetching")
            await MainActor.run {
                alertMessage = "No customers found to test detailed fetching"
                showingAlert = true
            }
            return
        }
        
        // Take first 3 customers for detailed fetching
        let customerIds = Array(customers.prefix(3).map { $0.id })
        log("📋 Fetching detailed data for \(customerIds.count) customers: \(customerIds.joined(separator: ", "))")
        
        // Fetch detailed customers using new Codable models
        let detailedCustomers = try await netSuiteAPI.fetchDetailedCustomers(for: customerIds, concurrentLimit: 3)
        
        log("✅ Detailed customer fetching test successful!")
        log("📊 Results:")
        log("  • Detailed customers fetched: \(detailedCustomers.count)")
        
        // Show some sample detailed data using the new Codable models
        for (index, detailedCustomer) in detailedCustomers.enumerated() {
            log("  👤 Detailed Customer \(index + 1):")
            
            // Using the new Codable model properties
            log("    • Customer ID: \(detailedCustomer.id)")
            log("    • Display Name: \(detailedCustomer.displayName)")
            log("    • Contact Info: \(detailedCustomer.contactSummary)")
            log("    • Address: \(detailedCustomer.addressSummary)")
            log("    • Balance: \(detailedCustomer.formattedBalance)")
            log("    • Status: \(detailedCustomer.statusSummary)")
            
            // Check if active
            if detailedCustomer.isActive {
                log("    • ✅ Customer is active")
            } else {
                log("    • ⚠️ Customer is inactive")
            }
            
            // Check if has outstanding balance
            if detailedCustomer.hasOutstandingBalance {
                log("    • 🔴 Customer has outstanding balance")
            } else {
                log("    • 🟢 Customer has no outstanding balance")
            }
            
            // Show days since last order
            if let daysSinceLastOrder = detailedCustomer.daysSinceLastOrder {
                if daysSinceLastOrder == 0 {
                    log("    • 📅 Last order: Today")
                } else if daysSinceLastOrder == 1 {
                    log("    • 📅 Last order: Yesterday")
                } else {
                    log("    • 📅 Last order: \(daysSinceLastOrder) days ago")
                }
            } else {
                log("    • 📅 No order history")
            }
            
            // Show address book details
            if let addressbook = detailedCustomer.addressbook, !addressbook.isEmpty {
                log("    📋 Address Book Details:")
                for (addrIndex, addressEntry) in addressbook.enumerated() {
                    let label = addressEntry.label ?? "Unnamed Address"
                    let type = addressEntry.defaultBilling == true ? "Billing" : addressEntry.defaultShipping == true ? "Shipping" : "Other"
                    log("      \(addrIndex + 1). \(label) (\(type))")
                    
                    if let address = addressEntry.addressbookAddress {
                        var addressParts: [String] = []
                        if let addr1 = address.addr1, !addr1.isEmpty { addressParts.append(addr1) }
                        if let city = address.city, !city.isEmpty { addressParts.append(city) }
                        if let state = address.state, !state.isEmpty { addressParts.append(state) }
                        if let zip = address.zip, !zip.isEmpty { addressParts.append(zip) }
                        if let country = address.country, !country.isEmpty { addressParts.append(country) }
                        
                        let formattedAddress = addressParts.isEmpty ? "No address details" : addressParts.joined(separator: ", ")
                        log("        \(formattedAddress)")
                    } else {
                        log("        No address details")
                    }
                }
            } else {
                log("    📋 No address book entries")
            }
        }
        
        // Test conversion to existing Customer model
        log("🔄 Testing conversion to existing Customer model...")
        for (index, detailedCustomer) in detailedCustomers.enumerated() {
            let convertedCustomer = detailedCustomer.toCustomer()
            log("  👤 Converted Customer \(index + 1): \(convertedCustomer.name)")
            log("    • Email: \(convertedCustomer.email ?? "N/A")")
            log("    • Phone: \(convertedCustomer.phone ?? "N/A")")
            if let address = convertedCustomer.address {
                log("    • Address: \(address.street ?? ""), \(address.city ?? ""), \(address.state ?? "") \(address.zipCode ?? "")")
            } else {
                log("    • Address: N/A")
            }
        }
        
        await MainActor.run {
            alertMessage = "Detailed customer fetching test successful! Fetched \(detailedCustomers.count) detailed customers with Codable models"
            showingAlert = true
        }
    }
    
    private func testSuiteQLQueries() async {
        log("🔍 Testing SuiteQL queries for customer transaction and payment history...")
        
        do {
            // Test SuiteQL for Customer Transaction History
            log("📋 Testing SuiteQL for Customer Transaction History...")
            let transactionQuery = SuiteQLQuery.customerTransactionHistory(customerId: "1264") // Use a valid customer ID
            let transactionResponse = try await NetSuiteAPI.shared.executeSuiteQLQuery(transactionQuery.query)
            log("✅ SuiteQL Transaction History executed successfully")
            log("   - Count: \(transactionResponse.count)")
            log("   - Has More: \(transactionResponse.hasMore)")
            log("   - Items: \(transactionResponse.items.count)")
            
            // Test SuiteQL for Customer Payment History
            log("📋 Testing SuiteQL for Customer Payment History...")
            let paymentQuery = SuiteQLQuery.customerPaymentHistory(customerId: "1264") // Use a valid customer ID
            let paymentResponse = try await NetSuiteAPI.shared.executeSuiteQLQuery(paymentQuery.query)
            log("✅ SuiteQL Payment History executed successfully")
            log("   - Count: \(paymentResponse.count)")
            log("   - Has More: \(paymentResponse.hasMore)")
            log("   - Items: \(paymentResponse.items.count)")
            
            // Test SuiteQL for Customer Invoice History
            log("📋 Testing SuiteQL for Customer Invoice History...")
            let invoiceQuery = SuiteQLQuery.customerInvoiceHistory(customerId: "1264") // Use a valid customer ID
            let invoiceResponse = try await NetSuiteAPI.shared.executeSuiteQLQuery(invoiceQuery.query)
            log("✅ SuiteQL Invoice History executed successfully")
            log("   - Count: \(invoiceResponse.count)")
            log("   - Has More: \(invoiceResponse.hasMore)")
            log("   - Items: \(invoiceResponse.items.count)")
            
            await MainActor.run {
                alertMessage = "SuiteQL queries executed successfully! All three query types (transactions, payments, invoices) returned results."
                showingAlert = true
            }
            
        } catch {
            log("❌ SuiteQL query test failed: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "SuiteQL query test failed: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    /// Discover available columns in NetSuite transaction table
    private func discoverTransactionColumns() async {
        do {
            let columns = try await netSuiteAPI.debugTableColumns("transaction")
            await MainActor.run {
                log("🔍 Transaction Table Column Discovery")
                log("📊 Available columns in 'transaction' table:")
                for (index, column) in columns.enumerated() {
                    log("  \(index + 1). \(column)")
                }
                log("💡 Use these column names in your SuiteQL SELECT statements")
                log("✅ Total columns found: \(columns.count)")
            }
        } catch {
            await MainActor.run {
                log("❌ Failed to discover transaction columns: \(error.localizedDescription)")
                alertMessage = "Column discovery failed: \(error.localizedDescription)"
                showingAlert = true
            }
        }
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