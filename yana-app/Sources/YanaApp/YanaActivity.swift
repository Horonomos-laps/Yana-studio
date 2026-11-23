import Foundation
import SwiftUI

// What the notch shows about Yana's own work: is a reply being written, is a command waiting for a yes or no, what was
// asked, what was answered, how many tokens. Built from the chat's lines by a pure function so it can be tested; the
// app pushes the chat into it whenever the chat changes. The "one row per run" idea is credited to OneNotch's
// coding-agents page in CREDITS.md.

struct YanaRun: Equatable {
	enum State: Equatable { case idle, working, waiting }

	var state: State = .idle
	var question = ""            // the last thing the person asked
	var reply = ""               // the latest answer text (may still be growing)
	var inputTokens = 0
	var outputTokens = 0
	var askCount = 0             // approval cards in this chat
	var waitingFor: String?      // what the open approval card wants to run, e.g. the capability name

	var isActive: Bool { state != .idle }

	static let maxQuestion = 140, maxReply = 240

	static func make(lines: [ChatLine], running: Bool) -> YanaRun {
		var run = YanaRun()
		run.question = clip(lines.last(where: { $0.role == .user })?.raw ?? lines.last(where: { $0.role == .user })?.text ?? "", maxQuestion)
		run.reply = clip(lines.last(where: { $0.role == .assistant && !$0.text.isEmpty })?.text ?? "", maxReply)
		run.inputTokens = lines.reduce(0) { $0 + $1.inputTokens }
		run.outputTokens = lines.reduce(0) { $0 + $1.outputTokens }
		run.askCount = lines.filter { $0.approval != nil }.count
		if let open = lines.last(where: { $0.approval != nil && $0.approval?.decided == nil })?.approval {
			run.waitingFor = open.capability
			run.state = .waiting
		} else if running {
			run.state = .working
		}
		return run
	}

	// One line of text with no line breaks, cut to a length with an ellipsis.
	static func clip(_ text: String, _ limit: Int) -> String {
		let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
		return flat.count > limit ? String(flat.prefix(limit - 1)) + "…" : flat
	}

	// "12.3k" style so a count fits a small chip.
	static func short(_ n: Int) -> String {
		n < 1000 ? "\(n)" : n < 10_000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n / 1000)k"
	}
}

@MainActor
final class YanaActivity: ObservableObject {
	static let shared = YanaActivity()
	@Published private(set) var run = YanaRun()
	@Published private(set) var startedAt: Date?
	@Published private(set) var model = ""
	@Published private(set) var project = ""
	@Published private(set) var branch = ""
	// Set by the app: answers the open approval card the same way its buttons in the chat do.
	var decide: ((Bool) -> Void)?

	func update(lines: [ChatLine], running: Bool, model: String?, provider: String, workspace: String) {
		let next = YanaRun.make(lines: lines, running: running)
		if next.isActive, !run.isActive { startedAt = Date() }
		if !next.isActive { startedAt = nil }
		if next != run { run = next }
		let label = [provider, model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
		if label != self.model { self.model = label }
		let name = (workspace as NSString).lastPathComponent
		if name != project { project = name; loadBranch(workspace) }
	}

	private func loadBranch(_ workspace: String) {
		branch = ""
		DispatchQueue.global(qos: .utility).async { [weak self] in
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
			process.arguments = ["-C", workspace, "rev-parse", "--abbrev-ref", "HEAD"]
			let pipe = Pipe()
			process.standardOutput = pipe
			process.standardError = Pipe()
			guard (try? process.run()) != nil else { return }
			process.waitUntilExit()
			let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
				.trimmingCharacters(in: .whitespacesAndNewlines)
			let value = process.terminationStatus == 0 ? text : ""
			Task { @MainActor in self?.branch = value }
		}
	}
}
