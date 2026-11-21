import AppKit
import SwiftUI

// Settings panes that show state rather than change it: safety (from yana-rt), where data lives, and
// keyboard shortcuts. Values come from yana-rt and the file system, read when the pane opens.

struct SecuritySettings: View {
	let openApprovals: () -> Void
	@State private var approvals: ApprovalsData? = nil
	@State private var connectors: [Connector] = []
	@State private var trust: [(name: String, state: String)] = []

	var body: some View {
		Form {
			Section {
				LabeledContent(L("set.secPending"), value: count(approvals?.pending.count))
				LabeledContent(L("set.secDecisions"), value: count(approvals?.decisions.count))
				LabeledContent(L("set.secExecutions"), value: count(approvals?.executions.count))
				Button(L("set.secOpenApprovals"), action: openApprovals)
			} header: { Text(L("nav.Tool approvals")) } footer: { SettingsNote(L("set.secNote")) }

			Section {
				let enabled = connectors.filter { !$0.enabledScopes.isEmpty }
				LabeledContent(L("set.secConnectors"), value: "\(enabled.count) / \(connectors.count)")
				ForEach(enabled, id: \.name) { connector in
					LabeledContent(connector.name, value: connector.enabledScopes.joined(separator: ", "))
				}
			} header: { Text(L("nav.Plugins")) }

			Section {
				if trust.isEmpty { Text(L("loading")).font(.fbCaption).foregroundStyle(FB.textSecondary) }
				ForEach(trust, id: \.name) { item in LabeledContent(item.name, value: item.state) }
			} header: { Text(L("set.secTrust")) } footer: { SettingsNote(L("set.secTrustNote")) }
		}
		.task { await load() }
	}

	private func count(_ value: Int?) -> String { value.map(String.init) ?? "…" }

	private func load() async {
		let result = await Task.detached { () -> (ApprovalsData, [Connector], String) in
			let connectors = (try? RtClient.loadConnectors().get()) ?? []
			return (RtClient.loadApprovals(), connectors, RtClient.act(["trust", "status"]).message)
		}.value
		approvals = result.0
		connectors = result.1
		// `trust status` prints "name   state" lines.
		trust = result.2.split(separator: "\n").compactMap { line in
			let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
			guard parts.count == 2 else { return nil }
			return (String(parts[0]), parts[1].trimmingCharacters(in: .whitespaces))
		}
	}
}

struct DataSettings: View {
	@EnvironmentObject private var engine: ChatEngine
	@ObservedObject private var history = ChatHistoryStore.shared
	@State private var message = ""
	@State private var confirmDelete = false
	private var appData: URL {
		FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/YanaApp")
	}
	private var projectData: URL { URL(fileURLWithPath: engine.workspace).appendingPathComponent(".yana-ai") }

	var body: some View {
		Form {
			Section {
				LabeledContent(L("data.chats"), value: String(format: L("data.counts"), history.chats.count, ChatSections.archivedCount(history.chats)))
				Button(L("data.export")) { exportAll() }.disabled(history.chats.isEmpty)
				Button(L("data.archiveAll")) { history.archiveAll(); engine.reset() }
					.disabled(history.chats.allSatisfy(\.isArchived))
				Button(L("data.deleteAll"), role: .destructive) { confirmDelete = true }.disabled(history.chats.isEmpty)
				if !message.isEmpty { Text(message).font(.fbCaption).foregroundStyle(FB.textSecondary) }
			} header: { Text(L("data.chats")) }

			Section {
				folderRow(L("set.dataApp"), appData)
				folderRow(L("set.dataProject"), projectData)
				LabeledContent(L("set.dataKeychain"), value: "ai.yana.app.provider-key")
			} footer: { SettingsNote(L("set.dataNote")) }

			Section {
				fileRow("ledger.jsonl", L("set.dataLedger"))
				fileRow("authority-receipts.jsonl", L("set.dataReceipts"))
				fileRow("pending-approvals.json", L("set.dataPending"))
			} header: { Text(L("set.dataFiles")) }
		}
		.alert(L("data.deleteTitle"), isPresented: $confirmDelete) {
			Button(L("data.deleteConfirm"), role: .destructive) { engine.reset(); history.deleteAll(); message = "" }
			Button(L("set.cancel"), role: .cancel) {}
		} message: { Text(L("data.deleteBody")) }
	}

	private func exportAll() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		guard panel.runModal() == .OK, let base = panel.url else { return }
		let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
		do {
			let count = try history.exportAll(to: base.appendingPathComponent("Yana chats \(stamp)", isDirectory: true))
			message = String(format: L("data.exportDone"), count)
		} catch {
			message = "\(L("data.exportFailed")): \(error.localizedDescription)"
		}
	}

	private func folderRow(_ title: String, _ url: URL) -> some View {
		let exists = FileManager.default.fileExists(atPath: url.path)
		return LabeledContent(title) {
			HStack(spacing: 8) {
				Text(url.path).font(.fbCaption).foregroundStyle(FB.textSecondary).lineLimit(1).truncationMode(.middle)
				Button(L("set.showInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }.disabled(!exists)
			}
		}
	}

	private func fileRow(_ name: String, _ title: String) -> some View {
		let url = projectData.appendingPathComponent(name)
		let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
		return LabeledContent(title) {
			Text(size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? L("set.dataNone"))
				.font(.fbCaption).foregroundStyle(FB.textSecondary)
		}
	}
}

// The Shortcuts pane is in ShortcutViews.swift.
