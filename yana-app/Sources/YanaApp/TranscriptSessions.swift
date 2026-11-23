import Foundation

// Claude Code sessions seen without any hook. Claude Code keeps a log of every session as a .jsonl file under
// ~/.claude/projects/<folder>/, and writes to it while it works. So a log that changed a moment ago is a session at work,
// and one whose last entry is a finished answer is a session that is done. This needs no setup and no restart, so a
// session already running (in Yana Studio's terminal or anywhere) shows at once. It cannot tell "waiting for your
// permission" from "running a long command"; the hooks (AgentHooks.swift) say that precisely when they are connected, and win.

struct TranscriptInfo: Equatable {
	var id: String
	var cwd: String
	var lastRole: String?          // "user" or "assistant"
	var lastHadToolUse: Bool       // the last assistant entry asked to run a tool
	var modified: Date
}

enum TranscriptSessions {
	static let workingWindow: TimeInterval = 8       // written within this: it is working
	static let toolWindow: TimeInterval = 90         // a tool was asked for and nothing came back yet: probably still running it
	static let doneWindow: TimeInterval = 120        // a finished answer this recent is shown as done
	static let looksBack: TimeInterval = 600         // logs older than this are not even opened
	static let tailBytes = 65_536

	// The last entries of a log: its folder, and what the last real entry was. Lines that are cut or not JSON are skipped
	// (the first line of a tail is usually cut in the middle).
	static func parse(tail: String, id: String, modified: Date) -> TranscriptInfo {
		var cwd = "", role: String?, tool = false
		for line in tail.split(separator: "\n") {
			guard let data = line.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
			if let c = json["cwd"] as? String, !c.isEmpty { cwd = c }
			guard let type = json["type"] as? String, type == "user" || type == "assistant" else { continue }
			role = type
			let content = (json["message"] as? [String: Any])?["content"]
			tool = type == "assistant" && ((content as? [[String: Any]]) ?? []).contains { $0["type"] as? String == "tool_use" }
		}
		return TranscriptInfo(id: id, cwd: cwd, lastRole: role, lastHadToolUse: tool, modified: modified)
	}

	// The session this log shows now, or nil when it is old, or empty of real entries.
	static func session(from info: TranscriptInfo, now: Date = Date()) -> AgentSession? {
		guard info.lastRole != nil else { return nil }
		let age = now.timeIntervalSince(info.modified)
		var state: AgentSession.State?
		if age <= workingWindow { state = .working }
		else if info.lastRole == "user" && age <= toolWindow { state = .working }                // it is thinking over what it was sent
		else if info.lastHadToolUse && age <= toolWindow { state = .working }                    // running the tool
		else if info.lastRole == "assistant" && !info.lastHadToolUse && age <= doneWindow { state = .done }
		guard let state else { return nil }
		return AgentSession(id: info.id, tool: .claude, cwd: info.cwd, state: state, message: nil, updated: info.modified, appBundleID: nil)
	}

	// Hook sessions and log sessions together, one per id, the more recent of the two for an id both know. A hook knows more
	// (it says waiting), so when it is as recent or newer it is the one kept.
	static func merge(hooks: [AgentSession], logs: [AgentSession]) -> [AgentSession] {
		var byID: [String: AgentSession] = [:]
		for s in logs { byID[s.id] = s }
		for h in hooks {
			if let l = byID[h.id], l.updated > h.updated, l.state == .working, h.state != .waiting {
				var s = l; s.message = h.message ?? l.message; s.appBundleID = h.appBundleID ?? l.appBundleID; byID[h.id] = s
			} else {
				byID[h.id] = h
			}
		}
		return Array(byID.values)
	}

	static var root: URL {
		if let dir = ProcessInfo.processInfo.environment["YANA_CLAUDE_PROJECTS"] { return URL(fileURLWithPath: dir, isDirectory: true) }
		return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
	}

	// Looks at the recent logs under `root` (one level of folders, like Claude Code lays them out) and reads their tails.
	static func scan(root: URL = root, now: Date = Date()) -> [AgentSession] {
		let files = FileManager.default
		guard let folders = try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
		var out: [AgentSession] = []
		for folder in folders {
			guard let logs = try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
			for log in logs where log.pathExtension == "jsonl" {
				guard let modified = (try? log.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
				      now.timeIntervalSince(modified) <= looksBack, let text = tail(of: log) else { continue }
				let info = parse(tail: text, id: log.deletingPathExtension().lastPathComponent, modified: modified)
				if let session = session(from: info, now: now) { out.append(session) }
			}
		}
		return out
	}

	private static func tail(of url: URL) -> String? {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
		defer { try? handle.close() }
		let size = (try? handle.seekToEnd()) ?? 0
		try? handle.seek(toOffset: size > UInt64(tailBytes) ? size - UInt64(tailBytes) : 0)
		return (try? handle.readToEnd()).map { String(decoding: $0, as: UTF8.self) }
	}
}
