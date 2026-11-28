import AppKit

// Closing the window leaves Yana running behind its menu bar item, without a Dock icon. Quit (⌘Q, or "Quit Yana" in
// the panel) ends the app. The Dock icon stays when the person asks for it, and always when the menu bar item is off,
// because a running app with neither would be impossible to reach.

@MainActor
enum BackgroundMode {
	nonisolated static let menuBarKey = "yana.menubar.enabled"
	nonisolated static let keepDockKey = "yana.menubar.keepDock"

	nonisolated static func hidesDockIcon(menuBarOn: Bool, keepDockIcon: Bool) -> Bool {
		menuBarOn && !keepDockIcon
	}

	static var menuBarOn: Bool {
		UserDefaults.standard.object(forKey: menuBarKey) as? Bool ?? true
	}

	static func windowClosed() {
		let keep = UserDefaults.standard.bool(forKey: keepDockKey)
		if hidesDockIcon(menuBarOn: menuBarOn, keepDockIcon: keep) { NSApplication.shared.setActivationPolicy(.accessory) }
	}

	static func windowShown() {
		if NSApplication.shared.activationPolicy() != .regular { NSApplication.shared.setActivationPolicy(.regular) }
	}

	// A setting changed while no window is showing: bring the Dock icon back if it is now wanted.
	static func settingsChanged() {
		MenuBarController.shared.apply()
		let keep = UserDefaults.standard.bool(forKey: keepDockKey)
		if !hidesDockIcon(menuBarOn: menuBarOn, keepDockIcon: keep) { windowShown() }
	}
}
