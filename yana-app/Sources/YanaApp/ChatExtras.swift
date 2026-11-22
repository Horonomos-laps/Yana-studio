import AppKit
import SwiftUI

// Chat screen extras: a title with a menu at the top of an open chat, a button to jump to the latest message, and a
// copy button under the person's own messages. The menu uses the same actions as the chat list's right-click menu.

enum ChatHeaderTitle {
	static let maxChars = 60

	// The name set in the list wins; before the chat is saved it is the first line of the first question.
	static func text(saved: String?, first: String?) -> String {
		if let name = saved?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
		if let line = first?.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces),
		   !line.isEmpty { return String(line.prefix(maxChars)) }
		return L("chathdr.untitled")
	}
}

enum ScrollFollow {
	// Keep the view on the newest text while a reply streams in, but never pull it away from someone who scrolled up
	// to read; a message the person just sent always scrolls into view.
	static func shouldFollow(atBottom: Bool, lastIsUser: Bool) -> Bool { atBottom || lastIsUser }
}

enum ChatExport {
	// Saves one chat as a Markdown file wherever the person picks.
	@MainActor
	static func save(_ chat: SavedChat, history: ChatHistoryStore) {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = ChatLibrary.fileName(for: chat.displayTitle)
		panel.canCreateDirectories = true
		guard panel.runModal() == .OK, let url = panel.url else { return }
		do {
			try Data(history.markdown(chat).utf8).write(to: url, options: .atomic)
		} catch {
			let alert = NSAlert()
			alert.messageText = L("history.exportFailed")
			alert.informativeText = error.localizedDescription
			alert.runModal()
		}
	}
}

struct ChatHeader: View {
	@EnvironmentObject private var engine: ChatEngine
	@ObservedObject private var history = ChatHistoryStore.shared
	@State private var renaming = false
	@State private var renameText = ""
	@State private var showMenu = false
	static let maxWidth: CGFloat = 320

	private var saved: SavedChat? { history.chat(engine.currentChatID) }
	private var title: String { ChatHeaderTitle.text(saved: saved?.displayTitle, first: engine.title) }

	var body: some View {
		HStack(spacing: 4) {
			Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(FB.text)
				.lineLimit(1).truncationMode(.tail)
			FBIconButton(icon: "more-horizontal", variant: .ghost, size: .small, tooltip: L("chathdr.menu")) { showMenu = true }
				.popover(isPresented: $showMenu, arrowEdge: .bottom) { menu }
		}
		.padding(.horizontal, 10).frame(height: 34).frame(maxWidth: Self.maxWidth)
		.sheet(isPresented: $renaming) {
			RenameSheet(text: $renameText, cancel: { renaming = false }) {
				if let saved { history.rename(saved.id, to: renameText) }
				renaming = false
			}
		}
	}

	// The same list as the chat list's right-click menu, plus copying the whole conversation.
	private var menu: some View {
		VStack(alignment: .leading, spacing: 0) {
			if let saved {
				row("pin", saved.isPinned ? L("history.unpin") : L("history.pin")) {
					history.setPinned(saved.id, !saved.isPinned)
				}
				row("edit", L("history.rename")) { renameText = saved.displayTitle; renaming = true }
				row("share", L("history.export")) { ChatExport.save(saved, history: history) }
			}
			row("copy", L("chathdr.copyAll")) { copyAll() }
			if let saved {
				FB.divider.frame(height: 1).padding(.vertical, 4)
				row("archive", saved.isArchived ? L("history.unarchive") : L("history.archive")) {
					if !saved.isArchived { engine.reset() }
					history.setArchived(saved.id, !saved.isArchived)
				}
			}
		}
		.padding(6).frame(width: 250)
	}

	private func row(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
		HStack(spacing: 10) {
			FBIcon(name: icon, size: 15, color: FB.textSecondary).frame(width: 18)
			Text(title).font(.fbBody).foregroundStyle(FB.text).lineLimit(1)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 10).frame(height: 32)
		.contentShape(Rectangle())
		.onTapGesture { showMenu = false; action() }
	}

	// The whole conversation as Markdown, on the clipboard.
	private func copyAll() {
		let text = ChatLibrary.markdown(title: title, provider: engine.provider, model: engine.model, updated: Date(),
		                                lines: engine.lines.map { (user: $0.role == .user, text: $0.text) })
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
	}
}

// Copies a message to the clipboard; the icon turns into a check for a moment.
struct CopyIconButton: View {
	let text: String
	@State private var copied = false

	var body: some View {
		FBIconButton(icon: copied ? "check" : "copy", variant: .ghost, size: .small, tooltip: L("msg.copy")) {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(text, forType: .string)
			copied = true
		}
	}
}

let chatExtraRows: [StringRow] = [
	StringRow("chathdr.untitled", "Chat mới", "New chat", "새 채팅"),
	StringRow("chathdr.menu", "Thao tác với chat này", "Actions for this chat", "이 채팅의 작업"),
	StringRow("chathdr.copyAll", "Sao chép cả cuộc trò chuyện", "Copy the whole conversation", "대화 전체 복사"),
	StringRow("chathdr.scrollDown", "Cuộn xuống tin mới nhất", "Jump to the latest message", "최신 메시지로 이동"),
]
