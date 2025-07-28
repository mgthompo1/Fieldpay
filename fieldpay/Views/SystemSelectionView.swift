import SwiftUI

struct SystemSelectionView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select Accounting System") {
                    ForEach(AccountingSystem.allCases, id: \.self) { system in
                        Button(action: {
                            settingsViewModel.connectToSystem(system)
                        }) {
                            HStack {
                                Image(systemName: system.icon)
                                    .foregroundColor(system.color)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(system.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if system == .none {
                                        Text("Run without external accounting system")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(settingsViewModel.canConnectToSystem(system) ? "Ready to connect" : "Not configured")
                                            .font(.caption)
                                            .foregroundColor(settingsViewModel.canConnectToSystem(system) ? .green : .red)
                                    }
                                }
                                
                                Spacer()
                                
                                if settingsViewModel.selectedSystem == system {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!settingsViewModel.canConnectToSystem(system) && system != .none)
                    }
                }
                
                if settingsViewModel.selectedSystem != .none {
                    Section("Current Connection") {
                        HStack {
                            Image(systemName: settingsViewModel.isSystemConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(settingsViewModel.isSystemConnected ? .green : .red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settingsViewModel.selectedSystem.displayName)
                                    .font(.headline)
                                
                                Text(settingsViewModel.systemConnectionStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Disconnect") {
                                settingsViewModel.disconnectFromCurrentSystem()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Section("System Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Only one accounting system can be connected at a time")
                        Text("• All core functions work in standalone mode")
                        Text("• Configure OAuth settings before connecting")
                        Text("• Disconnect current system to switch to another")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if settingsViewModel.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Connecting...")
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
            .navigationTitle("System Selection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 