import CoreGraphics

// How the chat page shares its width between the chat column and the right panel (terminal or browser).
// The window's width is what it is: the rail and the chat list are fixed, so whatever is left is split here.
// If the panel kept its remembered width regardless, the chat column would be squeezed under what the composer
// needs, the page would grow wider than the window, and macOS would clip the rail on the left and the panel on the
// right (that is how this was found). So the panel gives way first.

enum PanelLayout {
	// The least the chat column keeps: the composer's controls and a readable message.
	static let chatMin: CGFloat = 440
	// The least the panel gives way to, so the chat can keep chatMin (the drag handle in ChatHome stops at 320).
	static let panelMin: CGFloat = 240
	static let panelMax: CGFloat = 1200
	// The drag handle between chat and panel.
	static let handle: CGFloat = 5

	struct Split: Equatable {
		let chat: CGFloat
		let panel: CGFloat
	}

	// `available` is the width of the page (the window minus the rail and the chat list). `requested` is the
	// width the person dragged the panel to. The panel is never above what was asked, never below panelMin when
	// there is room for it, and the two always add up to `available`.
	static func split(available: CGFloat, requested: CGFloat, showsHandle: Bool = true) -> Split {
		let total = max(available, 0)
		let gap = showsHandle ? handle : 0
		let wanted = min(max(requested, panelMin), panelMax)
		let roomForPanel = total - gap - chatMin
		let panel = max(0, min(wanted, max(roomForPanel, panelMin)))
		// When even panelMin does not fit, the chat column keeps whatever is left (never negative).
		let chat = max(total - gap - panel, 0)
		return Split(chat: chat, panel: panel)
	}
}
