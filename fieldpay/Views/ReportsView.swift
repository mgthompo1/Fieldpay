//
//  ReportsView.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/27/25.
//

import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customerViewModel = CustomerViewModel()
    @StateObject private var invoiceViewModel = InvoiceViewModel()
    @StateObject private var paymentViewModel = PaymentViewModel()
    @StateObject private var salesOrderViewModel = SalesOrderViewModel()
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedReportType: ReportType = .payments
    @State private var showingDatePicker = false
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case quarter = "This Quarter"
        case year = "This Year"
        
        var icon: String {
            switch self {
            case .day: return "calendar.day.timeline.left"
            case .week: return "calendar.badge.clock"
            case .month: return "calendar"
            case .quarter: return "calendar.badge.plus"
            case .year: return "calendar.badge.exclamationmark"
            }
        }
    }
    
    enum ReportType: String, CaseIterable {
        case payments = "Payments"
        case invoices = "Invoices"
        case customers = "Customers"
        case orders = "Orders"
        
        var icon: String {
            switch self {
            case .payments: return "creditcard.fill"
            case .invoices: return "doc.text.fill"
            case .customers: return "person.2.fill"
            case .orders: return "cart.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reports & Analytics")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Business insights and performance metrics")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    // Filters Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Filters")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Reset") {
                                selectedTimeRange = .week
                                selectedReportType = .payments
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        // Time Range Filter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Time Range")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TimeRange.allCases, id: \.self) { range in
                                        ModernFilterPill(
                                            title: range.rawValue,
                                            icon: range.icon,
                                            isSelected: selectedTimeRange == range
                                        ) {
                                            selectedTimeRange = range
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Report Type Filter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Report Type")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(ReportType.allCases, id: \.self) { type in
                                        ModernFilterPill(
                                            title: type.rawValue,
                                            icon: type.icon,
                                            isSelected: selectedReportType == type
                                        ) {
                                            selectedReportType = type
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    
                    // Summary Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ModernSummaryCard(
                            title: "Total Revenue",
                            value: String(format: "$%.0f", getTotalRevenue()),
                            subtitle: "This period",
                            icon: "dollarsign.circle.fill",
                            color: .green,
                            gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        
                        ModernSummaryCard(
                            title: "Total Payments",
                            value: "\(getTotalPayments())",
                            subtitle: "Transactions",
                            icon: "creditcard.fill",
                            color: .blue,
                            gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        
                        ModernSummaryCard(
                            title: "Outstanding",
                            value: String(format: "$%.0f", getOutstandingAmount()),
                            subtitle: "Invoices",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        
                        ModernSummaryCard(
                            title: "Active Customers",
                            value: "\(getActiveCustomers())",
                            subtitle: "Total",
                            icon: "person.2.fill",
                            color: .purple,
                            gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Chart Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Payment Trends")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("Export") {
                                // Export functionality
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        
                        ModernChartContainer(data: getChartData())
                            .frame(height: 250)
                            .padding(.horizontal, 20)
                    }
                    
                    // Recent Activity Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Activity")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("View All") {
                                // Navigate to full activity view
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ForEach(getRecentActivity(), id: \.id) { activity in
                                ModernActivityRow(
                                    title: activity.title,
                                    subtitle: activity.subtitle,
                                    time: activity.time,
                                    icon: activity.icon,
                                    color: activity.color
                                )
                            }
                            
                            if getRecentActivity().isEmpty {
                                ModernEmptyStateView(
                                    icon: "chart.bar",
                                    title: "No Recent Activity",
                                    subtitle: "Your activity will appear here"
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Connect PaymentViewModel to CustomerViewModel for local payment storage
                paymentViewModel.setCustomerViewModel(customerViewModel)
            }
        }
    }
    
    // MARK: - Data Methods
    
    private func getTotalRevenue() -> Double {
        let payments = paymentViewModel.payments.filter { payment in
            isInSelectedTimeRange(payment.createdDate)
        }
        return payments.reduce(0) { sum, payment in
            sum + (payment.amount as NSDecimalNumber).doubleValue
        }
    }
    
    private func getTotalPayments() -> Int {
        return paymentViewModel.payments.filter { payment in
            isInSelectedTimeRange(payment.createdDate)
        }.count
    }
    
    private func getOutstandingAmount() -> Double {
        return NSDecimalNumber(decimal: invoiceViewModel.getTotalOutstanding()).doubleValue
    }
    
    private func getActiveCustomers() -> Int {
        return customerViewModel.customers.filter { $0.isActive }.count
    }
    
    private func getChartData() -> [ChartDataPoint] {
        // Mock data for chart - in a real app, this would be calculated based on actual data
        return [
            ChartDataPoint(date: Date().addingTimeInterval(-6 * 24 * 3600), value: 1200),
            ChartDataPoint(date: Date().addingTimeInterval(-5 * 24 * 3600), value: 1800),
            ChartDataPoint(date: Date().addingTimeInterval(-4 * 24 * 3600), value: 1500),
            ChartDataPoint(date: Date().addingTimeInterval(-3 * 24 * 3600), value: 2200),
            ChartDataPoint(date: Date().addingTimeInterval(-2 * 24 * 3600), value: 1900),
            ChartDataPoint(date: Date().addingTimeInterval(-1 * 24 * 3600), value: 2400),
            ChartDataPoint(date: Date(), value: 2100)
        ]
    }
    
    private func getRecentActivity() -> [ActivityItem] {
        let payments = paymentViewModel.payments.prefix(5)
        return payments.map { payment in
            ActivityItem(
                id: UUID(uuidString: payment.id) ?? UUID(),
                title: "Payment Processed",
                subtitle: "\(String(format: "$%.2f", (payment.amount as NSDecimalNumber).doubleValue)) - \(payment.paymentMethod.displayName)",
                time: payment.createdDate,
                icon: "creditcard.fill",
                color: .green
            )
        }
    }
    
    private func isInSelectedTimeRange(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return date >= weekAgo
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return date >= monthAgo
        case .quarter:
            let quarterAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            return date >= quarterAgo
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return date >= yearAgo
        }
    }
}

// MARK: - Modern Components

struct ModernSummaryCard: View {
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
                    .frame(width: 44, height: 44)
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

struct ModernChartContainer: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Revenue")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Last 7 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chart Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        
                        Text("Revenue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { point in
                    VStack(spacing: 8) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top)
                            )
                            .frame(width: 24, height: max(20, CGFloat(point.value / 25)))
                            .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // Date Label
                        Text(formatDate(point.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}



// MARK: - Data Models

struct ChartDataPoint {
    let date: Date
    let value: Double
}

struct ActivityItem {
    let id: UUID
    let title: String
    let subtitle: String
    let time: Date
    let icon: String
    let color: Color
}

#Preview {
    ReportsView()
} 