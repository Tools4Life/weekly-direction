import ActivityKit
import WidgetKit
import SwiftUI

/// The habit timer on the Lock Screen and in the Dynamic Island. Started and ended by the app; the countdown and the
/// bar run by themselves from the end time.
struct TimerLiveActivity: Widget {
    private let p = WPalette.of(light: false)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { ctx in
            // Lock Screen / banner
            let over = ctx.isStale || ctx.state.endsAt <= Date()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: ctx.attributes.symbol).font(.system(size: 13, weight: .light)).foregroundStyle(p.ac)
                    Text("TIMER · \(ctx.attributes.minutes) MIN").font(.custom("BarlowCondensed-Medium", size: 12)).tracking(2.4).foregroundStyle(p.ac)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(ctx.attributes.habit).font(.custom("Fraunces-Regular", size: 22)).foregroundStyle(p.tx).lineLimit(1)
                    Spacer(minLength: 8)
                    if over { Text("Done").font(.custom("Barlow-SemiBold", size: 26)).foregroundStyle(p.ac) }
                    else {
                        Text(timerInterval: ctx.state.startedAt...ctx.state.endsAt, countsDown: true)
                            .font(.custom("Barlow-SemiBold", size: 26)).monospacedDigit().foregroundStyle(p.tx)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 96, alignment: .trailing)
                    }
                }
                ProgressView(timerInterval: ctx.state.startedAt...ctx.state.endsAt, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear).tint(p.ac)
            }
            .padding(16)
            .activityBackgroundTint(p.bg)
            .activitySystemActionForegroundColor(p.tx)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: ctx.attributes.symbol).font(.system(size: 16, weight: .light)).foregroundStyle(p.ac)
                        Text(ctx.attributes.habit).font(.custom("BarlowCondensed-SemiBold", size: 16)).textCase(.uppercase).tracking(1.6)
                            .foregroundStyle(p.tx).lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: ctx.state.startedAt...ctx.state.endsAt, countsDown: true)
                        .font(.custom("Barlow-SemiBold", size: 24)).monospacedDigit().foregroundStyle(p.tx)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 84, alignment: .trailing).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(timerInterval: ctx.state.startedAt...ctx.state.endsAt, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .progressViewStyle(.linear).tint(p.ac)
                        Text("ENDS \(ctx.state.endsAt.formatted(date: .omitted, time: .shortened).uppercased())")
                            .font(.custom("BarlowCondensed-Medium", size: 12)).tracking(2).foregroundStyle(p.mu2)
                    }
                    .padding(.horizontal, 4).padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: ctx.attributes.symbol).font(.system(size: 14, weight: .regular)).foregroundStyle(p.ac)
            } compactTrailing: {
                Text(timerInterval: ctx.state.startedAt...ctx.state.endsAt, countsDown: true)
                    .font(.custom("Barlow-SemiBold", size: 14)).monospacedDigit().foregroundStyle(p.ac)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 46, alignment: .trailing)
            } minimal: {
                ProgressView(timerInterval: ctx.state.startedAt...ctx.state.endsAt, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular).tint(p.ac)
            }
            .widgetURL(Shared.weekURL)
            .keylineTint(p.ac)
        }
    }
}
