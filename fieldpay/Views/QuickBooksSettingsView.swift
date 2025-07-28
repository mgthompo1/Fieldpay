import SwiftUI

struct QuickBooksSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("QuickBooks API Configuration") {
                    TextField("Client ID", text: $settingsViewModel.quickBooksClientId)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Client Secret", text: $settingsViewModel.quickBooksClientSecret)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Environment", selection: $settingsViewModel.quickBooksEnvironment) {
                        Text("Sandbox").tag("sandbox")
                        Text("Production").tag("production")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Test Configuration") {
                    Button(action: {
                        settingsViewModel.startQuickBooksOAuth()
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.orange)
                            Text("Start QuickBooks OAuth")
                        }
                    }
                    .disabled(settingsViewModel.quickBooksClientId.isEmpty || settingsViewModel.quickBooksClientSecret.isEmpty)
                }
                
                Section("OAuth Requirements") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Create a QuickBooks app in the Intuit Developer Portal")
                        Text("• Set redirect URI to: fieldpay://oauth/quickbooks/callback")
                        Text("• Request scope: com.intuit.quickbooks.accounting")
                        Text("• Store your Client ID and Client Secret securely")
                        Text("• Choose between Sandbox and Production environments")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Go to https://developer.intuit.com")
                        Text("2. Create a new QuickBooks app")
                        Text("3. Configure OAuth 2.0 settings")
                        Text("4. Add the redirect URI above")
                        Text("5. Copy Client ID and Client Secret")
                        Text("6. Choose environment (Sandbox/Production)")
                        Text("7. Save settings and start OAuth flow")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if settingsViewModel.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
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
            .navigationTitle("QuickBooks Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settingsViewModel.saveQuickBooksSettings()
                        dismiss()
                    }
                    .disabled(settingsViewModel.quickBooksClientId.isEmpty || settingsViewModel.quickBooksClientSecret.isEmpty)
                }
            }
        }
    }
} 