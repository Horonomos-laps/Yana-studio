import Foundation

// Whether the icon rail is on screen. The sidebar button hides the whole left side: the rail goes with the chat
// list, and the chat page gets the full window. Other pages always keep the rail, so there is always a way to move
// around. The window buttons sit inside the rail's glass panel, so they follow it: with no rail they go back to
// macOS's own place (TrafficLights.swift reads `railShown`).

enum LeftSide {
	static let hiddenKey = "yana.ui.railHidden"
	static let shownKey = "yana.ui.railShown"

	// The rail is hidden only while the person asked for it and is on the chat page.
	static func railVisible(hidden: Bool, page: String) -> Bool { !(hidden && page == "Chat") }

	// Tells the window-button placer, through UserDefaults, which already wakes it when anything changes.
	static func publish(hidden: Bool, page: String, defaults: UserDefaults = .standard) {
		defaults.set(railVisible(hidden: hidden, page: page), forKey: shownKey)
	}

	static func railShown(_ defaults: UserDefaults = .standard) -> Bool {
		defaults.object(forKey: shownKey) as? Bool ?? true
	}
}
