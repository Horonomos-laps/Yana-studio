import AppKit
import SwiftUI

// Settings, laid out like macOS System Settings: categories on the left, each pane a header (icon, title,
// one line on what it controls) over a grouped Form. Every row reads or changes something real
// (AppSettings, the Keychain, the terminal store, yana-rt). Panes: here and in SettingsSections.swift,
// SettingsInfo.swift. API keys go to the macOS Keychain only and are never shown again after saving.

enum SettingsSection: String, CaseIterable, Identifiable {
	case general, appearance, notifications, chat, personal, memory, models, terminal, studio, git, worktree, hooks, security, data, updates, system, shortcuts, about
	var id: String { rawValue }
	var icon: String {
		switch self {
		case .general: return "settings"
		case .appearance: return "palette"
		case .notifications: return "bell"
		case .chat: return "message"
		case .personal: return "user"
		case .memory: return "bookmark"
		case .models: return "cpu"
		case .terminal: return "terminal"
		case .studio: return "code"
		case .git: return "steps"
		case .worktree: return "tree"
		case .hooks: return "link"
		case .security: return "shield"
		case .data: return "folder"
		case .updates: return "download"
		case .system: return "box"
		case .shortcuts: return "keyboard"
		case .about: return "info-circle"
		}
	}
	var title: String { L("set.section.\(rawValue)") }
	var subtitle: String { L("set.about.\(rawValue)") }
	// A thin line in the list before these, grouping app / AI / tools / safety / info like System Settings.
	var startsGroup: Bool { [.models, .git, .security, .updates].contains(self) }

	// The sections whose name or one-line description holds every word of the query, in the same order. The
	// match ignores case and accents, so "ca nhan" finds "Cá nhân hóa". An empty query is every section.
	static func matching(_ query: String) -> [SettingsSection] {
		let words = ChatLibrary.normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
		guard !words.isEmpty else { return allCases }
		return allCases.filter { item in
			let hay = ChatLibrary.normalize(item.title + " " + item.subtitle + " " + item.rawValue)
			return words.allSatisfy { hay.contains($0) }
		}
	}
}

struct SettingsPage: View {
	// Back to the page the person came from.
	var back: () -> Void = {}
	let openPage: (String) -> Void
	// YANA_SETTINGS=<section> opens a given pane (used to check panes in the live window).
	@State private var section: SettingsSection =
		ProcessInfo.processInfo.environment["YANA_SETTINGS"].flatMap(SettingsSection.init(rawValue:)) ?? .general
	@State private var query = ""
	private var shown: [SettingsSection] { SettingsSection.matching(query) }
	private var searching: Bool { !ChatLibrary.normalize(query).isEmpty }

	var body: some View {
		HStack(spacing: 0) {
			VStack(alignment: .leading, spacing: 0) {
				// The top of the column stays put, below the window buttons that sit in it; only the list of
				// sections scrolls. When all of it scrolled, Back and the title slid up under the buttons.
				VStack(alignment: .leading, spacing: 2) {
					Button(action: back) {
						HStack(spacing: 6) {
							FBIcon(name: "arrow-left", size: 14, color: FB.textSecondary)
							Text(L("set.back")).font(.system(size: 13, weight: .medium)).foregroundStyle(FB.text)
							Spacer(minLength: 0)
						}
						.padding(.horizontal, 10).frame(height: 30).contentShape(Rectangle())
					}
					.buttonStyle(.plain)
					.keyboardShortcut(.cancelAction)
					Text(L("nav.Settings")).font(.system(size: 20, weight: .semibold)).foregroundStyle(FB.text)
						.padding(EdgeInsets(top: 6, leading: 10, bottom: 8, trailing: 0))
					HStack(spacing: 6) {
						FBIcon(name: "search", size: 13, color: FB.textTertiary)
						TextField("", text: $query, prompt: Text(L("set.search"))).textFieldStyle(.plain).font(.system(size: 13))
						if searching {
							Button { query = "" } label: { FBIcon(name: "close", size: 11, color: FB.textTertiary) }.buttonStyle(.plain)
						}
					}
					.padding(.horizontal, 10).frame(height: 30)
					.background(RoundedRectangle(cornerRadius: 9).fill(FB.hoverOnChrome))
					.padding(EdgeInsets(top: 0, leading: 2, bottom: 8, trailing: 2))
				}
				.padding(EdgeInsets(top: 46, leading: 14, bottom: 4, trailing: 14))
				ScrollView {
					VStack(alignment: .leading, spacing: 2) {
					ForEach(shown) { item in
						if item.startsGroup && !searching { FB.divider.frame(height: 1).padding(.vertical, 6).padding(.horizontal, 10) }
						SettingsNavRow(icon: item.icon, title: item.title, selected: item == section, accent: Accent.section(item))
							.onTapGesture { section = item }
					}
					if shown.isEmpty {
						Text(L("set.noMatch")).font(.fbCaption).foregroundStyle(FB.textSecondary).padding(.horizontal, 10).padding(.vertical, 6)
					}
					}
					.padding(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
				}
			}
			.frame(width: 240)
			.frame(maxHeight: .infinity)
			.background(FBPair.rail.color)
			.overlay(alignment: .trailing) { FB.divider.frame(width: 1) }

			VStack(alignment: .leading, spacing: 0) {
				PaneHeader(section: section)
				pane.formStyle(.grouped).scrollContentBackground(.hidden)
			}
			.frame(maxWidth: 780, alignment: .topLeading)
			.padding(.leading, 12)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
	}

	@ViewBuilder
	private var pane: some View {
		switch section {
		case .general: GeneralSettings()
		case .appearance: AppearanceSettings()
		case .notifications: NotificationSettings()
		case .chat: ChatSettings()
		case .personal: PersonalSettings()
		case .memory: MemorySettings()
		case .models: ModelSettings()
		case .terminal: TerminalSettings()
		case .studio: StudioSettings()
		case .git: GitSettings()
		case .worktree: WorktreeSettings()
		case .hooks: HookSettings()
		case .security: SecuritySettings { openPage("Tool approvals") }
		case .data: DataSettings()
		case .updates: UpdateSettings()
		case .system: SystemSettings()
		case .shortcuts: ShortcutSettings()
		case .about: AboutSettings()
		}
	}
}

private struct PaneHeader: View {
	let section: SettingsSection

	var body: some View {
		HStack(spacing: 14) {
			FBIcon(name: section.icon, size: 22, color: .white)
				.frame(width: 44, height: 44)
				.background(RoundedRectangle(cornerRadius: 11).fill(LinearGradient(
					colors: [Accent.section(section).color, Accent.section(section).color.opacity(0.78)], startPoint: .top, endPoint: .bottom)))
			VStack(alignment: .leading, spacing: 3) {
				Text(section.title).font(.system(size: 18, weight: .semibold)).foregroundStyle(FB.text)
				Text(section.subtitle).font(.fbBody).foregroundStyle(FB.textSecondary)
			}
		}
		.padding(EdgeInsets(top: 28, leading: 22, bottom: 0, trailing: 22))
	}
}

private struct SettingsNavRow: View {
	let icon: String
	let title: String
	let selected: Bool
	var accent: Accent = .blue
	@State private var hover = false

	var body: some View {
		HStack(spacing: 10) {
			// A colored tile like System Settings: solid with a white icon, so each section has its own color.
			FBIcon(name: icon, size: 13, color: .white)
				.frame(width: 24, height: 24)
				.background(RoundedRectangle(cornerRadius: 6).fill(accent.color.opacity(selected ? 1 : 0.88)))
			Text(title).font(.system(size: 13, weight: selected ? .semibold : .regular)).foregroundStyle(FB.text)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 8)
		.frame(height: 34)
		.background(RoundedRectangle(cornerRadius: 8).fill(selected ? FB.canvas : hover ? FB.hoverOnChrome : .clear))
		.contentShape(Rectangle())
		.onHover { hover = $0 }
	}
}

struct SettingsNote: View {
	let text: String
	init(_ text: String) { self.text = text }
	var body: some View {
		Text(text).font(.fbCaption).foregroundStyle(FB.textSecondary).fixedSize(horizontal: false, vertical: true)
	}
}

// MARK: General

struct GeneralSettings: View {
	@ObservedObject private var loc = Loc.shared
	@ObservedObject private var settings = AppSettings.shared
	@AppStorage("yana.ui.chatSidebar") private var chatSidebar = true
	@AppStorage(SleepGuard.key) private var keepAwake = false

	var body: some View {
		Form {
			Section {
				Picker(L("set.language"), selection: $loc.lang) {
					ForEach(Lang.allCases) { Text($0.nativeName).tag($0) }
				}
				Picker(L("set.startPage"), selection: $settings.startPage) {
					Text(L("set.startAsk")).tag("ask")
					Text(L("nav.Terminal")).tag("Terminal")
					Text(L("nav.Chat")).tag("Chat")
				}
			} footer: { SettingsNote(L("set.languageNote")) }

			Section {
				LabeledContent(L("set.workspace")) {
					HStack(spacing: 8) {
						Text(RtClient.workspace()).font(.fbCaption).foregroundStyle(FB.textSecondary)
							.lineLimit(1).truncationMode(.middle)
						Button(L("set.choose")) { chooseFolder() }
						if !settings.workspace.isEmpty { Button(L("set.reset")) { settings.workspace = "" } }
					}
				}
			} footer: { SettingsNote(L("set.workspaceNote")) }

			Section {
				Toggle(L("set.showChatList"), isOn: $chatSidebar)
				Toggle(L("set.updatesOnLaunch"), isOn: $settings.checkUpdatesOnLaunch)
			} header: { Text(L("set.window")) }

			Section {
				Toggle(L("set.keepAwake"), isOn: $keepAwake)
				LaunchAtLoginRow()
			} footer: { SettingsNote(L("set.keepAwakeNote")) }
		}
	}

	private func chooseFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		if panel.runModal() == .OK, let url = panel.url { settings.workspace = url.path }
	}
}

// MARK: Chat

struct ChatSettings: View {
	@ObservedObject private var settings = AppSettings.shared
	// Speech to text may use Apple's servers only for a language with no on-device model (Dictation.swift).
	@AppStorage("yana.dictation.allowServer") private var dictationServer = false
	// Installed system voices, by display name.
	private let voices: [(id: String, name: String)] = NSSpeechSynthesizer.availableVoices.map { voice in
		let name = NSSpeechSynthesizer.attributes(forVoice: voice)[.name] as? String ?? voice.rawValue
		return (voice.rawValue, name)
	}.sorted { $0.name < $1.name }

	var body: some View {
		Form {
			Section {
				Picker(L("set.defaultMode"), selection: $settings.defaultPlanMode) {
					Text(L("chat.modeAct")).tag(false)
					Text(L("chat.modePlan")).tag(true)
				}
				Toggle(L("set.showTokens"), isOn: $settings.showTokens)
			} footer: { SettingsNote(L("set.defaultModeNote")) }

			Section {
				Picker(L("set.voice"), selection: $settings.voice) {
					Text(L("set.voiceSystem")).tag("")
					ForEach(voices, id: \.id) { Text($0.name).tag($0.id) }
				}
			} header: { Text(L("msg.read")) } footer: { SettingsNote(L("set.voiceNote")) }

			Section {
				Toggle(L("set.dictServer"), isOn: $dictationServer)
			} header: { Text(L("set.dict")) } footer: { SettingsNote(L("set.dictNote")) }
		}
	}
}
