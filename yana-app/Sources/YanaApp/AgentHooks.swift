import Foundation

// Connecting Claude Code to the notch: one hook per event in the agent's own settings file, each writing the event JSON
// into Yana's folder. It only changes the file when the person presses Connect, always saves a copy first, and
// Disconnect removes exactly what was added. The hook does nothing unless Yana is running, so closing Yana leaves nothing
// behind to pile up.

enum AgentHooks {
	static let marker = "YanaApp/Agents"
	static let events = ["UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd"]

	// Writes stdin to a hidden file, then renames it, so the reader never sees half a file.
	static let command = #"pgrep -xq YanaApp || exit 0; d="$HOME/Library/Application Support/YanaApp/Agents"; mkdir -p "$d" && t="$d/.$(uuidgen)" && cat > "$t" && mv "$t" "$d/$(uuidgen).json""#

	static var claudeSettings: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json") }

	// MARK: Pure editing of the settings dictionary

	private static func describes(_ group: [String: Any]) -> Bool {
		(group["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
	}

	static func isConnected(_ settings: [String: Any]) -> Bool {
		let hooks = settings["hooks"] as? [String: Any] ?? [:]
		return events.allSatisfy { event in (hooks[event] as? [[String: Any]] ?? []).contains(where: describes) }
	}

	// Adds one hook group per event, leaving every other hook and setting as it was. Doing it twice changes nothing more.
	static func connect(_ settings: [String: Any]) -> [String: Any] {
		var out = settings
		var hooks = out["hooks"] as? [String: Any] ?? [:]
		for event in events {
			var groups = hooks[event] as? [[String: Any]] ?? []
			guard !groups.contains(where: describes) else { continue }
			var group: [String: Any] = ["hooks": [["type": "command", "command": command]]]
			if event == "PostToolUse" { group["matcher"] = "*" }
			groups.append(group)
			hooks[event] = groups
		}
		out["hooks"] = hooks
		return out
	}

	// Removes only the groups this file added; an empty list of hooks is left out altogether.
	static func disconnect(_ settings: [String: Any]) -> [String: Any] {
		var out = settings
		guard var hooks = out["hooks"] as? [String: Any] else { return settings }
		for (event, value) in hooks {
			guard let groups = value as? [[String: Any]] else { continue }
			let kept = groups.filter { !describes($0) }
			hooks[event] = kept.isEmpty ? nil : kept
		}
		out["hooks"] = hooks.isEmpty ? nil : hooks
		return out
	}

	// MARK: The file

	enum Failure: Error, Equatable { case unreadable, noFolder }

	static func read(_ url: URL) throws -> [String: Any] {
		guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
		guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [:] }
		guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.unreadable }
		return object
	}

	// Writes the new settings after saving a dated copy of the old file next to it. A file that is a link (people keep
	// dotfiles that way) is written through the link and stays a link. A file that cannot be read as JSON is never replaced.
	static func write(_ settings: [String: Any], to link: URL, now: Date = Date()) throws {
		let url = link.resolvingSymlinksInPath()
		let folder = url.deletingLastPathComponent()
		guard FileManager.default.fileExists(atPath: folder.path) else { throw Failure.noFolder }
		if FileManager.default.fileExists(atPath: url.path) {
			let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-")
			// Two changes in the same second must not collide: a short random tail keeps every backup.
			let tail = UUID().uuidString.prefix(4).lowercased()
			try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent("settings.json.yana-backup-\(stamp)-\(tail)"))
		}
		let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
		try data.write(to: url, options: .atomic)
	}

	static func isConnected(at url: URL = claudeSettings) -> Bool { ((try? read(url)).map(isConnected)) ?? false }

	static func connect(at url: URL = claudeSettings) throws { try write(connect(read(url)), to: url) }
	static func disconnect(at url: URL = claudeSettings) throws { try write(disconnect(read(url)), to: url) }
}
