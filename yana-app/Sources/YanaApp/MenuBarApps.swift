import SwiftUI

// The two apps in the menu bar panel: running or not, what each uses, and what it is doing.

struct MenuBarApps: View {
	@ObservedObject var monitor: AppsMonitor
	@ObservedObject private var activity = YanaActivity.shared
	@ObservedObject private var loc = Loc.shared
	let canOpenStudio: Bool
	let openStudio: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			card("Yana", .blue, monitor.yana, detail: yanaDetail)
			card("Yana Studio", .pink, monitor.studio, detail: studioDetail)
			if canOpenStudio { Button(L("bar.openStudio")) { openStudio() } }
		}
	}

	private var yanaDetail: String {
		let state: String = switch activity.run.state {
		case .idle: L("notch.stateIdle")
		case .working: L("notch.stateWorking")
		case .waiting: L("notch.stateWaiting")
		}
		return [state, activity.model].filter { !$0.isEmpty }.joined(separator: " · ")
	}

	private var studioDetail: String? {
		let sessions = monitor.studioSessions
		guard sessions.working + sessions.waiting > 0 else { return nil }
		return String(format: L("bar.sessions"), sessions.working, sessions.waiting)
	}

	private func card(_ name: String, _ color: Color, _ card: AppCard, detail: String?) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			HStack(spacing: 6) {
				Circle().fill(card.running ? Color.green : Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
				Text(name).fontWeight(.medium)
				if let version = card.version { Text(version).font(.caption).foregroundStyle(.secondary) }
				Spacer()
				if !card.running { Text(L("bar.notRunning")).foregroundStyle(.secondary) }
			}
			if card.running, let use = card.use {
				Text("CPU \(SystemStats.percent(use.cpu)) · RAM \(AppStats.size(use.bytes, locale: Locale(identifier: loc.lang.rawValue)))")
					.font(.caption).monospacedDigit().foregroundStyle(.secondary)
			}
			if card.running, let detail {
				Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(color.opacity(card.running ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
		.accessibilityElement(children: .combine)
	}
}
