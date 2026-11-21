import SwiftUI

// Personalization: standing facts and instructions the person writes once, sent as a system instruction on every
// chat turn (ChatEngine). Like the Git guidance, nothing is sent while all the fields are empty. Stored in
// UserDefaults on this Mac only.

enum Personalization {
	static let nameKey = "yana.personal.name"
	static let aboutKey = "yana.personal.about"
	static let rulesKey = "yana.personal.rules"
	static let maxChars = 2000
	static let maxNameChars = 80

	// Trimmed, and cut so a pasted document cannot flood every request.
	static func clean(_ text: String, limit: Int = maxChars) -> String {
		String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
	}

	static func instruction(_ d: UserDefaults = .standard) -> String? {
		let name = clean(d.string(forKey: nameKey) ?? "", limit: maxNameChars)
		let about = clean(d.string(forKey: aboutKey) ?? "")
		let rules = clean(d.string(forKey: rulesKey) ?? "")
		var parts: [String] = []
		if !name.isEmpty { parts.append("The user's name is \(name). Address them that way.") }
		if !about.isEmpty { parts.append("About the user, from the user:\n\(about)") }
		if !rules.isEmpty { parts.append("Standing instructions from the user. Follow them in every reply unless a request says otherwise:\n\(rules)") }
		return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
	}
}

struct PersonalSettings: View {
	@AppStorage(Personalization.nameKey) private var name = ""
	@AppStorage(Personalization.aboutKey) private var about = ""
	@AppStorage(Personalization.rulesKey) private var rules = ""

	var body: some View {
		Form {
			Section {
				TextField(L("per.name"), text: $name, prompt: Text(L("per.namePrompt")))
			}
			Section {
				editor($about, prompt: L("per.aboutPrompt"))
			} header: { Text(L("per.about")) } footer: { counter(about) }
			Section {
				editor($rules, prompt: L("per.rulesPrompt"))
			} header: { Text(L("per.rules")) } footer: { counter(rules) }
			Section { SettingsNote(L("per.note")) }
		}
	}

	private func editor(_ text: Binding<String>, prompt: String) -> some View {
		ZStack(alignment: .topLeading) {
			TextEditor(text: text).font(.system(size: 13)).scrollContentBackground(.hidden)
				.frame(minHeight: 96).padding(4)
			if text.wrappedValue.isEmpty {
				Text(prompt).font(.system(size: 13)).foregroundStyle(FB.textTertiary).padding(.horizontal, 9).padding(.vertical, 12)
					.allowsHitTesting(false)
			}
		}
		.background(RoundedRectangle(cornerRadius: 8).fill(FB.surfaceSecondary))
	}

	private func counter(_ text: String) -> some View {
		let over = text.count > Personalization.maxChars
		return Text("\(text.count) / \(Personalization.maxChars)").font(.fbCaption)
			.foregroundStyle(over ? FB.warningText : FB.textTertiary)
			.frame(maxWidth: .infinity, alignment: .trailing)
	}
}
