import Foundation

// Whether the right panel (terminal, browser, files) is open when Yana starts. It is closed: a window that opens
// with a terminal taking half of it hides the chat the person came for. It opens only from its button at the top
// right of the chat, or when the person set the start page to Terminal in Settings, which is asking for it. The
// start chooser (Start with Yana) does not open it either.

enum LaunchPanel {
	static let terminalStartPage = "Terminal"

	static func opensTerminal(startPage: String) -> Bool { startPage == terminalStartPage }
}
