import SwiftUI

// The drawing of one notch: a black shape that grows out of the camera housing. The closed shape is solid black so it
// merges with the housing. Everything inside is placeholder in phase 1; phase 2 puts Yana's activity here.

struct NotchView: View {
	@ObservedObject var model: NotchModel
	var onSettings: () -> Void = {}
	@AppStorage(NotchPrefs.solidKey) private var solid = false
	@ObservedObject private var activity = YanaActivity.shared

	var body: some View {
		let look = model.look
		let size = model.geometry.size(look)
		let radii = model.geometry.radii(look)
		let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

		ZStack(alignment: .top) {
			// Closed it is solid black so it merges with the camera housing; open it is frosted glass you can see through.
			if model.isOpen && !solid {
				NotchGlass(shape: shape).transition(.opacity)
			} else {
				Color.black
			}
			if !model.isOpen, activity.run.isActive {
				ActivityWings(model: model, run: activity.run, glance: look == .glance)
					.frame(width: size.width, height: size.height, alignment: .top)
					.transition(.opacity)
			}
			if model.isOpen {
				OpenPanel(model: model, onSettings: onSettings)
					.frame(width: size.width, height: size.height, alignment: .top)
					.transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .top)))
			}
		}
		.frame(width: size.width + 2 * radii.top, height: size.height)
		.clipShape(shape)
		.shadow(color: .black.opacity(model.isOpen ? 0.5 : 0), radius: 14, y: 6)
		.contentShape(shape)
		.onTapGesture { model.open() }
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.accessibilityElement(children: .contain)
		.accessibilityLabel(Text("Yana"))
	}
}

private struct OpenPanel: View {
	@ObservedObject var model: NotchModel
	let onSettings: () -> Void

	var body: some View {
		let notch = model.geometry.closedSize
		VStack(spacing: 8) {
			// The top row sits beside the camera housing: tabs on the left, buttons on the right.
			HStack(spacing: 0) {
				HStack(spacing: 7) { ForEach(NotchTab.allCases, id: \.self) { dot($0) } }
				Spacer(minLength: model.geometry.hasNotch ? notch.width + 20 : 40)
				HStack(spacing: 14) {
					Button(action: onSettings) { Image(systemName: "gearshape") }.buttonStyle(.plain)
					Button(action: model.close) { Image(systemName: "chevron.up") }.buttonStyle(.plain)
				}
			}
			.font(.system(size: 13, weight: .semibold))
			.foregroundStyle(.secondary)
			.frame(height: max(notch.height, 28))

			Group {
				switch model.tab {
				case .yana:
					YanaCard()
				case .home:
					HStack(spacing: 8) {
						MusicCard(); TimerCard()
						TodoCard(typing: { model.typing = $0 }); NotesCard(typing: { model.typing = $0 })
					}
				case .clipboard:
					ClipboardTab()
				}
			}
			.frame(maxHeight: .infinity)
		}
		.padding(.horizontal, 22).padding(.bottom, 14)
	}

	// Three dots like a page control: the filled one is where you are; each one is a button.
	private func dot(_ value: NotchTab) -> some View {
		Button { withAnimation(.notchHover) { model.tab = value } } label: {
			Circle().fill(model.tab == value ? Color.primary : Color.primary.opacity(0.3)).frame(width: 8, height: 8)
		}
		.buttonStyle(.plain)
		.help(title(value))
	}

	private func title(_ tab: NotchTab) -> String {
		switch tab {
		case .yana: "Yana"
		case .home: L("notch.home")
		case .clipboard: L("notch.clipboard")
		}
	}
}

// The closed pill while Yana is busy: a status dot on the left wing, moving bars on the right wing, and under them a
// short line (the answer so far, or what is waiting for a yes or no) while it glances.
private struct ActivityWings: View {
	@ObservedObject var model: NotchModel
	let run: YanaRun
	let glance: Bool

	var body: some View {
		let notch = model.geometry.closedSize
		VStack(spacing: 0) {
			HStack(spacing: 0) {
				YanaMascot(state: run.state, width: 26).frame(width: NotchGeometry.wing)
				Spacer(minLength: notch.width)
				EqualizerBars(active: run.state == .working).frame(width: NotchGeometry.wing)
			}
			.frame(height: model.geometry.rowHeight)
			if glance {
				Text(run.state == .waiting ? (run.waitingFor ?? "") : run.reply)
					.font(.system(size: 10)).foregroundStyle(.white.opacity(0.8)).lineLimit(1).padding(.horizontal, 12)
			}
		}
	}
}

private struct EqualizerBars: View {
	let active: Bool
	var body: some View {
		TimelineView(.animation(minimumInterval: 0.12, paused: !active)) { context in
			let t = context.date.timeIntervalSinceReferenceDate
			HStack(spacing: 2) {
				ForEach(0 ..< 4, id: \.self) { i in
					Capsule().fill(Color.white.opacity(0.85))
						.frame(width: 2.5, height: active ? 5 + 9 * abs(sin(t * 6 + Double(i) * 1.3)) : 4)
				}
			}
		}
	}
}

// The open panel's background: real Liquid Glass on macOS 26 over a light-following frosted material, so the desktop
// shows through and the panel is bright in light mode and dark in dark mode. Text uses the primary color and follows.
// Older systems get the frosted material alone.
struct NotchGlass: View {
	let shape: NotchShape
	static let topOpacity = 0.97      // black at the top, where it joins the camera housing
	static let bottomOpacity = 0.45   // and clearer going down, so the desktop shows through the lower part

	var body: some View {
		// Dark see-through glass, drawn here because the system's blur and glass effect do not work in this borderless
		// panel: black at the top fading to a lighter tint at the bottom, with a faint rim that brightens downward.
		ZStack {
			shape.fill(LinearGradient(colors: [Color.black.opacity(Self.topOpacity), Color.black.opacity(Self.bottomOpacity)],
			                          startPoint: .top, endPoint: .bottom))
			shape.stroke(LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.35)], startPoint: .top, endPoint: .bottom),
			             lineWidth: 1.5)
		}
	}
}

// Frosted material that shows the desktop behind the window, blurred.
struct NotchFrost: NSViewRepresentable {
	func makeNSView(context: Context) -> NSVisualEffectView {
		let view = NSVisualEffectView()
		view.material = .popover
		view.blendingMode = .behindWindow
		view.state = .active
		return view
	}

	func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
