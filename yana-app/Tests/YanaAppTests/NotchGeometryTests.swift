import XCTest
@testable import YanaApp

final class NotchGeometryTests: XCTestCase {
	private let withNotch = NotchGeometry(notch: CGSize(width: 190, height: 38))
	private let plain = NotchGeometry(notch: nil)
	private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

	func testTheNotchIsMeasuredFromTheSafeAreaAndTheTwoSidesAndAbsentWithoutThem() {
		let size = NotchGeometry.notch(topInset: 38, screenWidth: 1728, leftAreaWidth: 769, rightAreaWidth: 769)
		XCTAssertEqual(size, CGSize(width: 190, height: 38))
		XCTAssertNil(NotchGeometry.notch(topInset: 0, screenWidth: 1728, leftAreaWidth: 769, rightAreaWidth: 769))
		XCTAssertNil(NotchGeometry.notch(topInset: 38, screenWidth: 1728, leftAreaWidth: nil, rightAreaWidth: 769))
		XCTAssertNil(NotchGeometry.notch(topInset: 38, screenWidth: 1728, leftAreaWidth: 900, rightAreaWidth: 900), "no negative width")
	}

	func testTheClosedShapeIsExactlyTheHousingAndWithoutOneASmallHandle() {
		XCTAssertEqual(withNotch.size(.closed), CGSize(width: 190, height: 38))
		XCTAssertEqual(plain.size(.closed), NotchGeometry.handleSize)
		XCTAssertEqual(plain.radii(.closed).top, 3); XCTAssertEqual(withNotch.radii(.closed).top, 6)
	}

	func testEachLookGrowsFromTheOneBefore() {
		let closed = withNotch.size(.closed), hover = withNotch.size(.hover), act = withNotch.size(.activity)
		let glance = withNotch.size(.glance), open = withNotch.size(.open)
		XCTAssertEqual(hover, CGSize(width: closed.width + 16, height: closed.height + 4))
		XCTAssertEqual(act.width, closed.width + 92); XCTAssertEqual(act.height, 38)
		XCTAssertEqual(withNotch.size(.activityHover).width, act.width + 8)
		XCTAssertEqual(glance.width, act.width + 70); XCTAssertEqual(glance.height, act.height + 26)
		XCTAssertGreaterThan(open.width, glance.width); XCTAssertGreaterThan(open.height, glance.height)
	}

	func testAnActivityRowIsNeverShorterThanThirtyPoints() {
		XCTAssertEqual(plain.size(.activity).height, 30)
		XCTAssertEqual(withNotch.size(.activity).height, 38)
	}

	func testRadiiOnlyGrowAsTheShapeOpens() {
		let order: [NotchLook] = [.closed, .hover, .glance, .open]
		for pair in zip(order, order.dropFirst()) {
			XCTAssertLessThanOrEqual(withNotch.radii(pair.0).bottom, withNotch.radii(pair.1).bottom)
		}
		XCTAssertEqual(withNotch.shapeWidth(.open), NotchGeometry.openSize.width + 28)
	}

	func testTheHitRectangleIsPaddedMoreWhenClosedAndSitsAtTheTopCenter() {
		let closed = withNotch.hitRect(.closed, screenFrame: screen)
		XCTAssertEqual(closed.midX, screen.midX, accuracy: 0.01)
		XCTAssertEqual(closed.maxY, screen.maxY + 1, accuracy: 0.01, "reaches the very top edge")
		XCTAssertEqual(closed.width, 190 + 20)
		XCTAssertEqual(withNotch.hitRect(.open, screenFrame: screen).width, NotchGeometry.openSize.width + 8)
		XCTAssertTrue(closed.contains(CGPoint(x: screen.midX, y: screen.maxY - 5)))
		XCTAssertFalse(closed.contains(CGPoint(x: screen.midX + 300, y: screen.maxY - 5)), "beside it clicks pass through")
	}

	func testTheWindowIsTheFullWidthOfTheScreenPinnedToItsTop() {
		let frame = NotchGeometry.windowFrame(screenFrame: screen)
		XCTAssertEqual(frame.width, screen.width); XCTAssertEqual(frame.maxY, screen.maxY)
		XCTAssertEqual(frame.height, NotchGeometry.windowHeight)
		let second = CGRect(x: 1728, y: -200, width: 1920, height: 1080)
		XCTAssertEqual(NotchGeometry.windowFrame(screenFrame: second).minX, 1728, "a screen to the side keeps its own origin")
	}

	func testTheLookFollowsOpenThenActivityThenHover() {
		XCTAssertEqual(NotchGeometry.look(open: true, hovering: true, hasActivity: true, glancing: true), .open)
		XCTAssertEqual(NotchGeometry.look(open: false, hovering: true, hasActivity: true, glancing: true), .glance)
		XCTAssertEqual(NotchGeometry.look(open: false, hovering: true, hasActivity: true, glancing: false), .activityHover)
		XCTAssertEqual(NotchGeometry.look(open: false, hovering: false, hasActivity: true, glancing: false), .activity)
		XCTAssertEqual(NotchGeometry.look(open: false, hovering: true, hasActivity: false, glancing: false), .hover)
		XCTAssertEqual(NotchGeometry.look(open: false, hovering: false, hasActivity: false, glancing: false), .closed)
	}

	func testTheShapePathStaysInsideItsRectEvenWhenTheRadiiAreTooBig() {
		let rect = CGRect(x: 0, y: 0, width: 40, height: 10)
		let bounds = NotchShape(topRadius: 14, bottomRadius: 26).path(in: rect).boundingRect
		XCTAssertLessThanOrEqual(bounds.width, rect.width + 0.01); XCTAssertLessThanOrEqual(bounds.height, rect.height + 0.01)
		XCTAssertFalse(bounds.isNull)
	}

	func testTheNewStringsExistInAllLanguages() {
		XCTAssertEqual(notchRows.count, 29)
		for row in notchRows { XCTAssertFalse(row.vi.isEmpty); XCTAssertFalse(row.en.isEmpty); XCTAssertFalse(row.ko.isEmpty) }
	}

	func testHoverOpensAndGlassAreTheDefaults() {
		let d = UserDefaults.standard
		let h = d.object(forKey: NotchPrefs.hoverKey), s = d.object(forKey: NotchPrefs.solidKey)
		d.removeObject(forKey: NotchPrefs.hoverKey); d.removeObject(forKey: NotchPrefs.solidKey)
		defer { d.set(h, forKey: NotchPrefs.hoverKey); d.set(s, forKey: NotchPrefs.solidKey) }
		XCTAssertTrue(NotchPrefs.openOnHover, "resting on the notch opens it unless switched off")
		XCTAssertFalse(NotchPrefs.solid, "see-through unless switched to solid")
		d.set(false, forKey: NotchPrefs.hoverKey)
		XCTAssertFalse(NotchPrefs.openOnHover)
		XCTAssertLessThan(NotchController.openDelay, 0.5, "short enough to feel immediate")
		XCTAssertGreaterThan(NotchController.openDelay, NotchController.closeDelay, "a pass-over does not open it")
	}
}
