import AppKit
import XCTest
@testable import YanaApp

final class RailTests: XCTestCase {
	func testPagesAreSplitIntoAMainGroupAndTheRest() {
		let groups = RailMetrics.groups(railEntries)
		XCTAssertEqual(groups.count, 2)
		XCTAssertEqual(groups[0].map(\.id), ["Chat", "Overview", "Tool approvals", "Tasks"])
		XCTAssertEqual(groups[1].map(\.id), ["Skills", "Plugins", "Health", "Usage"])
		XCTAssertEqual(groups.flatMap { $0 }.count, railEntries.count, "no page may be dropped")
	}

	func testGroupingHandlesShortAndEmptyLists() {
		XCTAssertTrue(RailMetrics.groups([]).isEmpty)
		let two = Array(railEntries.prefix(2))
		XCTAssertEqual(RailMetrics.groups(two).map { $0.count }, [2])
	}

	func testEveryPageHasAnIconAndAName() {
		for entry in railEntries {
			XCTAssertNotNil(FBIcons.markup[entry.icon], "no icon \(entry.icon)")
			XCTAssertNotEqual(L("nav.\(entry.id)"), "nav.\(entry.id)", "no name for \(entry.id)")
		}
	}

	// The reported bug: the green window button hung over the rail's edge. macOS draws the three buttons in a
	// fixed place, so this measures them on the machine running the test and checks the rail holds them with room.
	@MainActor
	func testTheWindowButtonsSitInsideTheRailWithRoomToSpare() throws {
		// Without a running application the buttons are not laid out (and closing the window crashes the test host),
		// so: become an accessory app, show the window, let it lay out, measure, and only hide it again.
		NSApplication.shared.setActivationPolicy(.accessory)
		let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 900, height: 600),
		                      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
		                      backing: .buffered, defer: false)
		window.isReleasedWhenClosed = false
		window.titlebarAppearsTransparent = true
		window.titleVisibility = .hidden
		window.makeKeyAndOrderFront(nil)
		RunLoop.current.run(until: Date().addingTimeInterval(0.4))
		defer { window.orderOut(nil) }
		guard let content = window.contentView,
		      let zoom = window.standardWindowButton(.zoomButton),
		      let close = window.standardWindowButton(.closeButton) else { throw XCTSkip("no window buttons in this session") }
		// Where the app puts the buttons (TrafficLightsPlacer), not macOS's own place.
		TrafficLightsPlacer.apply(to: window, custom: true)
		let right = zoom.convert(zoom.bounds, to: content).maxX
		let bottom = content.bounds.height - close.convert(close.bounds, to: content).minY
		XCTAssertGreaterThan(right, 40, "the buttons were not laid out")
		XCTAssertLessThanOrEqual(right + 6, RailMetrics.width, "the zoom button (\(right) pt) hangs over the rail (\(RailMetrics.width) pt)")
		XCTAssertLessThanOrEqual(bottom + 10, RailMetrics.topInset, "the first page starts under the buttons")
	}

	func testTheRailIsWideEnoughForItsItems() {
		XCTAssertGreaterThanOrEqual(RailMetrics.width - RailMetrics.itemWidth, 12, "items need a margin on both sides")
	}
}
