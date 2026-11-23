import AppKit
import Darwin

// Which app a Claude Code session runs in. The session's log knows the folder but not the app, so Yana looks at the running
// processes: a `claude` process, its folder, and the app it sits under (Yana Studio's terminal, Terminal, iTerm, an editor).
// Pressing a session line can then bring that app to the front. Read only: it lists processes and asks the system for a
// process's folder and for the app that owns it.

enum ProcessTable {
	struct Entry: Equatable {
		let pid: Int32, parent: Int32, command: String
	}

	// Lines of `ps -axo pid=,ppid=,command=`.
	static func parse(_ output: String) -> [Entry] {
		output.split(separator: "\n").compactMap { line in
			let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
			guard parts.count == 3, let pid = Int32(parts[0]), let parent = Int32(parts[1]) else { return nil }
			return Entry(pid: pid, parent: parent, command: String(parts[2]))
		}
	}

	// A Claude Code process: the program is called claude, or a node/bun program that runs the Claude Code package.
	static func isClaude(_ command: String) -> Bool {
		let first = command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
		if (first as NSString).lastPathComponent == "claude" { return true }
		return command.contains("@anthropic-ai/claude-code") && !command.contains("claude-code-guide")
	}

	// The chain of parents from a process up to the first one a closure recognizes as an app.
	static func ancestorApp(of pid: Int32, entries: [Entry], appFor: (Int32) -> String?) -> String? {
		let byPID = Dictionary(uniqueKeysWithValues: entries.map { ($0.pid, $0) })
		var current = pid, steps = 0
		while steps < 30, let entry = byPID[current] {
			if let app = appFor(entry.parent) { return app }
			if entry.parent <= 1 || entry.parent == current { break }
			current = entry.parent; steps += 1
		}
		return nil
	}

	// Folder of a process (its current directory), from the system.
	static func folder(of pid: Int32) -> String? {
		var info = proc_vnodepathinfo()
		let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
		guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
		return withUnsafePointer(to: &info.pvi_cdir.vip_path) {
			$0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
		}
	}

	static func list() -> [Entry] {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/bin/ps")
		process.arguments = ["-axo", "pid=,ppid=,command="]
		let pipe = Pipe()
		process.standardOutput = pipe; process.standardError = Pipe()
		guard (try? process.run()) != nil else { return [] }
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()
		return parse(String(decoding: data, as: UTF8.self))
	}

	// folder -> bundle id of the app each Claude Code process runs under. Where two processes share a folder the later wins.
	static func appsByFolder() -> [String: String] {
		let entries = list()
		var out: [String: String] = [:]
		for entry in entries where isClaude(entry.command) {
			guard let folder = folder(of: entry.pid),
			      let app = ancestorApp(of: entry.pid, entries: entries, appFor: { appBundleID(pid: $0) }) else { continue }
			out[folder] = app
		}
		return out
	}

	// The bundle id of a running app that owns this process, nil for a plain process.
	static func appBundleID(pid: Int32) -> String? {
		guard pid > 1 else { return nil }
		return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
	}
}
