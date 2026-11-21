import AppKit
import XCTest
@testable import YanaApp

final class TrafficLightsLayoutTests: XCTestCase {
	func testTheThreeButtonsFitInsideTheRoundedRailPanelWithAMargin() {
		XCTAssertTrue(TrafficLights.fitsInPanel(margin: 4))
	}

	// The reported problem: at macOS's own place the red button's corner is outside the panel's curved corner.
	func testMacOSDefaultPlaceDoesNotFit() {
		let defaultSpots = [9.0, 32.0, 55.0].map { CGPoint(x: $0, y: 9) }
		let outside = defaultSpots.contains { !TrafficLights.inside(CGPoint(x: $0.x - 4, y: $0.y - 4), of: TrafficLights.panel, radius: LiquidGlass.panelRadius) }
		XCTAssertTrue(outside, "if the default place fitted, moving the buttons would not be needed")
	}

	func testTheButtonsAreEvenlySpacedAndSitInARow() {
		let spots = (0 ..< 3).map(TrafficLights.origin)
		XCTAssertEqual(spots[1].x - spots[0].x, spots[2].x - spots[1].x)
		XCTAssertTrue(spots.allSatisfy { $0.y == spots[0].y })
		XCTAssertGreaterThan(TrafficLights.step, TrafficLights.size, "the buttons must not touch")
	}

	func testTheSpaceLeftAndRightOfTheRowIsAboutEqual() {
		let panel = TrafficLights.panel
		let left = TrafficLights.origin(0).x - panel.minX
		let right = panel.maxX - (TrafficLights.origin(2).x + TrafficLights.size)
		XCTAssertLessThan(abs(left - right), 6)
	}

	func testTheRowEndsAboveWhereTheRailItemsStart() {
		XCTAssertLessThanOrEqual(TrafficLights.top + TrafficLights.size + 8, RailMetrics.topInset)
	}

	func testInsideKnowsTheRoundedCorner() {
		let r = CGRect(x: 0, y: 0, width: 100, height: 100)
		XCTAssertTrue(TrafficLights.inside(CGPoint(x: 50, y: 50), of: r, radius: 24))
		XCTAssertFalse(TrafficLights.inside(CGPoint(x: 1, y: 1), of: r, radius: 24), "the very corner is cut off")
		XCTAssertTrue(TrafficLights.inside(CGPoint(x: 24, y: 1), of: r, radius: 24))
		XCTAssertFalse(TrafficLights.inside(CGPoint(x: -1, y: 50), of: r, radius: 24))
	}
}

@MainActor
final class TrafficLightsPlacerTests: XCTestCase {
	private func makeWindow() -> NSWindow {
		NSApplication.shared.setActivationPolicy(.accessory)
		let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 900, height: 600),
		                      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
		                      backing: .buffered, defer: false)
		window.isReleasedWhenClosed = false
		window.titlebarAppearsTransparent = true
		window.titleVisibility = .hidden
		window.makeKeyAndOrderFront(nil)
		RunLoop.current.run(until: Date().addingTimeInterval(0.4))
		return window
	}

	// Each button's top-left corner measured from the window's top-left corner.
	private func spots(_ window: NSWindow) -> [CGPoint] {
		guard let content = window.contentView else { return [] }
		return [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { kind in
			guard let b = window.standardWindowButton(kind) else { return nil }
			let r = b.convert(b.bounds, to: content)
			return CGPoint(x: r.minX, y: content.bounds.height - r.maxY)
		}
	}

	func testTheButtonsMoveToTheGlassLayoutAndBackToMacOSs() throws {
		let window = makeWindow()
		defer { window.orderOut(nil) }
		let before = spots(window)
		try XCTSkipIf(before.count != 3, "no window buttons in this session")
		TrafficLightsPlacer.apply(to: window, custom: true)
		let moved = spots(window)
		for (i, spot) in moved.enumerated() {
			XCTAssertEqual(spot.x, TrafficLights.origin(i).x, accuracy: 1, "button \(i) x")
			XCTAssertEqual(spot.y, TrafficLights.origin(i).y, accuracy: 1, "button \(i) y")
		}
		TrafficLightsPlacer.apply(to: window, custom: false)
		for (a, b) in zip(spots(window), before) {
			XCTAssertEqual(a.x, b.x, accuracy: 1)
			XCTAssertEqual(a.y, b.y, accuracy: 1)
		}
	}

	func testPlacingTwiceGivesTheSamePlaces() throws {
		let window = makeWindow()
		defer { window.orderOut(nil) }
		try XCTSkipIf(spots(window).count != 3, "no window buttons in this session")
		TrafficLightsPlacer.apply(to: window, custom: true)
		let once = spots(window)
		TrafficLightsPlacer.apply(to: window, custom: true)
		XCTAssertEqual(spots(window), once)
	}
}
