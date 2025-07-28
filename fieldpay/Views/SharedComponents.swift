//
//  SharedComponents.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/27/25.
//

import SwiftUI

// MARK: - Shared Modern Components

struct ModernFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing) :
                LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

struct ModernErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                retryAction()
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

struct ModernEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

struct ModernActivityRow: View {
    let title: String
    let subtitle: String
    let time: Date
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        ModernFilterPill(title: "All", icon: "person.2.fill", isSelected: true) {}
        ModernLoadingView(message: "Loading...")
        ModernErrorView(message: "Network error") {}
        ModernEmptyStateView(icon: "person.2", title: "No Data", subtitle: "Try again later")
        ModernActivityRow(
            title: "Payment Processed",
            subtitle: "$25.00 - Credit Card",
            time: Date(),
            icon: "creditcard.fill",
            color: .green
        )
    }
    .padding()
} 