import Foundation
import SwiftUI

// How much the agent may do without asking: the control level (1 to 5) and the away mode. Both live in yana-rt
// (`level get|set`, `away start|status|stop|report`) and are kept in the person's own store, outside the project,
// so the app only reads and asks; it never decides what is allowed. A runtime that predates them has no such
// commands, so everything here is offered only when `RtClient.supportsAutonomyControls` is true.

extension RtClient {
	// `level` and `away` shipped in the same yana-rt release as the remember-an-answer scope.
	static var supportsAutonomyControls: Bool { supportsApprovalScopes }
}

struct LevelState: Equatable {
	var level = 2
	// Levels above this one only record what they would have approved; they approve nothing yet.
	var enforcedUpTo = 2
	var problem: String?

	var observedOnly: Bool { level > enforcedUpTo }

	// nil for anything that is not a level report, so a malformed answer changes nothing.
	static func from(_ json: [String: Any]) -> LevelState? {
		guard let level = (json["level"] as? NSNumber)?.intValue, (1 ... 5).contains(level) else { return nil }
		let enforced = (json["enforced_up_to"] as? NSNumber)?.intValue ?? 2
		return LevelState(level: level, enforcedUpTo: min(max(enforced, 1), 5), problem: json["problem"] as? String)
	}
}

struct AwayState: Equatable {
	var active = false
	var level = 4
	var budget = 0
	var used = 0
	var parked = 0
	var expiresAt: Date?

	var remaining: Int { max(budget - used, 0) }

	static func from(_ json: [String: Any]) -> AwayState? {
		guard let active = json["active"] as? Bool else { return nil }
		var state = AwayState(active: active)
		state.parked = (json["parked"] as? NSNumber)?.intValue ?? 0
		guard active else { return state }
		state.level = (json["level"] as? NSNumber)?.intValue ?? 4
		state.budget = (json["budget"] as? NSNumber)?.intValue ?? 0
		state.used = (json["used"] as? NSNumber)?.intValue ?? 0
		state.expiresAt = parseDate(json["expires_at"] as? String)
		return state
	}

	// yana-rt writes times like "2026-11-19T14:20:10.426185Z", with or without the fraction.
	static func parseDate(_ text: String?) -> Date? {
		guard let text else { return nil }
		let withFraction = ISO8601DateFormatter()
		withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
	}
}

// One action that waited for the person: what it was and why it was not approved.
struct ParkedEntry: Identifiable, Equatable {
	let id: String
	let capability: String
	let summary: String
	let reason: String

	static func list(from json: [String: Any]) -> [ParkedEntry] {
		(json["parked_items"] as? [[String: Any]] ?? []).compactMap { item in
			guard let id = item["id"] as? String, let capability = item["capability"] as? String else { return nil }
			return ParkedEntry(id: id, capability: capability, summary: item["summary"] as? String ?? "", reason: item["reason"] as? String ?? "")
		}
	}
}

@MainActor
final class AutonomyStore: ObservableObject {
	static let shared = AutonomyStore()
	static let decidedBy = "human:yana-app"
	static let durations = [30, 60, 240]
	static let budgetRange = 10 ... 500
	static let defaultBudget = 50
	static let awayLevels = [3, 4, 5]

	@Published private(set) var level = LevelState()
	@Published private(set) var away = AwayState()
	@Published private(set) var parked: [ParkedEntry] = []
	@Published private(set) var error: String?
	private var folder = ""
	private var timer: Timer?

	// Reads both from yana-rt; a failure keeps what was shown and says why.
	func refresh(folder: String) {
		self.folder = folder
		guard RtClient.supportsAutonomyControls else { return }
		do {
			if let state = LevelState.from(try run(["level", "get"])) { level = state }
			let report = try run(["away", "report"])
			if let state = AwayState.from(report) { away = state }
			parked = ParkedEntry.list(from: report)
			error = nil
		} catch { self.error = error.localizedDescription }
		updateTimer()
	}

	func setLevel(_ number: Int) {
		act { _ = try self.run(["level", "set", String(number), "--decided-by", Self.decidedBy]) }
	}

	func startAway(minutes: Int, budget: Int, level: Int) {
		act {
			_ = try self.run(["away", "start", "--minutes", String(minutes), "--budget", String(budget),
			                  "--level", String(level), "--decided-by", Self.decidedBy])
		}
	}

	func stopAway() { act { _ = try self.run(["away", "stop"]) } }

	// The person has read the queue.
	func clearParked() { act { _ = try self.run(["away", "report", "--clear"]) } }

	private func act(_ change: () throws -> Void) {
		do { try change(); error = nil } catch { self.error = error.localizedDescription }
		refresh(folder: folder)
	}

	// While the box is on, look again every few seconds: what it has used, what is waiting, and when it ends.
	private func updateTimer() {
		guard away.active else { timer?.invalidate(); timer = nil; return }
		guard timer == nil else { return }
		timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
			Task { @MainActor in
				guard let self else { return }
				self.refresh(folder: self.folder)
			}
		}
	}

	// Runs yana-rt in the project folder (its root is the folder it was started in) and reads its JSON answer.
	private func run(_ args: [String]) throws -> [String: Any] {
		guard let binary = RtClient.binaryPath() else { throw AutoRunError.message(RtError.notInstalled.message) }
		let process = Process()
		process.executableURL = URL(fileURLWithPath: binary)
		process.arguments = args + ["--json"]
		process.currentDirectoryURL = URL(fileURLWithPath: folder)
		let out = Pipe(), err = Pipe()
		process.standardOutput = out
		process.standardError = err
		try process.run()
		let data = out.fileHandleForReading.readDataToEndOfFile()
		let errorText = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
		process.waitUntilExit()
		guard process.terminationStatus == 0 else {
			let detail = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
			throw AutoRunError.message(detail.contains("flock-v1") ? L("auto.notInstalledHere") : detail)
		}
		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw AutoRunError.message(RtError.badOutput(args.joined(separator: " ")).message)
		}
		return json
	}
}
