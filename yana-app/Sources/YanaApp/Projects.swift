import AppKit
import SwiftUI

// Projects, like the ones in Claude and ChatGPT: a place for work that stays apart from ordinary chats. A project has a
// name, an optional folder (where Yana works while the project is open) and its own instructions, which Yana follows in
// every chat of the project. Chats started inside a project belong to it and appear only there; the rest are ordinary
// chats. Deleting a project keeps its chats and turns them into ordinary ones.

struct Project: Codable, Identifiable, Equatable {
	var id: String = UUID().uuidString.lowercased()
	var name: String
	var folder: String = ""          // empty: no folder of its own, the usual working folder is kept
	var instructions: String = ""
	var created: Date = Date()
}

enum ProjectLogic {
	static let maxName = 60
	static let maxInstructions = 8_000

	static func cleanName(_ text: String) -> String {
		String(text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces).prefix(maxName))
	}

	static func cleanInstructions(_ text: String) -> String {
		String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxInstructions))
	}

	// A project needs a name; the folder, when given, must be a directory that exists (checked by the caller with a closure
	// so this stays testable).
	static func isValid(name: String, folder: String, isDirectory: (String) -> Bool = { path in
		var isDir: ObjCBool = false
		return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
	}) -> Bool {
		!cleanName(name).isEmpty && (folder.isEmpty || isDirectory(folder))
	}

	static func add(_ list: [Project], name: String, folder: String, instructions: String) -> [Project] {
		let clean = cleanName(name)
		guard !clean.isEmpty else { return list }
		return list + [Project(name: clean, folder: folder, instructions: cleanInstructions(instructions))]
	}

	static func update(_ list: [Project], id: String, name: String, folder: String, instructions: String) -> [Project] {
		let clean = cleanName(name)
		guard !clean.isEmpty else { return list }
		return list.map { $0.id == id ? Project(id: $0.id, name: clean, folder: folder, instructions: cleanInstructions(instructions), created: $0.created) : $0 }
	}

	static func remove(_ list: [Project], id: String) -> [Project] { list.filter { $0.id != id } }

	// What Yana is told in every chat of the project: where it is, and the person's own instructions.
	static func instruction(for project: Project) -> String {
		var text = "This chat belongs to the project \"\(project.name)\". Keep to that project."
		if !project.instructions.isEmpty {
			text += "\nInstructions for this project, from the user. Follow them in every reply unless a request says otherwise:\n\(project.instructions)"
		}
		return text
	}

	// The chats that belong to a project (nil: the ordinary chats, which belong to none).
	static func scope(_ chats: [SavedChat], projectID: String?) -> [SavedChat] { chats.filter { $0.projectID == projectID } }

	// How many chats each project holds.
	static func counts(_ chats: [SavedChat]) -> [String: Int] {
		var out: [String: Int] = [:]
		for chat in chats where !chat.isArchived { if let id = chat.projectID { out[id, default: 0] += 1 } }
		return out
	}
}

@MainActor
final class ProjectStore: ObservableObject {
	static let shared = ProjectStore()
	private static let key = "yana.projects"
	// YANA_PROJECTS (a JSON list) replaces the saved list for a run, to check the sidebar without touching real projects.
	@Published private(set) var items: [Project] = {
		if let json = ProcessInfo.processInfo.environment["YANA_PROJECTS"], let list = try? JSONDecoder().decode([Project].self, from: Data(json.utf8)) { return list }
		return UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([Project].self, from: $0) } ?? []
	}()

	func project(_ id: String?) -> Project? { id.flatMap { id in items.first { $0.id == id } } }

	@discardableResult
	func add(name: String, folder: String, instructions: String) -> Project? {
		let before = items.count
		set(ProjectLogic.add(items, name: name, folder: folder, instructions: instructions))
		return items.count > before ? items.last : nil
	}

	func update(_ id: String, name: String, folder: String, instructions: String) {
		set(ProjectLogic.update(items, id: id, name: name, folder: folder, instructions: instructions))
	}

	// Removes the project; its chats stay and become ordinary chats.
	func remove(_ id: String) {
		set(ProjectLogic.remove(items, id: id))
		ChatHistoryStore.shared.releaseProject(id)
	}

	private func set(_ new: [Project]) {
		items = new
		if let data = try? JSONEncoder().encode(new) { UserDefaults.standard.set(data, forKey: Self.key) }
	}
}

// The window to make or change a project.
struct ProjectSheet: View {
	var editing: Project?
	let cancel: () -> Void
	let save: (String, String, String) -> Void
	@State private var name = ""
	@State private var folder = ""
	@State private var instructions = ""

	private var valid: Bool { ProjectLogic.isValid(name: name, folder: folder) }

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(L(editing == nil ? "project.new" : "project.edit")).font(.system(size: 16, weight: .semibold)).foregroundStyle(FB.text)
			Text(L("project.name")).font(.fbCaption).foregroundStyle(FB.textSecondary)
			TextField(L("project.nameHint"), text: $name).textFieldStyle(.roundedBorder)
			Text(L("project.folder")).font(.fbCaption).foregroundStyle(FB.textSecondary)
			HStack {
				Text(folder.isEmpty ? L("project.noFolder") : folder).font(.fbCaption).foregroundStyle(FB.textSecondary)
					.lineLimit(1).truncationMode(.middle)
				Spacer()
				if !folder.isEmpty { Button(L("project.clearFolder")) { folder = "" } }
				Button(L("set.choose")) { chooseFolder() }
			}
			Text(L("project.instructions")).font(.fbCaption).foregroundStyle(FB.textSecondary)
			TextEditor(text: $instructions).font(.system(size: 12)).frame(height: 120)
				.overlay(RoundedRectangle(cornerRadius: 6).stroke(FB.divider)).scrollContentBackground(.hidden)
			Text(L("project.note")).font(.fbCaption).foregroundStyle(FB.textTertiary)
			HStack {
				Spacer()
				FBButton(title: L("store.cancel"), variant: .secondary, size: .small, action: cancel)
				FBButton(title: L("history.save"), variant: .primary, size: .small) { if valid { save(name, folder, instructions) } }
					.opacity(valid ? 1 : 0.45)
			}
		}
		.padding(20).frame(width: 440).background(FB.canvas)
		.onAppear {
			if let editing { name = editing.name; folder = editing.folder; instructions = editing.instructions }
		}
	}

	private func chooseFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		if panel.runModal() == .OK, let url = panel.url { folder = url.path }
	}
}

let projectRows: [StringRow] = [
	StringRow("project.new", "Dự án mới", "New project", "새 프로젝트"),
	StringRow("project.edit", "Sửa dự án", "Edit project", "프로젝트 편집"),
	StringRow("project.name", "Tên dự án", "Project name", "프로젝트 이름"),
	StringRow("project.nameHint", "Ví dụ: Website công ty", "For example: Company website", "예: 회사 웹사이트"),
	StringRow("project.folder", "Thư mục làm việc (tùy chọn)", "Working folder (optional)", "작업 폴더(선택)"),
	StringRow("project.noFolder", "Dùng thư mục mặc định", "Use the usual folder", "기본 폴더 사용"),
	StringRow("project.clearFolder", "Bỏ", "Clear", "지우기"),
	StringRow("project.instructions", "Hướng dẫn cho dự án này", "Instructions for this project", "이 프로젝트 지침"),
	StringRow("project.note", "Yana làm theo hướng dẫn này trong mọi đoạn chat của dự án. Đoạn chat thường không bị ảnh hưởng.", "Yana follows these in every chat of the project. Ordinary chats are not affected.", "Yana는 이 프로젝트의 모든 대화에서 이 지침을 따릅니다. 일반 대화에는 영향이 없습니다."),
	StringRow("project.ordinary", "Chat thường", "Ordinary chats", "일반 대화"),
	StringRow("project.edit.menu", "Sửa dự án…", "Edit project…", "프로젝트 편집…"),
	StringRow("project.delete", "Xóa dự án", "Delete project", "프로젝트 삭제"),
	StringRow("project.deleteNote", "Các đoạn chat của dự án được giữ lại và thành chat thường.", "Its chats are kept and become ordinary chats.", "대화는 유지되며 일반 대화가 됩니다."),
	StringRow("project.chats", "đoạn chat", "chats", "대화"),
	StringRow("project.moveTo", "Chuyển vào dự án", "Move to project", "프로젝트로 이동"),
	StringRow("project.newChatIn", "Đoạn chat mới trong dự án", "New chat in this project", "이 프로젝트에서 새 대화"),
	StringRow("project.empty", "Chưa có đoạn chat. Bấm + để bắt đầu.", "No chats yet. Press + to start one.", "대화가 없습니다. +를 눌러 시작하세요."),
	StringRow("project.inProject", "Trong dự án", "In project", "프로젝트 내"),
]
