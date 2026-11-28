import Foundation
import SwiftUI

// "Auto" mode: the user lets Yana run project commands and edit project files without a click per call,
// for a set time. It is yana-rt's Capability Lease, not an app-side switch: the app asks yana-rt to grant
// time-boxed, budget-boxed leases to the subject "agent:yana-app" and sends that subject with each chat
// turn. yana-rt still checks HALT, the destructive-command guard and the lease scope on every call and
// writes a receipt for each. Web fetches, MCP calls and config writes are never leased: they always ask.
// Stopping revokes the leases at once; leftovers from a closed app are revoked at the next launch.

@MainActor
final class AutoRunStore: ObservableObject {
	static let shared = AutoRunStore()
	static let subject = "agent:yana-app"
	static let budget = 100 // calls per capability per session; the time limit usually ends it first
	static let durations = [30, 60, 240]
	// File edits carry no command text, so their lease needs no allow list (yana-rt keeps them in the repo).
	static let fileCapabilities = ["file.write", "file.patch"]
	// Commands must match an allow entry (prefix, by words) and no deny entry. An empty allow list allows nothing.
	static let allow = ["npm test", "cargo build", "cargo test", "cargo check", "cargo clippy", "swift build", "swift test",
	                    "go build", "go test", "ls", "cat", "pwd", "git status", "git diff", "git log", "git show"]
	static let deny = ["rm", "sudo", "git push", "git reset", "git clean", "curl", "wget", "ssh", "scp",
	                   "chmod", "chown", "dd", "mv"]

	@Published private(set) var until: Date?
	@Published private(set) var error: String?
	private var leaseIDs: [String] = []
	private var folder = ""
	private var timer: Timer?

	var isOn: Bool { until.map { $0 > Date() } ?? false }

	// What the user picked under "Custom…", remembered between launches.
	struct Choice: Codable, Equatable {
		var minutes = 60
		var commands = true
		var files = true
	}
	static let minuteRange = 5 ... 480
	private static let choiceKey = "yana.auto.custom"

	static var savedChoice: Choice {
		get {
			guard let data = UserDefaults.standard.data(forKey: choiceKey),
			      let choice = try? JSONDecoder().decode(Choice.self, from: data) else { return Choice() }
			return choice
		}
		set { if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: choiceKey) } }
	}

	func start(minutes: Int, folder: String) {
		start(Choice(minutes: minutes), folder: folder)
	}

	func start(_ choice: Choice, folder: String) {
		stop()
		self.folder = folder
		error = nil
		guard choice.commands || choice.files else { error = L("auto.pickOne"); return }
		let minutes = min(max(choice.minutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
		var ids: [String] = []
		do {
			if choice.commands {
				let allow = Self.allow
				ids.append(try grant("command.execute", minutes: minutes, scope: allow.flatMap { ["--allow", $0] } + Self.deny.flatMap { ["--deny", $0] }))
			}
			if choice.files {
				for capability in Self.fileCapabilities { ids.append(try grant(capability, minutes: minutes, scope: [])) }
			}
		} catch {
			for id in ids { revoke(id) } // all or nothing
			self.error = error.localizedDescription
			return
		}
		leaseIDs = ids
		until = Date().addingTimeInterval(TimeInterval(minutes * 60))
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			Task { @MainActor in
				guard let self else { return }
				if !self.isOn { self.stop() } else { self.objectWillChange.send() }
			}
		}
	}

	func stop() {
		timer?.invalidate()
		timer = nil
		for id in leaseIDs { revoke(id) }
		leaseIDs = []
		until = nil
	}

	// Revokes this app's leases still active in `folder` (the app quit while Auto was on).
	func revokeLeftovers(folder: String) {
		self.folder = folder
		guard let data = try? rt(["lease", "list", "--json"]),
		      let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
		for lease in list where lease["subject"] as? String == Self.subject && (lease["revoked"] as? Bool) == false {
			if let id = lease["id"] as? String { revoke(id) }
		}
	}

	// A personal grant is kept outside the project, so a folder cannot ship one.
	static func grantArguments(_ capability: String, minutes: Int, scope: [String]) -> [String] {
		["lease", "grant", "--personal", "--subject", subject, "--capability", capability,
		 "--expires-in-minutes", String(minutes), "--invocation-budget", String(budget)] + scope + ["--json"]
	}

	// What to tell the person about a failed yana-rt call.
	static func problem(_ detail: String) -> String {
		if detail.contains("--personal") { return L("auto.needsNewRt") }
		return detail.contains("flock-v1") ? L("auto.notInstalledHere") : detail
	}

	private func grant(_ capability: String, minutes: Int, scope: [String]) throws -> String {
		let data = try rt(Self.grantArguments(capability, minutes: minutes, scope: scope))
		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let id = json["id"] as? String else {
			throw AutoRunError.message(L("auto.grantFailed"))
		}
		return id
	}

	private func revoke(_ id: String) {
		do { _ = try rt(["lease", "revoke", id, "--json"]) } catch {
			self.error = "\(L("auto.revokeFailed")) \(id): \(error.localizedDescription)"
		}
	}

	// Runs yana-rt in the project folder with fixed arguments; stderr becomes the error text.
	private func rt(_ args: [String]) throws -> Data {
		guard let binary = RtClient.binaryPath() else { throw AutoRunError.message(RtError.notInstalled.message) }
		let process = Process()
		process.executableURL = URL(fileURLWithPath: binary)
		process.arguments = args
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
			throw AutoRunError.message(Self.problem(detail))
		}
		return data
	}
}

enum AutoRunError: LocalizedError {
	case message(String)
	var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

// The composer chip: "Auto" off, or the time left while on. The popover picks a duration or stops.
struct AutoRunChip: View {
	@ObservedObject var store: AutoRunStore
	let folder: String
	@State private var open = false
	@State private var custom = false
	@State private var choice = AutoRunStore.savedChoice

	private var remaining: String {
		guard let until = store.until else { return "" }
		let left = max(Int(until.timeIntervalSinceNow), 0)
		return String(format: "%d:%02d", left / 60, left % 60)
	}

	var body: some View {
		Chip(icon: store.isOn ? "clock" : "play", title: store.isOn ? "\(L("auto.on")) \(remaining)" : L("auto.title"), trailing: "chevron-down")
			.overlay(Capsule().stroke(store.isOn ? FB.primary : .clear, lineWidth: 1.5))
			.help(L("auto.help"))
			.onTapGesture { open = true }
			.popover(isPresented: $open, arrowEdge: .top) { menu }
	}

	private var menu: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(L("auto.title")).font(.fbHeading5).foregroundStyle(FB.text)
			Text(L("auto.explain")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				.fixedSize(horizontal: false, vertical: true)
			if store.isOn {
				FBButton(title: "\(L("auto.stop")) (\(remaining))", variant: .danger) { store.stop(); open = false }
			} else {
				HStack {
					ForEach(AutoRunStore.durations, id: \.self) { minutes in
						FBButton(title: minutes < 60 ? "\(minutes) \(L("auto.min"))" : "\(minutes / 60) \(L("auto.hour"))", variant: .secondary) {
							store.start(minutes: minutes, folder: folder)
							if store.error == nil { open = false }
						}
					}
					FBButton(title: L("auto.custom"), variant: custom ? .primary : .outline) { custom.toggle() }
				}
				if custom { customForm }
			}
			DisclosureGroup(L("auto.scope")) {
				Text("\(L("auto.allowed")): \(AutoRunStore.allow.joined(separator: ", "))")
				Text("\(L("auto.denied")): \(AutoRunStore.deny.joined(separator: ", "))")
				Text(L("auto.alwaysAsk"))
			}
			.font(.fbCaption).foregroundStyle(FB.textSecondary)
			if let error = store.error { Text(error).font(.fbCaption).foregroundStyle(FB.errorText).fixedSize(horizontal: false, vertical: true) }
		}
		.padding(16).frame(width: 420)
	}

	// Custom: any duration and which kinds of work.
	private var customForm: some View {
		VStack(alignment: .leading, spacing: 10) {
			Stepper(value: $choice.minutes, in: AutoRunStore.minuteRange, step: 5) {
				Text("\(L("auto.duration")): \(choice.minutes) \(L("auto.min"))").font(.fbBody)
			}
			Toggle(L("auto.runCommands"), isOn: $choice.commands)
			Toggle(L("auto.editFiles"), isOn: $choice.files)
			HStack {
				Spacer()
				FBButton(title: L("auto.startCustom"), variant: .primary) {
					AutoRunStore.savedChoice = choice
					store.start(choice, folder: folder)
					if store.error == nil { open = false; custom = false }
				}
			}
		}
		.font(.fbBody)
		.padding(12)
		.background(RoundedRectangle(cornerRadius: FB.radiusLG).fill(FB.surfaceSecondary))
	}
}
