import CoreGraphics

// Two-finger swipes on the notch, as pure rules. One gesture gives at most one action. The gesture ideas come from
// boring.notch (see CREDITS.md); the code is Yana's.

enum NotchSwipe: Equatable { case up, down, left, right }

struct SwipeAccumulator {
	static let vertical: CGFloat = 20
	static let sideways: CGFloat = 40
	private var total = CGSize.zero
	private var fired = false

	// Where the fingers moved (right and down are positive), whatever the "natural scrolling" setting says.
	static func fingers(dx: CGFloat, dy: CGFloat, inverted: Bool) -> CGSize {
		inverted ? CGSize(width: dx, height: dy) : CGSize(width: -dx, height: -dy)
	}

	mutating func begin() {
		total = .zero
		fired = false
	}

	mutating func add(_ move: CGSize) -> NotchSwipe? {
		guard !fired, move.width.isFinite, move.height.isFinite else { return nil }
		total.width += move.width
		total.height += move.height
		let x = abs(total.width), y = abs(total.height)
		let swipe: NotchSwipe
		if x > Self.sideways, x > 2 * y {
			swipe = total.width > 0 ? .right : .left
		} else if y > Self.vertical, x <= 2 * y {
			swipe = total.height > 0 ? .down : .up
		} else {
			return nil
		}
		fired = true
		return swipe
	}
}

enum NotchSwipeAction: Equatable {
	case open, close, nextPage, previousPage, nextTrack, previousTrack

	// `inHeader`: the pointer is on the top row. `contentScrolls`: the page under it scrolls by itself.
	static func of(_ swipe: NotchSwipe, open: Bool, inHeader: Bool, contentScrolls: Bool, hasMusic: Bool) -> NotchSwipeAction? {
		guard open else {
			switch swipe {
			case .down: return .open
			case .left: return hasMusic ? .nextTrack : nil
			case .right: return hasMusic ? .previousTrack : nil
			case .up: return nil
			}
		}
		let listUnderPointer = contentScrolls && !inHeader
		switch swipe {
		case .up: return inHeader ? .close : nil
		case .left: return listUnderPointer ? nil : .nextPage
		case .right: return listUnderPointer ? nil : .previousPage
		case .down: return nil
		}
	}
}
