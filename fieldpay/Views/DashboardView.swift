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
            ZStack {
                FieldPayBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        DashboardHeader()
                        
                        DashboardHeroCard(
                            customerCount: customerViewModel.customers.count,
                            invoiceCount: invoiceViewModel.invoices.count,
                            paymentCount: paymentViewModel.payments.count,
                            orderCount: salesOrderViewModel.salesOrders.count
                        )
                        
                        QuickActionsGrid(
                            selectedTab: $selectedTab,
                            showingPaymentSheet: $showingPaymentSheet,
                            showingTapToPaySheet: $showingTapToPaySheet,
                            showingInvoiceSheet: $showingInvoiceSheet,
                            showingCustomerSheet: $showingCustomerSheet,
                            showingReportsSheet: $showingReportsSheet
                        )
                        
                        RecentActivitySection(
                            customerViewModel: customerViewModel,
                            invoiceViewModel: invoiceViewModel
                        )
                    }
                    .padding(.vertical, 24)
                }
                .navigationBarHidden(true)
            }
        }
    }
}

// MARK: - Dashboard Header
struct DashboardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FieldPay")
                .font(FieldPayFont.display)
                .foregroundColor(FieldPayTheme.ink)
            
            Text("Operations, payments, and customer activity at a glance.")
                .font(FieldPayFont.callout)
                .foregroundColor(FieldPayTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

struct DashboardHeroCard: View {
    let customerCount: Int
    let invoiceCount: Int
    let paymentCount: Int
    let orderCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today")
                        .font(FieldPayFont.callout)
                        .foregroundColor(FieldPayTheme.inkMuted)
                    
                    Text("Business Pulse")
                        .font(FieldPayFont.title)
                        .foregroundColor(FieldPayTheme.ink)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(FieldPayTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DashboardMetricTile(title: "Customers", value: "\(customerCount)", tint: FieldPayTheme.accent)
                DashboardMetricTile(title: "Invoices", value: "\(invoiceCount)", tint: FieldPayTheme.highlight)
                DashboardMetricTile(title: "Payments", value: "\(paymentCount)", tint: FieldPayTheme.success)
                DashboardMetricTile(title: "Orders", value: "\(orderCount)", tint: FieldPayTheme.ink)
            }
        }
        .fieldPayCard(padding: 22, cornerRadius: 22)
        .padding(.horizontal, 20)
    }
}

struct DashboardMetricTile: View {
    let title: String
    let value: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FieldPayFont.caption)
                .foregroundColor(FieldPayTheme.inkMuted)
            
            Text(value)
                .font(FieldPayFont.metric)
                .foregroundColor(FieldPayTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(FieldPayFont.title2)
                .foregroundColor(FieldPayTheme.ink)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
            QuickActionCard(
                title: "New Payment",
                subtitle: "Process payment",
                icon: "creditcard.fill",
                color: FieldPayTheme.accent
            ) {
                showingPaymentSheet = true
            }
            
            QuickActionCard(
                title: "Tap to Pay",
                subtitle: "Contactless payment",
                icon: "wave.3.right",
                color: FieldPayTheme.success
            ) {
                showingTapToPaySheet = true
            }
            
            QuickActionCard(
                title: "Customers",
                subtitle: "Manage customers",
                icon: "person.2.fill",
                color: FieldPayTheme.ink
            ) {
                selectedTab = 1
            }
            
            QuickActionCard(
                title: "Sales Orders",
                subtitle: "View orders",
                icon: "cart.fill",
                color: FieldPayTheme.highlight
            ) {
                selectedTab = 2
            }
            
            QuickActionCard(
                title: "Reports",
                subtitle: "Analytics & insights",
                icon: "chart.bar.fill",
                color: FieldPayTheme.accentDeep
            ) {
                showingReportsSheet = true
            }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    @ObservedObject var customerViewModel: CustomerViewModel
    @ObservedObject var invoiceViewModel: InvoiceViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(FieldPayFont.title2)
                .foregroundColor(FieldPayTheme.ink)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                if customerViewModel.customers.isEmpty && invoiceViewModel.invoices.isEmpty {
                    Text("No recent activity")
                        .font(FieldPayFont.callout)
                        .foregroundColor(FieldPayTheme.inkMuted)
                        .padding()
                } else {
                    // Show recent customers
                    if !customerViewModel.customers.isEmpty {
                        ForEach(customerViewModel.customers.prefix(3), id: \.id) { customer in
                            RecentActivityRow(
                                title: customer.name,
                                subtitle: "Customer",
                                icon: "person.fill",
                                color: FieldPayTheme.accent
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
                                color: FieldPayTheme.highlight
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [color.opacity(0.9), color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(FieldPayTheme.inkMuted)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(FieldPayFont.headline)
                        .foregroundColor(FieldPayTheme.ink)
                    
                    Text(subtitle)
                        .font(FieldPayFont.caption)
                        .foregroundColor(FieldPayTheme.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fieldPaySoftCard(padding: 16, cornerRadius: 18)
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
                .font(FieldPayFont.headline)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FieldPayFont.callout)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(subtitle)
                    .font(FieldPayFont.caption)
                    .foregroundColor(FieldPayTheme.inkMuted)
            }
            
            Spacer()
        }
        .fieldPaySoftCard(padding: 14, cornerRadius: 14)
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
