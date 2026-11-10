import SwiftUI

/// Sample-data mode only (`-OpenScreen widgets`): the Home Screen widgets drawn at their real sizes, for screenshots.
/// The Live Activity and the Lock Screen widgets can only be seen on a device.
struct WidgetPreview: View {
    private func tile<V: View>(_ w: CGFloat, _ h: CGFloat, _ v: V, light: Bool) -> some View {
        v.padding(16).frame(width: w, height: h).background(WPalette.of(light: light).bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    var body: some View {
        let light = UserDefaults.standard.string(forKey: "MockTheme") == "light"
        var s = WidgetSnapshot.sample; s.light = light; s.day = Rules.ymd(Date())
        return ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    tile(158, 158, WeekWidgetBody(snap: s, date: Date(), size: .small), light: light)
                    Spacer(minLength: 0)
                }
                tile(338, 158, WeekWidgetBody(snap: s, date: Date(), size: .medium), light: light)
                tile(338, 354, WeekWidgetBody(snap: s, date: Date(), size: .large), light: light)
            }
            .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 40)
        }
        .background(Color(hex: light ? 0xC9C4BA : 0x2A2A30).ignoresSafeArea())
    }
}
