//
//  fieldpayApp.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/26/25.
//

import SwiftUI
// import TapToPaySDK  // Temporarily commented out due to build issues

@main
struct fieldpayApp: App {
    @StateObject private var oAuthManager = OAuthManager.shared
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var tapToPayManager = TapToPayManager.shared
    
    init() {
        print("Debug: ===== FieldPay app starting... =====")
        print("Debug: App bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("Debug: App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        print("Debug: App build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")")
        
        // Check URL schemes
        if let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] {
            print("Debug: Configured URL types: \(urlTypes)")
            for (index, urlType) in urlTypes.enumerated() {
                if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                    print("Debug: URL type \(index) schemes: \(schemes)")
                }
            }
        } else {
            print("Debug: ❌ No URL types found in Info.plist")
        }
        
        // Initialize NetSuiteAPI with stored configuration if available
        print("Debug: Initializing NetSuiteAPI with stored configuration...")
        if let accountId = UserDefaults.standard.string(forKey: "netsuite_account_id"),
           let accessToken = UserDefaults.standard.string(forKey: "netsuite_access_token") {
            print("Debug: Found stored NetSuite configuration - Account ID: \(accountId)")
            NetSuiteAPI.shared.configure(accountId: accountId, accessToken: accessToken)
            print("Debug: NetSuiteAPI configured successfully")
        } else {
            print("Debug: No stored NetSuite configuration found")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsViewModel)
                .onAppear {
                    print("Debug: ContentView appeared, validating OAuth state...")
                    Task {
                        await oAuthManager.validateAuthenticationState()
                        
                        // Initialize Tap to Pay SDK
                        await tapToPayManager.initializeSDK()
                    }
                }
                .onOpenURL { url in
                    // Handle OAuth callback
                    print("Debug: ===== onOpenURL CALLBACK TRIGGERED =====")
                    print("Debug: Received URL: \(url)")
                    print("Debug: URL absolute string: \(url.absoluteString)")
                    print("Debug: URL scheme: \(url.scheme ?? "nil")")
                    print("Debug: URL host: \(url.host ?? "nil")")
                    print("Debug: URL path: \(url.path)")
                    print("Debug: URL query: \(url.query ?? "nil")")
                    print("Debug: URL components: \(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])")
                    
                    // Check if this is our OAuth callback - be more flexible with URL matching
                    let isOAuthCallback = url.scheme == "fieldpay" || 
                                        (url.scheme == "https" && url.host?.contains("netsuite") == true) ||
                                        url.absoluteString.contains("code=")
                    
                    if isOAuthCallback {
                        print("Debug: ✅ URL matches OAuth callback pattern")
                        print("Debug: Processing OAuth callback...")
                        Task {
                            do {
                                try await oAuthManager.handleOAuthCallback(url: url)
                                print("Debug: ✅ OAuth callback handled successfully")
                                
                                // Update settings view model
                                await MainActor.run {
                                    settingsViewModel.handleOAuthCallback()
                                }
                            } catch {
                                print("Debug: ❌ OAuth callback error: \(error)")
                                print("Debug: ❌ OAuth callback error details: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        print("Debug: ❌ URL does not match OAuth callback pattern")
                        print("Debug: Expected scheme: 'fieldpay', got: '\(url.scheme ?? "nil")'")
                        print("Debug: Expected host: 'callback', got: '\(url.host ?? "nil")'")
                        print("Debug: Full URL for debugging: \(url.absoluteString)")
                    }
                }
        }
    }
}
