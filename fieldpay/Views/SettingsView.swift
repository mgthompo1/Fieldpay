import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @State private var showingStripeSettings = false
    @State private var showingNetSuiteSettings = false
    @State private var showingWindcaveSettings = false

    @State private var showingQuickBooksSettings = false
    @State private var showingSalesforceSettings = false
    @State private var showingSystemSelection = false
    @State private var showingNetSuiteDebug = false
    @State private var showingPaymentConfiguration = false
    @State private var showingCompanyBranding = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Configuration") {
                    Button(action: {
                        showingCompanyBranding = true
                    }) {
                        HStack {
                            Image(systemName: "building.2.crop.circle")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Company Branding")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure company logo and name for customer payments")
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
                        showingPaymentConfiguration = true
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Payment Processing")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Configure Stripe or Windcave payment processing")
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
                        Image(systemName: settingsViewModel.isWindcaveConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(settingsViewModel.isWindcaveConnected ? .green : .red)
                        
                        Text("Windcave")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(settingsViewModel.isWindcaveConnected ? "Connected" : "Not Connected")
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
                                
                                Text("Check current OAuth authentication status")
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
                                Text("NetSuite Debug")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Debug NetSuite API calls and responses")
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
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCompanyBranding) {
            CompanyBrandingView(settingsViewModel: settingsViewModel)
        }
        .sheet(isPresented: $showingPaymentConfiguration) {
            PaymentConfigurationView()
        }
        .sheet(isPresented: $showingStripeSettings) {
            StripeSettingsView(settingsViewModel: settingsViewModel)
        }
        .sheet(isPresented: $showingNetSuiteSettings) {
            NetSuiteSettingsView(settingsViewModel: settingsViewModel)
        }
        .sheet(isPresented: $showingWindcaveSettings) {
            WindcaveSettingsView(settingsViewModel: settingsViewModel)
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

// MARK: - Payment Configuration View
struct PaymentConfigurationView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPaymentSystem: SettingsViewModel.PaymentSystem = .none
    @State private var showingStripeSettings = false
    @State private var showingWindcaveSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Select Payment System") {
                    ForEach(SettingsViewModel.PaymentSystem.allCases, id: \.self) { system in
                        Button(action: {
                            selectedPaymentSystem = system
                            savePaymentSystemSelection()
                        }) {
                            HStack {
                                Image(systemName: system.icon)
                                    .foregroundColor(system.color)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(system.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(system.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPaymentSystem == system {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if selectedPaymentSystem == .stripe {
                    Section("Stripe Configuration") {
                        Button(action: {
                            showingStripeSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Configure Stripe")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Set up API keys and account settings")
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
                }
                
                if selectedPaymentSystem == .windcave {
                    Section("Windcave Configuration") {
                        Button(action: {
                            showingWindcaveSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(.purple)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Configure Windcave")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Set up QR Code payments via Windcave")
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
                }
            }
            .navigationTitle("Payment Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentPaymentSystem()
        }
        .sheet(isPresented: $showingStripeSettings) {
            StripeSettingsView(settingsViewModel: settingsViewModel)
        }
        .sheet(isPresented: $showingWindcaveSettings) {
            WindcaveSettingsView(settingsViewModel: settingsViewModel)
        }
    }
    
    private func loadCurrentPaymentSystem() {
        // Load the currently selected payment system from UserDefaults
        if let savedSystem = UserDefaults.standard.string(forKey: "selected_payment_system"),
           let system = SettingsViewModel.PaymentSystem(rawValue: savedSystem) {
            selectedPaymentSystem = system
        } else {
            // Default to none if nothing is saved
            selectedPaymentSystem = .none
        }
    }
    
    private func savePaymentSystemSelection() {
        UserDefaults.standard.set(selectedPaymentSystem.rawValue, forKey: "selected_payment_system")
        
        // Update the settings view model
        settingsViewModel.savePaymentSystemSelection(selectedPaymentSystem)
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
                        VStack(spacing: 10) {
                            Button("Disconnect NetSuite") {
                                settingsViewModel.disconnectNetSuite()
                            }
                            .foregroundColor(.red)
                            
                            Button("Reconnect NetSuite") {
                                print("Debug: Reconnect button tapped")
                                settingsViewModel.reconnectNetSuite()
                            }
                            .foregroundColor(.blue)
                        }
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

// MARK: - Company Branding View
struct CompanyBrandingView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var companyLogoImage: UIImage?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Company Information") {
                    TextField("Company Name", text: $settingsViewModel.companyName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Company Logo") {
                    VStack(spacing: 16) {
                        // Logo Preview
                        if let logoImage = companyLogoImage {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        } else if let logoData = settingsViewModel.companyLogoData,
                                  let uiImage = UIImage(data: logoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray6))
                                .frame(height: 120)
                                .cornerRadius(12)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                        Text("No Logo Selected")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        
                        // Photo Picker Button
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Select Logo from Photos")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Remove Logo Button
                        if settingsViewModel.companyLogoData != nil || companyLogoImage != nil {
                            Button("Remove Logo") {
                                companyLogoImage = nil
                                settingsViewModel.clearCompanyLogo()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Section("Logo Guidelines") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("For best results:")
                            .font(.headline)
                        
                        Text("• Use a square or rectangular logo")
                        Text("• Recommended size: 200x200px or larger")
                        Text("• Use PNG or JPEG format")
                        Text("• Logo will appear above QR codes during payment")
                        Text("• Keep file size under 5MB")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Company Branding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let logoImage = companyLogoImage {
                            settingsViewModel.companyLogoData = logoImage.jpegData(compressionQuality: 0.8)
                        }
                        settingsViewModel.saveCompanyBranding()
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { newPhoto in
                Task {
                    if let newPhoto = newPhoto {
                        if let data = try? await newPhoto.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                companyLogoImage = uiImage
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 