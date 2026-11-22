import AppKit
import SwiftUI

// One panel per screen, pinned to the top. The panel never takes focus from the app you are in, and it ignores the
// mouse everywhere except over the notch shape, so a click next to it reaches whatever is underneath. Hover is read
// from mouse-move monitors, which need no special permission. Ideas credited to notchd in CREDITS.md.

final class NotchPanel: NSPanel {
	init(frame: NSRect) {
		super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		isOpaque = false
		backgroundColor = .clear
		hasShadow = false
		isMovable = false
		isReleasedWhenClosed = false
		level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue + 3)
		collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
	}

	override var canBecomeKey: Bool { true }
	override var canBecomeMain: Bool { false }
}

// A click on the notch works at once, even when another app is in front.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchController {
	static let closeDelay = 0.15   // the pointer may slip off for a moment without closing it
	static let openDelay = 0.22    // resting on the notch opens it; just passing over does not

	let screen: NSScreen
	let model: NotchModel
	private let panel: NotchPanel
	private var monitors: [Any] = []
	private var closeWork: DispatchWorkItem?
	private var openWork: DispatchWorkItem?

	init(screen: NSScreen) {
		self.screen = screen
		model = NotchModel(screen: screen)
		panel = NotchPanel(frame: NotchGeometry.windowFrame(screenFrame: screen.frame))
		let host = FirstMouseHostingView(rootView: NotchView(model: model, onSettings: {
			NSApp.activate(ignoringOtherApps: true)
			_ = WindowKeeper.show()
		}))
		host.sizingOptions = []
		panel.contentView = host
		panel.ignoresMouseEvents = true
		panel.orderFrontRegardless()

		let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged]
		monitors.append(NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
			Task { @MainActor in self?.update() }
		} as Any)
		monitors.append(NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
			Task { @MainActor in self?.update() }
			return event
		} as Any)
	}

	func close() {
		monitors.forEach(NSEvent.removeMonitor)
		monitors = []
		closeWork?.cancel()
		openWork?.cancel()
		panel.close()
	}

	private var hitRect: CGRect { model.geometry.hitRect(model.look, screenFrame: screen.frame) }

	private func update() {
		let mouse = NSEvent.mouseLocation
		let inside = hitRect.contains(mouse)
		// Only over the shape does the panel take the mouse; everywhere else clicks pass through.
		panel.ignoresMouseEvents = !inside
		if !inside { openWork?.cancel(); openWork = nil }
		model.setHovering(inside)
		if inside {
			closeWork?.cancel()
			closeWork = nil
			if !model.isOpen, NotchPrefs.openOnHover, openWork == nil {
				let work = DispatchWorkItem { [weak self] in
					self?.openWork = nil
					if self?.model.hovering == true { self?.model.open() }
				}
				openWork = work
				DispatchQueue.main.asyncAfter(deadline: .now() + Self.openDelay, execute: work)
			}
		} else if model.isOpen, closeWork == nil {
			let work = DispatchWorkItem { [weak self] in
				self?.closeWork = nil
				self?.model.close()
			}
			closeWork = work
			DispatchQueue.main.asyncAfter(deadline: .now() + Self.closeDelay, execute: work)
		}
	}
}

// All the screens' notches, rebuilt when screens are plugged in or out.
@MainActor
final class NotchCenter {
	static let shared = NotchCenter()
	private var controllers: [NotchController] = []
	private var observer: NSObjectProtocol?

	func apply() {
		if NotchPrefs.enabled { start() } else { stop() }
	}

	private func start() {
		rebuild()
		guard observer == nil else { return }
		observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
		                                                  object: nil, queue: .main) { [weak self] _ in
			Task { @MainActor in self?.rebuild() }
		}
	}

	private func stop() {
		if let observer { NotificationCenter.default.removeObserver(observer) }
		observer = nil
		controllers.forEach { $0.close() }
		controllers = []
	}

	private func rebuild() {
		controllers.forEach { $0.close() }
		controllers = NSScreen.screens.map { NotchController(screen: $0) }
	}
}
