import AppKit
import SwiftUI

// What one screen's notch is doing. The controller changes it from mouse events; the view only draws it.

@MainActor
final class NotchModel: ObservableObject {
	@Published var isOpen = false
	@Published var hovering = false
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
	static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
	static var quiet: Bool { UserDefaults.standard.bool(forKey: quietKey) }
}
