import Foundation
import SwiftUI

// The Reasoning chip. Whether a provider and model take a reasoning setting is decided by one table inside
// yana-rt (`yana-rt reasoning --provider P --model M --json`); the app keeps no list of its own, so the chip and
// the runtime cannot disagree. A runtime without that command, or a model not on its table, leaves the chip off
// and sends nothing. The choice is sent as `reasoning_effort` on the next turn only when the current model takes it.

enum ReasoningLevel: String, CaseIterable, Identifiable {
	case low, medium, high
	var id: String { rawValue }
	var title: String { L("reasoning.\(rawValue)") }
}

struct ReasoningSupport: Equatable {
	var supported = false
	var levels: [ReasoningLevel] = []

	// nil for anything that is not a report, so a malformed answer reads as "not available".
	static func from(_ json: [String: Any]) -> ReasoningSupport? {
		guard let supported = json["supported"] as? Bool else { return nil }
		let names = json["levels"] as? [String] ?? []
		return ReasoningSupport(supported: supported, levels: names.compactMap { ReasoningLevel(rawValue: $0) })
	}
}

@MainActor
final class ReasoningStore: ObservableObject {
	static let shared = ReasoningStore()
	private static let defaultsKey = "yana.reasoning"

	@Published private(set) var support = ReasoningSupport()
	// The person's pick; nil is off. Kept across models, applied only where the model takes it.
	@Published var chosen: ReasoningLevel? {
		didSet { UserDefaults.standard.set(chosen?.rawValue, forKey: Self.defaultsKey) }
	}
	private var asked = ""

	init() {
		chosen = UserDefaults.standard.string(forKey: Self.defaultsKey).flatMap { ReasoningLevel(rawValue: $0) }
	}

	// What goes to yana-rt: a chosen level the current model is known to take, otherwise nothing.
	var activeLevel: ReasoningLevel? {
		guard support.supported, let chosen, support.levels.contains(chosen) else { return nil }
		return chosen
	}

	func refresh(provider: String, model: String?) async {
		let id = "\(provider)|\(model ?? "")"
		asked = id
		guard let model, !model.isEmpty, let binary = RtClient.binaryPath() else { support = ReasoningSupport(); return }
		let answer = await Task.detached { Self.ask(binary: binary, provider: provider, model: model) }.value
		// A newer question was asked while this one ran: that answer wins.
		guard asked == id else { return }
		support = answer ?? ReasoningSupport()
	}

	nonisolated private static func ask(binary: String, provider: String, model: String) -> ReasoningSupport? {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: binary)
		process.arguments = ["reasoning", "--provider", provider, "--model", model, "--json"]
		process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
		let out = Pipe()
		process.standardOutput = out
		process.standardError = Pipe()
		do { try process.run() } catch { return nil }
		let data = out.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()
		// A runtime that predates the command exits non-zero: the chip stays off.
		guard process.terminationStatus == 0,
		      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
		return ReasoningSupport.from(json)
	}
}

struct ReasoningChip: View {
	@ObservedObject var store: ReasoningStore
	@ObservedObject var engine: ChatEngine
	@State private var open = false

	private var on: Bool { store.support.supported }

	private var title: String {
		guard on, let level = store.activeLevel else { return L("chat.reasoning") }
		return "\(L("chat.reasoning")): \(level.title)"
	}

	var body: some View {
		Chip(icon: "layers", title: title, trailing: on ? "chevron-down" : nil)
			.opacity(on ? 1 : 0.45)
			.help(on ? L("reasoning.help") : L("reasoning.unavailable"))
			.onTapGesture { if on { open = true } }
			.popover(isPresented: $open, arrowEdge: ChatHome.popoverEdge) { menu }
			.task(id: "\(engine.provider)|\(engine.model ?? "")") {
				await store.refresh(provider: engine.provider, model: engine.model)
			}
	}

	private var menu: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(L("chat.reasoning")).font(.fbHeading5).foregroundStyle(FB.text).padding(.bottom, 4)
			row(nil, L("reasoning.off"))
			ForEach(store.support.levels) { level in row(level, level.title) }
			Text(L("reasoning.note")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				.fixedSize(horizontal: false, vertical: true).padding(.top, 6)
		}
		.padding(12)
		.frame(width: 260)
		.background(FB.canvas)
	}

	private func row(_ level: ReasoningLevel?, _ name: String) -> some View {
		let chosen = store.chosen == level
		return HStack(spacing: 8) {
			FBIcon(name: chosen ? "check" : "layers", size: 14, color: chosen ? FB.primaryText : FB.textTertiary)
			Text(name).font(.system(size: 13, weight: chosen ? .semibold : .regular)).foregroundStyle(FB.text)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 8)
		.frame(height: 30)
		.background(RoundedRectangle(cornerRadius: 8).fill(chosen ? FB.primarySubtle : .clear))
		.contentShape(Rectangle())
		.onTapGesture { store.chosen = level; open = false }
	}
}
