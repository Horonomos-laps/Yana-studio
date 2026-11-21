import SwiftUI

// The far-left rail: the Yana mark, the pages in two groups, then the update notice and Settings. Each page is an
// icon with its name under it, so the rail can be read at a glance. The Chat entry shows a live dot while the AI is
// working, so it is visible from any page.

enum RailMetrics {
	// The window's close, minimize and zoom buttons are drawn by macOS at 9 to 69 pt from the left edge, so the rail
	// has to be wider than that with room to spare, or the green one hangs over the edge (RailTests measures it).
	static let width: CGFloat = 80
	// Space above the first item, below the buttons.
	static let topInset: CGFloat = 52
	static let itemWidth: CGFloat = 62
	static let itemHeight: CGFloat = 50
	// How many of the first pages form the main group; the others follow after a divider.
	static let mainGroupSize = 4

	static func groups(_ entries: [RailEntry]) -> [[RailEntry]] {
		[Array(entries.prefix(mainGroupSize)), Array(entries.dropFirst(mainGroupSize))].filter { !$0.isEmpty }
	}
}

// One page in the rail.
struct RailItem: View {
	let icon: String
	let label: String
	let selected: Bool
	// A live dot on the icon: the AI is working on this page.
	var busy = false
	// A red dot on the icon: something here needs a look.
	var alert = false
	@State private var hover = false

	var body: some View {
		VStack(spacing: 4) {
			ZStack(alignment: .topTrailing) {
				FBIcon(name: icon, size: 20, color: selected ? FB.primaryText : FB.textSecondary)
				if busy { RailBusyDot().offset(x: 5, y: -3) }
				if alert { Circle().fill(FB.error).frame(width: 8, height: 8).offset(x: 5, y: -3) }
			}
			.frame(height: 22)
			Text(label)
				.font(.system(size: 10.5, weight: selected ? .semibold : .medium))
				.foregroundStyle(selected ? FB.primaryText : FB.textSecondary)
				.multilineTextAlignment(.center)
				.lineLimit(2)
				.minimumScaleFactor(0.85)
		}
		.frame(width: RailMetrics.itemWidth, height: RailMetrics.itemHeight)
		.background(RoundedRectangle(cornerRadius: 12).fill(selected ? FB.canvas : hover ? FB.hoverOnChrome : .clear))
		.overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? FB.primaryBorder : .clear, lineWidth: 1))
		.overlay(alignment: .leading) {
			// A short bar on the left edge marks the page that is open.
			RoundedRectangle(cornerRadius: 1.5).fill(FB.primary).frame(width: 3, height: 22)
				.offset(x: -5).opacity(selected ? 1 : 0)
		}
		.shadow(color: selected ? FB.shadow : .clear, radius: 6, y: 2)
		.contentShape(Rectangle())
		.help(label)
		.onHover { hover = $0 }
		.animation(FB.fast, value: hover)
		.animation(FB.fast, value: selected)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(label))
		.accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
	}
}

// A small green dot that breathes.
struct RailBusyDot: View {
	@State private var pulse = false

	var body: some View {
		ZStack {
			Circle().fill(FB.success.opacity(pulse ? 0 : 0.45)).frame(width: 12, height: 12).scaleEffect(pulse ? 1.5 : 0.8)
			Circle().fill(FB.success).frame(width: 8, height: 8)
		}
		.onAppear { withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true } }
	}
}

struct IconRail: View {
	@Binding var selected: String
	@EnvironmentObject private var runtime: RuntimeUpdater
	@EnvironmentObject private var terminals: TerminalStore
	@EnvironmentObject private var appUpdater: AppUpdater
	@EnvironmentObject private var engine: ChatEngine
	@State private var showUpdate = false

	var body: some View {
		VStack(spacing: 4) {
			RabbitLogo(cell: 1.4).padding(.bottom, 8).help("Yana")
			ForEach(Array(RailMetrics.groups(railEntries).enumerated()), id: \.offset) { index, group in
				if index > 0 { FB.divider.frame(width: 40, height: 1).padding(.vertical, 6) }
				ForEach(group) { entry in
					RailItem(icon: entry.icon, label: L("nav.\(entry.id)"), selected: selected == entry.id,
					         busy: entry.id == "Chat" && engine.running)
						.onTapGesture { selected = entry.id }
				}
			}
			Spacer(minLength: 0)
			// A newer Yana app on GitHub Releases, kept reachable after "Remind me later".
			if appUpdater.available != nil && !appUpdater.showSheet {
				UpdatePill { appUpdater.showSheet = true }.padding(.bottom, 4)
			}
			// Install/update notice, folded into one button (red dot) instead of a banner over the content.
			if runtime.showsBanner {
				RailItem(icon: "download", label: L("rt.updateButton"), selected: showUpdate, alert: true)
					.onTapGesture { showUpdate.toggle() }
					.popover(isPresented: $showUpdate, arrowEdge: .trailing) {
						// Install runs in the app's own terminal panel; the app keeps working meanwhile.
						RuntimeBanner(updater: runtime) {
							runtime.install(in: terminals, folder: engine.workspace)
							selected = "Chat" // the terminal panel lives on the chat page
							showUpdate = false
						}
						.frame(width: 520).padding(10)
					}
			}
			FB.divider.frame(width: 40, height: 1).padding(.vertical, 6)
			RailItem(icon: "settings", label: L("nav.Settings"), selected: selected == "Settings")
				.onTapGesture { selected = "Settings" }
		}
		.padding(EdgeInsets(top: RailMetrics.topInset, leading: (RailMetrics.width - RailMetrics.itemWidth) / 2, bottom: 14,
		                    trailing: (RailMetrics.width - RailMetrics.itemWidth) / 2))
		.frame(width: RailMetrics.width)
		.frame(maxHeight: .infinity)
		.background(SidebarBackground(color: railBackground))
	}
}
