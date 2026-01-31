import SwiftUI

// MARK: - Design System

struct DesignSystem {
    // MARK: - Colors (Light Blue/Cyan Palette)
    struct Colors {
        // Background - Lighter dark
        static let background = Color(hex: "0F1419")
        static let panelBackground = Color(hex: "1C2631").opacity(0.9)
        static let cardBackground = Color(hex: "243242").opacity(0.6)
        
        // Gradients - Blue to Cyan palette
        static let gradientBlue = Color(hex: "0EA5E9")      // Sky blue
        static let gradientCyan = Color(hex: "22D3EE")      // Bright cyan
        static let gradientTeal = Color(hex: "14B8A6")      // Teal
        static let gradientAqua = Color(hex: "67E8F9")      // Light aqua
        
        // Accent gradient - Main gradient for UI elements
        static let accentGradient = LinearGradient(
            colors: [gradientBlue, gradientCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Slider gradient - Full spectrum for sliders
        static let sliderGradient = LinearGradient(
            colors: [gradientTeal, gradientBlue, gradientCyan],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        // Glow gradient for effects
        static let glowGradient = LinearGradient(
            colors: [gradientCyan.opacity(0.4), gradientBlue.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Text colors
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let textMuted = Color.white.opacity(0.4)
        
        // UI Elements
        static let sliderTrack = Color.white.opacity(0.12)
        static let divider = Color.white.opacity(0.08)
        
        // Accent for mute button (soft coral)
        static let muteAccent = Color(hex: "F472B6")
    }
    
    // MARK: - Typography
    struct Typography {
        static let title = Font.system(size: 18, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 13, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 11, weight: .medium, design: .rounded)
        static let mono = Font.system(size: 11, weight: .semibold, design: .monospaced)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    // MARK: - Animation
    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    }
    
    // MARK: - Blur
    struct Blur {
        static let panel: CGFloat = 30
        static let card: CGFloat = 20
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
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

// MARK: - Glass Panel Modifier
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Blur background
                    DesignSystem.Colors.panelBackground
                    
                    // Subtle gradient overlay
                    DesignSystem.Colors.glowGradient
                        .opacity(0.05)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 20, y: 10)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

// MARK: - Glow Effect Modifier
struct GlowEffect: ViewModifier {
    var color: Color
    var radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
    }
}

extension View {
    func glow(color: Color = DesignSystem.Colors.gradientCyan, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}
