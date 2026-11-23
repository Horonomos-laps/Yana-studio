import AppKit
import SwiftUI

// Coding agents running outside Yana's own chat, above all in Yana Studio's terminal: Claude Code and Codex. The notch
// has to know about them because that is where much of the work happens. They tell Yana through small event files:
// a hook of the agent writes its event, as JSON, into a folder; Yana reads and deletes each file once. No network and no
// background program. The idea (event files in a watched folder, the states working / waiting / done, and an agent that
// stops without a word being noticed by its transcript) is credited to notchd in CREDITS.md. The code is Yana's.

struct AgentSession: Equatable, Identifiable {
	enum Tool: String { case claude = "Claude Code", codex = "Codex" }
	enum State: Equatable { case working, waiting, done }

	var id: String
	var tool: Tool
	var cwd: String
	var state: State
	var message: String?
	var updated: Date
	var appBundleID: String?       // the app in front when the prompt was sent: Yana Studio, a terminal, an editor

	var project: String { cwd.isEmpty ? tool.rawValue : (cwd as NSString).lastPathComponent }
}

enum AgentEvents {
	static let workingTimeout: TimeInterval = 600       // a turn that sent nothing for 10 minutes is over
	static let waitingTimeout: TimeInterval = 7_200
	static let doneTimeout: TimeInterval = 300
	static let maxMessage = 160

	// Permission requests and questions need the person; idle reminders and sign-in notices do not.
	static func needsYou(_ json: [String: Any]) -> Bool {
		if let type = json["notification_type"] as? String { return type == "permission_prompt" || type == "elicitation_dialog" }
		let message = (json["message"] as? String ?? "").lowercased()
		return !message.isEmpty && !message.contains("waiting for your input")
	}

	private static func clip(_ text: String?) -> String? {
		guard let text else { return nil }
		let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
		return flat.isEmpty ? nil : String(flat.prefix(maxMessage))
	}

	// One event applied to the list of sessions. Unknown events change nothing.
	static func apply(_ sessions: [AgentSession], json: [String: Any], now: Date = Date(), frontmost: String? = nil) -> [AgentSession] {
		let cwd = json["cwd"] as? String ?? ""
		var out = sessions
		func upsert(_ id: String, tool: AgentSession.Tool, state: AgentSession.State, message: String?, app: String? = nil) {
			var s = out.first { $0.id == id } ?? AgentSession(id: id, tool: tool, cwd: cwd, state: state, message: nil, updated: now, appBundleID: app)
			s.state = state; s.message = message; s.updated = now
			if !cwd.isEmpty { s.cwd = cwd }
			if let app { s.appBundleID = app }
			out.removeAll { $0.id == id }
			out.append(s)
		}
		// Codex's notify command reports only a finished turn.
		if let type = json["type"] as? String {
			guard type == "agent-turn-complete" else { return sessions }
			upsert(json["thread-id"] as? String ?? cwd, tool: .codex, state: .done, message: clip(json["last-assistant-message"] as? String))
			return out
		}
		guard let event = json["hook_event_name"] as? String else { return sessions }
		let id = json["session_id"] as? String ?? cwd
		switch event {
		case "UserPromptSubmit":
			upsert(id, tool: .claude, state: .working, message: clip(json["prompt"] as? String), app: frontmost)
		case "PreToolUse", "PostToolUse":
			// Only an ongoing turn; a tool event is no news for a session that is not known.
			guard let known = out.first(where: { $0.id == id }) else { return sessions }
			upsert(id, tool: .claude, state: .working, message: known.message)
		case "Notification":
			guard needsYou(json) else { return sessions }
			upsert(id, tool: .claude, state: .waiting, message: clip(json["message"] as? String))
		case "Stop":
			upsert(id, tool: .claude, state: .done, message: out.first(where: { $0.id == id })?.message)
		case "StopFailure", "SessionEnd":
			out.removeAll { $0.id == id }
		default:
			return sessions
		}
		return out
	}

	// Drops sessions that have been silent too long.
	static func expire(_ sessions: [AgentSession], now: Date = Date()) -> [AgentSession] {
		sessions.filter { s in
			let age = now.timeIntervalSince(s.updated)
			switch s.state {
			case .working: return age < workingTimeout
			case .waiting: return age < waitingTimeout
			case .done: return age < doneTimeout
			}
		}
	}

	// What the notch shows overall: waiting wins over working; nothing when only finished sessions are left.
	static func overall(_ sessions: [AgentSession]) -> YanaRun.State? {
		if sessions.contains(where: { $0.state == .waiting }) { return .waiting }
		if sessions.contains(where: { $0.state == .working }) { return .working }
		return nil
	}
}

@MainActor
final class AgentMonitor: ObservableObject {
	static let shared = AgentMonitor()
	@Published private(set) var sessions: [AgentSession] = []
	private var timer: Timer?

	// Sessions to show: the ones at work or waiting first (waiting on top), then the recently finished.
	var shown: [AgentSession] {
		sessions.sorted { a, b in
			func rank(_ s: AgentSession) -> Int { s.state == .waiting ? 0 : s.state == .working ? 1 : 2 }
			return (rank(a), b.updated) < (rank(b), a.updated)
		}
	}

	// The folder the hooks write into. YANA_AGENTS_DIR points it elsewhere (for tests).
	static var spool: URL {
		if let dir = ProcessInfo.processInfo.environment["YANA_AGENTS_DIR"] { return URL(fileURLWithPath: dir, isDirectory: true) }
		return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("YanaApp/Agents", isDirectory: true)
	}

	func start() {
		guard timer == nil else { return }
		try? FileManager.default.createDirectory(at: Self.spool, withIntermediateDirectories: true)
		drain(maxAge: 60)      // events written while Yana was not looking are history, not news
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			Task { @MainActor in self?.tick() }
		}
	}

	func stop() { timer?.invalidate(); timer = nil; sessions = [] }

	private func tick() {
		drain(maxAge: AgentEvents.workingTimeout)
		let kept = AgentEvents.expire(sessions)
		if kept != sessions { sessions = kept }
	}

	// Reads and deletes every finished event file. Hooks write a hidden temporary file and rename it, so a file without a
	// leading dot is whole.
	private func drain(maxAge: TimeInterval) {
		let keys: [URLResourceKey] = [.creationDateKey]
		let files = ((try? FileManager.default.contentsOfDirectory(at: Self.spool, includingPropertiesForKeys: keys)) ?? [])
			.filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(".") }
			.sorted { Self.created($0) < Self.created($1) }
		for file in files {
			defer { try? FileManager.default.removeItem(at: file) }
			guard Date().timeIntervalSince(Self.created(file)) <= maxAge,
			      let data = try? Data(contentsOf: file),
			      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
			let next = AgentEvents.apply(sessions, json: json, frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
			if next != sessions { sessions = next }
		}
	}

	private static func created(_ url: URL) -> Date {
		(try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
	}

	// Brings the app the session was started from back to the front (Yana Studio, a terminal, an editor).
	func focus(_ session: AgentSession) {
		guard let id = session.appBundleID, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { return }
		app.activate()
	}
}
