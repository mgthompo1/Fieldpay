import SwiftUI

struct XeroSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Xero API Configuration") {
                    TextField("Client ID", text: $settingsViewModel.xeroClientId)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Client Secret", text: $settingsViewModel.xeroClientSecret)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Test Configuration") {
                    Button(action: {
                        settingsViewModel.startXeroOAuth()
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text("Start Xero OAuth")
                        }
                    }
                    .disabled(settingsViewModel.xeroClientId.isEmpty || settingsViewModel.xeroClientSecret.isEmpty)
                }
                
                Section("OAuth Requirements") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Create a Xero app in the Xero Developer Portal")
                        Text("• Set redirect URI to: fieldpay://oauth/xero/callback")
                        Text("• Request scopes: offline_access, accounting.transactions, accounting.contacts, accounting.settings")
                        Text("• Store your Client ID and Client Secret securely")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Go to https://developer.xero.com")
                        Text("2. Create a new app")
                        Text("3. Configure OAuth 2.0 settings")
                        Text("4. Add the redirect URI above")
                        Text("5. Copy Client ID and Client Secret")
                        Text("6. Save settings and start OAuth flow")
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
            .navigationTitle("Xero Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settingsViewModel.saveXeroSettings()
                        dismiss()
                    }
                    .disabled(settingsViewModel.xeroClientId.isEmpty || settingsViewModel.xeroClientSecret.isEmpty)
                }
            }
        }
    }
} 