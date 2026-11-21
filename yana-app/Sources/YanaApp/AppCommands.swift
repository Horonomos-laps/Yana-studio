import SwiftUI

// The menu bar. Each item posts one named action; RootView (which owns the pages, the chat, the terminal
// and the editor launcher) performs it, so the menu never needs its own copy of app state.
// Titles are read when the menu is built: after a language change they update on the next launch.

enum MenuAction: String {
	case settings, checkUpdates, newChat, openFolder, openStudio, terminal, toggleChatList, pinChat, dictate, uninstall, tour
	case page1, page2, page3, page4, page5, page6, page7
}

extension Notification.Name {
	static let yanaMenu = Notification.Name("ai.yana.menu")
}

func post(_ action: MenuAction) {
	NotificationCenter.default.post(name: .yanaMenu, object: action.rawValue)
}

struct YanaCommands: Commands {
	// The menu shortcuts come from the store, so a change in Settings > Shortcuts shows up here at once.
	@ObservedObject private var shortcuts = ShortcutStore.shared

	var body: some Commands {
		CommandGroup(replacing: .appSettings) {
			Button(L("nav.Settings") + "…") { post(.settings) }.yanaShortcut(shortcuts.effective(.settings))
			Button(L("menu.checkUpdates")) { post(.checkUpdates) }
			Divider()
			Button(L("menu.uninstall")) { post(.uninstall) }
		}
		CommandGroup(replacing: .help) {
			Button(L("menu.tour")) { post(.tour) }
		}
		CommandGroup(replacing: .newItem) {
			Button(L("chat.new")) { post(.newChat) }.yanaShortcut(shortcuts.effective(.newChat))
			Button(L("menu.openFolder")) { post(.openFolder) }.yanaShortcut(shortcuts.effective(.openFolder))
			Divider()
			Button(L("menu.openStudio")) { post(.openStudio) }.yanaShortcut(shortcuts.effective(.openStudio))
		}
		CommandGroup(before: .sidebar) {
			Button(L("nav.Terminal")) { post(.terminal) }.yanaShortcut(shortcuts.effective(.terminal))
			Button(L("menu.toggleChatList")) { post(.toggleChatList) }.yanaShortcut(shortcuts.effective(.toggleChatList))
			Button(L("history.pinToggle")) { post(.pinChat) }.yanaShortcut(shortcuts.effective(.pinChat))
			Button(L("dict.start")) { post(.dictate) }.yanaShortcut(shortcuts.effective(.dictate))
			Divider()
			ForEach(Array(railEntries.prefix(7).enumerated()), id: \.offset) { index, entry in
				Button(L("nav.\(entry.id)")) { post(MenuAction(rawValue: "page\(index + 1)") ?? .page1) }
					.yanaShortcut(ShortcutAction(rawValue: "page\(index + 1)").flatMap { shortcuts.effective($0) })
			}
			Divider()
		}
	}
}
