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
                    let ents = Entry.parse(w.liveRefl).reversed()
                    if ents.isEmpty {
                        Text("Nothing yet this week.").foregroundStyle(Theme.mu)
                    }
                    ForEach(Array(ents.enumerated()), id: \.offset) { _, e in
                        VStack(alignment: .leading, spacing: 4) {
                            if let stamp = e.stamp { Eyebrow(text: stamp) }
                            Text(e.text).font(Theme.serif(17)).foregroundStyle(Theme.tx)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .background(Theme.bg)
    }
}

/// One block of the week's text: "Sunday, 10:22 pm" on the first line, then what was said.
struct Entry {
    let stamp: String?
    let text: String

    static let stampPattern = try! NSRegularExpression(
        pattern: "^(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday), (\\d{1,2}:\\d{2} [ap]m)$")

    static func parse(_ t: String) -> [Entry] {
        // same split as the web app: blocks are separated by a blank line (which may hold spaces)
        t.replacingOccurrences(of: "\n[ \t]*\n\\s*", with: "\u{1E}", options: .regularExpression)
            .components(separatedBy: "\u{1E}").compactMap { raw in
            let block = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !block.isEmpty else { return nil }
            var lines = block.components(separatedBy: "\n")
            let first = lines[0].trimmingCharacters(in: .whitespaces)
            let isStamp = stampPattern.firstMatch(in: first, range: NSRange(first.startIndex..., in: first)) != nil
            if isStamp && lines.count > 1 {
                lines.removeFirst()
                return Entry(stamp: first, text: lines.joined(separator: "\n"))
            }
            return Entry(stamp: nil, text: block)
        }
    }
}
