import AppKit
import SwiftUI

// Liquid Glass, the translucent material of macOS 26 and later. When it is on, the window sits on a soft colored
// backdrop, the icon rail and the chat list float over it as glass panels, and the composer and the open page in the
// rail are glass too. It switches itself off, and every surface falls back to the flat look it had before, when:
// the Mac is older than macOS 26, "Reduce transparency" is on in System Settings, the person turned it off in
// Settings > General, or the app is drawing an image (ImageRenderer cannot draw live materials).

enum LiquidGlass {
	static let enabledKey = "yana.ui.liquidGlass"
	static let minimumMajorVersion = 26

	// The decision, as a plain function so each case can be tested.
	static func isActive(enabled: Bool, osMajor: Int, reduceTransparency: Bool, rendering: Bool) -> Bool {
		enabled && osMajor >= minimumMajorVersion && !reduceTransparency && !rendering
	}

	static func enabledSetting(_ d: UserDefaults = .standard) -> Bool { d.object(forKey: enabledKey) as? Bool ?? true }

	static var active: Bool {
		isActive(enabled: enabledSetting(), osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
		         reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency, rendering: isRenderingForImage)
	}

	// Glass takes its color from what lies behind it, which is how it picked up a yellow cast (the wallpaper, the
	// display). A pure white layer under every glass surface at this strength keeps the whites white.
	static let whiteBacking = 0.75
	// Space between a floating panel and the window edge.
	static let panelInset: CGFloat = 8
	static let panelRadius: CGFloat = 24
}

// A glass surface in any shape, with a flat fallback of the same shape.
struct YanaGlass<S: Shape>: ViewModifier {
	let shape: S
	var tint: Color? = nil
	var interactive = false
	// Re-read when the person flips the switch in Settings.
	@AppStorage(LiquidGlass.enabledKey) private var enabled = true

	func body(content: Content) -> some View {
		if LiquidGlass.active, #available(macOS 26.0, *) {
			content
				.glassEffect(style, in: shape)
				.background { shape.fill(FBPair.glassBacking.color.opacity(LiquidGlass.whiteBacking)) }
		} else {
			content
				.background(shape.fill(FB.canvas))
				.overlay(shape.stroke(FB.divider, lineWidth: 1))
				.shadow(color: FB.shadow, radius: 14, y: 4)
		}
	}

	@available(macOS 26.0, *)
	private var style: Glass {
		var glass = Glass.regular
		if let tint { glass = glass.tint(tint) }
		return interactive ? glass.interactive() : glass
	}
}

// A column on the right (terminal, browser, tools): the same floating glass panel as the rail and the chat list,
// the same radius and the same distance from the window edge. Flat and untouched when Liquid Glass is off.
struct FloatingPanel: ViewModifier {
	@AppStorage(LiquidGlass.enabledKey) private var enabled = true

	func body(content: Content) -> some View {
		if LiquidGlass.active, #available(macOS 26.0, *) {
			let shape = RoundedRectangle(cornerRadius: LiquidGlass.panelRadius, style: .continuous)
			content
				.clipShape(shape)
				.background {
					ZStack {
						shape.fill(FBPair.glassBacking.color.opacity(LiquidGlass.whiteBacking))
						Color.clear.glassEffect(.regular, in: shape)
					}
				}
				.padding(EdgeInsets(top: LiquidGlass.panelInset, leading: 2, bottom: LiquidGlass.panelInset, trailing: LiquidGlass.panelInset))
		} else {
			content
		}
	}
}

extension View {
	func floatingPanel() -> some View { modifier(FloatingPanel()) }

	func yanaGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
		modifier(YanaGlass(shape: shape, tint: tint, interactive: interactive))
	}

	// The background of a side column: a floating glass panel when Liquid Glass is on, otherwise the flat column.
	func sidePanelBackground(color: Color, leadingInset: CGFloat = LiquidGlass.panelInset) -> some View {
		modifier(SidePanelBackground(color: color, leadingInset: leadingInset))
	}
}

struct SidePanelBackground: ViewModifier {
	let color: Color
	let leadingInset: CGFloat
	@AppStorage(LiquidGlass.enabledKey) private var enabled = true

	func body(content: Content) -> some View {
		if LiquidGlass.active, #available(macOS 26.0, *) {
			content.background {
				Color.clear.overlay {
					ZStack {
						RoundedRectangle(cornerRadius: LiquidGlass.panelRadius, style: .continuous)
							.fill(FBPair.glassBacking.color.opacity(LiquidGlass.whiteBacking))
						RoundedRectangle(cornerRadius: LiquidGlass.panelRadius, style: .continuous)
							.fill(Color.clear)
							.glassEffect(.regular, in: RoundedRectangle(cornerRadius: LiquidGlass.panelRadius, style: .continuous))
					}
						.padding(EdgeInsets(top: LiquidGlass.panelInset, leading: leadingInset, bottom: LiquidGlass.panelInset, trailing: 2))
				}
			}
		} else {
			content.background(SidebarBackground(color: color))
		}
	}
}

// The colors behind the glass. Glass needs something to refract: on plain white it would look like a gray box.
struct GlassBackdrop: View {
	@AppStorage(LiquidGlass.enabledKey) private var enabled = true
	@Environment(\.colorScheme) private var scheme

	// Strength of each soft glow: barely there on white, a little more on dark so the glass has something to catch.
	private func strength(_ light: Double, _ dark: Double) -> Double { scheme == .dark ? dark : light }

	private func glow(_ color: Color, center: UnitPoint, radius: CGFloat) -> some View {
		RadialGradient(colors: [color, color.opacity(0)], center: center, startRadius: 0, endRadius: radius)
	}

	var body: some View {
		if LiquidGlass.active {
			ZStack {
				// Pure white in the light look (dark gray in the dark one), so the glass reads as clear and frosted.
				LinearGradient(colors: [FBPair.backdropTop.color, FBPair.backdropMiddle.color, FBPair.backdropBottom.color],
				               startPoint: .topLeading, endPoint: .bottomTrailing)
				// Radial gradients that fade to clear, so the soft glow needs no blur filter (which some renderers skip).
				glow(FB.primary.opacity(strength(0.025, 0.12)), center: .topLeading, radius: 620)
				glow(Color(hex: 0xB58CFF).opacity(strength(0.02, 0.10)), center: .bottomTrailing, radius: 680)
				glow(Color(hex: 0x5BD6E8).opacity(strength(0.015, 0.08)), center: UnitPoint(x: 0.55, y: 0), radius: 520)
			}
			.ignoresSafeArea()
		} else {
			FB.canvas
		}
	}
}
