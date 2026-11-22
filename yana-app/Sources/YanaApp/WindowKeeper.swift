import SwiftUI
import AppKit

// Closing the window (the red button or ⌘W) hides it instead of destroying it, and a click on the Dock icon
// brings it back. Without this the click does nothing: the menu bar replaces macOS's "New Window" item
// (AppCommands.swift), and that item is what macOS uses to make a window again for an app that has none.
// Hiding keeps the open chat too. Quit (⌘Q or the Dock menu) still ends the app.



@MainActor
enum WindowKeeper {
	// Held strongly on purpose: a hidden window must not be released, or there is nothing to bring back.
	private(set) static var window: NSWindow?
	private static let closeHandler = CloseHidesWindow()
	private static var watching: NSKeyValueObservation?

	// Called with the window RootView lives in. Safe to call again: the language switch rebuilds the view.
	// SwiftUI sets its own window delegate after the view is first placed, so this also watches the delegate
	// and takes it over again whenever SwiftUI replaces it.
	static func adopt(_ candidate: NSWindow) {
		window = candidate
		takeOver(candidate)
		watching = candidate.observe(\.delegate, options: [.new]) { observed, _ in
			Task { @MainActor in takeOver(observed) }
		}
	}

	private static func takeOver(_ candidate: NSWindow) {
		guard candidate.delegate !== closeHandler else { return }
		closeHandler.original = candidate.delegate
		candidate.delegate = closeHandler
	}

	// True when it showed the window, so the caller can tell macOS not to try making another one.
	@discardableResult
	static func show() -> Bool {
		guard let window else { return false }
		if window.isMiniaturized { window.deminiaturize(nil) }
		window.makeKeyAndOrderFront(nil)
		NSApplication.shared.activate(ignoringOtherApps: true)
		return true
	}
}

// Takes over the window delegate for one decision (close means hide) and hands every other question to
// the delegate SwiftUI installed, so the window keeps behaving as before.
private final class CloseHidesWindow: NSObject, NSWindowDelegate {
	weak var original: NSWindowDelegate?

	func windowShouldClose(_ sender: NSWindow) -> Bool {
		sender.orderOut(nil)
		return false
	}

	override func responds(to selector: Selector!) -> Bool {
		super.responds(to: selector) || (original?.responds(to: selector) ?? false)
	}

	override func forwardingTarget(for selector: Selector!) -> Any? {
		if let original, original.responds(to: selector) { return original }
		return super.forwardingTarget(for: selector)
	}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		NotchCenter.shared.apply()
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		if !flag, WindowKeeper.show() { return false }
		return true
	}
}

// Placed behind RootView so it can reach the window that holds it.
struct KeepWindowOnClose: NSViewRepresentable {
	func makeNSView(context: Context) -> NSView { Probe() }
	func updateNSView(_ view: NSView, context: Context) {}

	private final class Probe: NSView {
		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			if let window { WindowKeeper.adopt(window) }
		}
	}
}
