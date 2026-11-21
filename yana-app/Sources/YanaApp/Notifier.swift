import Foundation
import UserNotifications

// A macOS notification when a long turn finishes, or the agent waits for a decision, while the app is not the
// window in front: the person has gone to another app and would not otherwise know. Off by a switch in
// Settings. Only the packaged app can post: a binary run straight from the build folder has no bundle identity
// and the notification center would stop the process, so there it is skipped.

enum Notifier {
	// A turn shorter than this is not worth a notification; a wait for the person always is.
	static let minSeconds: TimeInterval = 15
	static let defaultsKey = "yana.notify"

	static var enabled: Bool { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }

	static func shouldNotify(enabled: Bool, appActive: Bool, elapsed: TimeInterval, needsPerson: Bool) -> Bool {
		guard enabled, !appActive else { return false }
		return needsPerson || elapsed >= minSeconds
	}

	// The first useful line of a reply, without Markdown markers or a code fence line, cut to `limit` characters.
	static func summary(_ text: String, limit: Int = 120) -> String {
		for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
			var line = raw.trimmingCharacters(in: .whitespaces)
			if line.hasPrefix("```") { continue }
			while let first = line.first, "#>-*• ".contains(first) { line.removeFirst() }
			line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
				.trimmingCharacters(in: .whitespaces)
			if line.isEmpty { continue }
			return line.count > limit ? String(line.prefix(limit)) + "…" : line
		}
		return ""
	}

	// Asks for permission the first time (the system shows its own dialog once), then posts.
	static func post(title: String, body: String, id: String) {
		guard Bundle.main.bundleIdentifier != nil else { return }
		let center = UNUserNotificationCenter.current()
		center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
			guard granted else { return }
			let content = UNMutableNotificationContent()
			content.title = title
			content.body = body
			center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
		}
	}
}
