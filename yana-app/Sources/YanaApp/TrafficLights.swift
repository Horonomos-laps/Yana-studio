import AppKit
import SwiftUI

// The window's close, minimize and zoom buttons. macOS draws them at its default place, 9 pt from the corner and
// 12 pt across, which looks big and crowded against the icon rail. So they are drawn smaller (70% of the size, with
// the space between them cut to match) and centered in the top of the rail, with the same space left and right of the row. TrafficLightsPlacer
// can put them back where macOS puts them.

enum TrafficLights {
	// Where the first button's top-left corner is, from the window's top-left corner, and the gap between buttons.
	static let leading: CGFloat = 8
	static let top: CGFloat = 21
	static let step: CGFloat = 13
	static let size: CGFloat = 14
	// The dots are drawn smaller than macOS draws them (12 pt across), so they sit lightly in the rail.
	static let scale: CGFloat = 0.7
	// How wide macOS draws a dot inside its 14 pt button; the drawn size is this times the scale.
	static let dot: CGFloat = 12
	// The space between two drawn dots. Their buttons overlap by a pt, which is harmless: the drawn dots never do.
	static var gap: CGFloat { step - dot * scale }

	// What the buttons must sit inside: the icon rail, a flat column against the window's edge. The same place also
	// lies inside the Settings list's glass panel, which has rounded corners, so fitsInPanel keeps a rounded corner
	// in mind for both.
	static var panel: CGRect {
		CGRect(x: 0, y: 0, width: RailMetrics.width, height: 400)
	}

	static func origin(_ index: Int) -> CGPoint { CGPoint(x: leading + CGFloat(index) * step, y: top) }

	// True when a point is inside a rectangle whose corners are rounded with `radius`.
	static func inside(_ p: CGPoint, of rect: CGRect, radius: CGFloat) -> Bool {
		guard rect.contains(p) else { return false }
		let cx = min(max(p.x, rect.minX + radius), rect.maxX - radius)
		let cy = min(max(p.y, rect.minY + radius), rect.maxY - radius)
		let dx = p.x - cx, dy = p.y - cy
		return dx * dx + dy * dy <= radius * radius
	}

	// Every corner of every button, with a margin, lies inside the rounded panel.
	static func fitsInPanel(margin: CGFloat = 4) -> Bool {
		(0 ..< 3).allSatisfy { i in
			let o = origin(i)
			let corners = [CGPoint(x: o.x - margin, y: o.y - margin), CGPoint(x: o.x + size + margin, y: o.y - margin),
			               CGPoint(x: o.x - margin, y: o.y + size + margin), CGPoint(x: o.x + size + margin, y: o.y + size + margin)]
			return corners.allSatisfy { inside($0, of: panel, radius: LiquidGlass.panelRadius) }
		}
	}
}

@MainActor
enum TrafficLightsPlacer {
	// The transform that scales a layer about its own center. A layer scales about its anchor point, and a view's
	// backing layer may use (0, 0) or (0.5, 0.5), so the difference between the center and the anchor is added back.
	static func scaling(_ factor: CGFloat, size: CGSize, anchor: CGPoint) -> CGAffineTransform {
		let tx = (size.width / 2 - anchor.x * size.width) * (1 - factor)
		let ty = (size.height / 2 - anchor.y * size.height) * (1 - factor)
		return CGAffineTransform(a: factor, b: 0, c: 0, d: factor, tx: tx, ty: ty)
	}

	private static func shrink(_ button: NSButton, to factor: CGFloat) {
		button.wantsLayer = true
		guard let layer = button.layer else { return }
		layer.setAffineTransform(factor == 1 ? .identity : scaling(factor, size: button.bounds.size, anchor: layer.anchorPoint))
	}

	private static let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

	// What macOS laid out, kept the first time so it can be put back: the buttons, and the title bar views that
	// clip them (the title bar is only 28 pt tall, so a button lower than that would be cut off).
	private struct Saved {
		let buttons: [NSPoint]
		let host: NSRect
		let container: NSRect
	}
	private static var originals: [ObjectIdentifier: Saved] = [:]

	// With custom true the glass layout is used; with false, macOS's own.
	static func apply(to window: NSWindow, custom: Bool) {
		let buttons = kinds.compactMap { window.standardWindowButton($0) }
		guard buttons.count == 3, let host = buttons[0].superview else { return }
		let container = host.superview
		let key = ObjectIdentifier(window)
		// Full screen hides them and macOS lays them out itself.
		if window.styleMask.contains(.fullScreen) { return }
		if originals[key] == nil {
			originals[key] = Saved(buttons: buttons.map(\.frame.origin), host: host.frame, container: container?.frame ?? .zero)
		}
		guard let saved = originals[key] else { return }
		if !custom {
			container?.frame = saved.container
			host.frame = saved.host
			for (button, origin) in zip(buttons, saved.buttons) { button.setFrameOrigin(origin); shrink(button, to: 1) }
			return
		}
		// Make the title bar tall enough to hold the lowered buttons, still glued to the top of the window.
		let needed = TrafficLights.top + TrafficLights.size + 6
		if let container, saved.host.height < needed {
			container.frame = NSRect(x: saved.container.minX, y: saved.container.maxY - needed, width: saved.container.width, height: needed)
			host.frame = NSRect(x: saved.host.minX, y: 0, width: saved.host.width, height: needed)
		}
		for (index, button) in buttons.enumerated() {
			let spot = TrafficLights.origin(index)
			// The title bar view is not flipped: y runs up from its bottom, which is `needed` below the window's top.
			button.setFrameOrigin(NSPoint(x: spot.x, y: host.frame.height - spot.y - button.frame.height))
			shrink(button, to: TrafficLights.scale)
		}
	}
}

// Sits in the window's view tree to find the window, and puts the buttons in place now and after anything that makes
// macOS lay them out again (resizing, full screen, the glass switch).
struct TrafficLightsAnchor: NSViewRepresentable {
	func makeNSView(context: Context) -> NSView { AnchorView() }
	func updateNSView(_ view: NSView, context: Context) { (view as? AnchorView)?.refresh() }

	private final class AnchorView: NSView {
		private var observers: [NSObjectProtocol] = []

		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			observers.forEach(NotificationCenter.default.removeObserver)
			observers = []
			guard let window else { return }
			let names: [Notification.Name] = [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
			                                  NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
			                                  NSWindow.didChangeScreenNotification, UserDefaults.didChangeNotification]
			observers = names.map { name in
				NotificationCenter.default.addObserver(forName: name, object: name == UserDefaults.didChangeNotification ? nil : window,
				                                       queue: .main) { [weak self] _ in
					MainActor.assumeIsolated { self?.refresh() }
				}
			}
			refresh()
		}

		func refresh() {
			// macOS may lay the buttons out again right after the event, so place them on the next turn.
			DispatchQueue.main.async { [weak self] in
				guard let window = self?.window else { return }
				TrafficLightsPlacer.apply(to: window, custom: true)
			}
		}

		deinit { observers.forEach(NotificationCenter.default.removeObserver) }
	}
}
