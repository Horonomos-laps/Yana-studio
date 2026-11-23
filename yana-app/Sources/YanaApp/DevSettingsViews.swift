import AppKit
import SwiftUI

// The Git, Worktrees and Hooks panes of Settings. Logic is in DevSettingsLogic.swift.

// Runs git without a shell: arguments are passed as a list, so nothing is interpreted.
enum GitRunner {
	static func run(_ args: [String], in dir: String) async -> (ok: Bool, output: String) {
		await withCheckedContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				let process = Process()
				process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
				process.arguments = ["-C", dir] + args
				let pipe = Pipe()
				process.standardOutput = pipe
				process.standardError = pipe
				do { try process.run() } catch {
					continuation.resume(returning: (false, error.localizedDescription))
					return
				}
				let data = pipe.fileHandleForReading.readDataToEndOfFile()
				process.waitUntilExit()
				continuation.resume(returning: (process.terminationStatus == 0, String(decoding: data, as: UTF8.self)))
			}
		}
	}
}

// MARK: Git

struct GitSettings: View {
	@AppStorage(GitPrefs.prefixKey) private var prefix = BranchNaming.defaultPrefix
	@AppStorage(GitPrefs.templateKey) private var template = BranchNaming.defaultTemplate
	@AppStorage(GitPrefs.mergeKey) private var merge = "merge"
	@AppStorage(GitPrefs.draftKey) private var draft = true
	@AppStorage(GitPrefs.leaseKey) private var lease = false
	@AppStorage(GitPrefs.commitKey) private var commitGuide = ""
	@AppStorage(GitPrefs.prKey) private var prGuide = ""

	private var preview: String {
		BranchNaming.name(prefix: prefix, template: template, feature: "Sửa lỗi đăng nhập", branch: "main")
	}

	var body: some View {
		Form {
			Section {
				TextField(L("set.git.prefix"), text: $prefix, prompt: Text(BranchNaming.defaultPrefix))
				TextField(L("set.git.template"), text: $template, prompt: Text(BranchNaming.defaultTemplate))
				LabeledContent(L("set.git.preview")) {
					Text(preview).font(.system(size: 12, design: .monospaced)).foregroundStyle(FB.textSecondary)
						.textSelection(.enabled)
				}
			} header: { Text(L("set.git.branches")) } footer: {
				SettingsNote("\(L("set.git.placeholders")) \(BranchNaming.placeholders.joined(separator: "  "))")
			}

			Section {
				Picker(L("set.git.merge"), selection: $merge) {
					Text(L("set.git.mergeMerge")).tag("merge")
					Text(L("set.git.mergeSquash")).tag("squash")
				}
				Toggle(L("set.git.draft"), isOn: $draft)
				Toggle(L("set.git.lease"), isOn: $lease)
			} header: { Text(L("set.git.prs")) } footer: { SettingsNote(L("set.git.leaseNote")) }

			Section {
				guideEditor($commitGuide)
			} header: { Text(L("set.git.commitGuide")) } footer: { SettingsNote(L("set.git.guideNote")) }

			Section {
				guideEditor($prGuide)
			} header: { Text(L("set.git.prGuide")) }
		}
	}

	private func guideEditor(_ text: Binding<String>) -> some View {
		TextEditor(text: text)
			.font(.system(size: 13))
			.frame(minHeight: 84)
			.scrollContentBackground(.hidden)
			.background(RoundedRectangle(cornerRadius: 8).fill(FB.surfaceSecondary))
	}
}

// MARK: Worktrees

struct WorktreeSettings: View {
	@AppStorage("yana.worktree.root") private var root = ""
	@AppStorage("yana.worktree.keep") private var keep = 15
	@AppStorage("yana.worktree.confirm") private var confirm = true
	@State private var entries: [WorktreeEntry] = []
	@State private var message = ""
	@State private var pendingRemove: WorktreeEntry? = nil
	@State private var pendingPrune: [WorktreeEntry] = []
	@State private var loaded = false

	private var workspace: String { RtClient.workspace() }

	var body: some View {
		Form {
			Section {
				LabeledContent(L("set.wt.root")) {
					HStack(spacing: 8) {
						Text(root.isEmpty ? L("set.wt.rootDefault") : root).font(.fbCaption).foregroundStyle(FB.textSecondary)
							.lineLimit(1).truncationMode(.middle)
						Button(L("set.choose")) { chooseRoot() }
						if !root.isEmpty { Button(L("set.reset")) { root = "" } }
					}
				}
				Stepper(value: $keep, in: 1 ... 200) { LabeledContent(L("set.wt.keep"), value: "\(keep)") }
				Toggle(L("set.wt.confirm"), isOn: $confirm)
			} footer: { SettingsNote(L("set.wt.note")) }

			Section {
				if !loaded {
					Text(L("set.wt.loading")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				} else if entries.isEmpty {
					Text(L("set.wt.none")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				}
				ForEach(entries) { entry in row(entry) }
				HStack {
					Button(L("refresh")) { Task { await reload() } }
					Button(L("set.wt.prune")) { planPrune() }.disabled(entries.count <= 1)
					Spacer()
					if !message.isEmpty { Text(message).font(.fbCaption).foregroundStyle(FB.textSecondary).lineLimit(2) }
				}
			} header: { Text("\(L("set.wt.list")) (\(entries.count))") }
		}
		.task { await reload() }
		.alert(L("set.wt.removeTitle"), isPresented: Binding(get: { pendingRemove != nil }, set: { if !$0 { pendingRemove = nil } })) {
			Button(L("set.wt.delete"), role: .destructive) { if let e = pendingRemove { Task { await remove([e]) } }; pendingRemove = nil }
			Button(L("set.cancel"), role: .cancel) { pendingRemove = nil }
		} message: { Text(pendingRemove?.path ?? "") }
		.alert(L("set.wt.pruneTitle"), isPresented: Binding(get: { !pendingPrune.isEmpty }, set: { if !$0 { pendingPrune = [] } })) {
			Button(L("set.wt.delete"), role: .destructive) { let list = pendingPrune; pendingPrune = []; Task { await remove(list) } }
			Button(L("set.cancel"), role: .cancel) { pendingPrune = [] }
		} message: { Text(pendingPrune.map(\.path).joined(separator: "\n")) }
	}

	private func row(_ entry: WorktreeEntry) -> some View {
		HStack(spacing: 10) {
			VStack(alignment: .leading, spacing: 2) {
				Text(entry.branch ?? (entry.detached ? "HEAD \(entry.head.prefix(7))" : "?")).font(.fbBodyMedium).foregroundStyle(FB.text)
				Text(entry.path).font(.fbCaption).foregroundStyle(FB.textSecondary).lineLimit(1).truncationMode(.middle)
			}
			Spacer(minLength: 0)
			if entry.isMain { badge(L("set.wt.main")) }
			if entry.locked { badge(L("set.wt.locked")) }
			if entry.prunable { badge(L("set.wt.stale")) }
			if !entry.isMain && !entry.locked {
				Button(L("set.wt.delete")) { if confirm { pendingRemove = entry } else { Task { await remove([entry]) } } }
			}
		}
	}

	private func badge(_ text: String) -> some View {
		Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(FB.textSecondary)
			.padding(.horizontal, 7).padding(.vertical, 2)
			.background(Capsule().fill(FB.surfaceSecondary))
	}

	private func reload() async {
		let result = await GitRunner.run(["worktree", "list", "--porcelain"], in: workspace)
		entries = result.ok ? Worktrees.parse(porcelain: result.output) : []
		message = result.ok ? "" : L("set.wt.notRepo")
		loaded = true
	}

	private func planPrune() {
		let list = Worktrees.surplus(entries, keep: keep, protecting: workspace) { entry in
			(try? FileManager.default.attributesOfItem(atPath: entry.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
		}
		if list.isEmpty { message = L("set.wt.nothing"); return }
		pendingPrune = list
	}

	// `git worktree remove` without --force: git itself refuses a worktree with uncommitted changes.
	private func remove(_ list: [WorktreeEntry]) async {
		var failed: [String] = []
		for entry in list {
			let result = await GitRunner.run(["worktree", "remove", entry.path], in: workspace)
			if !result.ok { failed.append(URL(fileURLWithPath: entry.path).lastPathComponent) }
		}
		message = failed.isEmpty ? String(format: L("set.wt.removed"), list.count) : "\(L("set.wt.kept")) \(failed.joined(separator: ", "))"
		await reload()
	}

	private func chooseRoot() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		if panel.runModal() == .OK, let url = panel.url { root = url.path }
	}
}

// MARK: Hooks

struct HookSettings: View {
	@State private var hooks: [HookEntry] = []
	@State private var loaded = false

	private var events: [String] { Array(Set(hooks.map(\.event))).sorted() }
	private var issues: Int { hooks.filter(\.scriptMissing).count }

	var body: some View {
		Form {
			Section {
				LabeledContent(L("set.hook.total"), value: "\(hooks.count)")
				LabeledContent(L("set.hook.issues")) {
					Text("\(issues)").foregroundStyle(issues == 0 ? FB.successText : FB.warningText)
				}
				Button(L("refresh")) { load() }
			} footer: { SettingsNote(L("set.hook.note")) }

			if loaded && hooks.isEmpty {
				Section { Text(L("set.hook.none")).font(.fbCaption).foregroundStyle(FB.textSecondary) }
			}
			ForEach(events, id: \.self) { event in
				Section {
					ForEach(hooks.filter { $0.event == event }) { hook in
						VStack(alignment: .leading, spacing: 2) {
							HStack(spacing: 8) {
								Text(hook.matcher).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(FB.text)
								Text(hook.source).font(.fbCaption).foregroundStyle(FB.textSecondary)
								if hook.scriptMissing { Text(L("set.hook.missing")).font(.fbCaption).foregroundStyle(FB.warningText) }
							}
							Text(hook.command).font(.system(size: 11, design: .monospaced)).foregroundStyle(FB.textSecondary)
								.lineLimit(2).truncationMode(.middle).textSelection(.enabled)
						}
					}
				} header: { Text("\(event) (\(hooks.filter { $0.event == event }.count))") }
			}
		}
		.onAppear { if !loaded { load() } }
	}

	// Project settings, project local settings, then the user's own, in that order.
	private func load() {
		let project = RtClient.workspace()
		let home = NSHomeDirectory()
		let files = [("\(project)/.claude/settings.json", L("set.hook.srcProject")),
		             ("\(project)/.claude/settings.local.json", L("set.hook.srcLocal")),
		             ("\(home)/.claude/settings.json", L("set.hook.srcUser"))]
		var found: [HookEntry] = []
		for (path, label) in files {
			guard let data = FileManager.default.contents(atPath: path) else { continue }
			found += HookScan.parse(json: data, source: label, projectDir: project) { FileManager.default.fileExists(atPath: $0) }
		}
		hooks = found
		loaded = true
	}
}
