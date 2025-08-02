//
//  DashboardView.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/26/25.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var customerViewModel: CustomerViewModel
    @ObservedObject var invoiceViewModel: InvoiceViewModel
    @ObservedObject var paymentViewModel: PaymentViewModel
    @ObservedObject var salesOrderViewModel: SalesOrderViewModel
    @Binding var selectedTab: Int
    @Binding var showingPaymentSheet: Bool
    @Binding var showingTapToPaySheet: Bool
    @Binding var showingInvoiceSheet: Bool
    @Binding var showingCustomerSheet: Bool
    @Binding var showingReportsSheet: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    DashboardHeader()
                    
                    // Quick Actions Grid
                    QuickActionsGrid(
                        selectedTab: $selectedTab,
                        showingPaymentSheet: $showingPaymentSheet,
                        showingTapToPaySheet: $showingTapToPaySheet,
                        showingInvoiceSheet: $showingInvoiceSheet,
                        showingCustomerSheet: $showingCustomerSheet,
                        showingReportsSheet: $showingReportsSheet
                    )
                    
                    // Recent Activity Section
                    RecentActivitySection(
                        customerViewModel: customerViewModel,
                        invoiceViewModel: invoiceViewModel
                    )
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Dashboard Header
struct DashboardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FieldPay Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Manage your business operations")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

// MARK: - Quick Actions Grid
struct QuickActionsGrid: View {
    @Binding var selectedTab: Int
    @Binding var showingPaymentSheet: Bool
    @Binding var showingTapToPaySheet: Bool
    @Binding var showingInvoiceSheet: Bool
    @Binding var showingCustomerSheet: Bool
    @Binding var showingReportsSheet: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickActionCard(
                title: "New Payment",
                subtitle: "Process payment",
                icon: "creditcard.fill",
                color: .blue
            ) {
                showingPaymentSheet = true
            }
            
            QuickActionCard(
                title: "Tap to Pay",
                subtitle: "Contactless payment",
                icon: "wave.3.right",
                color: .green
            ) {
                showingTapToPaySheet = true
            }
            
            QuickActionCard(
                title: "Customers",
                subtitle: "Manage customers",
                icon: "person.2.fill",
                color: .purple
            ) {
                selectedTab = 1
            }
            
            QuickActionCard(
                title: "Sales Orders",
                subtitle: "View orders",
                icon: "cart.fill",
                color: .red
            ) {
                selectedTab = 2
            }
            
            QuickActionCard(
                title: "Reports",
                subtitle: "Analytics & insights",
                icon: "chart.bar.fill",
                color: .indigo
            ) {
                showingReportsSheet = true
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    @ObservedObject var customerViewModel: CustomerViewModel
    @ObservedObject var invoiceViewModel: InvoiceViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                if customerViewModel.customers.isEmpty && invoiceViewModel.invoices.isEmpty {
                    Text("No recent activity")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Show recent customers
                    if !customerViewModel.customers.isEmpty {
                        ForEach(customerViewModel.customers.prefix(3), id: \.id) { customer in
                            RecentActivityRow(
                                title: customer.name,
                                subtitle: "Customer",
                                icon: "person.fill",
                                color: .blue
                            )
                        }
                    }
                    
                    // Show recent invoices
                    if !invoiceViewModel.invoices.isEmpty {
                        ForEach(invoiceViewModel.invoices.prefix(3).map { $0 }, id: \.id) { invoice in
                            RecentActivityRow(
                                title: "Invoice #\(invoice.invoiceNumber)",
                                subtitle: "$\(String(format: "%.2f", (invoice.amount as NSDecimalNumber).doubleValue))",
                                icon: "doc.text.fill",
                                color: .orange
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentActivityRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView(
        customerViewModel: CustomerViewModel(),
        invoiceViewModel: InvoiceViewModel(),
        paymentViewModel: PaymentViewModel(),
        salesOrderViewModel: SalesOrderViewModel(),
        selectedTab: .constant(0),
        showingPaymentSheet: .constant(false),
        showingTapToPaySheet: .constant(false),
        showingInvoiceSheet: .constant(false),
        showingCustomerSheet: .constant(false),
        showingReportsSheet: .constant(false)
    )
} 