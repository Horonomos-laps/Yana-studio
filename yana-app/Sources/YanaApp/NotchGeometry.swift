import CoreGraphics
import Foundation

// Sizes and corner radii of the notch shape for every look it can take, and the rectangle that counts as "on it".
// Pure numbers, so every rule can be tested without a screen. The idea (a shape that grows from the notch's own size,
// with flared top corners and a spring) is credited to notchd in CREDITS.md; the code is Yana's.

enum NotchLook: Equatable {
	case closed        // nothing going on
	case hover         // the pointer is on it
	case activity      // something is happening: wings on both sides
	case activityHover
	case glance        // a line of detail slides out under an activity
	case open          // the panel
}

struct NotchGeometry: Equatable {
	// The camera housing, nil on a screen without one.
	let notch: CGSize?
	var hasNotch: Bool { notch != nil }

	static let handleSize = CGSize(width: 100, height: 5)   // stand-in on a screen without a notch
	static let wing: CGFloat = 46                            // width of each side of an activity
	static let glanceExtraWidth: CGFloat = 70
	static let glanceExtraHeight: CGFloat = 26
	static let minRowHeight: CGFloat = 30
	static let openSize = CGSize(width: 440, height: 150)    // phase 1 panel; later it follows its content
	static let windowHeight: CGFloat = 280                   // room for the open shape, its shadow and the spring overshoot

	var closedSize: CGSize { notch ?? Self.handleSize }
	var rowHeight: CGFloat { max(closedSize.height, Self.minRowHeight) }

	// Body between the two flared corners.
	func size(_ look: NotchLook) -> CGSize {
		let base = closedSize
		switch look {
		case .closed: return base
		case .hover:
			return hasNotch ? CGSize(width: base.width + 16, height: base.height + 4) : CGSize(width: base.width + 30, height: 22)
		case .activity: return CGSize(width: base.width + 2 * Self.wing, height: rowHeight)
		case .activityHover: return CGSize(width: base.width + 2 * Self.wing + 8, height: rowHeight + 3)
		case .glance:
			return CGSize(width: base.width + 2 * Self.wing + Self.glanceExtraWidth, height: rowHeight + Self.glanceExtraHeight)
		case .open: return Self.openSize
		}
	}

	// (top, bottom) corner radii.
	func radii(_ look: NotchLook) -> (top: CGFloat, bottom: CGFloat) {
		switch look {
		case .open: return (14, 26)
		case .glance: return (10, 18)
		case .activity, .activityHover, .hover: return (8, 13)
		case .closed: return hasNotch ? (6, 10) : (3, 4)
		}
	}

	// Full width of the drawn shape: the body plus the two flared corners.
	func shapeWidth(_ look: NotchLook) -> CGFloat { size(look).width + 2 * radii(look).top }

	// What counts as on the notch, in screen coordinates (origin bottom left, like NSEvent.mouseLocation).
	func hitRect(_ look: NotchLook, screenFrame: CGRect) -> CGRect {
		let s = size(look)
		let pad: CGFloat = look == .open ? 4 : 10
		return CGRect(x: screenFrame.midX - s.width / 2 - pad, y: screenFrame.maxY - s.height - pad,
		              width: s.width + 2 * pad, height: s.height + pad + 1)
	}

	// The camera housing from the screen's top safe area and the two usable areas beside it.
	static func notch(topInset: CGFloat, screenWidth: CGFloat, leftAreaWidth: CGFloat?, rightAreaWidth: CGFloat?) -> CGSize? {
		guard topInset > 0, let left = leftAreaWidth, let right = rightAreaWidth else { return nil }
		let width = screenWidth - left - right
		return width > 0 ? CGSize(width: width, height: topInset) : nil
	}

	// Where the window goes: the full width of the screen, pinned to its top.
	static func windowFrame(screenFrame: CGRect) -> CGRect {
		CGRect(x: screenFrame.minX, y: screenFrame.maxY - windowHeight, width: screenFrame.width, height: windowHeight)
	}

	// Which look to draw.
	static func look(open: Bool, hovering: Bool, hasActivity: Bool, glancing: Bool) -> NotchLook {
		if open { return .open }
		if hasActivity { return glancing ? .glance : (hovering ? .activityHover : .activity) }
		return hovering ? .hover : .closed
	}
}
