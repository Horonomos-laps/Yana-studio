import AppKit
import SwiftUI

// A shelf in the notch: files dragged there wait to be dragged out, sent by AirDrop or attached to the chat. Only the
// paths are remembered, for a day; Yana never copies, moves or deletes the files. The idea comes from NotchDrop (see
// CREDITS.md); the code is Yana's.

struct ShelfItem: Codable, Equatable, Identifiable {
	var path: String
	var added: Date
	var id: String { path }
	var url: URL { URL(fileURLWithPath: path) }
}

enum Shelf {
	static let limit = 20
	static let lifetime: TimeInterval = 24 * 60 * 60
	static let dropSize = CGSize(width: 400, height: 90)

	// Newest first; a file already there moves to the front.
	static func adding(_ urls: [URL], to items: [ShelfItem], now: Date) -> [ShelfItem] {
		var seen = Set<String>()
		let fresh = urls.filter(\.isFileURL).map { ShelfItem(path: $0.path, added: now) }
		return Array((fresh + items).filter { seen.insert($0.path).inserted }.prefix(limit))
	}

	static func kept(_ items: [ShelfItem], now: Date, exists: (String) -> Bool) -> [ShelfItem] {
		items.filter { now.timeIntervalSince($0.added) < lifetime && exists($0.path) }
	}

	// The picked items, or all of them when none that is picked is still there.
	static func targets(_ items: [ShelfItem], selected: Set<String>) -> [ShelfItem] {
		let picked = items.filter { selected.contains($0.path) }
		return picked.isEmpty ? items : picked
	}

	// The drag pasteboard changes when a drag starts, so an unchanged count means no new drag.
	static func isFileDrag(countAtMouseDown: Int, countNow: Int, carriesFiles: Bool) -> Bool {
		countNow != countAtMouseDown && carriesFiles
	}

	// Where a dragged file opens the notch, in screen coordinates (origin bottom left).
	static func dropZone(screenFrame: CGRect) -> CGRect {
		CGRect(x: screenFrame.midX - dropSize.width / 2, y: screenFrame.maxY - dropSize.height,
		       width: dropSize.width, height: dropSize.height + 1)
	}
}

@MainActor
final class ShelfStore: ObservableObject {
	static let shared = ShelfStore()
	private static let key = "yana.notch.shelf"
	@Published private(set) var items: [ShelfItem] = []
	@Published var selected: Set<String> = []

	private init() {
		items = UserDefaults.standard.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([ShelfItem].self, from: $0) } ?? []
		prune()
	}

	func add(_ urls: [URL]) { set(Shelf.adding(urls, to: items, now: Date())) }
	func remove(_ path: String) { set(items.filter { $0.path != path }) }
	func clear() { set([]) }
	func prune() { set(Shelf.kept(items, now: Date()) { FileManager.default.fileExists(atPath: $0) }) }

	private func set(_ value: [ShelfItem]) {
		selected.formIntersection(value.map(\.path))
		guard value != items else { return }
		items = value
		if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: Self.key) }
	}

	// Reads the file addresses out of a drop.
	static func accept(_ providers: [NSItemProvider], then done: @escaping @MainActor () -> Void) -> Bool {
		let usable = providers.filter { $0.canLoadObject(ofClass: URL.self) }
		for provider in usable {
			_ = provider.loadObject(ofClass: URL.self) { url, _ in
				guard let url, url.isFileURL else { return }
				Task { @MainActor in ShelfStore.shared.add([url]); done() }
			}
		}
		return !usable.isEmpty
	}

	var targetURLs: [URL] { Shelf.targets(items, selected: selected).map(\.url) }

	func sendByAirDrop() {
		prune()
		let urls = targetURLs
		guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else { return }
		NSApp.activate(ignoringOtherApps: true)
		service.perform(withItems: urls)
	}

	// Folders cannot be attached to a message.
	var attachableURLs: [URL] { targetURLs.filter { !$0.hasDirectoryPath && !isFolder($0) } }

	private func isFolder(_ url: URL) -> Bool {
		var folder: ObjCBool = false
		return FileManager.default.fileExists(atPath: url.path, isDirectory: &folder) && folder.boolValue
	}

	func attachToChat() {
		prune()
		let urls = attachableURLs
		guard !urls.isEmpty else { return }
		ChatInbox.send(urls)
		NSApp.activate(ignoringOtherApps: true)
		_ = WindowKeeper.show()
	}
}

// Files handed to the chat from outside the window. They wait here until the window takes them.
@MainActor
enum ChatInbox {
	static let arrived = Notification.Name("yana.chat.inbox")
	private static var waiting: [URL] = []

	static func send(_ urls: [URL]) {
		waiting.append(contentsOf: urls)
		NotificationCenter.default.post(name: arrived, object: nil)
	}

	static func take() -> [URL] {
		defer { waiting = [] }
		return waiting
	}
}

struct FilesTab: View {
	@ObservedObject private var store = ShelfStore.shared

	var body: some View {
		VStack(spacing: 8) {
			if store.items.isEmpty {
				VStack(spacing: 6) {
					Image(systemName: "tray.and.arrow.down").font(.system(size: 22))
					Text(L("notch.filesEmpty")).font(.system(size: 11)).multilineTextAlignment(.center)
				}
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
			} else {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) { ForEach(store.items) { ShelfTile(item: $0) } }
				}
				.frame(maxHeight: .infinity)
				HStack(spacing: 8) {
					action("notch.airdrop", "dot.radiowaves.left.and.right") { store.sendByAirDrop() }
					action("notch.attach", "paperclip") { store.attachToChat() }.disabled(store.attachableURLs.isEmpty)
					Spacer()
					action("notch.clear", "xmark") { store.clear() }
				}
			}
		}
		.onAppear { store.prune() }
	}

	private func action(_ key: String, _ symbol: String, run: @escaping () -> Void) -> some View {
		Button(action: run) {
			Label(L(key), systemImage: symbol).font(.system(size: 11, weight: .semibold))
				.padding(.horizontal, 10).padding(.vertical, 5)
				.background(Color.primary.opacity(0.12), in: Capsule())
		}
		.buttonStyle(.plain)
	}
}

private struct ShelfTile: View {
	let item: ShelfItem
	@ObservedObject private var store = ShelfStore.shared

	var body: some View {
		let picked = store.selected.contains(item.path)
		VStack(spacing: 4) {
			Image(nsImage: NSWorkspace.shared.icon(forFile: item.path)).resizable().scaledToFit().frame(width: 40, height: 40)
			Text(item.url.lastPathComponent).font(.system(size: 10)).lineLimit(2).truncationMode(.middle)
				.multilineTextAlignment(.center)
		}
		.padding(8).frame(width: 88).frame(maxHeight: .infinity)
		.background(Color.primary.opacity(picked ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.contentShape(Rectangle())
		.onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
		.onTapGesture { if picked { store.selected.remove(item.path) } else { store.selected.insert(item.path) } }
		.onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
		.help(item.path)
		.contextMenu {
			Button(L("notch.fileOpen")) { NSWorkspace.shared.open(item.url) }
			Button(L("notch.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
			Button(L("notch.remove")) { store.remove(item.path) }
		}
		.accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
	}
}
