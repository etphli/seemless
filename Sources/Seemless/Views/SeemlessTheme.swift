import SwiftUI

struct SeemlessTheme {
    let scheme: ColorScheme

    var canvas: Color { colour(0x16171B, 0xFAFAFC) }
    var raised: Color { colour(0x1E2026, 0xFFFFFF) }
    var inset: Color { colour(0x121317, 0xF1F2F6) }
    var accent: Color { colour(0xB0A1F4, 0x7562CA) }
    var text: Color { colour(0xF1F0F5, 0x25252D) }
    var secondary: Color { colour(0xA4A4B2, 0x696A7A) }
    var muted: Color { colour(0x737580, 0x898B98) }
    var line: Color { colour(0xFFFFFF, 0x222238).opacity(scheme == .dark ? 0.075 : 0.085) }
    var selection: Color { accent.opacity(scheme == .dark ? 0.11 : 0.085) }

    private func colour(_ dark: UInt32, _ light: UInt32) -> Color {
        let hex = scheme == .dark ? dark : light
        return Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct SeemlessMark: View {
    var size: CGFloat = 28
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = SeemlessTheme(scheme: scheme)
        Image(systemName: "square.stack.3d.up")
            .font(.system(size: size * 0.52, weight: .medium))
            .foregroundStyle(theme.accent)
            .frame(width: size, height: size)
            .background(theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: size * 0.27))
            .overlay(RoundedRectangle(cornerRadius: size * 0.27).strokeBorder(theme.accent.opacity(0.16)))
            .accessibilityHidden(true)
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let theme = SeemlessTheme(scheme: scheme)
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(prominent ? theme.accent : theme.secondary)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background((prominent ? theme.selection : theme.raised).opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(prominent ? theme.accent.opacity(0.2) : theme.line))
    }
}
