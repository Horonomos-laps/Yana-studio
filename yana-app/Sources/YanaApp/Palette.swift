import SwiftUI
import AppKit

// Every color that changes between the light and the dark look, as a pair of hex values. A pair becomes a color
// that follows the window's appearance by itself (NSColor's dynamic provider), so a screen written with the FB
// tokens needs nothing extra to turn dark. The pairs are kept as plain numbers so the tests can measure their
// contrast (PaletteTests).

struct TokenPair: Equatable {
	let light: UInt32
	let dark: UInt32
	init(_ light: UInt32, _ dark: UInt32) { self.light = light; self.dark = dark }

	func hex(dark isDark: Bool) -> UInt32 { isDark ? dark : light }

	var nsColor: NSColor {
		let pair = self
		return NSColor(name: nil) { appearance in
			let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
			return NSColor.srgb(pair.hex(dark: isDark))
		}
	}

	var color: Color { Color(nsColor: nsColor) }
}

extension NSColor {
	static func srgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
		NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
		        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
	}
}

enum FBPair {
	// Blue (the solid primary stays the same in both looks)
	static let primarySubtle = TokenPair(0xE6F4FF, 0x12294D)
	static let primarySubtleHover = TokenPair(0xBAE0FF, 0x1B3B6E)
	static let primaryBorder = TokenPair(0x91CAFF, 0x2F5FA8)
	static let primaryText = TokenPair(0x0958D9, 0x69B1FF)

	// Surfaces and lines
	static let background = TokenPair(0xF5F5F5, 0x1E1F22)
	static let surface = TokenPair(0xFFFFFF, 0x17181A)
	static let surfaceSecondary = TokenPair(0xFAFAFA, 0x1F2023)
	static let surfaceTertiary = TokenPair(0xF0F0F0, 0x2A2B2F)
	static let border = TokenPair(0xD9D9D9, 0x3A3B40)
	static let borderSubtle = TokenPair(0xF0F0F0, 0x2A2B2F)
	static let borderStrong = TokenPair(0xBFBFBF, 0x55565C)
	static let ghostHover = TokenPair(0xF5F5F5, 0x25262A)

	// Text
	static let text = TokenPair(0x141414, 0xECECEE)
	static let textSecondary = TokenPair(0x595959, 0xA8A9AF)
	static let textTertiary = TokenPair(0x555555, 0x9A9BA2)
	static let textDisabled = TokenPair(0xBFBFBF, 0x5C5D63)

	// Status (the darker or lighter text variants, and the pale fills behind them)
	static let successText = TokenPair(0x237804, 0x73D13D)
	static let successSubtle = TokenPair(0xF6FFED, 0x162312)
	static let successBorder = TokenPair(0xB7EB8F, 0x274916)
	static let warningText = TokenPair(0x9A5C00, 0xFFC53D)
	static let warningSubtle = TokenPair(0xFFFBE6, 0x2B2111)
	static let warningBorder = TokenPair(0xFFE58F, 0x594214)
	static let errorText = TokenPair(0xCF1322, 0xFF7875)
	static let errorSubtle = TokenPair(0xFFF2F0, 0x2A1215)
	static let errorBorder = TokenPair(0xFFCCC7, 0x58181C)

	// The icon rail, the layer under glass, and the window backdrop. Pure white in the light look.
	static let rail = TokenPair(0xFFFFFF, 0x1B1C1F)
	static let glassBacking = TokenPair(0xFFFFFF, 0x1E1F22)
	static let backdropTop = TokenPair(0xFFFFFF, 0x17181B)
	static let backdropMiddle = TokenPair(0xFFFFFF, 0x141416)
	static let backdropBottom = TokenPair(0xFFFFFF, 0x111113)

	// Pairs whose text color must read on a fill, for the contrast tests: (name, text, fill).
	static let readable: [(String, TokenPair, TokenPair)] = [
		("text on surface", text, surface), ("text on background", text, background),
		("text on secondary", text, surfaceSecondary), ("text on tertiary", text, surfaceTertiary),
		("secondary text on surface", textSecondary, surface), ("secondary text on background", textSecondary, background),
		("secondary text on tertiary", textSecondary, surfaceTertiary),
		("tertiary text on surface", textTertiary, surface), ("tertiary text on background", textTertiary, background),
		("blue text on surface", primaryText, surface), ("blue text on pale blue", primaryText, primarySubtle),
		("success on pale green", successText, successSubtle), ("warning on pale yellow", warningText, warningSubtle),
		("error on pale red", errorText, errorSubtle), ("error on surface", errorText, surface),
		("success on surface", successText, surface), ("warning on surface", warningText, surface),
	]

	// WCAG relative luminance and contrast ratio of two sRGB hex values.
	static func luminance(_ hex: UInt32) -> Double {
		func channel(_ shift: UInt32) -> Double {
			let c = Double((hex >> shift) & 0xFF) / 255
			return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
		}
		return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
	}

	static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
		let la = luminance(a), lb = luminance(b)
		return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
	}
}

// Which look the window has: follow macOS, or one of the two. Light stays the default.
enum Appearance: String, CaseIterable, Identifiable {
	case system, light, dark
	var id: String { rawValue }

	var nsAppearance: NSAppearance? {
		switch self {
		case .system: return nil
		case .light: return NSAppearance(named: .aqua)
		case .dark: return NSAppearance(named: .darkAqua)
		}
	}

	var colorScheme: ColorScheme? {
		switch self {
		case .system: return nil
		case .light: return .light
		case .dark: return .dark
		}
	}

	// YANA_APPEARANCE=dark|light|system shows a look at launch without saving it (used to check the screens).
	static var launchOverride: Appearance? {
		ProcessInfo.processInfo.environment["YANA_APPEARANCE"].flatMap(Appearance.init(rawValue:))
	}

	static func resolved(_ setting: Appearance) -> Appearance { launchOverride ?? setting }

	@MainActor
	static func apply(_ setting: Appearance) {
		NSApplication.shared.appearance = resolved(setting).nsAppearance
	}

	// Whether the app is drawing dark right now (for AppKit views that do not follow SwiftUI's color scheme).
	@MainActor
	static var isDarkNow: Bool {
		NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
	}
}
