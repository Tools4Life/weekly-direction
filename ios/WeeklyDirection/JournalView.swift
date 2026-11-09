import SwiftUI

/// This week's journal entries, newest first. Recording comes in phase 3.
struct JournalView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reflect").font(Theme.serif(44)).foregroundStyle(Theme.tx)
                if let w = store.activeWeek {
                    Eyebrow(text: "This week", color: Theme.ac)
                    Text(w.focus).font(Theme.serif(26)).foregroundStyle(Theme.tx)
                    let ents = Journal.entries(w.liveRefl).reversed()
                    if ents.isEmpty {
                        Text("Nothing yet this week.").foregroundStyle(Theme.mu)
                    }
                    ForEach(Array(ents)) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            if let d = e.d, let t = e.t { Eyebrow(text: "\(d), \(t)") }
                            Text(e.x).font(Theme.serif(17)).foregroundStyle(Theme.tx)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
    }
}
