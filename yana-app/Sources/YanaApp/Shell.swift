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
// The chat list is a flat column like the icon rail beside it (white in the light look), not a floating rounded panel.
private let sidebarColor = FBPair.rail.color
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
	@ObservedObject private var projects = ProjectStore.shared
	@State private var projectEdit: ProjectEdit?
	@State private var deleting: Project?
	@AppStorage("yana.ui.sidebar.collapsedProjects") private var collapsedProjects = ""

	// "Pinned" then "Recent", filtered by the search box (title and every message). See ChatSections.swift.
	@AppStorage("yana.ui.sidebar.pinnedCollapsed") private var pinnedCollapsed = false
	@AppStorage("yana.ui.sidebar.recentCollapsed") private var recentCollapsed = false
	@State private var showAllRecent = false
	@State private var showArchived = false
	// The search box opens from the magnifier in the header, like ChatGPT's, instead of always taking a row.
	@State private var showSearch = false
	@FocusState private var searchFocused: Bool
	@AppStorage("yana.ui.sidebar.projectsCollapsed") private var projectsCollapsed = false
	private var searching: Bool { !ChatLibrary.normalize(query).isEmpty }
	private var sections: [ChatSection] {
		// The ordinary chats; a search looks in every chat, projects included.
		ChatSections.build(chats: searching ? history.chats : ProjectLogic.scope(history.chats, projectID: nil), query: query,
		                   showAllRecent: showAllRecent, showArchived: showArchived)
	}
	private var archivedCount: Int { ChatSections.archivedCount(history.chats) }

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 4) {
				RainbowText(text: "Yana", size: 32).offset(y: -6)
				Spacer()
				FBIconButton(icon: "search", variant: showSearch ? .secondary : .ghost, size: .small, tooltip: L("history.search")) {
					showSearch.toggle()
					if showSearch { searchFocused = true } else { query = "" }
				}
				FBIconButton(icon: "sidebar", variant: .ghost, size: .small, tooltip: L("sidebar.hide"), action: collapse)
			}
			.padding(EdgeInsets(top: 0, leading: 8, bottom: 10, trailing: 2))

			// Clears the conversation and starts a new yana-rt session id.
			SidebarRow(icon: "edit", title: L("chat.new"), strong: false)
				.onTapGesture { engine.startChat(in: nil) }
				.opacity(engine.running ? 0.4 : 1)


			// Saved chats (ChatHistory.swift), newest first; the open one is highlighted. Right-click deletes.
			if showSearch || searching { searchField }
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 2) {
					if query.isEmpty, engine.title != nil && history.chat(engine.currentChatID) == nil {
						RecentRow(title: engine.title ?? "", date: nil, current: true)
					}
					// Projects first, grouped like folders; then the ordinary chats (Pinned, Recent) below.
					if !searching { projectsSection }
					if !searching, !projects.items.isEmpty || !sections.isEmpty {
						SidebarSectionHeader(title: L("project.ordinary"), count: 0, collapsed: false, foldable: false, plain: true) {}
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
		.background(sidebarColor)
		.overlay(alignment: .trailing) { FB.divider.frame(width: 1) }
		.sheet(item: $projectEdit) { edit in
			ProjectSheet(editing: edit.project, cancel: { projectEdit = nil }) { name, folder, instructions in
				if let project = edit.project {
					projects.update(project.id, name: name, folder: folder, instructions: instructions)
					if engine.projectID == project.id { engine.refreshProject() }
				} else if let made = projects.add(name: name, folder: folder, instructions: instructions) {
					engine.startChat(in: made.id)
				}
				projectEdit = nil
			}
		}
		.confirmationDialog(L("project.delete"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
		                    presenting: deleting) { project in
			Button(L("project.delete"), role: .destructive) {
				if engine.projectID == project.id { engine.startChat(in: nil) }
				projects.remove(project.id)
			}
		} message: { _ in Text(L("project.deleteNote")) }
		.sheet(item: $renaming) { chat in
			RenameSheet(text: $renameText, cancel: { renaming = nil }) {
				history.rename(chat.id, to: renameText)
				renaming = nil
			}
		}
	}

	private func isCollapsed(_ project: Project) -> Bool { collapsedProjects.split(separator: ",").contains { $0 == project.id } }

	private func toggleCollapsed(_ project: Project) {
		var ids = collapsedProjects.split(separator: ",").map(String.init)
		if let i = ids.firstIndex(of: project.id) { ids.remove(at: i) } else { ids.append(project.id) }
		collapsedProjects = ids.joined(separator: ",")
	}

	// The projects, each a group like a folder: its name and chat count, a button for a new chat inside it, and its chats.
	@ViewBuilder
	private var projectsSection: some View {
		HStack {
			Text(L("chat.projects")).font(.system(size: 13)).foregroundStyle(FB.textTertiary)
			Spacer()
			Button { projectEdit = ProjectEdit(project: nil) } label: { FBIcon(name: "plus", size: 12, color: FB.textTertiary) }
				.buttonStyle(.plain).help(L("project.new"))
		}
		.padding(EdgeInsets(top: 14, leading: 10, bottom: 4, trailing: 10))
		ForEach(projects.items) { project in projectGroup(project) }
	}

	@ViewBuilder
	private func projectGroup(_ project: Project) -> some View {
		let chats = ProjectLogic.scope(history.chats, projectID: project.id).filter { !$0.isArchived }
			.sorted { ($0.isPinned ? 1 : 0, $0.updated) > ($1.isPinned ? 1 : 0, $1.updated) }
		let collapsed = isCollapsed(project)
		HStack(spacing: 6) {
			FBIcon(name: collapsed ? "chevron-right" : "chevron-down", size: 10, color: FB.textTertiary)
			FBIcon(name: "folder", size: 14, color: Accent.amber.color)
			Text(project.name).font(.system(size: 13, weight: engine.projectID == project.id ? .semibold : .regular))
				.foregroundStyle(FB.text).lineLimit(1)
			Text("\(chats.count)").font(.system(size: 11)).foregroundStyle(FB.textTertiary)
			Spacer(minLength: 0)
			Button { engine.startChat(in: project.id) } label: { FBIcon(name: "plus", size: 12, color: FB.textSecondary) }
				.buttonStyle(.plain).help(L("project.newChatIn"))
		}
		.padding(.horizontal, 10).frame(height: 30)
		.contentShape(Rectangle())
		.onTapGesture { toggleCollapsed(project) }
		.help(project.folder.isEmpty ? project.name : project.folder)
		.contextMenu {
			Button(L("project.newChatIn")) { engine.startChat(in: project.id) }
			Button(L("project.edit.menu")) { projectEdit = ProjectEdit(project: project) }
			Divider()
			Button(L("project.delete"), role: .destructive) { deleting = project }
		}
		if !collapsed {
			if chats.isEmpty {
				Text(L("project.empty")).font(.fbCaption).foregroundStyle(FB.textTertiary).padding(.horizontal, 26).padding(.vertical, 4)
			}
			ForEach(chats.prefix(8)) { chat in chatRow(chat).padding(.leading, 12) }
		}
	}

	// One group: a heading that folds it (not while searching, so matches are never hidden), then its chats.
	@ViewBuilder
	private func sectionView(_ section: ChatSection) -> some View {
		let kind = section.kind
		let collapsed = kind == .pinned ? pinnedCollapsed : kind == .recent ? recentCollapsed : false
		let title = kind == .pinned ? L("chat.pinned") : kind == .recent ? L("chat.recent") : L("chat.archived")
		SidebarSectionHeader(title: title, count: section.chats.count + section.hidden,
		                     collapsed: collapsed && !searching, foldable: !searching && kind != .archived, plain: true) {
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
				Menu(L("project.moveTo")) {
					ForEach(projects.items) { project in
						Button(project.name) { engine.move(chat.id, to: project.id) }.disabled(chat.projectID == project.id)
					}
					if chat.projectID != nil { Divider(); Button(L("project.ordinary")) { engine.move(chat.id, to: nil) } }
				}
				.disabled(projects.items.isEmpty && chat.projectID == nil)
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
			TextField(L("history.search"), text: $query).textFieldStyle(.plain).font(.system(size: 13)).focused($searchFocused)
			if !query.isEmpty {
				Button { query = "" } label: { FBIcon(name: "close", size: 11, color: FB.textTertiary) }.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 10).frame(height: 30)
		.background(RoundedRectangle(cornerRadius: 9).fill(FB.hoverOnChrome))
		.padding(.bottom, 4)
	}

	// Saves one chat as a Markdown file wherever the person picks.
	private func export(_ chat: SavedChat) { ChatExport.save(chat, history: history) }
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
				Text(title).font(.system(size: 13.5, weight: current ? .medium : .regular)).foregroundStyle(FB.text).lineLimit(1)
				if let snippet { Text(snippet).font(.system(size: 11)).foregroundStyle(FB.textTertiary).lineLimit(1) }
			}
			Spacer(minLength: 4)
			// While the pointer is on the row, a pin button shows (no date: the list is ordered by it already).
			if hover, let togglePin {
				Button(action: togglePin) {
					FBIcon(name: "pin", size: 13, color: pinned ? FB.primaryText : FB.textSecondary)
						.frame(width: 22, height: 22).contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.help(pinned ? L("history.unpin") : L("history.pin"))
			}
		}
		.padding(.horizontal, 10)
		.frame(height: snippet == nil ? 34 : 44)
		.background(RoundedRectangle(cornerRadius: 10).fill(current ? Color.primary.opacity(0.08) : (hover ? Color.primary.opacity(0.04) : .clear)))
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
	// Plain: just the muted name, with the chevron shown only while the pointer is on it (the ChatGPT look).
	var plain = false
	let toggle: () -> Void
	@State private var hover = false

	var body: some View {
		Button(action: toggle) {
			if plain {
				HStack(spacing: 5) {
					Text(title).font(.system(size: 13)).foregroundStyle(FB.textTertiary)
					Spacer(minLength: 0)
					FBIcon(name: collapsed ? "chevron-right" : "chevron-down", size: 10, color: FB.textTertiary)
						.opacity(hover && foldable ? 1 : 0)
				}
				.padding(EdgeInsets(top: 14, leading: 10, bottom: 4, trailing: 10))
				.contentShape(Rectangle())
			} else {
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

// What the project window is doing: making a new project (project nil) or changing one.
struct ProjectEdit: Identifiable {
	let project: Project?
	var id: String { project?.id ?? "new" }
}
