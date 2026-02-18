//
//  Color+Hex.swift
//  MAMONAKU
//
//  Created by gpt-5.2-codex on 2026/01/23.
//

import SwiftUI

extension Color {
    
    
    /// Initialize a Color from a hex string like "#RRGGBB" or "RRGGBB".
    init(hex: String, alpha: Double = 1.0) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum AppColors {
    static let background = Color(hex: "#F8F8F8")
    static let systemBackground = Color(hex: "#252525")
    static let systemBackgroundSecondary = Color(hex: "#eaeaea")
    static let systemBackground2 = Color(hex: "#f5f6fa")
    static let shadow = Color(hex: "#b5bace")
    static let textPrimary = Color(hex: "#111111")
    static let textSecondary = Color(hex: "#6B6B6B")
    static let divider = Color(hex: "#E5E5E5")
    static let accent = Color(hex: "#000000")
}
