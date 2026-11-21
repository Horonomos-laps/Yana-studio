import XCTest
@testable import YanaApp

final class AccentTests: XCTestCase {
	func testEveryRailPageHasItsOwnColor() {
		let colors = railEntries.map { Accent.page($0.id) }
		XCTAssertEqual(Set(colors.map { "\($0)" }).count, colors.count, "two pages in the rail share a color")
	}

	func testNeighbouringPagesInTheRailNeverShareAColor() {
		let ids = railEntries.map(\.id) + ["Settings"]
		for (a, b) in zip(ids, ids.dropFirst()) { XCTAssertNotEqual(Accent.page(a), Accent.page(b), "\(a) next to \(b)") }
	}

	func testSettingsSectionsUseSeveralColorsAndNeighboursDiffer() {
		let sections = SettingsSection.allCases
		XCTAssertGreaterThanOrEqual(Set(sections.map { "\(Accent.section($0))" }).count, 7, "the list is nearly one color again")
		for (a, b) in zip(sections, sections.dropFirst()) {
			XCTAssertNotEqual(Accent.section(a), Accent.section(b), "\(a) next to \(b)")
		}
	}

	func testTheColorsAreDistinctFromEachOther() {
		// Compare the rendered RGB, so two cases cannot quietly share a hex value.
		let rgb = Accent.allCases.map { accent -> String in
			let c = NSColor(accent.color).usingColorSpace(.sRGB) ?? .black
			return String(format: "%.2f-%.2f-%.2f", c.redComponent, c.greenComponent, c.blueComponent)
		}
		XCTAssertEqual(Set(rgb).count, Accent.allCases.count)
	}

	func testAnUnknownPageFallsBackToBlue() {
		XCTAssertEqual(Accent.page("nope"), .blue)
	}
}
