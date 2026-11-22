import Foundation

// Adding a task from the Tasks page: `yana-rt task create <name>`. The rest of the bridge only reads; this one write
// is explicit (a typed name and a button) and goes into the workspace's own task list, which the Tasks page reads.

enum TaskDraft {
	static let maxLength = 200

	// What gets sent for what was typed: one line, trimmed, no leading dashes (they would be read as an option),
	// cut at maxLength. Nil when nothing is left.
	static func clean(_ raw: String) -> String? {
		let oneLine = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
		let spaced = oneLine.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
		let noDashes = String(spaced.drop { $0 == "-" || $0 == " " }).trimmingCharacters(in: .whitespaces)
		guard !noDashes.isEmpty else { return nil }
		return String(noDashes.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
	}
}

extension RtClient {
	// Nil when the task was created, otherwise a message for the person.
	static func createTask(name: String) -> String? {
		guard let clean = TaskDraft.clean(name) else { return L("tasks.emptyName") }
		do {
			let made = try run(["task", "create", clean], as: AnyJSON.self).value
			return made["id"] is String ? nil : L("tasks.createFailed")
		} catch let error as RtError {
			return error.message
		} catch {
			return error.localizedDescription
		}
	}
}

let taskCreateRows: [StringRow] = [
	StringRow("tasks.addPrompt", "Thêm công việc mới", "Add a new task", "새 작업 추가"),
	StringRow("tasks.add", "Thêm", "Add", "추가"),
	StringRow("tasks.emptyName", "Hãy gõ tên công việc trước.", "Type the task's name first.", "작업 이름을 먼저 입력하세요."),
	StringRow("tasks.createFailed", "yana-rt không tạo được công việc.", "yana-rt could not create the task.", "yana-rt가 작업을 만들지 못했습니다."),
]
