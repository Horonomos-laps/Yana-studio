import AppKit
import SwiftUI

// The menu bar item and the panel that drops from it, made with AppKit. SwiftUI's MenuBarExtra, bound to a stored
// setting, rebuilt the app's menus without end and froze the app. The panel's numbers are sampled only while it is open.

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
	static let shared = MenuBarController()

	private(set) var item: NSStatusItem?
	private(set) lazy var popover: NSPopover = {
		let popover = NSPopover()
		popover.behavior = .transient   // a click anywhere else closes it
		popover.delegate = self
		let host = NSHostingController(rootView: MenuBarPanel(monitor: .shared))
		host.sizingOptions = .preferredContentSize
		popover.contentViewController = host
		return popover
	}()

	// Adds or removes the item to match the setting. Safe to call again.
	func apply() {
		if BackgroundMode.menuBarOn {
			guard item == nil else { return }
			let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
			item.button?.image = MenuBarLabel.frames.first
			item.button?.target = self
			item.button?.action = #selector(toggle)
			self.item = item
			startColours()
		} else if let item {
			close()
			colourTimer?.invalidate()
			colourTimer = nil
			NSStatusBar.system.removeStatusItem(item)
			self.item = nil
		}
	}

	private var colourTimer: Timer?
	private var shownFrame = 0

	private func startColours() {
		let timer = Timer(timeInterval: 1 / MenuBarLabel.framesPerSecond, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.step() }
		}
		timer.tolerance = timer.timeInterval / 4   // lets macOS group wake-ups
		RunLoop.main.add(timer, forMode: .common)
		colourTimer = timer
	}

	// The colours stand still with macOS "reduce motion" on, and nothing is drawn while the item cannot be seen
	// (sleeping screen, full screen app).
	private func step() {
		guard let button = item?.button, button.window?.occlusionState.contains(.visible) == true else { return }
		let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
		let frame = still ? 0 : MenuBarLabel.frame(at: Date().timeIntervalSinceReferenceDate, always: popover.isShown)
		guard frame != shownFrame else { return }
		shownFrame = frame
		button.image = MenuBarLabel.frames[frame]
	}

	@objc func toggle() {
		if popover.isShown { close(); return }
		guard let button = item?.button else { return }
		SystemMonitor.shared.start()
		popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
		popover.contentViewController?.view.window?.makeKey()
	}

	func close() {
		if popover.isShown { popover.performClose(nil) }
	}

	func popoverDidClose(_ notification: Notification) {
		SystemMonitor.shared.stop()
	}
}
