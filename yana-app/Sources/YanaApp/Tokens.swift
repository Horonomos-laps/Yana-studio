import SwiftUI

// Design tokens. Values follow the Fluent Blue light theme (MIT, github.com/danieldev23/fluent-blue), with Yana's
// primary blue #1470F0 (the lightest blue that keeps white text at 4.5:1). The colors that differ between the light
// and the dark look are pairs in Palette.swift; the rest (the solid primary and status colors) are the same in both.

extension Color {
	init(hex: UInt32, opacity: Double = 1) {
		self.init(.sRGB,
			red: Double((hex >> 16) & 0xFF) / 255,
			green: Double((hex >> 8) & 0xFF) / 255,
			blue: Double(hex & 0xFF) / 255,
			opacity: opacity)
	}
}

enum FB {
	// Blue
	static let primary = Color(hex: 0x1470F0)
	static let primaryHover = Color(hex: 0x0F62DC)
	static let primaryPressed = Color(hex: 0x0D54BA)
	static let primarySubtle = FBPair.primarySubtle.color
	static let primarySubtleHover = FBPair.primarySubtleHover.color
	static let primaryBorder = FBPair.primaryBorder.color
	static let primaryText = FBPair.primaryText.color
	static let ramp300 = Color(hex: 0x69B1FF)
	static let ramp700 = Color(hex: 0x003EB3)
	static let ramp100 = Color(hex: 0xBAE0FF)
	static let ramp500 = Color(hex: 0x1677FF)

	// Surfaces and lines
	static let background = FBPair.background.color
	static let surface = FBPair.surface.color
	static let surfaceSecondary = FBPair.surfaceSecondary.color
	static let surfaceTertiary = FBPair.surfaceTertiary.color
	static let border = FBPair.border.color
	static let borderSubtle = FBPair.borderSubtle.color
	static let borderStrong = FBPair.borderStrong.color
	static let ghostHover = FBPair.ghostHover.color

	// Text
	static let text = FBPair.text.color
	static let textSecondary = FBPair.textSecondary.color
	static let textTertiary = FBPair.textTertiary.color
	static let textDisabled = FBPair.textDisabled.color

	// Status. The *Text colors are the darker variants so small text stays readable.
	static let success = Color(hex: 0x52C41A)
	static let successText = FBPair.successText.color
	static let successSubtle = FBPair.successSubtle.color
	static let successBorder = FBPair.successBorder.color
	static let warning = Color(hex: 0xFAAD14)
	static let warningText = FBPair.warningText.color
	static let warningSubtle = FBPair.warningSubtle.color
	static let warningBorder = FBPair.warningBorder.color
	static let error = Color(hex: 0xD92D30)
	static let errorText = FBPair.errorText.color
	static let errorSubtle = FBPair.errorSubtle.color
	static let errorBorder = FBPair.errorBorder.color

	// Semantic roles (core/rules/color-rules.md: name the role, never a raw value). Every role points at a
	// Fluent Blue value above, so the app stays on one system; screens use these, not hex literals.
	static let chrome = background            // rails, sidebars, side panels
	static let canvas = surface               // the main reading area and cards on it
	static let divider = border               // 1 px lines between regions
	static let hoverOnChrome = surfaceTertiary
	static let hoverOnCanvas = ghostHover
	static let onPrimary = Color.white        // text and icons on primary fills (4.56:1 on #1470F0)
	static let shadow = primary.opacity(0.08) // brand-tinted, not grey (color-rules.md)

	// Shape
	static let radiusSM: CGFloat = 4
	static let radiusMD: CGFloat = 6
	static let radiusLG: CGFloat = 8
	static let radiusXL: CGFloat = 12

	// Control heights
	static let heightSmall: CGFloat = 28
	static let heightMedium: CGFloat = 34
	static let heightLarge: CGFloat = 40

	// Motion: short and meaningful (90 / 160 / 260 ms)
	static let fast = Animation.easeOut(duration: 0.09)
	static let normal = Animation.easeOut(duration: 0.16)
}

extension Font {
	static func fb(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
	static let fbHeading5 = Font.system(size: 16, weight: .semibold)
	static let fbBody = Font.system(size: 13, weight: .regular)
	static let fbBodyMedium = Font.system(size: 13, weight: .medium)
	// 12 pt minimum for visible text (typography-rules.md: nothing under 12 px).
	static let fbCaption = Font.system(size: 12, weight: .regular)
	static let fbButton = Font.system(size: 13, weight: .medium)
}

// The rail's gradient: paler than Fluent Blue's deep ends (anh asked for a lighter rail). The darkest stop
// is #0958D9 and the lightest #1470F0, so white text stays at 4.5:1 or better everywhere.
let fbRailGradient = LinearGradient(
	stops: [.init(color: FB.primaryText, location: 0), .init(color: FB.primary, location: 0.55), .init(color: FB.primaryText, location: 1)],
	startPoint: .topLeading, endPoint: UnitPoint(x: 0.4, y: 1))
