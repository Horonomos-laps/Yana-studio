import Foundation

// A sandbox for the built-in terminal. When it is on, a new terminal tab starts its shell under macOS's
// sandbox-exec with a profile that lets the shell write only inside the project folder, the temp folders and
// a few cache and history files, and (if asked) blocks all network. Reading is not limited, so tools still
// find their config. It covers the terminal tabs only: commands the AI runs through yana-rt are guarded by
// yana-rt's own approvals, not by this. sandbox-exec is marked deprecated by Apple but ships with macOS.

enum TerminalSandbox {
	static let enabledKey = "yana.terminal.sandbox"
	static let blockNetworkKey = "yana.terminal.sandboxNoNetwork"
	static let executable = "/usr/bin/sandbox-exec"

	static var isAvailable: Bool { FileManager.default.isExecutableFile(atPath: executable) }

	struct Policy: Equatable {
		var enabled: Bool
		var blockNetwork: Bool
	}

	static func current(_ d: UserDefaults = .standard) -> Policy {
		Policy(enabled: d.bool(forKey: enabledKey), blockNetwork: d.bool(forKey: blockNetworkKey))
	}

	// Folders under the temp area and device files every shell needs to write to.
	static let systemWritable = ["/private/tmp", "/private/var/folders", "/dev"]
	// Where the home folder may be written: tool caches and the shell's own history.
	static let homeFolders = [".cache", ".npm", ".cargo", "Library/Caches", ".zsh_sessions"]
	static let homeFiles = [".zsh_history", ".zsh_history.LOCK", ".bash_history"]

	// The path with links followed, so it names the real place: the profile matches real paths, and /tmp is
	// /private/tmp. realpath is used because Foundation's resolvingSymlinksInPath turns /private/tmp back into /tmp.
	// A path that does not exist yet keeps its missing tail: the nearest folder that exists is resolved.
	static func canonical(_ path: String) -> String {
		if let resolved = realpath(path, nil) {
			defer { free(resolved) }
			return String(cString: resolved)
		}
		let url = URL(fileURLWithPath: path)
		let parent = url.deletingLastPathComponent().path
		guard parent != path, parent != "/", !parent.isEmpty else { return path }
		return canonical(parent) + "/" + url.lastPathComponent
	}

	// Inside a profile string a backslash or a quote must be escaped; nothing else is special there.
	static func escape(_ path: String) -> String {
		path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
	}

	static func profile(folder: String, home: String, blockNetwork: Bool) -> String {
		var rules = ["(subpath \"\(escape(folder))\")"]
		rules += systemWritable.map { "(subpath \"\(escape($0))\")" }
		rules += homeFolders.map { "(subpath \"\(escape(home + "/" + $0))\")" }
		rules += homeFiles.map { "(literal \"\(escape(home + "/" + $0))\")" }
		var lines = [
			"(version 1)",
			"(allow default)",
			"(deny file-write* (require-not (require-any \(rules.joined(separator: " ")))))",
		]
		if blockNetwork { lines.append("(deny network*)") }
		return lines.joined(separator: "\n") + "\n"
	}

	// The program and arguments that start `shell` as a login shell inside the sandbox.
	static func launch(shell: String, folder: String, home: String, blockNetwork: Bool) -> (executable: String, args: [String]) {
		(executable, ["-p", profile(folder: canonical(folder), home: canonical(home), blockNetwork: blockNetwork), shell, "-l"])
	}
}
