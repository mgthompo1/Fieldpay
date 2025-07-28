//
//  NetSuiteAPIDebug.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/27/25.
//

import Foundation
import Combine

class NetSuiteAPIDebug: ObservableObject {
    static let shared = NetSuiteAPIDebug()
    
    private(set) var accessToken: String?
    private var accountId: String?
    
    private var baseURL: String {
        guard let accountId = accountId, !accountId.isEmpty else {
            print("🔴 DEBUG: NetSuiteAPI - Account ID not configured, cannot make API calls")
            return "https://placeholder.suitetalk.api.netsuite.com"
        }
        let url = "https://\(accountId).suitetalk.api.netsuite.com"
        print("🔵 DEBUG: NetSuiteAPI - Using base URL: \(url)")
        return url
    }
    
    private init() {}
    
    // MARK: - Configuration
    func configure(accountId: String, accessToken: String) {
        self.accountId = accountId
        self.accessToken = accessToken
        print("🟢 DEBUG: NetSuiteAPI configured with account ID: \(accountId)")
        print("🟢 DEBUG: NetSuiteAPI access token length: \(accessToken.count)")
        print("🟢 DEBUG: NetSuiteAPI access token preview: \(accessToken.prefix(20))...")
    }
    
    func isConfigured() -> Bool {
        let configured = accountId != nil && !accountId!.isEmpty && accessToken != nil && !accessToken!.isEmpty
        print("🔍 DEBUG: NetSuiteAPI configuration status: \(configured)")
        if configured {
            print("🟢 DEBUG: NetSuiteAPI - Account ID: \(accountId ?? "nil")")
            print("🟢 DEBUG: NetSuiteAPI - Access token present: \(accessToken != nil)")
            print("🟢 DEBUG: NetSuiteAPI - Access token length: \(accessToken?.count ?? 0)")
        } else {
            print("🔴 DEBUG: NetSuiteAPI - Missing configuration:")
            print("  - Account ID: \(accountId ?? "nil")")
            print("  - Access token: \(accessToken != nil ? "present" : "missing")")
        }
        return configured
    }
    
    func testConnection() async throws {
        guard isConfigured() else {
            print("🔴 DEBUG: NetSuiteAPI - Not configured for connection test")
            throw NetSuiteError.notConfigured
        }
        
        // Try to fetch a single customer to test the connection
        let endpoint = "/services/rest/record/v1/customer?limit=1"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔍 DEBUG: NetSuiteAPI - Testing connection to: \(url)")
        print("🔍 DEBUG: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 DEBUG: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("📊 DEBUG: NetSuiteAPI - Test connection response status: \(httpResponse.statusCode)")
        print("📊 DEBUG: NetSuiteAPI - Test connection response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 DEBUG: NetSuiteAPI - Test connection response body: \(responseString)")
        }
        
        if httpResponse.statusCode != 200 {
            print("🔴 DEBUG: NetSuiteAPI - Test connection failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        print("🟢 DEBUG: NetSuiteAPI - Connection test successful")
    }
    
    // MARK: - Data Status Methods
    func getCustomerCount() async throws -> Int {
        guard isConfigured() else {
            print("🔴 DEBUG: NetSuiteAPI - Not configured for customer count")
            throw NetSuiteError.notConfigured
        }
        
        let endpoint = "/services/rest/record/v1/customer?limit=1"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔍 DEBUG: NetSuiteAPI - Getting customer count from: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        print("📊 DEBUG: NetSuiteAPI - Customer count response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 DEBUG: NetSuiteAPI - Customer count response: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        // Try to parse the response to get count
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteCustomerResponse>.self, from: data)
            return netSuiteResponse.count ?? netSuiteResponse.items.count
        } catch {
            print("⚠️ DEBUG: NetSuiteAPI - Could not parse customer count response: \(error)")
            return 0
        }
    }
    
    func getInvoiceCount() async throws -> Int {
        guard isConfigured() else {
            print("🔴 DEBUG: NetSuiteAPI - Not configured for invoice count")
            throw NetSuiteError.notConfigured
        }
        
        let endpoint = "/services/rest/record/v1/invoice?limit=1"
        let url = URL(string: baseURL + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔍 DEBUG: NetSuiteAPI - Getting invoice count from: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetSuiteError.requestFailed
        }
        
        print("📊 DEBUG: NetSuiteAPI - Invoice count response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 DEBUG: NetSuiteAPI - Invoice count response: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetSuiteError.requestFailed
        }
        
        // Try to parse the response to get count
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteInvoiceResponse>.self, from: data)
            return netSuiteResponse.count ?? netSuiteResponse.items.count
        } catch {
            print("⚠️ DEBUG: NetSuiteAPI - Could not parse invoice count response: \(error)")
            return 0
        }
    }
    
    // MARK: - Comprehensive Data Testing
    func testRealNetSuiteData() async throws -> String {
        guard isConfigured() else {
            return "❌ NetSuite not configured"
        }
        
        var result = "🔍 NetSuite Data Test Results:\n\n"
        
        // Test customers
        do {
            let customerCount = try await getCustomerCount()
            result += "👥 Customers: \(customerCount)\n"
        } catch {
            result += "👥 Customers: ❌ Error - \(error.localizedDescription)\n"
        }
        
        // Test invoices
        do {
            let invoiceCount = try await getInvoiceCount()
            result += "📄 Invoices: \(invoiceCount)\n"
        } catch {
            result += "📄 Invoices: ❌ Error - \(error.localizedDescription)\n"
        }
        
        // Test raw customer data
        do {
            let rawCustomerData = try await testRawAPI(endpoint: "/services/rest/record/v1/customer?limit=3")
            result += "\n📋 Sample Customer Data:\n\(rawCustomerData.prefix(500))...\n"
        } catch {
            result += "\n📋 Sample Customer Data: ❌ Error - \(error.localizedDescription)\n"
        }
        
        // Test raw invoice data
        do {
            let rawInvoiceData = try await testRawAPI(endpoint: "/services/rest/record/v1/invoice?limit=3")
            result += "\n📋 Sample Invoice Data:\n\(rawInvoiceData.prefix(500))...\n"
        } catch {
            result += "\n📋 Sample Invoice Data: ❌ Error - \(error.localizedDescription)\n"
        }
        
        return result
    }
    
    // MARK: - Customers
    func fetchCustomers() async throws -> [Customer] {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            print("🔴 DEBUG: NetSuiteAPI - Access token not configured")
            throw NetSuiteError.notConfigured
        }
        
        let endpoint = "/services/rest/record/v1/customer"
        let url = URL(string: baseURL + endpoint)!
        
        print("🔍 DEBUG: NetSuiteAPI - Fetching customers from: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔍 DEBUG: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 DEBUG: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("📊 DEBUG: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
        print("📊 DEBUG: NetSuiteAPI - Response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 DEBUG: NetSuiteAPI - Response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("🔴 DEBUG: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        // Parse NetSuite customer response using the proper response model
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteCustomerResponse>.self, from: data)
            let customers = netSuiteResponse.items.map { $0.toCustomer() }
            print("🟢 DEBUG: NetSuiteAPI - Successfully fetched \(customers.count) customers")
            return customers
        } catch {
            print("🔴 DEBUG: NetSuiteAPI - Failed to decode customer response: \(error)")
            print("🔴 DEBUG: NetSuiteAPI - Decoding error details: \(error.localizedDescription)")
            
            // Try to decode as a single customer if it's not a list response
            do {
                let singleCustomer = try JSONDecoder().decode(NetSuiteCustomerResponse.self, from: data)
                let customer = singleCustomer.toCustomer()
                print("🟡 DEBUG: NetSuiteAPI - Successfully fetched 1 customer (single response)")
                return [customer]
            } catch {
                print("🔴 DEBUG: NetSuiteAPI - Failed to decode as single customer: \(error)")
                print("🔴 DEBUG: NetSuiteAPI - API response could not be parsed, throwing error")
                throw NetSuiteError.invalidResponse
            }
        }
    }
    
    // MARK: - Invoices
    func fetchInvoices() async throws -> [Invoice] {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            print("🔴 DEBUG: NetSuiteAPI - Access token not configured")
            throw NetSuiteError.notConfigured
        }
        
        let endpoint = "/services/rest/record/v1/invoice"
        let url = URL(string: baseURL + endpoint)!
        
        print("🔍 DEBUG: NetSuiteAPI - Fetching invoices from: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔍 DEBUG: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 DEBUG: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("📊 DEBUG: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
        print("📊 DEBUG: NetSuiteAPI - Response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 DEBUG: NetSuiteAPI - Response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("🔴 DEBUG: NetSuiteAPI - Request failed with status: \(httpResponse.statusCode)")
            throw NetSuiteError.requestFailed
        }
        
        // Parse NetSuite invoice response using the proper response model
        do {
            let netSuiteResponse = try JSONDecoder().decode(NetSuiteResponse<NetSuiteInvoiceResponse>.self, from: data)
            let invoices = netSuiteResponse.items.map { $0.toInvoice() }
            print("🟢 DEBUG: NetSuiteAPI - Successfully fetched \(invoices.count) invoices")
            return invoices
        } catch {
            print("🔴 DEBUG: NetSuiteAPI - Failed to decode invoice response: \(error)")
            print("🔴 DEBUG: NetSuiteAPI - Decoding error details: \(error.localizedDescription)")
            
            // Try to decode as a single invoice if it's not a list response
            do {
                let singleInvoice = try JSONDecoder().decode(NetSuiteInvoiceResponse.self, from: data)
                let invoice = singleInvoice.toInvoice()
                print("🟡 DEBUG: NetSuiteAPI - Successfully fetched 1 invoice (single response)")
                return [invoice]
            } catch {
                print("🔴 DEBUG: NetSuiteAPI - Failed to decode as single invoice: \(error)")
                print("🔴 DEBUG: NetSuiteAPI - API response could not be parsed, throwing error")
                throw NetSuiteError.invalidResponse
            }
        }
    }
    
    // MARK: - Raw API Testing
    func testRawAPI(endpoint: String) async throws -> String {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            print("🔴 DEBUG: NetSuiteAPI - Access token not configured")
            throw NetSuiteError.notConfigured
        }
        
        let url = URL(string: baseURL + endpoint)!
        
        print("🔍 DEBUG: NetSuiteAPI - Testing raw endpoint: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔍 DEBUG: NetSuiteAPI - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 DEBUG: NetSuiteAPI - Invalid response type")
            throw NetSuiteError.requestFailed
        }
        
        print("📊 DEBUG: NetSuiteAPI - Response status: \(httpResponse.statusCode)")
        print("📊 DEBUG: NetSuiteAPI - Response headers: \(httpResponse.allHeaderFields)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 DEBUG: NetSuiteAPI - Raw response: \(responseString)")
            return responseString
        } else {
            print("🔴 DEBUG: NetSuiteAPI - Could not decode response as string")
            throw NetSuiteError.invalidResponse
        }
    }
} 