import Foundation

// Logic behind the Git, Worktrees and Hooks settings panes. Nothing here touches the UI or the
// disk by itself: the parsers take text, the planners take lists, so each can be tested alone.

// MARK: Branch names

enum BranchNaming {
	static let placeholders = ["{feature}", "{branch}", "{uuid}", "{ts}", "{date}", "{time}"]
	static let defaultTemplate = "{feature}"
	static let defaultPrefix = "yana/"
	private static let maxSlug = 40

	// "Fix the login bug!" becomes "fix-the-login-bug": lowercase, ASCII letters and digits, single dashes.
	static func slug(_ text: String) -> String {
		let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
			.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d")
		var out = ""
		for scalar in folded.lowercased().unicodeScalars {
			if (scalar.value >= 97 && scalar.value <= 122) || (scalar.value >= 48 && scalar.value <= 57) {
				out.unicodeScalars.append(scalar)
			} else if !out.hasSuffix("-") {
				out.append("-")
			}
		}
		let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
		return String(trimmed.prefix(maxSlug)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
	}

	// Fills the template and puts the prefix in front. The result is always a valid git ref name.
	static func name(prefix: String, template: String, feature: String, branch: String,
	                 now: Date = Date(), uuid: UUID = UUID(), timeZone: TimeZone = .current) -> String {
		let posix = Locale(identifier: "en_US_POSIX")
		let day = DateFormatter(); day.locale = posix; day.timeZone = timeZone; day.dateFormat = "yyyy-MM-dd"
		let clock = DateFormatter(); clock.locale = posix; clock.timeZone = timeZone; clock.dateFormat = "HHmmss"
		let tpl = template.trimmingCharacters(in: .whitespaces).isEmpty ? defaultTemplate : template
		let filled = tpl
			.replacingOccurrences(of: "{feature}", with: slug(feature))
			.replacingOccurrences(of: "{branch}", with: slug(branch))
			.replacingOccurrences(of: "{uuid}", with: String(uuid.uuidString.lowercased().prefix(8)))
			.replacingOccurrences(of: "{ts}", with: String(Int(now.timeIntervalSince1970)))
			.replacingOccurrences(of: "{date}", with: day.string(from: now))
			.replacingOccurrences(of: "{time}", with: clock.string(from: now))
		return sanitizeRef(prefix + filled)
	}

	// git forbids spaces, ~ ^ : ? * [ \, "..", "@{", a leading "-", a trailing "/" or ".", and ".lock" endings.
	static func sanitizeRef(_ raw: String) -> String {
		var ref = raw.replacingOccurrences(of: "..", with: ".").replacingOccurrences(of: "@{", with: "@")
		let banned = CharacterSet(charactersIn: " ~^:?*[\\\u{7f}").union(.controlCharacters)
		ref = String(ref.unicodeScalars.map { banned.contains($0) ? "-" : Character($0) })
		ref = ref.replacingOccurrences(of: "//", with: "/")
		while ref.hasPrefix("-") || ref.hasPrefix("/") || ref.hasPrefix(".") { ref.removeFirst() }
		while ref.hasSuffix("/") || ref.hasSuffix(".") || ref.hasSuffix("-") { ref.removeLast() }
		if ref.hasSuffix(".lock") { ref.removeLast(5) }
		return ref.isEmpty ? "yana/work" : ref
	}
}

// MARK: Worktrees

struct WorktreeEntry: Equatable, Identifiable {
	var id: String { path }
	let path: String
	let head: String
	let branch: String?
	let detached: Bool
	let locked: Bool
	let prunable: Bool
	let isMain: Bool
}

enum Worktrees {
	// Parses `git worktree list --porcelain`: blocks separated by a blank line; the first block is the main checkout.
	static func parse(porcelain text: String) -> [WorktreeEntry] {
		var entries: [WorktreeEntry] = []
		for block in text.components(separatedBy: "\n\n") {
			var path = "", head = "", branch: String? = nil
			var detached = false, locked = false, prunable = false
			for line in block.split(separator: "\n") {
				if line.hasPrefix("worktree ") { path = String(line.dropFirst(9)) }
				else if line.hasPrefix("HEAD ") { head = String(line.dropFirst(5)) }
				else if line.hasPrefix("branch ") { branch = String(line.dropFirst(7)).replacingOccurrences(of: "refs/heads/", with: "") }
				else if line == "detached" { detached = true }
				else if line.hasPrefix("locked") { locked = true }
				else if line.hasPrefix("prunable") { prunable = true }
			}
			guard !path.isEmpty else { continue }
			entries.append(WorktreeEntry(path: path, head: head, branch: branch, detached: detached,
			                            locked: locked, prunable: prunable, isMain: entries.isEmpty))
		}
		return entries
	}

	// Which worktrees go beyond the number to keep. The main checkout, locked ones and the folder the
	// app is working in are never listed. Oldest first, by the modified time `age` reports (newer = larger).
	static func surplus(_ entries: [WorktreeEntry], keep: Int, protecting current: String,
	                    age: (WorktreeEntry) -> TimeInterval) -> [WorktreeEntry] {
		let candidates = entries.filter { !$0.isMain && !$0.locked && $0.path != current }
		let newestFirst = candidates.sorted { age($0) > age($1) }
		return Array(newestFirst.dropFirst(max(keep, 0))).reversed()
	}
}

// MARK: Hooks

struct HookEntry: Equatable, Identifiable {
	var id: String { "\(source)|\(event)|\(matcher)|\(command)" }
	let source: String
	let event: String
	let matcher: String
	let command: String
	// The script the command runs, when one can be told apart; nil for inline shell.
	let script: String?
	let scriptMissing: Bool
}

enum HookScan {
	// Reads the "hooks" object of a Claude Code style settings file.
	// `projectDir` fills $CLAUDE_PROJECT_DIR; `exists` says whether a script path is on disk.
	static func parse(json: Data, source: String, projectDir: String, exists: (String) -> Bool) -> [HookEntry] {
		guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
		      let hooks = root["hooks"] as? [String: Any] else { return [] }
		var out: [HookEntry] = []
		for event in hooks.keys.sorted() {
			guard let groups = hooks[event] as? [[String: Any]] else { continue }
			for group in groups {
				let matcher = group["matcher"] as? String ?? "*"
				for hook in (group["hooks"] as? [[String: Any]]) ?? [] {
					guard let command = hook["command"] as? String else { continue }
					let scripts = scriptPaths(in: command, projectDir: projectDir)
					out.append(HookEntry(source: source, event: event, matcher: matcher, command: command,
					                     script: scripts.first, scriptMissing: scripts.contains { !exists($0) }))
				}
			}
		}
		return out
	}

	// Every word that is a script file (.sh .js .py .mjs .cjs .ts), with the project variable filled.
	// Quotes keep a path with spaces in one piece, and the value of a VAR=value prefix counts too,
	// because hooks often pass their own script that way.
	static func scriptPaths(in command: String, projectDir: String) -> [String] {
		let expanded = command
			.replacingOccurrences(of: "${CLAUDE_PROJECT_DIR}", with: projectDir)
			.replacingOccurrences(of: "$CLAUDE_PROJECT_DIR", with: projectDir)
		let tails = [".sh", ".js", ".py", ".mjs", ".cjs", ".ts"]
		return words(expanded).compactMap { word in
			var w = word
			if let eq = w.firstIndex(of: "="), !w.hasPrefix("/"), !w.hasPrefix(".") { w = String(w[w.index(after: eq)...]) }
			return tails.contains { w.hasSuffix($0) } ? w : nil
		}
	}

	static func scriptPath(in command: String, projectDir: String) -> String? {
		scriptPaths(in: command, projectDir: projectDir).first
	}

	// Splits on spaces and tabs, keeping anything inside "..." or '...' together and dropping the quote marks.
	static func words(_ text: String) -> [String] {
		var out: [String] = [], current = "", quote: Character? = nil, started = false
		for ch in text {
			if let q = quote {
				if ch == q { quote = nil } else { current.append(ch) }
			} else if ch == "\"" || ch == "'" {
				quote = ch; started = true
			} else if ch == " " || ch == "\t" || ch == "\n" {
				if started || !current.isEmpty { out.append(current); current = ""; started = false }
			} else {
				current.append(ch); started = true
			}
		}
		if started || !current.isEmpty { out.append(current) }
		return out
	}
}

// MARK: Git preferences

// The Git pane's values, read straight from UserDefaults so the chat engine and the pane agree.
enum GitPrefs {
	static let prefixKey = "yana.git.branchPrefix"
	static let templateKey = "yana.git.branchTemplate"
	static let mergeKey = "yana.git.mergeMethod"
	static let draftKey = "yana.git.draftPR"
	static let leaseKey = "yana.git.forceWithLease"
	static let commitKey = "yana.git.commitGuidance"
	static let prKey = "yana.git.prGuidance"

	// A system instruction for chat, only when something differs from the defaults. nil means add nothing.
	static func instruction(_ d: UserDefaults = .standard) -> String? {
		var lines: [String] = []
		let prefix = d.string(forKey: prefixKey) ?? BranchNaming.defaultPrefix
		let template = d.string(forKey: templateKey) ?? BranchNaming.defaultTemplate
		if prefix != BranchNaming.defaultPrefix || template != BranchNaming.defaultTemplate {
			lines.append("When you create a git branch, name it with the prefix \"\(prefix)\" and the pattern \"\(template)\" (feature is a short slug of the task, date is yyyy-MM-dd, ts is a unix time, uuid is 8 hex characters).")
		}
		if (d.string(forKey: mergeKey) ?? "merge") == "squash" { lines.append("When you merge a pull request, squash it.") }
		if d.object(forKey: draftKey) as? Bool == false { lines.append("Open pull requests as ready for review, not as drafts.") }
		if d.bool(forKey: leaseKey) { lines.append("When a push needs force, use --force-with-lease and never plain --force.") }
		let commit = (d.string(forKey: commitKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		if !commit.isEmpty { lines.append("Commit message guidance from the user:\n\(commit)") }
		let pr = (d.string(forKey: prKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		if !pr.isEmpty { lines.append("Pull request title and description guidance from the user:\n\(pr)") }
		return lines.isEmpty ? nil : lines.joined(separator: "\n")
	}
}
