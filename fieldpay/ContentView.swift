//
//  ContentView.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/26/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var customerViewModel = CustomerViewModel()
    @StateObject private var invoiceViewModel = InvoiceViewModel()
    @StateObject private var paymentViewModel = PaymentViewModel()
    @StateObject private var salesOrderViewModel = SalesOrderViewModel()
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    // State for navigation
    @State private var selectedTab = 0
    @State private var showingPaymentSheet = false
    @State private var showingTapToPaySheet = false
    @State private var showingInvoiceSheet = false
    @State private var showingCustomerSheet = false
    @State private var showingReportsSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                customerViewModel: customerViewModel,
                invoiceViewModel: invoiceViewModel,
                paymentViewModel: paymentViewModel,
                salesOrderViewModel: salesOrderViewModel,
                selectedTab: $selectedTab,
                showingPaymentSheet: $showingPaymentSheet,
                showingTapToPaySheet: $showingTapToPaySheet,
                showingInvoiceSheet: $showingInvoiceSheet,
                showingCustomerSheet: $showingCustomerSheet,
                showingReportsSheet: $showingReportsSheet
            )
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            CustomerListView(viewModel: customerViewModel)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Customers")
                }
                .tag(1)
            
            SalesOrderListView(viewModel: salesOrderViewModel)
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Orders")
                }
                .tag(2)
            
            PaymentView(viewModel: paymentViewModel, customerViewModel: customerViewModel, settingsViewModel: settingsViewModel)
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Payments")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentView(viewModel: paymentViewModel, customerViewModel: customerViewModel, settingsViewModel: settingsViewModel)
        }
        .sheet(isPresented: $showingTapToPaySheet) {
            TapToPayView()
        }
        .sheet(isPresented: $showingInvoiceSheet) {
            InvoiceListView(viewModel: invoiceViewModel, customerViewModel: customerViewModel)
        }
        .sheet(isPresented: $showingCustomerSheet) {
            CustomerListView(viewModel: customerViewModel)
        }
        .sheet(isPresented: $showingReportsSheet) {
            ReportsView()
        }
    }
}

// MARK: - Helper Functions

private func formatCurrency(_ amount: Decimal) -> String {
    // Safely convert Decimal to Double, handling potential NaN or invalid values
    let nsDecimal = NSDecimalNumber(decimal: amount)
    let doubleValue = nsDecimal.doubleValue
    
    // Check for NaN or infinite values
    if doubleValue.isNaN || doubleValue.isInfinite {
        return "$0"
    }
    
    return String(format: "$%.0f", doubleValue)
}



// MARK: - Modern Components

struct ModernStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let gradient: LinearGradient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct ModernQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}





#Preview {
    ContentView()
}
