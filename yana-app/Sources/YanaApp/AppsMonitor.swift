import AppKit

// The two Yana apps as the panel shows them. Refreshed by SystemMonitor, so only while the panel is open.

struct AppCard: Equatable {
	var running = false
	var version: String?
	var use: AppUse?
}

@MainActor
final class AppsMonitor: ObservableObject {
	nonisolated static let studioID = "link.vutam.yana.studio"

	@Published private(set) var yana = AppCard()
	@Published private(set) var studio = AppCard()
	@Published private(set) var studioSessions = (working: 0, waiting: 0)

	private var previous: [String: (at: Date, use: [Int32: ProcessUse])] = [:]
	private var scanning = false
	private var apps: (at: Date, byFolder: [String: String]) = (.distantPast, [:])
	nonisolated private static let appsMaxAge: TimeInterval = 6   // listing every command line is not free

	func reset() { previous = [:] }

	func refresh(editor: URL?) {
		let parents = AppProbe.parents()
		let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.studioID)
		let studioRoots = running.map(\.processIdentifier)
		yana = card("yana", roots: [ProcessInfo.processInfo.processIdentifier], parents: parents, bundle: Bundle.main.bundleURL)
		// The copy that is running may not be the one Yana would open, so its own version is shown.
		studio = card("studio", roots: studioRoots, parents: parents, bundle: running.first?.bundleURL ?? editor)
		if studioRoots.isEmpty { studioSessions = (0, 0) } else { scanSessions() }
	}

	private func card(_ key: String, roots: [Int32], parents: [Int32: Int32], bundle: URL?) -> AppCard {
		// Read from disk each time: Bundle caches the plist, and an app can be updated while Yana runs.
		let plist = bundle.flatMap { NSDictionary(contentsOf: $0.appendingPathComponent("Contents/Info.plist")) }
		let version = plist?["CFBundleShortVersionString"] as? String
		guard !roots.isEmpty else { previous[key] = nil; return AppCard(version: version) }
		let now = Date()
		let use = AppProbe.use(of: AppStats.tree(roots: roots, parents: parents))
		let old = previous[key]
		previous[key] = (now, use)
		let result = AppStats.use(now: use, before: old?.use, seconds: old.map { now.timeIntervalSince($0.at) } ?? 0,
		                          cores: ProcessInfo.processInfo.activeProcessorCount)
		return AppCard(running: true, version: version, use: result)
	}

	// Claude Code sessions in the editor's terminal, read from its own logs. Nothing has to be set up for this.
	private func scanSessions() {
		guard !scanning else { return }
		scanning = true
		let cached = apps
		Task.detached(priority: .utility) { [weak self] in
			var found = TranscriptSessions.scan()
			var apps = cached
			if !found.isEmpty, Date().timeIntervalSince(apps.at) > Self.appsMaxAge {
				apps = (Date(), ProcessTable.appsByFolder())
			}
			for index in found.indices { found[index].appBundleID = apps.byFolder[found[index].cwd] }
			let counts = AppStats.sessions(found, app: Self.studioID)
			await self?.finishScan(counts, apps: apps)
		}
	}

	private func finishScan(_ counts: (working: Int, waiting: Int), apps: (at: Date, byFolder: [String: String])) {
		studioSessions = counts
		self.apps = apps
		scanning = false
	}
}
