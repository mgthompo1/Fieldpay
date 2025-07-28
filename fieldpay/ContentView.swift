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
            
            InvoiceListView(viewModel: invoiceViewModel)
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Invoices")
                }
                .tag(2)
            
            PaymentView(viewModel: paymentViewModel)
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Payments")
                }
                .tag(3)
            
            SalesOrderListView(viewModel: salesOrderViewModel)
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Orders")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(5)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentView(viewModel: paymentViewModel)
        }
        .sheet(isPresented: $showingTapToPaySheet) {
            TapToPayView()
        }
        .sheet(isPresented: $showingInvoiceSheet) {
            InvoiceListView(viewModel: invoiceViewModel)
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

struct DashboardView: View {
    @ObservedObject var customerViewModel: CustomerViewModel
    @ObservedObject var invoiceViewModel: InvoiceViewModel
    @ObservedObject var paymentViewModel: PaymentViewModel
    @ObservedObject var salesOrderViewModel: SalesOrderViewModel
    
    // Navigation bindings
    @Binding var selectedTab: Int
    @Binding var showingPaymentSheet: Bool
    @Binding var showingTapToPaySheet: Bool
    @Binding var showingInvoiceSheet: Bool
    @Binding var showingCustomerSheet: Bool
    @Binding var showingReportsSheet: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back!")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text("FieldPay Dashboard")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Profile/Status indicator
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Stats Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ModernStatCard(
                            title: "Outstanding",
                            value: formatCurrency(invoiceViewModel.getTotalOutstanding()),
                            subtitle: "Invoices",
                            icon: "doc.text.fill",
                            color: .orange,
                            gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        
                        ModernStatCard(
                            title: "Today's Revenue",
                            value: formatCurrency(paymentViewModel.getTotalPayments()),
                            subtitle: "Payments",
                            icon: "creditcard.fill",
                            color: .green,
                            gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        
                        ModernStatCard(
                            title: "Active",
                            value: "\(customerViewModel.customers.filter { $0.isActive }.count)",
                            subtitle: "Customers",
                            icon: "person.2.fill",
                            color: .blue,
                            gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        
                        ModernStatCard(
                            title: "Pending",
                            value: "\(salesOrderViewModel.getPendingApprovalOrders().count)",
                            subtitle: "Orders",
                            icon: "cart.fill",
                            color: .purple,
                            gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Quick Actions")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("View All") {
                                // Could navigate to a full actions view
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ModernQuickActionButton(
                                title: "Tap to Pay",
                                subtitle: "Accept contactless card payments",
                                icon: "creditcard.radiowaves.left.and.right",
                                color: .blue,
                                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            ) {
                                showingTapToPaySheet = true
                            }
                            
                            ModernQuickActionButton(
                                title: "Process Payment",
                                subtitle: "Accept card, cash, or check payments",
                                icon: "creditcard.fill",
                                color: .green,
                                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            ) {
                                showingPaymentSheet = true
                            }
                            
                            ModernQuickActionButton(
                                title: "Create Invoice",
                                subtitle: "Generate new invoice for customer",
                                icon: "doc.text.fill",
                                color: .blue,
                                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            ) {
                                showingInvoiceSheet = true
                            }
                            
                            ModernQuickActionButton(
                                title: "Add Customer",
                                subtitle: "Create new customer profile",
                                icon: "person.badge.plus",
                                color: .orange,
                                gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                            ) {
                                showingCustomerSheet = true
                            }
                            
                            ModernQuickActionButton(
                                title: "View Reports",
                                subtitle: "Sales, payments, and analytics",
                                icon: "chart.bar.fill",
                                color: .purple,
                                gradient: LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                            ) {
                                showingReportsSheet = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Recent Activity Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Activity")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("See All") {
                                // Navigate to full activity view
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(paymentViewModel.payments.prefix(3)), id: \.id) { payment in
                                ModernActivityRow(
                                    title: "Payment Processed",
                                    subtitle: "\(String(format: "$%.2f", (payment.amount as NSDecimalNumber).doubleValue)) - \(payment.paymentMethod.displayName)",
                                    time: payment.createdDate,
                                    icon: "creditcard.fill",
                                    color: .green
                                )
                            }
                            
                            if paymentViewModel.payments.isEmpty {
                                ModernEmptyStateView(
                                    icon: "creditcard",
                                    title: "No Recent Activity",
                                    subtitle: "Your payment activity will appear here"
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
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
