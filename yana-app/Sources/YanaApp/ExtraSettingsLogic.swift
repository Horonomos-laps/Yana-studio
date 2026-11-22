import AppKit
import Foundation
import SwiftUI

// Logic behind the Appearance, Notifications and Sleep settings, kept apart from the views so it can be tested.

// The font and size of code in replies. "" is the system monospaced font (SF Mono).
enum CodeFont {
	static let defaultSize = 12.5
	static let sizeRange: ClosedRange<Double> = 10 ... 20
	static let sizeStep = 0.5
	static let sample = "func greet(name: String) -> String {\n\treturn \"Xin chào, \\(name)!\"\n}"

	// PostScript names, so the lookup works; the label is what the person reads.
	static let candidates: [(id: String, label: String)] = [
		("Menlo-Regular", "Menlo"), ("Monaco", "Monaco"), ("AndaleMono", "Andale Mono"), ("CourierNewPSMT", "Courier New"),
	]

	// Only the fonts this Mac really has.
	static var choices: [(id: String, label: String)] { candidates.filter { NSFont(name: $0.id, size: 12) != nil } }

	static func clampedSize(_ value: Double) -> Double { min(max(value, sizeRange.lowerBound), sizeRange.upperBound) }

	static func font(name: String, size: Double) -> Font {
		let size = clampedSize(size)
		if !name.isEmpty, NSFont(name: name, size: size) != nil { return .custom(name, size: size) }
		return .system(size: size, design: .monospaced)
	}
}

// What to notify about, and when. `enabled` is the old single switch (Notifier.defaultsKey), so a person who turned
// notifications off stays off.
struct NotifyPrefs: Equatable {
	static let doneKey = "yana.notify.done"
	static let approvalKey = "yana.notify.approval"
	static let minSecondsKey = "yana.notify.minSeconds"
	static let soundKey = "yana.notify.sound"
	static let defaultMinSeconds = 15.0
	static let minChoices: [Double] = [0, 15, 30, 60, 180]

	var enabled = true
	var onDone = true
	var onApproval = true
	var minSeconds = NotifyPrefs.defaultMinSeconds
	var sound = true

	static func current(_ defaults: UserDefaults = .standard) -> NotifyPrefs {
		NotifyPrefs(enabled: defaults.object(forKey: Notifier.defaultsKey) as? Bool ?? true,
		            onDone: defaults.object(forKey: doneKey) as? Bool ?? true,
		            onApproval: defaults.object(forKey: approvalKey) as? Bool ?? true,
		            minSeconds: defaults.object(forKey: minSecondsKey) as? Double ?? defaultMinSeconds,
		            sound: defaults.object(forKey: soundKey) as? Bool ?? true)
	}

	// Never while the app is in front. A wait for the person follows its own switch; a finished turn needs its
	// switch and to have run at least `minSeconds`.
	func shouldNotify(appActive: Bool, elapsed: TimeInterval, needsPerson: Bool) -> Bool {
		guard enabled, !appActive else { return false }
		return needsPerson ? onApproval : (onDone && elapsed >= minSeconds)
	}
}

// Keeps the Mac awake while Yana works, if the person asked: a long reply would otherwise be cut by the Mac going
// to sleep. The hold ends the moment the work does, or the switch goes off.
@MainActor
final class SleepGuard {
	static let shared = SleepGuard()
	static let key = "yana.keepAwake"
	private var token: NSObjectProtocol?

	nonisolated static func shouldHold(enabled: Bool, running: Bool) -> Bool { enabled && running }
	var isHolding: Bool { token != nil }

	func update(enabled: Bool, running: Bool) {
		let hold = Self.shouldHold(enabled: enabled, running: running)
		if hold, token == nil {
			token = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated],
			                                              reason: "Yana is working")
		} else if !hold, let held = token {
			ProcessInfo.processInfo.endActivity(held)
			token = nil
		}
	}
}
