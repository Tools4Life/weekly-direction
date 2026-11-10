import SwiftUI
import UIKit

// The web app's palette (dark first, light from html[data-theme=light]) and type: Fraunces for titles, focus word and
// entries; Barlow for UI text; Barlow Condensed, letter-spaced and uppercase, for labels and dates.
enum Theme {
    /// "Not now" palette preview (-MockPalette focus, sample-data mode only): a design finding, not an approved theme.
    /// bg, tx and ac are sampled from the /focus page screenshot; the other tones are derived from them.
    private static let focus = Mock.enabled && UserDefaults.standard.string(forKey: "MockPalette") == "focus"
    /// Flat style preview (-MockStyle 1 or 2, sample-data mode only): a design finding Eddie tried and turned down
    /// (Nov 9 2026: "keep original"). 1 = square, outlined shapes; 2 = the same plus condensed caps titles.
    static let style: Int = Mock.enabled ? UserDefaults.standard.integer(forKey: "MockStyle") : 0
    /// Calmer stats preview (-MockStats 1, sample data only): a design finding, not approved.
    static let statsV2: Bool = Mock.enabled && UserDefaults.standard.integer(forKey: "MockStats") == 1
    /// The journal's own page (Eddie, Nov 9 2026): a warm brown-black page in dark mode, the web app's cream paper in
    /// light mode, set in Georgia with plain-word buttons and italic stamps. Used by the journal list, the week page
    /// and the editor only.
    static let jbg = dyn(0x17130F, 0xF3EEE4)
    static let jtx = dyn(0xEFE6D8, 0x1F1B16)
    static let jmu = dyn(0xA99D8D, 0x6B6257)
    static let jmu2 = dyn(0x877C6E, 0x8C8273)
    static let jrule = dyn(0x2B251E, 0xE0D7C7)
    static let jac = dyn(0xE8743B, 0x8A2E22)
    static func jserif(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
    static func jitalic(_ size: CGFloat) -> Font { .custom("Georgia-Italic", size: size) }
    static func r(_ x: CGFloat) -> CGFloat { style > 0 ? 0 : x }
    static var pill: AnyShape { style > 0 ? AnyShape(Rectangle()) : AnyShape(Capsule()) }
    static var dot: AnyShape { style > 0 ? AnyShape(Rectangle()) : AnyShape(Circle()) }
    static let bg = dyn(focus ? 0x0F1115 : 0x0B0B0C, 0xF6F5F2)
    static var card: Color { style > 0 ? flatCard : roundCard }
    private static let flatCard = dyn(0x0B0B0C, 0xF6F5F2)
    private static let roundCard = dyn(focus ? 0x171A20 : 0x151517, 0xFFFFFF)
    static var card2: Color { style > 0 ? flatCard2 : roundCard2 }
    private static let flatCard2 = dyn(0x101012, 0xF1EFEA)
    private static let roundCard2 = dyn(focus ? 0x1D2028 : 0x1C1C1F, 0xF0EEE9)
    static let tx = dyn(focus ? 0xF2EFE9 : 0xF7F4EF, 0x1B1917)
    static let mu = dyn(focus ? 0xA9A8A4 : 0xABA69F, 0x6F6A63)
    static let mu2 = dyn(focus ? 0x83858B : 0x8A857F, 0x8D877F)
    static let rule = dyn(focus ? 0x242831 : 0x222225, 0xE4E1DB)
    static let line = dyn(focus ? 0x30343E : 0x2C2C30, 0xD9D5CE)
    static let ac = dyn(focus ? 0xD9B56C : 0xE8743B, 0xD2602A)
    static let acSoft = dyn(focus ? 0x3B3424 : 0x4A2C22, 0xFBE7DC)
    static let acDim = dyn(focus ? 0x8C7748 : 0x86452A, 0xE9A07C)
    static let onAc = dyn(focus ? 0x0F1115 : 0x0B0B0C, 0xFFFFFF)
    static let danger = Color(hex: 0xE5484D)

    static func serif(_ size: CGFloat) -> Font { .custom("Fraunces-Regular", size: size) }
    static func serifItalic(_ size: CGFloat) -> Font { .custom("Fraunces-Italic", size: size) }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(weight == .semibold || weight == .bold ? "Barlow-SemiBold" : weight == .medium ? "Barlow-Medium" : "Barlow-Regular", size: size)
    }
    static func label(_ size: CGFloat = 12) -> Font { .custom("BarlowCondensed-Medium", size: size) }
    static func num(_ size: CGFloat) -> Font { .custom("Barlow-SemiBold", size: size) }

    private static func dyn(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: light) : UIColor(hex: dark) })
    }

    /// the web's icon names (ICON_CHOICES and the prayer icons) as SF Symbols
    static let symbols: [String: String] = [
        "sun": "sunrise", "hands": "hands.sparkles", "book": "book", "bookmark": "bookmark", "scroll": "scroll",
        "pen": "pencil.line", "brain": "brain", "cross": "cross", "church": "building.columns", "flame": "flame",
        "moon": "moon.stars", "sunfull": "sun.max", "heart": "heart", "handheart": "hand.raised", "music": "music.note",
        "leaf": "leaf", "drop": "drop", "eye": "eye", "phone": "iphone", "cup": "cup.and.saucer", "walk": "figure.walk",
        "clock": "clock", "home": "house", "bed": "bed.double", "users": "person.2", "briefcase": "briefcase",
        "hardhat": "shield.lefthalf.filled", "hammer": "hammer", "wrench": "wrench.adjustable", "laptop": "laptopcomputer",
        "clipboard": "list.clipboard", "calendar": "calendar", "list": "list.bullet", "mail": "envelope", "target": "target",
        "chart": "chart.line.uptrend.xyaxis", "money": "dollarsign.circle", "bulb": "lightbulb", "handshake": "person.2.wave.2",
        "car": "car", "timer": "timer", "check": "checkmark",
        "compass": "location.north.circle", "family": "figure.2.and.child.holdinghands", "work": "briefcase",
        "health": "cross.case", "self": "person", "world": "globe"
    ]
    static func symbol(_ name: String?) -> String {
        let s = symbols[name ?? "check"] ?? "checkmark"
        return UIImage(systemName: s) == nil ? "checkmark" : s
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
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
    var size: CGFloat = 12
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(size))
            .tracking(size * 0.2)
            .foregroundStyle(color)
    }
}

/// a habit / prayer icon by its web name
struct Ico: View {
    let name: String?
    var size: CGFloat = 20
    var body: some View {
        Image(systemName: Theme.symbol(name))
            .font(.system(size: size, weight: .light))
            .frame(width: size + 8, height: size + 8)
    }
}

/// two-option pill switch (JOURNAL | PRAYER, WEEKS | HABITS, ALL TIME | WEEK)
struct Seg: View {
    let options: [(String, String)]   // (value, title)
    @Binding var value: String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { o in
                Button {
                    if value != o.0 { Haptic.tick(); value = o.0 }
                } label: {
                    Text(o.1.uppercased())
                        .font(Theme.label(13)).tracking(1.6)
                        .foregroundStyle(value == o.0 ? (Theme.style > 0 ? Theme.bg : Theme.tx) : Theme.mu)
                        .padding(.horizontal, 14).frame(height: 30)
                        .background(value == o.0 ? (Theme.style > 0 ? Theme.tx : Theme.card2) : .clear, in: Theme.pill)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.card, in: Theme.pill)
        .overlay { if Theme.style > 0 { Rectangle().stroke(Theme.line, lineWidth: 1) } }
    }
}

enum Haptic {
    static func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

extension View {
    func card(_ radius: CGFloat = 20) -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(radius), style: .continuous))
            .overlay { if Theme.style > 0 { Rectangle().stroke(Theme.line, lineWidth: 1) } }
    }
    /// screen title: Fraunces, or heavy condensed caps in flat style 2 (preview only)
    @ViewBuilder func title(_ size: CGFloat) -> some View {
        if Theme.style == 2 { font(.custom("BarlowCondensed-SemiBold", size: size * 1.12)).textCase(.uppercase).tracking(size * 0.03) }
        else { font(Theme.serif(size)) }
    }
    /// Names, rows and buttons: heavy condensed caps (Eddie, Nov 9 2026). Page titles and journal text keep the serif;
    /// sentences and descriptions keep Barlow.
    func caps(_ size: CGFloat = 16) -> some View {
        font(.custom("BarlowCondensed-SemiBold", size: size)).textCase(.uppercase).tracking(size * 0.11)
    }
    /// a button inside the journal: plain words, not caps
    func jbutton(_ size: CGFloat = 16) -> some View { font(Theme.ui(size + 1)) }
    /// habit name
    func rowTitle() -> some View { caps(17) }
    /// full-width, leading-aligned content: nothing in the app is centered in a narrow column
    func fullWidth() -> some View { frame(maxWidth: .infinity, alignment: .leading) }
}
