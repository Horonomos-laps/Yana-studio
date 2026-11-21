import CryptoKit
import Foundation

// "Get" for a Claude marketplace plugin: copies the plugin's skills and its slash commands (plain Markdown files)
// into the person's own folder, ~/.yana-ai/plugins/<plugin>/, so they work in every session and every project.
//
// What is copied is text only, from one pinned commit:
//   - files come from raw.githubusercontent.com at the plugin's `sha`, listed through api.github.com; no other host
//   - only SKILL.md files with their .md/.txt companions, and commands/<name>.md; never a script, hook or binary
//   - sizes and counts are capped, a file that is not UTF-8 text is refused, and a file that looks like a prompt
//     injection refuses the whole plugin (nothing is written)
// Hooks, agents, MCP servers and language servers of the plugin are not installed here; the plan says which exist
// so the person knows what was left out. Nothing here depends on the app's views, so it can be tested alone.

enum PluginInstaller {
	static let hosts: Set<String> = ["api.github.com", "raw.githubusercontent.com"]
	static let maxComponents = 60
	static let maxFileBytes = 200_000
	static let maxFilesPerSkill = 20
	static let maxTotalBytes = 2_000_000
	static let maxTreeBytes = 12_000_000
	private static let maxDepth = 5       // a SKILL.md deeper than this below the plugin root is not looked for
	private static let timeout: TimeInterval = 20

	struct Source: Equatable {
		let owner: String
		let repo: String
		let sha: String
		let subpath: String               // "" is the repository root
	}

	struct File: Equatable {
		let repoPath: String              // path in the repository
		let relative: String              // path inside the component's folder
		let size: Int
	}

	struct Component: Equatable {
		enum Kind: String, Codable { case skill, command }
		let kind: Kind
		let name: String
		let files: [File]
	}

	// What exists in the plugin but is not installed here.
	enum Left: String, Codable, CaseIterable { case hooks, agents, mcp, lsp, scripts }

	struct Plan: Equatable {
		let plugin: String
		let version: String?
		let source: Source
		let components: [Component]
		let left: [Left]
		// The MCP servers the plugin declares in .mcp.json, described, never installed by Get (see McpServer).
		var mcp: [McpServer] = []
		var totalBytes: Int { components.flatMap(\.files).reduce(0) { $0 + $1.size } }
	}

	// One server from a plugin's .mcp.json. Remote ones (https) are named so the person knows why they are not
	// connected: yana-rt starts local servers only. A local one that runs `npx` or `uvx` with an exact version
	// can be added to a project through McpInstaller; anything else (an unpinned package, another program) is
	// not offered, because it would run code nobody fixed to a version.
	struct McpServer: Equatable {
		enum Kind: Equatable {
			case remote(url: String)
			case local(command: String, args: [String], pinned: Bool)
			case other
		}
		let name: String
		let kind: Kind
		let env: [String]              // variable names the server reads; values are never copied
		var installable: Bool { if case .local(_, _, true) = kind { return true }; return false }
	}

	static let maxMcpServers = 16
	static let maxMcpBytes = 20_000

	struct Manifest: Codable, Equatable {
		struct Entry: Codable, Equatable { let kind: Component.Kind; let name: String; let files: [FileHash] }
		struct FileHash: Codable, Equatable { let path: String; let sha256: String }
		let plugin: String
		let version: String?
		let repo: String                  // owner/repo
		let sha: String
		let installedAt: Date
		let left: [Left]
		let components: [Entry]
	}

	enum Failure: LocalizedError {
		case message(String)
		var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
	}

	static func defaultRoot() -> URL {
		URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".yana-ai/plugins", isDirectory: true)
	}

	// MARK: Names and sources (pure)

	// Lowercase letters, digits, dot, underscore, hyphen; never empty, never starting with a dot.
	static func safeName(_ raw: String) -> String? {
		let name = raw.lowercased()
		guard (1 ... 64).contains(name.count), !name.hasPrefix(".") else { return nil }
		let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._-")
		return name.allSatisfy { allowed.contains($0) } ? name : nil
	}

	private static func isSha(_ text: String) -> Bool {
		text.count == 40 && text.allSatisfy { $0.isHexDigit && !$0.isUppercase }
	}

	private static func cleanPath(_ raw: String) throws -> String {
		let parts = raw.split(separator: "/").map(String.init).filter { $0 != "." && !$0.isEmpty }
		guard !parts.contains(".."), parts.allSatisfy({ !$0.contains("\0") }) else { throw Failure.message("The plugin's folder path is not allowed.") }
		return parts.joined(separator: "/")
	}

	// A marketplace source: a git URL on github.com with a pinned sha (and optionally a folder in it).
	static func source(url: String, path: String?, sha: String?) throws -> Source {
		guard let components = URLComponents(string: url), components.scheme == "https", components.host == "github.com" else {
			throw Failure.message("Only plugins hosted on github.com can be installed.")
		}
		let parts = components.path.split(separator: "/").map(String.init)
		guard parts.count >= 2 else { throw Failure.message("The plugin's repository address is not valid.") }
		let owner = parts[0]
		var repo = parts[1]
		if repo.hasSuffix(".git") { repo.removeLast(4) }
		let ok = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
		guard !owner.isEmpty, !repo.isEmpty, owner.allSatisfy({ ok.contains($0) }), repo.allSatisfy({ ok.contains($0) }) else {
			throw Failure.message("The plugin's repository address is not valid.")
		}
		guard let sha, isSha(sha) else { throw Failure.message("This plugin is not pinned to a commit, so it cannot be installed safely.") }
		return Source(owner: owner, repo: repo, sha: sha, subpath: try cleanPath(path ?? ""))
	}

	// MARK: Reading the repository tree (pure)

	struct TreeEntry: Equatable { let path: String; let size: Int }

	static func parseTree(_ data: Data) throws -> [TreeEntry] {
		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let tree = json["tree"] as? [[String: Any]] else {
			throw Failure.message("GitHub answered with something the app cannot read.")
		}
		if json["truncated"] as? Bool == true { throw Failure.message("This repository is too large to read safely.") }
		return tree.compactMap { entry in
			guard entry["type"] as? String == "blob", let path = entry["path"] as? String else { return nil }
			return TreeEntry(path: path, size: (entry["size"] as? NSNumber)?.intValue ?? 0)
		}
	}

	private static let textExtensions: Set<String> = ["md", "txt"]
	private static let skippedFolders: Set<String> = ["node_modules", ".git", ".github"]

	// Turns the repository tree into what would be installed, or throws when it is over a limit.
	static func plan(plugin: String, version: String?, source: Source, tree: [TreeEntry]) throws -> Plan {
		guard let plugin = safeName(plugin) else { throw Failure.message("The plugin's name is not allowed.") }
		let prefix = source.subpath.isEmpty ? "" : source.subpath + "/"
		let under: [(relative: String, entry: TreeEntry)] = tree.compactMap { entry in
			guard entry.path.hasPrefix(prefix) else { return nil }
			let relative = String(entry.path.dropFirst(prefix.count))
			let parts = relative.split(separator: "/").map(String.init)
			guard !parts.isEmpty, parts.count <= maxDepth + 1, !parts.contains(where: skippedFolders.contains) else { return nil }
			return (relative, entry)
		}

		// Skill folders: where a SKILL.md sits ("" for the root, otherwise "dir/"). The folder is the skill; the
		// plugin's own name stands in for the root.
		let skillDirs = under.filter { $0.relative == "SKILL.md" || $0.relative.hasSuffix("/SKILL.md") }
			.map { String($0.relative.dropLast("SKILL.md".count)) }
			.sorted()
		var used = Set<String>()
		var components: [Component] = []
		for dir in skillDirs {
			let trimmed = dir.hasSuffix("/") ? String(dir.dropLast()) : dir
			let base = trimmed.isEmpty ? plugin : (trimmed.split(separator: "/").last.map(String.init) ?? plugin)
			guard var name = safeName(base) else { continue }
			if used.contains(name), let joined = safeName(trimmed.replacingOccurrences(of: "/", with: "-")) { name = joined }
			guard used.insert(name).inserted else { continue }
			// Files of this skill: under its folder, not under a deeper skill's folder, text only.
			let deeper = skillDirs.filter { $0 != dir && $0.hasPrefix(dir) }
			let files = under.compactMap { item -> File? in
				guard item.relative.hasPrefix(dir), !deeper.contains(where: { item.relative.hasPrefix($0) }) else { return nil }
				let inside = String(item.relative.dropFirst(dir.count))
				guard !inside.isEmpty, textExtensions.contains((inside as NSString).pathExtension.lowercased()) else { return nil }
				return File(repoPath: item.entry.path, relative: inside, size: item.entry.size)
			}
			guard let main = files.first(where: { $0.relative == "SKILL.md" }), main.size <= maxFileBytes else { continue }
			let kept = Array(files.filter { $0.size <= maxFileBytes }.sorted { $0.relative < $1.relative }.prefix(maxFilesPerSkill))
			components.append(Component(kind: .skill, name: name, files: kept))
		}

		// Slash commands: commands/<name>.md at the plugin root.
		for item in under {
			let parts = item.relative.split(separator: "/").map(String.init)
			guard parts.count == 2, parts[0] == "commands", parts[1].hasSuffix(".md"), item.entry.size <= maxFileBytes,
			      let name = safeName(String(parts[1].dropLast(3))) else { continue }
			components.append(Component(kind: .command, name: name, files: [File(repoPath: item.entry.path, relative: parts[1], size: item.entry.size)]))
		}

		guard !components.isEmpty else { throw Failure.message("This plugin has no skills or commands that can be installed.") }
		guard components.count <= maxComponents else { throw Failure.message("This plugin has too many parts to install.") }
		let plan = Plan(plugin: plugin, version: version, source: source, components: components, left: leftOut(under.map(\.relative)))
		guard plan.totalBytes <= maxTotalBytes else { throw Failure.message("This plugin is too large to install.") }
		return plan
	}

	// What the plugin has beyond text skills and commands, named so the preview can say what is not installed.
	private static func leftOut(_ relatives: [String]) -> [Left] {
		var found = Set<Left>()
		for path in relatives {
			let parts = path.split(separator: "/").map(String.init)
			let file = parts.last ?? ""
			if parts.first == "hooks" || file == "hooks.json" { found.insert(.hooks) }
			if parts.first == "agents" { found.insert(.agents) }
			if file == ".mcp.json" { found.insert(.mcp) }
			if file == ".lsp.json" { found.insert(.lsp) }
			if parts.first == "scripts" || ["sh", "py", "js", "ts", "command"].contains((file as NSString).pathExtension.lowercased()) { found.insert(.scripts) }
		}
		return Left.allCases.filter(found.contains)
	}

	// MARK: .mcp.json (pure)

	// Both forms Claude Code reads: {"mcpServers": {...}} and the bare {"name": {...}}. Names are sorted so the
	// answer does not depend on dictionary order; a name that is not safe is skipped; at most maxMcpServers.
	static func parseMcp(_ data: Data) -> [McpServer] {
		guard data.count <= maxMcpBytes, let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
		let table = root["mcpServers"] as? [String: Any] ?? root
		return table.keys.sorted().compactMap { key -> McpServer? in
			guard let name = safeName(key), let object = table[key] as? [String: Any] else { return nil }
			let env = (object["env"] as? [String: Any])?.keys.sorted().filter { isEnvName($0) } ?? []
			return McpServer(name: name, kind: mcpKind(object), env: env)
		}.prefix(maxMcpServers).map { $0 }
	}

	// The servers kept next to the installed plugin (.mcp-servers.json), so the plugin's page can show them again.
	private struct StoredMcp: Codable {
		let name: String
		let kind: String            // remote, local or other
		var url: String?
		var command: String?
		var args: [String]?
		var pinned: Bool?
		let env: [String]
	}

	static func storedMcp(_ servers: [McpServer]) -> Data? {
		guard !servers.isEmpty else { return nil }
		let stored = servers.map { server -> StoredMcp in
			switch server.kind {
			case .remote(let url): return StoredMcp(name: server.name, kind: "remote", url: url, env: server.env)
			case .local(let command, let args, let pinned):
				return StoredMcp(name: server.name, kind: "local", command: command, args: args, pinned: pinned, env: server.env)
			case .other: return StoredMcp(name: server.name, kind: "other", env: server.env)
			}
		}
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return try? encoder.encode(stored)
	}

	static func loadMcp(_ data: Data) -> [McpServer] {
		guard data.count <= maxMcpBytes * 2, let stored = try? JSONDecoder().decode([StoredMcp].self, from: data) else { return [] }
		return stored.prefix(maxMcpServers).compactMap { item -> McpServer? in
			guard let name = safeName(item.name) else { return nil }
			switch item.kind {
			case "remote": return item.url.map { McpServer(name: name, kind: .remote(url: $0), env: item.env) }
			case "local":
				guard let command = item.command, let args = item.args else { return nil }
				return McpServer(name: name, kind: .local(command: command, args: args, pinned: item.pinned ?? false), env: item.env)
			default: return McpServer(name: name, kind: .other, env: item.env)
			}
		}
	}

	static func installedMcp(_ plugin: String, root: URL = defaultRoot()) -> [McpServer] {
		guard let name = safeName(plugin), isInstalled(name, root: root),
		      let data = try? Data(contentsOf: root.appendingPathComponent(name).appendingPathComponent(".mcp-servers.json")) else { return [] }
		return loadMcp(data)
	}

	private static func mcpKind(_ object: [String: Any]) -> McpServer.Kind {
		if object["command"] == nil, let url = object["url"] as? String {
			return url.hasPrefix("https://") ? .remote(url: url) : .other
		}
		guard let command = object["command"] as? String, command == "npx" || command == "uvx" else { return .other }
		let rawArgs = (object["args"] as? [Any]) ?? []
		guard rawArgs.allSatisfy({ $0 is String }) else { return .other }
		let strings = rawArgs.compactMap { $0 as? String }
		// The package is the first argument that is not a flag.
		let package = strings.first { !$0.hasPrefix("-") } ?? ""
		let pinned = command == "npx" ? isExactNpm(package) : isExactPython(package)
		return .local(command: command, args: strings, pinned: pinned)
	}

	private static func isEnvName(_ text: String) -> Bool {
		guard let first = text.first, first.isLetter || first == "_" else { return false }
		return text.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" }
	}

	private static let exactVersion = #"^\d+\.\d+\.\d+([-+][0-9A-Za-z.\-+]+)?$"#

	// "pkg@1.2.3" or "@scope/pkg@1.2.3": an exact version, not "latest", a range, or nothing.
	private static func isExactNpm(_ argument: String) -> Bool {
		let body = argument.hasPrefix("@") ? String(argument.dropFirst()) : argument
		guard let at = body.lastIndex(of: "@") else { return false }
		return body[body.index(after: at)...].range(of: exactVersion, options: .regularExpression) != nil
	}

	// "pkg==1.2.3".
	private static func isExactPython(_ argument: String) -> Bool {
		guard let range = argument.range(of: "==") else { return false }
		return argument[range.upperBound...].range(of: exactVersion, options: .regularExpression) != nil
	}

	// MARK: Scanning (pure)

	// Phrases that exist to take over the model reading the file, and characters that hide text. A hit refuses the
	// whole plugin. This is a screen, not a proof of safety: it misses anything worded differently, which is why
	// the person also sees what will be installed first.
	private static let injection: [NSRegularExpression] = [
		"ignore (all |the |your |any )?(previous|prior|above|earlier) (instructions|rules|guidelines|constraints)",
		"disregard (your|all|the) (previous|prior|system) (instructions|prompt|rules)",
		"forget (everything|all (your )?instructions|your training)",
		"your new (instructions|rules|purpose) (are|is)",
		"system override", "\\[inst\\]", "<\\|im_start\\|>", "<!--\\s*system",
	].compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

	private static let hiddenCharacters: Set<UInt32> = Set((0x200B ... 0x200F).map(UInt32.init) + (0x202A ... 0x202E).map(UInt32.init)
		+ (0x2060 ... 0x2064).map(UInt32.init) + [0xFEFF])

	static func scan(_ text: String) -> String? {
		if text.unicodeScalars.contains(where: { hiddenCharacters.contains($0.value) }) { return "it contains invisible characters" }
		let range = NSRange(text.startIndex..., in: text)
		for pattern in injection where pattern.firstMatch(in: text, range: range) != nil { return "it contains an instruction aimed at the model" }
		return nil
	}

	// MARK: Network

	private static let session = URLSession(configuration: .ephemeral)

	private static func get(_ url: URL, limit: Int) async throws -> Data {
		guard url.scheme == "https", let host = url.host, hosts.contains(host) else { throw Failure.message("That address is not allowed.") }
		var request = URLRequest(url: url, timeoutInterval: timeout)
		request.setValue("yana-app-plugin-install", forHTTPHeaderField: "User-Agent")
		let (data, response) = try await session.data(for: request)
		let status = (response as? HTTPURLResponse)?.statusCode ?? 0
		guard status == 200 else { throw Failure.message(status == 403 || status == 429 ? "GitHub is limiting requests right now. Try again in a few minutes." : "GitHub answered with status \(status).") }
		guard data.count <= limit else { throw Failure.message("A file was larger than the limit.") }
		return data
	}

	// For a plugin that lives inside the marketplace repository itself there is no pinned sha: the commit the
	// repository is at now is looked up once and then used for every file, and recorded.
	static func currentSha(owner: String, repo: String, ref: String = "HEAD") async throws -> String {
		guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(ref)") else { throw Failure.message("Bad address.") }
		var request = URLRequest(url: url, timeoutInterval: timeout)
		request.setValue("application/vnd.github.sha", forHTTPHeaderField: "Accept")
		request.setValue("yana-app-plugin-install", forHTTPHeaderField: "User-Agent")
		let (data, response) = try await session.data(for: request)
		let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
		guard (response as? HTTPURLResponse)?.statusCode == 200, isSha(text) else { throw Failure.message("Could not read the plugin's commit from GitHub.") }
		return text
	}

	static func fetchPlan(plugin: String, version: String?, source: Source) async throws -> Plan {
		guard let url = URL(string: "https://api.github.com/repos/\(source.owner)/\(source.repo)/git/trees/\(source.sha)?recursive=1") else {
			throw Failure.message("Bad address.")
		}
		let tree = try parseTree(try await get(url, limit: maxTreeBytes))
		var made = try plan(plugin: plugin, version: version, source: source, tree: tree)
		// The plugin's MCP servers are read only to describe them; a missing or unreadable file means none.
		let mcpPath = source.subpath.isEmpty ? ".mcp.json" : source.subpath + "/.mcp.json"
		if tree.contains(where: { $0.path == mcpPath && $0.size <= maxMcpBytes }), let raw = rawURL(source, mcpPath),
		   let data = try? await get(raw, limit: maxMcpBytes) {
			made.mcp = parseMcp(data)
		}
		return made
	}

	private static func rawURL(_ source: Source, _ path: String) -> URL? {
		var components = URLComponents()
		components.scheme = "https"
		components.host = "raw.githubusercontent.com"
		components.percentEncodedPath = "/\(source.owner)/\(source.repo)/\(source.sha)/" +
			path.split(separator: "/").map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
		return components.url
	}

	// MARK: Install and remove

	// Downloads every file of the plan, scans it, and only then writes: a refused file leaves nothing on disk.
	@discardableResult
	static func install(_ plan: Plan, root: URL = defaultRoot()) async throws -> Manifest {
		var texts: [String: String] = [:]
		for component in plan.components {
			for file in component.files {
				guard let url = rawURL(plan.source, file.repoPath) else { throw Failure.message("Bad address.") }
				let data = try await get(url, limit: maxFileBytes)
				guard let text = String(data: data, encoding: .utf8) else { throw Failure.message("\(file.relative) is not plain text.") }
				if let reason = scan(text) { throw Failure.message("\(component.name)/\(file.relative) was refused: \(reason).") }
				texts[file.repoPath] = text
			}
		}
		return try write(plan, texts: texts, root: root)
	}

	static func write(_ plan: Plan, texts: [String: String], root: URL) throws -> Manifest {
		let fm = FileManager.default
		let staging = root.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
		let pluginDir = staging.appendingPathComponent(plan.plugin, isDirectory: true)
		var entries: [Manifest.Entry] = []
		do {
			for component in plan.components {
				let folder = pluginDir.appendingPathComponent(component.kind == .skill ? "skills/\(component.name)" : "commands", isDirectory: true)
				try fm.createDirectory(at: folder, withIntermediateDirectories: true)
				var hashes: [Manifest.FileHash] = []
				for file in component.files {
					guard let text = texts[file.repoPath], !file.relative.split(separator: "/").contains("..") else { throw Failure.message("A file is missing.") }
					let destination = folder.appendingPathComponent(file.relative)
					try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
					try Data(text.utf8).write(to: destination, options: .atomic)
					hashes.append(.init(path: file.relative, sha256: SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()))
				}
				entries.append(.init(kind: component.kind, name: component.name, files: hashes))
			}
			let manifest = Manifest(plugin: plan.plugin, version: plan.version, repo: "\(plan.source.owner)/\(plan.source.repo)",
			                        sha: plan.source.sha, installedAt: Date(), left: plan.left, components: entries)
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			try encoder.encode(manifest).write(to: pluginDir.appendingPathComponent(".plugin.json"), options: .atomic)
			if let mcp = storedMcp(plan.mcp) { try mcp.write(to: pluginDir.appendingPathComponent(".mcp-servers.json"), options: .atomic) }
			let final = root.appendingPathComponent(plan.plugin, isDirectory: true)
			if fm.fileExists(atPath: final.path) { try fm.removeItem(at: final) }
			try fm.moveItem(at: pluginDir, to: final)
			try? fm.removeItem(at: staging)
			return manifest
		} catch {
			try? fm.removeItem(at: staging)
			throw error
		}
	}

	static func installed(root: URL = defaultRoot()) -> [Manifest] {
		let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return names.sorted().compactMap { name in
			guard safeName(name) == name, let data = try? Data(contentsOf: root.appendingPathComponent(name).appendingPathComponent(".plugin.json")) else { return nil }
			return try? decoder.decode(Manifest.self, from: data)
		}
	}

	static func isInstalled(_ plugin: String, root: URL = defaultRoot()) -> Bool {
		guard let name = safeName(plugin) else { return false }
		return installed(root: root).contains { $0.plugin == name }
	}

	// Removes a folder this installer made, found by its manifest; any other folder is left alone.
	static func remove(_ plugin: String, root: URL = defaultRoot()) throws {
		guard let name = safeName(plugin), isInstalled(name, root: root) else { throw Failure.message("That plugin is not installed.") }
		try FileManager.default.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
	}

	// MARK: Using what is installed

	struct Installed: Equatable {
		let id: String                    // what the person types after "/": plugin:name
		let kind: Component.Kind
		let file: URL
	}

	static func components(root: URL = defaultRoot()) -> [Installed] {
		installed(root: root).flatMap { manifest in
			manifest.components.map { entry -> Installed in
				let base = root.appendingPathComponent(manifest.plugin, isDirectory: true)
				let file = entry.kind == .skill ? base.appendingPathComponent("skills/\(entry.name)/SKILL.md") : base.appendingPathComponent("commands/\(entry.name).md")
				return Installed(id: "\(manifest.plugin):\(entry.name)", kind: entry.kind, file: file)
			}
		}
	}

	// A command file's prompt: its front matter dropped, $ARGUMENTS filled in (or the arguments appended).
	static func expandCommand(_ template: String, arguments: String) -> String {
		var body = template
		if body.hasPrefix("---"), let end = body.range(of: "\n---", range: body.index(body.startIndex, offsetBy: 3) ..< body.endIndex) {
			body = String(body[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
		}
		let args = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
		if body.contains("$ARGUMENTS") { return body.replacingOccurrences(of: "$ARGUMENTS", with: args) }
		return args.isEmpty ? body : "\(body)\n\nArguments: \(args)"
	}
}
