import SwiftUI

// The drawing of one notch: a black shape that grows out of the camera housing. The closed shape is solid black so it
// merges with the housing. Everything inside is placeholder in phase 1; phase 2 puts Yana's activity here.

struct NotchView: View {
	@ObservedObject var model: NotchModel
	var onSettings: () -> Void = {}
	@AppStorage(NotchPrefs.solidKey) private var solid = false

	var body: some View {
		let look = model.look
		let size = model.geometry.size(look)
		let radii = model.geometry.radii(look)
		let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

		ZStack(alignment: .top) {
			// Closed it is solid black so it merges with the camera housing; open it is frosted glass you can see through.
			if model.isOpen && !solid {
				NotchFrost().overlay(Color.black.opacity(0.28)).transition(.opacity)
			} else {
				Color.black
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
				HStack(spacing: 14) {
					tab("house", .home); tab("doc.on.clipboard", .clipboard)
				}
				Spacer(minLength: model.geometry.hasNotch ? notch.width + 20 : 40)
				HStack(spacing: 14) {
					Button(action: onSettings) { Image(systemName: "gearshape") }.buttonStyle(.plain)
					Button(action: model.close) { Image(systemName: "chevron.up") }.buttonStyle(.plain)
				}
			}
			.font(.system(size: 13, weight: .semibold))
			.foregroundStyle(.white.opacity(0.75))
			.frame(height: max(notch.height, 28))

			Group {
				switch model.tab {
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

	private func tab(_ icon: String, _ value: NotchTab) -> some View {
		Button { withAnimation(.notchHover) { model.tab = value } } label: { Image(systemName: icon) }
			.buttonStyle(.plain).foregroundStyle(model.tab == value ? .white : .white.opacity(0.45))
	}
}

// Frosted material that shows the desktop behind the window, blurred.
struct NotchFrost: NSViewRepresentable {
	func makeNSView(context: Context) -> NSVisualEffectView {
		let view = NSVisualEffectView()
		view.material = .hudWindow
		view.blendingMode = .behindWindow
		view.state = .active
		return view
	}

	func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
