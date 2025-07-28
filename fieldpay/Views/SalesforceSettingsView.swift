import SwiftUI

struct SalesforceSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Salesforce API Configuration") {
                    TextField("Client ID", text: $settingsViewModel.salesforceClientId)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Client Secret", text: $settingsViewModel.salesforceClientSecret)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Toggle("Use Sandbox Environment", isOn: $settingsViewModel.salesforceIsSandbox)
                }
                
                Section("Test Configuration") {
                    Button(action: {
                        settingsViewModel.startSalesforceOAuth()
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.purple)
                            Text("Start Salesforce OAuth")
                        }
                    }
                    .disabled(settingsViewModel.salesforceClientId.isEmpty || settingsViewModel.salesforceClientSecret.isEmpty)
                }
                
                Section("OAuth Requirements") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Create a Salesforce Connected App")
                        Text("• Set redirect URI to: fieldpay://oauth/salesforce/callback")
                        Text("• Request scopes: api, refresh_token")
                        Text("• Store your Client ID and Client Secret securely")
                        Text("• Choose between Production and Sandbox environments")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Go to Salesforce Setup")
                        Text("2. Navigate to App Manager")
                        Text("3. Create a new Connected App")
                        Text("4. Configure OAuth settings")
                        Text("5. Add the redirect URI above")
                        Text("6. Copy Client ID and Client Secret")
                        Text("7. Choose environment (Production/Sandbox)")
                        Text("8. Save settings and start OAuth flow")
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
            .navigationTitle("Salesforce Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settingsViewModel.saveSalesforceSettings()
                        dismiss()
                    }
                    .disabled(settingsViewModel.salesforceClientId.isEmpty || settingsViewModel.salesforceClientSecret.isEmpty)
                }
            }
        }
    }
} 