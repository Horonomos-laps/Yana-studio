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
		// The panel is always dark, like the camera housing it grows from: white text and dark glass, in any app look.
		appearance = NSAppearance(named: .darkAqua)
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
	private var debugHold = false   // only with YANA_NOTCH_SHOT

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
		if let path = ProcessInfo.processInfo.environment["YANA_NOTCH_SHOT"] { scheduleShot(to: path) }

		let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged]
		monitors.append(NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
			Task { @MainActor in self?.update() }
		} as Any)
		monitors.append(NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
			Task { @MainActor in self?.update() }
			return event
		} as Any)
	}

	// Debug only: open the notch and save what the panel's content draws, so the panel can be checked without screen
	// capture. YANA_NOTCH_SHOT=/path/file.png, optional YANA_NOTCH_TAB=0,1,2.
	private func scheduleShot(to path: String) {
		let tab = Int(ProcessInfo.processInfo.environment["YANA_NOTCH_TAB"] ?? "") ?? 0
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
			guard tab >= 0 else { return }   // YANA_NOTCH_TAB=-1 captures the closed pill
			self?.model.tab = NotchTab(rawValue: tab) ?? .yana
			self?.debugHold = true   // keeps it open while the pointer is elsewhere
			self?.model.open()
		}
		// Debug: YANA_NOTCH_CLICK="x,y" sends a click at that point of the panel (in points, from its top-left) shortly
		// before the capture, to check that the buttons really react.
		if let spec = ProcessInfo.processInfo.environment["YANA_NOTCH_CLICK"] {
			let wait = (Double(ProcessInfo.processInfo.environment["YANA_NOTCH_WAIT"] ?? "") ?? 2.5) - 0.8
			DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in self?.debugClick(spec) }
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + (Double(ProcessInfo.processInfo.environment["YANA_NOTCH_WAIT"] ?? "") ?? 2.5)) { [weak self] in
			guard let self, let view = panel.contentView,
			      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
			view.cacheDisplay(in: view.bounds, to: rep)
			try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
			NSLog("[NotchShot] wrote %@ open=%d tab=%d solid=%d look=%@ appearance=%@ bounds=%@", path, model.isOpen ? 1 : 0, model.tab.rawValue, NotchPrefs.solid ? 1 : 0, String(describing: model.look), panel.effectiveAppearance.name.rawValue, NSStringFromRect(view.bounds))
		}
	}

	private func debugClick(_ spec: String) {
		let parts = spec.split(separator: ",").compactMap { Double($0) }
		guard parts.count == 2, let view = panel.contentView else { return }
		let point = view.convert(NSPoint(x: parts[0], y: view.isFlipped ? parts[1] : view.bounds.height - parts[1]), to: nil)
		NSLog("[NotchClick] before: pomodoro running=%d", TimerStore.shared.pomodoro.isRunning ? 1 : 0)
		for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
			if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
			                                  windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
				panel.sendEvent(event)
			}
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
			NSLog("[NotchClick] after: pomodoro running=%d", TimerStore.shared.pomodoro.isRunning ? 1 : 0)
		}
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
		// Typing ended when the panel lost the keyboard (a click elsewhere).
		if model.typing, !panel.isKeyWindow { model.typing = false }
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
		} else if model.isOpen, !model.typing, !debugHold, closeWork == nil {
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
		if NotchPrefs.enabled || ProcessInfo.processInfo.environment["YANA_NOTCH_SHOT"] != nil { start() } else { stop() }
	}

	private func start() {
		MusicStore.shared.start(); TimerStore.shared.start(); ClipboardStore.shared.start(); AgentMonitor.shared.start()
		rebuild()
		guard observer == nil else { return }
		observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
		                                                  object: nil, queue: .main) { [weak self] _ in
			Task { @MainActor in self?.rebuild() }
		}
	}

	private func stop() {
		MusicStore.shared.stop(); TimerStore.shared.stop(); ClipboardStore.shared.stop(); AgentMonitor.shared.stop()
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
