import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @State private var showingStripeSettings = false
    @State private var showingNetSuiteSettings = false
    @State private var showingWindcaveSettings = false
    @State private var showingXeroSettings = false
    @State private var showingQuickBooksSettings = false
    @State private var showingSalesforceSettings = false
    @State private var showingSystemSelection = false
    @State private var showingNetSuiteDebug = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Payment Configuration") {
                    Button(action: {
                        showingStripeSettings = true
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stripe Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure Stripe API keys")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section("Accounting System Integration") {
                    Button(action: {
                        showingSystemSelection = true
                    }) {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("System Selection")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Choose accounting system to connect")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        print("Debug: NetSuite Settings button tapped")
                        showingNetSuiteSettings = true
                    }) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NetSuite Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure OAuth integration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingXeroSettings = true
                    }) {
                        HStack {
                            Image(systemName: "x.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Xero Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure OAuth integration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingQuickBooksSettings = true
                    }) {
                        HStack {
                            Image(systemName: "q.circle.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("QuickBooks Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure OAuth integration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingSalesforceSettings = true
                    }) {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Salesforce Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure OAuth integration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section("Tap to Pay Integration") {
                    Button(action: {
                        showingWindcaveSettings = true
                    }) {
                        HStack {
                            Image(systemName: "wave.3.right")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Windcave Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure Tap to Pay on iPhone")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section("Connection Status") {
                    HStack {
                        Image(systemName: settingsViewModel.isStripeConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(settingsViewModel.isStripeConnected ? .green : .red)
                        
                        Text("Stripe")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(settingsViewModel.isStripeConnected ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: settingsViewModel.isSystemConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(settingsViewModel.isSystemConnected ? .green : .red)
                        
                        Text(settingsViewModel.selectedSystem.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(settingsViewModel.systemConnectionStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: settingsViewModel.isWindcaveConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(settingsViewModel.isWindcaveConnected ? .green : .red)
                        
                        Text("Windcave")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(settingsViewModel.isWindcaveConnected ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("OAuth Troubleshooting") {
                    Button(action: {
                        print("Debug: Clear OAuth data button tapped")
                        Task {
                            await OAuthManager.shared.forceClearAllOAuthData()
                            await OAuthManager.shared.validateAuthenticationState()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Clear OAuth Data")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text("Clear all OAuth tokens and restart flow")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        print("Debug: Validate OAuth state button tapped")
                        Task {
                            await OAuthManager.shared.validateAuthenticationState()
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Validate OAuth State")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Check and fix authentication state")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingNetSuiteDebug = true
                    }) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NetSuite API Debug")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Test API calls and debug issues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                print("Debug: SettingsView appeared")
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingStripeSettings) {
                StripeSettingsView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingNetSuiteSettings) {
                NetSuiteSettingsView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingWindcaveSettings) {
                WindcaveSettingsView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingXeroSettings) {
                XeroSettingsView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingQuickBooksSettings) {
                QuickBooksSettingsView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingSalesforceSettings) {
                SalesforceSettingsView(settingsViewModel: settingsViewModel)
            }
                    .sheet(isPresented: $showingSystemSelection) {
            SystemSelectionView(settingsViewModel: settingsViewModel)
        }
        .sheet(isPresented: $showingNetSuiteDebug) {
            NetSuiteDebugView()
        }
        }
    }
}

struct StripeSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Stripe API Configuration") {
                    TextField("Public Key", text: $settingsViewModel.stripePublicKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Secret Key", text: $settingsViewModel.stripeSecretKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Account ID", text: $settingsViewModel.stripeAccountId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Test Configuration") {
                    Button("Test Stripe Connection") {
                        settingsViewModel.testStripeConnection()
                    }
                    .disabled(settingsViewModel.stripePublicKey.isEmpty || settingsViewModel.stripeSecretKey.isEmpty)
                }
                
                Section("Help") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To get your Stripe API keys:")
                            .font(.headline)
                        
                        Text("1. Log in to your Stripe Dashboard")
                        Text("2. Go to Developers → API keys")
                        Text("3. Copy your Publishable key and Secret key")
                        Text("4. For Account ID, use your Stripe account ID")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Stripe Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settingsViewModel.saveStripeSettings()
                        dismiss()
                    }
                    .disabled(settingsViewModel.stripePublicKey.isEmpty || settingsViewModel.stripeSecretKey.isEmpty)
                }
            }
        }
    }
}

struct NetSuiteSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("NetSuite OAuth Configuration") {
                    TextField("Client ID", text: $settingsViewModel.netSuiteClientId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Client Secret", text: $settingsViewModel.netSuiteClientSecret)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Account ID", text: $settingsViewModel.netSuiteAccountId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Redirect URI", text: $settingsViewModel.netSuiteRedirectUri)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("OAuth Flow") {
                    if settingsViewModel.isNetSuiteConnected {
                        Button("Disconnect NetSuite") {
                            settingsViewModel.disconnectNetSuite()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Connect to NetSuite") {
                            print("Debug: Connect button tapped")
                            print("Debug: Client ID: '\(settingsViewModel.netSuiteClientId)'")
                            print("Debug: Client Secret: '\(settingsViewModel.netSuiteClientSecret)'")
                            print("Debug: Account ID: '\(settingsViewModel.netSuiteAccountId)'")
                            print("Debug: Button should be enabled: \(!settingsViewModel.netSuiteClientId.isEmpty && !settingsViewModel.netSuiteClientSecret.isEmpty && !settingsViewModel.netSuiteAccountId.isEmpty)")
                            settingsViewModel.connectToNetSuite()
                        }
                        .disabled(settingsViewModel.netSuiteClientId.isEmpty || 
                                settingsViewModel.netSuiteClientSecret.isEmpty ||
                                settingsViewModel.netSuiteAccountId.isEmpty)
                        .onAppear {
                            print("Debug: Button state - Client ID empty: \(settingsViewModel.netSuiteClientId.isEmpty)")
                            print("Debug: Button state - Client Secret empty: \(settingsViewModel.netSuiteClientSecret.isEmpty)")
                            print("Debug: Button state - Account ID empty: \(settingsViewModel.netSuiteAccountId.isEmpty)")
                            print("Debug: Button state - Button disabled: \(settingsViewModel.netSuiteClientId.isEmpty || settingsViewModel.netSuiteClientSecret.isEmpty || settingsViewModel.netSuiteAccountId.isEmpty)")
                        }
                    }
                }
                
                Section("Integration Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To set up NetSuite OAuth integration:")
                            .font(.headline)
                        
                        Text("1. Go to Setup → Integration → New")
                        Text("2. Enter your application name and description")
                        Text("3. Check 'Authorization Code Grant'")
                        Text("4. Set Redirect URI to: fieldpay://oauth/callback")
                        Text("5. Check 'REST Web Services'")
                        Text("6. Save and copy the Client ID and Client Secret")
                        Text("7. Use your NetSuite Account ID")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Current Status") {
                    if settingsViewModel.netSuiteAccessToken != nil {
                        HStack {
                            Text("Access Token")
                            Spacer()
                            Text("✓ Valid")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Expires")
                            Spacer()
                            Text(settingsViewModel.tokenExpiryDate ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Access Token")
                            Spacer()
                            Text("Not Connected")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .onAppear {
                print("Debug: NetSuiteSettingsView appeared")
            }
            .navigationTitle("NetSuite Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settingsViewModel.saveNetSuiteSettings()
                        dismiss()
                    }
                    .disabled(settingsViewModel.netSuiteClientId.isEmpty || 
                            settingsViewModel.netSuiteClientSecret.isEmpty ||
                            settingsViewModel.netSuiteAccountId.isEmpty)
                }
            }
        }
    }
}

struct WindcaveSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Windcave API Configuration") {
                    TextField("REST API Username", text: $settingsViewModel.windcaveUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("REST API Key", text: $settingsViewModel.windcaveApiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Test Configuration") {
                    Button("Test Windcave Connection") {
                        settingsViewModel.testWindcaveConnection()
                    }
                    .disabled(settingsViewModel.windcaveUsername.isEmpty || settingsViewModel.windcaveApiKey.isEmpty)
                }
                
                Section("Tap to Pay Requirements") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To use Windcave Tap to Pay:")
                            .font(.headline)
                        
                        Text("• iOS 17+ required")
                        Text("• Active Windcave account")
                        Text("• Tap to Pay on iPhone entitlement from Apple")
                        Text("• REST API user with Tap to Pay enabled")
                        Text("• Compatible iPhone with NFC")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Contact Windcave to enable Tap to Pay")
                        Text("2. Request Tap to Pay entitlement from Apple")
                        Text("3. Get your REST API credentials")
                        Text("4. Configure settings in this app")
                        Text("5. Test the connection")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if settingsViewModel.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing connection...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let errorMessage = settingsViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Windcave Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settingsViewModel.saveWindcaveSettings()
                        dismiss()
                    }
                    .disabled(settingsViewModel.windcaveUsername.isEmpty || settingsViewModel.windcaveApiKey.isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 