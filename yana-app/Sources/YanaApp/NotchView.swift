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
				OpenPanel(onSettings: onSettings, close: model.close)
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
	let onSettings: () -> Void
	let close: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Yana").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
				Spacer()
				Button(action: onSettings) { Image(systemName: "gearshape") }.buttonStyle(.plain)
				Button(action: close) { Image(systemName: "chevron.up") }.buttonStyle(.plain)
			}
			.foregroundStyle(.white.opacity(0.7))
			Spacer(minLength: 0)
			Text(L("notch.idle")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 14)
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
