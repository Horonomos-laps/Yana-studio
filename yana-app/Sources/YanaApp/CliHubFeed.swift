import Foundation

// CLI-Hub (github.com/HKUDS/CLI-Anything), a public catalog of command-line tools made for agents. Each entry names a
// CLI and a SKILL.md that tells an agent how to use it. The store lists the entries and installs the SKILL.md, a text
// file, through PluginInstaller (pinned commit, scanned, size limits). The CLI itself is not installed here: its
// install command is `pip install git+https://...` on the repository's main branch with no pinned version, which is
// not something to run on a click, so it is only shown, with that warning.
//
// This file only reads the catalog; it knows nothing about views or the store's own types.

enum CliHubFeed {
	static let maxEntries = 1_000

	struct Entry: Equatable {
		let id: String                  // a safe name; also the plugin folder name when the skill is installed
		let displayName: String
		let summary: String
		let category: String
		let author: String?
		let version: String?
		let homepage: String?           // https only
		let installCommand: String?     // shown, never run
		let requires: String?
		let skillDir: String?           // folder of SKILL.md inside `repo`; nil: nothing to install
		let repo: String?               // https://github.com/<owner>/<repo>; nil: nothing to install
	}

	static func parse(_ data: Data) -> [Entry] {
		guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
		      let list = root["clis"] as? [[String: Any]] else { return [] }
		let repo = githubRepo((root["meta"] as? [String: Any])?["repo"] as? String)
		var seen = Set<String>()
		var out: [Entry] = []
		for item in list.prefix(maxEntries) {
			guard let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
			      let id = safeID(entryPoint: item["entry_point"] as? String, name: name), seen.insert(id).inserted else { continue }
			let skillDir = skillFolder(item["skill_md"] as? String)
			out.append(Entry(
				id: id,
				displayName: (item["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? name,
				summary: item["description"] as? String ?? "",
				category: (item["category"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "other",
				author: ((item["contributors"] as? [[String: Any]])?.first?["name"] as? String) ?? item["contributor"] as? String,
				version: item["version"] as? String,
				homepage: (item["homepage"] as? String).flatMap { $0.hasPrefix("https://") ? $0 : nil },
				installCommand: item["install_cmd"] as? String,
				requires: item["requires"] as? String,
				skillDir: repo == nil ? nil : skillDir,
				repo: skillDir == nil ? nil : repo))
		}
		return out
	}

	// "https://github.com/owner/repo" or ".../repo.git" -> without the suffix; any other host is refused.
	private static func githubRepo(_ text: String?) -> String? {
		guard let text, let url = URL(string: text), url.scheme == "https", url.host == "github.com" else { return nil }
		let parts = url.path.split(separator: "/").map(String.init)
		guard parts.count >= 2 else { return nil }
		let repo = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
		return "https://github.com/\(parts[0])/\(repo)"
	}

	// "skills/cli-anything-x/SKILL.md" -> "skills/cli-anything-x". Only a relative path ending in SKILL.md, with no ".." and no
	// empty part, counts; anything else means there is nothing to install.
	private static func skillFolder(_ path: String?) -> String? {
		guard let path, !path.hasPrefix("/") else { return nil }
		let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
		guard parts.last == "SKILL.md", !parts.contains(".."), !parts.contains(""), !parts.contains(".") else { return nil }
		let folder = parts.dropLast().joined(separator: "/")
		return folder.isEmpty ? nil : folder
	}

	// The entry point is already unique and prefixed ("cli-anything-gimp"); without a usable one the name is prefixed here.
	private static func safeID(entryPoint: String?, name: String) -> String? {
		if let entryPoint, let safe = PluginInstaller.safeName(entryPoint) { return safe }
		let cleaned = String(name.lowercased().map { ($0.isASCII && ($0.isLetter || $0.isNumber)) ? $0 : "-" })
			.split(separator: "-").joined(separator: "-")
		return PluginInstaller.safeName("cli-anything-\(cleaned)")
	}
}
