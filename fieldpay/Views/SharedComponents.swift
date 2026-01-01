//
//  SharedComponents.swift
//  fieldpay
//
//  Created by Mitchell Thompson on 7/27/25.
//

import SwiftUI

// MARK: - FieldPay Design System

enum FieldPayTheme {
    static let ink = Color(red: 0.08, green: 0.1, blue: 0.12)
    static let inkMuted = Color(red: 0.37, green: 0.41, blue: 0.45)
    static let accent = Color(red: 0.06, green: 0.52, blue: 0.6)
    static let accentDeep = Color(red: 0.03, green: 0.42, blue: 0.5)
    static let highlight = Color(red: 0.98, green: 0.66, blue: 0.32)
    static let success = Color(red: 0.18, green: 0.62, blue: 0.47)
    static let danger = Color(red: 0.88, green: 0.34, blue: 0.32)
    static let surface = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let surfaceSoft = Color(red: 0.96, green: 0.97, blue: 0.97)
    static let stroke = Color.black.opacity(0.06)
    static let shadow = Color.black.opacity(0.08)
    
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.98, blue: 0.99), Color(red: 0.93, green: 0.95, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let successGradient = LinearGradient(
        colors: [success, Color(red: 0.16, green: 0.72, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let highlightGradient = LinearGradient(
        colors: [highlight, Color(red: 0.95, green: 0.48, blue: 0.34)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum FieldPayFont {
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 14, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let metric = Font.system(size: 22, weight: .bold, design: .monospaced)
}

struct FieldPayBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.98, blue: 0.96), Color(red: 0.94, green: 0.96, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(FieldPayTheme.accent.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 8)
                .offset(x: 140, y: -200)
            
            RoundedRectangle(cornerRadius: 120)
                .fill(FieldPayTheme.highlight.opacity(0.08))
                .frame(width: 260, height: 180)
                .rotationEffect(.degrees(15))
                .offset(x: -140, y: 220)
        }
        .ignoresSafeArea()
    }
}

struct FieldPayCardStyle: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 20
    var background: Color = FieldPayTheme.surface
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(FieldPayTheme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: FieldPayTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

struct FieldPaySoftCardStyle: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FieldPayTheme.surfaceSoft)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(FieldPayTheme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func fieldPayCard(padding: CGFloat = 20, cornerRadius: CGFloat = 20) -> some View {
        modifier(FieldPayCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
    
    func fieldPaySoftCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        modifier(FieldPaySoftCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}

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
                    .font(FieldPayFont.caption)
                
                Text(title)
                    .font(FieldPayFont.callout)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                FieldPayTheme.accentGradient :
                LinearGradient(colors: [FieldPayTheme.surfaceSoft, FieldPayTheme.surfaceSoft], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(isSelected ? .white : FieldPayTheme.ink)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(FieldPayTheme.stroke, lineWidth: isSelected ? 0 : 1)
            )
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
                .font(FieldPayFont.callout)
                .foregroundColor(FieldPayTheme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .fieldPayCard(padding: 28, cornerRadius: 18)
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
                .foregroundColor(FieldPayTheme.highlight)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(FieldPayFont.title2)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(message)
                    .font(FieldPayFont.callout)
                    .foregroundColor(FieldPayTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                retryAction()
            }
            .font(FieldPayFont.callout)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(FieldPayTheme.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
        .fieldPayCard(padding: 28, cornerRadius: 18)
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
                .foregroundColor(FieldPayTheme.inkMuted)
            
            Text(title)
                .font(FieldPayFont.title)
                .foregroundColor(FieldPayTheme.ink)
            
            Text(subtitle)
                .font(FieldPayFont.callout)
                .foregroundColor(FieldPayTheme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .fieldPayCard(padding: 28, cornerRadius: 20)
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
                .font(FieldPayFont.headline)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FieldPayFont.headline)
                    .foregroundColor(FieldPayTheme.ink)
                
                Text(subtitle)
                    .font(FieldPayFont.caption)
                    .foregroundColor(FieldPayTheme.inkMuted)
            }
            
            Spacer()
            
            Text(time, style: .relative)
                .font(FieldPayFont.caption)
                .foregroundColor(FieldPayTheme.inkMuted)
        }
        .fieldPaySoftCard(padding: 16, cornerRadius: 16)
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
