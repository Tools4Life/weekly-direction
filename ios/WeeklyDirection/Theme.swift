import SwiftUI

// The web app's dark palette. Fraunces and Barlow Condensed fall back to the system serif and a condensed system font
// until the font files are added to the project.
enum Theme {
    static let bg = Color(hex: 0x0B0B0C)
    static let card = Color(hex: 0x151517)
    static let card2 = Color(hex: 0x1C1C1F)
    static let tx = Color(hex: 0xF7F4EF)
    static let mu = Color(hex: 0xABA69F)
    static let mu2 = Color(hex: 0x8A857F)
    static let rule = Color(hex: 0x222225)
    static let ac = Color(hex: 0xE8743B)
    static let onAc = Color(hex: 0x0B0B0C)

    static func serif(_ size: CGFloat) -> Font { .system(size: size, design: .serif) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium).width(.condensed) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// small caps-style label used for dates and section names
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.mu2
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(12))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}
