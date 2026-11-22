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
		let style = PersonalStyle.current(d).sentences
		if !style.isEmpty { parts.append("Reply style the user asked for:\n" + style.map { "- " + $0 }.joined(separator: "\n")) }
		if !rules.isEmpty { parts.append("Standing instructions from the user. Follow them in every reply unless a request says otherwise:\n\(rules)") }
		return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
	}
}

struct PersonalSettings: View {
	@AppStorage(Personalization.nameKey) private var name = ""
	@AppStorage(Personalization.aboutKey) private var about = ""
	@AppStorage(Personalization.rulesKey) private var rules = ""
	@AppStorage(PersonalStyle.toneKey) private var tone = BaseTone.standard.rawValue
	@AppStorage(PersonalStyle.warmKey) private var warm = StyleLevel.normal.rawValue
	@AppStorage(PersonalStyle.enthusiasticKey) private var enthusiastic = StyleLevel.normal.rawValue
	@AppStorage(PersonalStyle.emojiKey) private var emoji = StyleLevel.normal.rawValue
	@AppStorage(PersonalStyle.structureKey) private var structure = StyleLevel.normal.rawValue
	@AppStorage(PersonalStyle.visualKey) private var visual = false
	@AppStorage("yana.ui.suggestions") private var suggestions = true
	@State private var editingAgents = false

	var body: some View {
		Form {
			Section {
				Picker(L("per.tone"), selection: $tone) {
					ForEach(BaseTone.allCases) { Text(L("per.tone.\($0.rawValue)")).tag($0.rawValue) }
				}
				level(L("per.warm"), $warm)
				level(L("per.enthusiastic"), $enthusiastic)
				level(L("per.emoji"), $emoji)
				level(L("per.structure"), $structure)
				Toggle(L("per.visual"), isOn: $visual)
				Button(L("per.styleReset")) { resetStyle() }.disabled(PersonalStyle.current() == PersonalStyle())
			} header: { Text(L("per.style")) } footer: { SettingsNote(L("per.styleNote")) }

			Section {
				TextField(L("per.name"), text: $name, prompt: Text(L("per.namePrompt")))
			}
			Section {
				editor($about, prompt: L("per.aboutPrompt"))
			} header: { Text(L("per.about")) } footer: { counter(about) }
			Section {
				editor($rules, prompt: L("per.rulesPrompt"))
			} header: { Text(L("per.rules")) } footer: { counter(rules) }

			Section {
				Button(L("per.agentsEdit")) { editingAgents = true }
					.disabled(AgentsFile.url(workspace: RtClient.workspace()) == nil)
					.sheet(isPresented: $editingAgents) {
						AgentsFileSheet(workspace: RtClient.workspace()) { editingAgents = false }
					}
				if AgentsFile.url(workspace: RtClient.workspace()) == nil {
					Text(L("per.agentsNoFolder")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				}
			} header: { Text(L("per.agents")) } footer: { SettingsNote(L("per.agentsBody")) }

			Section {
				Toggle(L("per.suggestions"), isOn: $suggestions)
			} header: { Text(L("per.extra")) }

			Section { SettingsNote(L("per.note")) }
		}
	}

	private func level(_ title: String, _ binding: Binding<String>) -> some View {
		Picker(title, selection: binding) {
			ForEach(StyleLevel.allCases) { Text(L("per.level.\($0.rawValue)")).tag($0.rawValue) }
		}
	}

	private func resetStyle() {
		tone = BaseTone.standard.rawValue
		warm = StyleLevel.normal.rawValue; enthusiastic = StyleLevel.normal.rawValue
		emoji = StyleLevel.normal.rawValue; structure = StyleLevel.normal.rawValue
		visual = false
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
