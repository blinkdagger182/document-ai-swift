//
//  Theme.swift
//  documentAI
//
//  Design system: colors, fonts, shadows
//

import SwiftUI

struct Theme {
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "8B5CF6") // Purple
        static let secondary = Color(hex: "10B981") // Green
        static let background = Color(hex: "F9FAFB")
        static let cardBackground = Color.white
        static let textPrimary = Color(hex: "1F2937")
        static let textSecondary = Color(hex: "6B7280")
        static let textTertiary = Color(hex: "9CA3AF")
        static let border = Color(hex: "D1D5DB")
        static let progressTrack = Color(hex: "E5E7EB")
        
        // Gradient colors
        static let gradientStart = Color(hex: "DBEAFE")
        static let gradientEnd = Color(hex: "EDE9FE")
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 36, weight: .bold)
        static let title = Font.system(size: 20, weight: .semibold)
        static let title2 = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let bodySemibold = Font.system(size: 16, weight: .semibold)
        static let caption = Font.system(size: 14, weight: .regular)
        static let captionMedium = Font.system(size: 14, weight: .medium)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let card = Shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let button = Shadow(
            color: Colors.primary.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.xxl)
            .shadow(
                color: Theme.Shadows.card.color,
                radius: Theme.Shadows.card.radius,
                x: Theme.Shadows.card.x,
                y: Theme.Shadows.card.y
            )
    }
}

struct PrimaryButtonModifier: ViewModifier {
    let isDisabled: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, Theme.Spacing.lg)
            .background(Theme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(Theme.CornerRadius.md)
            .shadow(
                color: Theme.Shadows.button.color,
                radius: Theme.Shadows.button.radius,
                x: Theme.Shadows.button.x,
                y: Theme.Shadows.button.y
            )
            .opacity(isDisabled ? 0.6 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
    
    func primaryButtonStyle(isDisabled: Bool = false) -> some View {
        modifier(PrimaryButtonModifier(isDisabled: isDisabled))
    }
}
