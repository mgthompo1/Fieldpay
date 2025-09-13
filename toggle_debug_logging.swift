#!/usr/bin/env swift

import Foundation

// Simple script to toggle debug logging in SystemManager.swift
// Run this script to easily switch between verbose and quiet logging

let filePath = "fieldpay/Networking/SystemManager.swift"

func toggleDebugLogging() {
    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Check current state
        let isCurrentlyEnabled = content.contains("let debugLoggingEnabled = true")
        
        if isCurrentlyEnabled {
            // Turn off debug logging
            let newContent = content.replacingOccurrences(
                of: "let debugLoggingEnabled = true",
                with: "let debugLoggingEnabled = false"
            )
            try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("✅ Debug logging turned OFF")
            print("📝 To re-enable, run this script again")
        } else {
            // Turn on debug logging
            let newContent = content.replacingOccurrences(
                of: "let debugLoggingEnabled = false",
                with: "let debugLoggingEnabled = true"
            )
            try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("🔍 Debug logging turned ON")
            print("📝 To disable, run this script again")
        }
        
    } catch {
        print("❌ Error: \(error)")
        print("💡 Make sure you're running this script from the project root directory")
    }
}

print("🔧 FieldPay Debug Logging Toggle")
print("==================================")
toggleDebugLogging()


