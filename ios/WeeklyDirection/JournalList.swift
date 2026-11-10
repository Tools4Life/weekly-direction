import SwiftUI

// Mic-first layout (Eddie, Nov 9 2026): the mic lives in the tab bar, This Week shows the latest thought, and Reflect
// is a plain list of the journal. Layout only: entries are read and written exactly as before.

/// what the recorder is doing, and anything still waiting to upload (was the line above the old mic)
struct RecorderStatus: View {
    @EnvironmentObject var recorder: Recorder
    var body: some View {
        if recorder.sending || recorder.message != nil || recorder.pending > 0 {
            HStack(spacing: 10) {
                if recorder.sending { Text("Transcribing…") }
                else if let m = recorder.message { Text(m) }
                if recorder.pending > 0, !recorder.sending {
                    Text("\(recorder.pending) waiting ·")
                    Button("Retry") { Task { await recorder.flush() } }.foregroundStyle(Theme.ac)
                }
            }
            .font(Theme.ui(14)).foregroundStyle(Theme.mu)
        }
    }
}

/// This Week: the most recent thought of the week, one tap from the whole journal
struct LatestThought: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    let week: Week

    var body: some View {
        let e = Journal.entries(week.liveRefl).last
        VStack(alignment: .leading, spacing: 8) {
        RecorderStatus()
        Button { router.cover = .weekPage(week.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Theme.ac).frame(width: 2)
                VStack(alignment: .leading, spacing: 5) {
                    if recorder.sending, let heard = recorder.draftText {
                        Eyebrow(text: "Just now · transcribing", color: Theme.ac)
                        Text(heard).font(Theme.serif(16)).lineSpacing(4).foregroundStyle(Theme.mu).lineLimit(2).multilineTextAlignment(.leading)
                    } else if let e, let d = e.d, let t = e.t {
                        Eyebrow(text: "Latest thought · \(d == Fmt.dowl[Rules.weekday(Now.date)] ? "Today" : d) \(t)", color: Theme.mu2)
                        Text(e.x).font(Theme.serif(16)).lineSpacing(4).foregroundStyle(Theme.tx).lineLimit(2).multilineTextAlignment(.leading)
                    } else {
                        Eyebrow(text: "Thoughts", color: Theme.mu2)
                        Text("Tap the mic to leave the first one this week.").font(Theme.serifItalic(16)).foregroundStyle(Theme.mu)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.mu2).padding(.top, 3)
            }
            .padding(.vertical, 4)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        }
    }
}

/// Reflect as a plain reading list: this week's entries, newest first, then earlier weeks
struct JournalList: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        let past = store.weeks.filter { w in
            w.status == "closed" && (!(w.reflection.isEmpty ? w.liveRefl : w.reflection).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || w.summary != nil)
        }.sorted { $0.sealedAtMs > $1.sealedAtMs }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Journal").font(Theme.jserif(34)).foregroundStyle(Theme.jtx)
                    Spacer()
                    if store.activeWeek != nil {
                        Button { router.cover = .write } label: {
                            HStack(spacing: 6) { Image(systemName: "pencil.line").font(.system(size: 14)); Text("Write").jbutton(15) }.foregroundStyle(Theme.jac)
                        }
                        .buttonStyle(.plain)
                    }
                }
                RecorderStatus().padding(.top, 10)
                if let w = store.activeWeek {
                    (Text("This week · \(Fmt.weekRange(w, store.settings)) · ").foregroundColor(Theme.jmu2) + Text(w.focus).foregroundColor(Theme.jac))
                        .font(Theme.label(12)).tracking(2.4).textCase(.uppercase).padding(.top, 18)
                    let ents = Array(Journal.entries(w.liveRefl).reversed())
                    if ents.isEmpty {
                        Text("Nothing yet this week.").font(Theme.jitalic(17)).foregroundStyle(Theme.jmu2).padding(.top, 14)
                    }
                    ForEach(ents, id: \.i) { e in
                        VStack(alignment: .leading, spacing: 6) {
                            if let d = e.d, let t = e.t {
                                Text("\(d == Fmt.dowl[Rules.weekday(Now.date)] ? "Today" : d), \(t)").font(Theme.jitalic(13)).foregroundStyle(Theme.jmu2)
                            }
                            Text(e.x).font(Theme.jserif(17)).lineSpacing(7).foregroundStyle(Theme.jtx)
                        }
                        .fullWidth().padding(.vertical, 16)
                        .contentShape(Rectangle())
                        .onTapGesture { router.cover = .weekPage(w.id) }
                        .onLongPressGesture(minimumDuration: 0.5) { Haptic.tick(); router.entryMenu = e.i }
                        Rectangle().fill(Theme.jrule).frame(height: 1)
                    }
                }
                if !past.isEmpty { Eyebrow(text: "Earlier weeks", color: Theme.jmu2).padding(.top, 28) }
                ForEach(past) { w in
                    Button { router.cover = .weekPage(w.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(w.focus).font(Theme.jserif(19)).foregroundStyle(Theme.jtx)
                                Spacer()
                                Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.jmu2)
                            }
                            let first = w.summary ?? Journal.blocks(w.reflection.isEmpty ? w.liveRefl : w.reflection).first?.x
                            if let first { Text(first).font(Theme.jserif(15)).lineSpacing(4).foregroundStyle(Theme.jmu).lineLimit(2).multilineTextAlignment(.leading) }
                        }
                        .fullWidth().padding(.vertical, 14).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(Theme.jrule).frame(height: 1)
                }
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 56)
        }
        .scrollIndicators(.hidden)
        .background(Theme.jbg)
    }
}
