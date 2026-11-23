import AppKit
import XCTest
@testable import YanaApp

final class PaletteTests: XCTestCase {
	private static let minContrast = 4.5   // WCAG AA for normal text

	func testEveryTextAndFillPairReadsInBothLooks() {
		for (name, text, fill) in FBPair.readable {
			for dark in [false, true] {
				let ratio = FBPair.contrast(text.hex(dark: dark), fill.hex(dark: dark))
				XCTAssertGreaterThanOrEqual(ratio, Self.minContrast, "\(name) in \(dark ? "dark" : "light"): \(ratio)")
			}
		}
	}

	func testTheLightLookKeepsItsOldValues() {
		XCTAssertEqual(FBPair.text.light, 0x141414)
		XCTAssertEqual(FBPair.surface.light, 0xFFFFFF)
		XCTAssertEqual(FBPair.background.light, 0xF5F5F5)
		XCTAssertEqual(FBPair.primaryText.light, 0x0958D9)
	}

	func testTheRailAndBackdropAreWhiteInTheLightLookAndDarkInTheDarkOne() {
		for pair in [FBPair.rail, FBPair.glassBacking, FBPair.backdropTop, FBPair.backdropMiddle, FBPair.backdropBottom] {
			XCTAssertEqual(pair.light, 0xFFFFFF)
			XCTAssertLessThan(FBPair.luminance(pair.dark), 0.02)
		}
	}

	func testDarkSurfacesAreDarkAndDarkTextIsLight() {
		XCTAssertLessThan(FBPair.luminance(FBPair.surface.dark), 0.02)
		XCTAssertGreaterThan(FBPair.luminance(FBPair.text.dark), 0.7)
	}

	// The color really follows the appearance it is drawn in.
	func testAPairResolvesToItsLightOrDarkValueByAppearance() throws {
		let pair = TokenPair(0x112233, 0xAABBCC)
		func resolved(_ name: NSAppearance.Name) throws -> UInt32 {
			let appearance = try XCTUnwrap(NSAppearance(named: name))
			var hex: UInt32 = 0
			appearance.performAsCurrentDrawingAppearance {
				let c = pair.nsColor.usingColorSpace(.sRGB)!
				hex = (UInt32((c.redComponent * 255).rounded()) << 16) | (UInt32((c.greenComponent * 255).rounded()) << 8)
					| UInt32((c.blueComponent * 255).rounded())
			}
			return hex
		}
		XCTAssertEqual(try resolved(.aqua), 0x112233)
		XCTAssertEqual(try resolved(.darkAqua), 0xAABBCC)
	}

	func testTheThreeLooksMapToAppearanceAndScheme() {
		XCTAssertNil(Appearance.system.nsAppearance); XCTAssertNil(Appearance.system.colorScheme)
		XCTAssertEqual(Appearance.light.colorScheme, .light); XCTAssertEqual(Appearance.dark.colorScheme, .dark)
		XCTAssertEqual(Appearance.light.nsAppearance?.name, .aqua); XCTAssertEqual(Appearance.dark.nsAppearance?.name, .darkAqua)
		XCTAssertEqual(Appearance.allCases.count, 3)
	}

	func testTheSettingNamesAreTranslated() {
		for key in ["set.appearance", "set.appearanceLight", "set.appearanceDark", "set.appearanceSystem"] {
			XCTAssertNotEqual(L(key), key, key)
		}
	}
}
