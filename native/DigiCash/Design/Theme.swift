import SwiftUI

/// DigiCash design tokens. Brand purple #9409B6 comes from the supplied
/// DIGI:CASH logo asset and overrides the spec's suggested green.
enum DCColor {
    static let brand = Color(red: 0x94/255, green: 0x09/255, blue: 0xB6/255)
    static let brandSoft = Color(red: 0xB4/255, green: 0x4A/255, blue: 0xD1/255)
    static let brandDeep = Color(red: 0x6D/255, green: 0x07/255, blue: 0x86/255)
    static let income = Color(red: 0x39/255, green: 0xD9/255, blue: 0x8A/255)
    static let expense = Color(red: 1.0, green: 0x6B/255, blue: 0x6B/255)
    static let warning = Color(red: 1.0, green: 0xB0/255, blue: 0x20/255)
    static let transfer = Color(red: 0x4A/255, green: 0xA8/255, blue: 1)

    static func category(_ name: String) -> Color {
        switch name {
        case "orange": return Color(red: 1, green: 0x9F/255, blue: 0x43/255)
        case "green": return income
        case "blue": return Color(red: 0x4A/255, green: 0xA8/255, blue: 1)
        case "purple": return brandSoft
        case "pink": return Color(red: 1, green: 0x6B/255, blue: 0x9D/255)
        case "teal": return Color(red: 0x2D/255, green: 0xD4/255, blue: 0xBF/255)
        case "yellow": return warning
        case "red": return expense
        case "indigo": return Color(red: 0x7C/255, green: 0x8A/255, blue: 1)
        case "violet": return Color(red: 0x9D/255, green: 0x7B/255, blue: 1)
        case "rose": return Color(red: 0xFB/255, green: 0x71/255, blue: 0x85/255)
        case "cyan": return Color(red: 0x22/255, green: 0xD3/255, blue: 0xEE/255)
        case "slate": return Color(red: 0x94/255, green: 0xA3/255, blue: 0xB8/255)
        case "amber": return Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255)
        case "sky": return Color(red: 0x38/255, green: 0xBD/255, blue: 0xF8/255)
        default: return .gray
        }
    }
}

enum DCRadius {
    static let card: CGFloat = 20
    static let small: CGFloat = 14
    static let pill: CGFloat = 999
}

enum DCSpacing {
    static let screen: CGFloat = 20
    static let card: CGFloat = 18
    static let section: CGFloat = 28
}

struct DCFonts {
    static func balance() -> Font { .system(size: 38, weight: .heavy, design: .rounded) }
    static func title() -> Font { .system(size: 28, weight: .bold, design: .default) }
    static func headline() -> Font { .headline }
    static func money() -> Font { .system(size: 17, weight: .bold, design: .rounded) }
}

/// iOS-native glass. Uses real system materials (which render with the
/// Liquid Glass treatment on iOS 26+), with a bordered fallback baked in.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = DCRadius.card
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 18)
        }
    }
}

extension View {
    func dcGlass(cornerRadius: CGFloat = DCRadius.card) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }

    /// Respects Reduce Motion for animated transitions.
    func dcAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReduceMotionAware(animation: animation, value: value))
    }
}

private struct ReduceMotionAware<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var animation: Animation?
    var value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
