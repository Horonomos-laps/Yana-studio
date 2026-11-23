import Foundation

// Whether the icon rail is on screen. Settings has its own list of sections on the left, so the rail steps aside
// there and the page gets that room; a "Back" button at the top of the Settings list returns to the page the person
// came from. Every other page keeps the rail, so there is always a way to move around.

enum LeftSide {
	static let pageWithoutRail = "Settings"

	static func railVisible(page: String) -> Bool { page != pageWithoutRail }
}
