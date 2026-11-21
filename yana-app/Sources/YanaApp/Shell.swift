import SwiftUI
import AppKit

// The application shell, laid out like Codex and Goose: a narrow icon rail on the far left, a list sidebar
// that belongs to the chat section, and the page on the right. The two sidebars use the macOS sidebar
// material (frosted glass). That material is a live AppKit view, so image renders use a flat color instead.

// The window hides its title bar, but macOS still treats the top ~28 pt as the drag area: a button there
// moves the window instead of being pressed. Controls near the top edge sit at least this far down.
let titleBarClearance: CGFloat = 34

// Set by `--render`. ImageRenderer cannot draw AppKit-backed views (the material, Menu), so it gets stand-ins.
var isRenderingForImage = false

struct RailEntry: Identifiable {
	let id: String
	let icon: String
}

// The icons in the rail. `id` is the page key; the label comes from L("nav.<id>").
// Only pages backed by real data are listed. The planned pages in Features.swift (Extensions, Recipes,
// Scheduler, Sessions, Providers, Context, System) come back here once each is wired to yana-rt.
let railEntries: [RailEntry] = [
	.init(id: "Chat", icon: "message"),
	.init(id: "Overview", icon: "dashboard"),
	.init(id: "Tool approvals", icon: "shield"),
	.init(id: "Tasks", icon: "check-circle"),
	.init(id: "Skills", icon: "zap"),
	.init(id: "Plugins", icon: "layers"),
	.init(id: "Health", icon: "chart-pie"),
	.init(id: "Usage", icon: "chart-bar"),
]

// Sidebars are solid token colors. A behind-window material was tried first (2026-11-07): with macOS in
// dark mode it took the dark desktop color and turned the sidebar and the glass composer a muddy grey.
// The icon rail is pure white in the light look (a neutral gray read as yellowish next to the page), dark gray in the dark.
private let railColor = FBPair.rail.color
private let sidebarColor = FB.chrome
private let dividerColor = FB.divider

struct SidebarBackground: View {
	var color: Color
	var body: some View {
		color.overlay(alignment: .trailing) { dividerColor.frame(width: 1) }
	}
}

// A white card with a thin border and a soft shadow (the composer).
struct GlassCard: ViewModifier {
	var radius: CGFloat

	func body(content: Content) -> some View {
		content.yanaGlass(in: RoundedRectangle(cornerRadius: radius, style: .continuous))
	}
}

extension View {
	func glassCard(radius: CGFloat = 22) -> some View { modifier(GlassCard(radius: radius)) }
}

// The icon rail (RailViews.swift) draws the far-left column; its colors are shared from here.
let railBackground = railColor

// The list sidebar of the chat section. It shows only real things: the current project and, when
// yana-rt can list them, chats. Today there is nothing to list, and it says so instead of inventing rows.
struct ChatSidebar: View {
	@EnvironmentObject private var engine: ChatEngine
	@ObservedObject private var history = ChatHistoryStore.shared
	let collapse: () -> Void
	@State private var query = ""
	@State private var renaming: SavedChat?
	@State private var renameText = ""

	// "Pinned" then "Recent", filtered by the search box (title and every message). See ChatSections.swift.
	@AppStorage("yana.ui.sidebar.pinnedCollapsed") private var pinnedCollapsed = false
	@AppStorage("yana.ui.sidebar.recentCollapsed") private var recentCollapsed = false
	@State private var showAllRecent = false
	@State private var showArchived = false
	private var searching: Bool { !ChatLibrary.normalize(query).isEmpty }
	private var sections: [ChatSection] {
		ChatSections.build(chats: history.chats, query: query, showAllRecent: showAllRecent, showArchived: showArchived)
	}
	private var archivedCount: Int { ChatSections.archivedCount(history.chats) }

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 8) {
				RabbitLogo(cell: 1.3)
				Text("Yana").font(.system(size: 19, weight: .semibold)).foregroundStyle(FB.text)
				Spacer()
				FBIconButton(icon: "sidebar", variant: .ghost, size: .small, tooltip: L("sidebar.hide"), action: collapse)
			}
			.padding(EdgeInsets(top: 4, leading: 6, bottom: 10, trailing: 2))

			// Clears the conversation and starts a new yana-rt session id.
			SidebarRow(icon: "edit", title: L("chat.new"), strong: true)
				.onTapGesture { engine.reset() }
				.opacity(engine.running ? 0.4 : 1)

			SidebarHeading(L("chat.projects"))
			SidebarRow(icon: "folder", title: URL(fileURLWithPath: engine.workspace).lastPathComponent, strong: false, accent: Accent.amber.color)
				.help(engine.workspace)

			// Saved chats (ChatHistory.swift), newest first; the open one is highlighted. Right-click deletes.
			searchField
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 2) {
					if query.isEmpty, engine.title != nil && history.chat(engine.currentChatID) == nil {
						RecentRow(title: engine.title ?? "", date: nil, current: true)
					}
					ForEach(sections) { section in sectionView(section) }
					if archivedCount > 0 && !searching {
						SidebarLink(title: showArchived ? L("chat.archivedHide") : String(format: L("chat.archivedShow"), archivedCount)) {
							showArchived.toggle()
						}
					}
					if sections.isEmpty && !query.isEmpty {
						Text(L("history.noMatch")).font(.fbCaption).foregroundStyle(FB.textSecondary)
							.padding(.horizontal, 10).padding(.vertical, 6)
					} else if history.chats.isEmpty && engine.title == nil {
						Text(L("chat.noChats")).font(.fbCaption).foregroundStyle(FB.textSecondary)
							.padding(.horizontal, 10).padding(.vertical, 6)
					}
				}
			}
			.opacity(engine.running ? 0.6 : 1)
			if let error = history.lastError { Text(error).font(.fbCaption).foregroundStyle(FB.errorText).padding(.horizontal, 10) }
		}
		.padding(EdgeInsets(top: 38, leading: 12, bottom: 14, trailing: 12))
		.frame(width: 252)
		.frame(maxHeight: .infinity)
		.sidePanelBackground(color: sidebarColor, leadingInset: 2)
		.sheet(item: $renaming) { chat in
			RenameSheet(text: $renameText, cancel: { renaming = nil }) {
				history.rename(chat.id, to: renameText)
				renaming = nil
			}
		}
	}

	// One group: a heading that folds it (not while searching, so matches are never hidden), then its chats.
	@ViewBuilder
	private func sectionView(_ section: ChatSection) -> some View {
		let kind = section.kind
		let collapsed = kind == .pinned ? pinnedCollapsed : kind == .recent ? recentCollapsed : false
		let title = kind == .pinned ? L("chat.pinned") : kind == .recent ? L("chat.recent") : L("chat.archived")
		SidebarSectionHeader(title: title, count: section.chats.count + section.hidden,
		                     collapsed: collapsed && !searching, foldable: !searching && kind != .archived) {
			if kind == .pinned { pinnedCollapsed.toggle() } else if kind == .recent { recentCollapsed.toggle() }
		}
		if searching || !collapsed {
			ForEach(section.chats) { chat in chatRow(chat) }
			if section.hidden > 0 {
				SidebarLink(title: String(format: L("chat.showMore"), section.hidden)) { showAllRecent = true }
			} else if kind == .recent && showAllRecent && !searching && section.chats.count > ChatSections.recentLimit {
				SidebarLink(title: L("chat.showLess")) { showAllRecent = false }
			}
		}
	}

	private func chatRow(_ chat: SavedChat) -> some View {
		RecentRow(title: chat.displayTitle, date: chat.updated, current: chat.id == engine.currentChatID,
		          pinned: chat.isPinned, snippet: ChatLibrary.snippet(lines: chat.lines.map(\.text), query: query, radius: 24),
		          togglePin: { history.setPinned(chat.id, !chat.isPinned) })
			.onTapGesture { engine.open(chat) }
			.contextMenu {
				if !chat.isArchived {
					Button(chat.isPinned ? L("history.unpin") : L("history.pin")) { history.setPinned(chat.id, !chat.isPinned) }
				}
				Button(L("history.rename")) { renameText = chat.displayTitle; renaming = chat }
				Button(L("history.export")) { export(chat) }
				Button(L("history.fork")) { if let copy = history.fork(chat.id) { engine.open(copy) } }
				Button(chat.isArchived ? L("history.unarchive") : L("history.archive")) {
					if chat.id == engine.currentChatID && !chat.isArchived { engine.reset() }
					history.setArchived(chat.id, !chat.isArchived)
				}
				Divider()
				Button(L("history.delete"), role: .destructive) {
					if chat.id == engine.currentChatID { engine.reset() }
					history.delete(chat.id)
				}
			}
	}

	// Searches the titles and every message of the saved chats, ignoring case and accents.
	private var searchField: some View {
		HStack(spacing: 6) {
			FBIcon(name: "search", size: 13, color: FB.textTertiary)
			TextField(L("history.search"), text: $query).textFieldStyle(.plain).font(.system(size: 13))
			if !query.isEmpty {
				Button { query = "" } label: { FBIcon(name: "close", size: 11, color: FB.textTertiary) }.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 10).frame(height: 30)
		.background(RoundedRectangle(cornerRadius: 9).fill(FB.hoverOnChrome))
		.padding(.bottom, 4)
	}

	// Saves one chat as a Markdown file wherever the person picks.
	private func export(_ chat: SavedChat) {
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

struct RenameSheet: View {
	@Binding var text: String
	let cancel: () -> Void
	let save: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(L("history.rename")).font(.system(size: 16, weight: .semibold)).foregroundStyle(FB.text)
			TextField(L("history.renameHint"), text: $text).textFieldStyle(.roundedBorder).onSubmit(save)
			HStack {
				Spacer()
				FBButton(title: L("store.cancel"), variant: .secondary, size: .small, action: cancel)
				FBButton(title: L("history.save"), variant: .primary, size: .small, action: save)
			}
		}
		.padding(20).frame(width: 360).background(FB.canvas)
	}
}

// One saved chat in "Recent": its title, a pin when pinned, and when it was last used; while searching, the
// words around the match.
struct RecentRow: View {
	let title: String
	let date: Date?
	let current: Bool
	var pinned = false
	var snippet: String? = nil
	// Pins or unpins from the row itself; nil for a chat that is not saved yet.
	var togglePin: (() -> Void)? = nil
	@State private var hover = false

	var body: some View {
		HStack(spacing: 8) {
			VStack(alignment: .leading, spacing: 1) {
				Text(title).font(.system(size: 13, weight: current ? .semibold : .regular)).foregroundStyle(FB.text).lineLimit(1)
				if let snippet { Text(snippet).font(.system(size: 11)).foregroundStyle(FB.textTertiary).lineLimit(1) }
			}
			Spacer(minLength: 4)
			// While the pointer is on the row, the date gives way to a pin button.
			if hover, let togglePin {
				Button(action: togglePin) {
					FBIcon(name: "pin", size: 13, color: pinned ? FB.primaryText : FB.textSecondary)
						.frame(width: 22, height: 22).contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.help(pinned ? L("history.unpin") : L("history.pin"))
			} else if let date {
				Text(date, format: .relative(presentation: .numeric)).font(.system(size: 10)).foregroundStyle(FB.textTertiary).lineLimit(1)
			}
		}
		.padding(.horizontal, 10)
		.frame(height: snippet == nil ? 30 : 42)
		.background(RoundedRectangle(cornerRadius: 9).fill(current ? FB.primarySubtle : (hover ? FB.hoverOnChrome : .clear)))
		.contentShape(Rectangle())
		.onHover { hover = $0 }
		.help(title)
	}
}

// The heading of a chat group: a chevron, the name and how many chats it holds. Pressing it folds the group.
struct SidebarSectionHeader: View {
	let title: String
	let count: Int
	let collapsed: Bool
	let foldable: Bool
	let toggle: () -> Void
	@State private var hover = false

	var body: some View {
		Button(action: toggle) {
			HStack(spacing: 5) {
				FBIcon(name: collapsed ? "chevron-right" : "chevron-down", size: 10, color: FB.textTertiary)
					.opacity(foldable ? 1 : 0)
				Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(FB.textSecondary)
				Text("\(count)").font(.system(size: 11)).foregroundStyle(FB.textTertiary)
				Spacer(minLength: 0)
			}
			.padding(EdgeInsets(top: 12, leading: 8, bottom: 4, trailing: 8))
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.disabled(!foldable)
		.onHover { hover = $0 }
		.accessibilityLabel(Text("\(title), \(count)"))
	}
}

// A quiet text button under a group ("Show more").
struct SidebarLink: View {
	let title: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Text(title).font(.system(size: 12)).foregroundStyle(FB.primaryText)
				.padding(.horizontal, 10).padding(.vertical, 5)
				.frame(maxWidth: .infinity, alignment: .leading)
				.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

struct SidebarHeading: View {
	let text: String
	init(_ text: String) { self.text = text }

	var body: some View {
		Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(FB.textSecondary)
			.padding(EdgeInsets(top: 14, leading: 10, bottom: 4, trailing: 10))
	}
}

struct SidebarRow: View {
	let icon: String
	let title: String
	let strong: Bool
	var accent: Color? = nil
	@State private var hover = false

	var body: some View {
		HStack(spacing: 9) {
			FBIcon(name: icon, size: 15, color: accent ?? (strong ? FB.primaryText : FB.textSecondary))
			Text(title).font(.system(size: 13, weight: strong ? .semibold : .regular)).foregroundStyle(FB.text).lineLimit(1)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 10)
		.frame(height: 32)
		.background(RoundedRectangle(cornerRadius: 10).fill(hover ? FB.hoverOnChrome : .clear))
		.contentShape(Rectangle())
		.onHover { hover = $0 }
	}
}
