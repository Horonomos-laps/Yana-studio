import AppKit
import SwiftUI

// What one screen's notch is doing. The controller changes it from mouse events; the view only draws it.

enum NotchTab: Equatable { case home, clipboard }

@MainActor
final class NotchModel: ObservableObject {
	@Published var isOpen = false
	@Published var hovering = false
	@Published var tab: NotchTab = .home
	@Published var typing = false   // a text field has the keyboard: do not close under the person's hands
	// Phase 2 fills these from yana-rt; in phase 1 they only come from the preview switch.
	@Published var hasActivity = false
	@Published var glancing = false

	let geometry: NotchGeometry
	let displayID: CGDirectDisplayID

	init(screen: NSScreen) {
		let size = NotchGeometry.notch(topInset: screen.safeAreaInsets.top, screenWidth: screen.frame.width,
		                               leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
		                               rightAreaWidth: screen.auxiliaryTopRightArea?.width)
		geometry = NotchGeometry(notch: size)
		displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
	}

	var look: NotchLook {
		NotchGeometry.look(open: isOpen, hovering: hovering, hasActivity: hasActivity, glancing: glancing)
	}

	func open() {
		guard !isOpen else { return }
		withAnimation(.notchOpen) { isOpen = true }
		if !NotchPrefs.quiet { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
	}

	func close() {
		guard isOpen else { return }
		withAnimation(.notchClose) { isOpen = false }
	}

	func setHovering(_ value: Bool) {
		guard value != hovering else { return }
		withAnimation(.notchHover) { hovering = value }
	}
}

enum NotchPrefs {
	static let enabledKey = "yana.notch.enabled"
	static let quietKey = "yana.notch.noHaptics"
	static let hoverKey = "yana.notch.openOnHover"
	static let solidKey = "yana.notch.solid"
	static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
	static var quiet: Bool { UserDefaults.standard.bool(forKey: quietKey) }
	// On unless switched off: resting the pointer on the notch opens it.
	static var openOnHover: Bool { UserDefaults.standard.object(forKey: hoverKey) as? Bool ?? true }
	// The open panel is see-through frosted glass unless the person wants it solid black.
	static var solid: Bool { UserDefaults.standard.bool(forKey: solidKey) }
}
