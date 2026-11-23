import AppKit
import SwiftUI

// Settings > Shortcuts: record a new combination for each menu action, clear it, or restore the default.
// Logic and storage are in ShortcutStore.swift.

// A button that shows the combination; pressing it waits for the next key press and reports it.
// Esc cancels. While waiting, every key press is swallowed so the menu does not run it.
struct ShortcutRecorder: View {
	let current: Shortcut?
	let onRecord: (Shortcut) -> Void
	@State private var recording = false
	@State private var monitor: Any? = nil

	var body: some View {
		Button { recording ? stop() : start() } label: {
			Text(recording ? L("sc.press") : (current?.display ?? L("sc.none")))
				.font(.system(size: 12, weight: .medium, design: .monospaced))
				.foregroundStyle(recording ? FB.onPrimary : current == nil ? FB.textSecondary : FB.text)
				.frame(minWidth: 84)
				.padding(.horizontal, 8).padding(.vertical, 4)
				.background(RoundedRectangle(cornerRadius: 6).fill(recording ? FB.primary : FB.surfaceSecondary))
		}
		.buttonStyle(.plain)
		.onDisappear { stop() }
	}

	private func start() {
		recording = true
		monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
			if event.keyCode == 53 { stop(); return nil } // Esc
			if let shortcut = Shortcut.from(characters: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
			                                flags: event.modifierFlags) {
				stop()
				onRecord(shortcut)
			}
			return nil
		}
	}

	private func stop() {
		recording = false
		if let monitor { NSEvent.removeMonitor(monitor) }
		monitor = nil
	}
}

struct ShortcutSettings: View {
	@ObservedObject private var store = ShortcutStore.shared
	@State private var query = ""
	@State private var notice: (action: ShortcutAction, text: String)? = nil
	@State private var taking: (action: ShortcutAction, shortcut: Shortcut, other: ShortcutAction)? = nil

	private let fixed: [(keys: String, key: String)] = [
		("⌘T", "set.kNewTab"), ("⌘W", "set.kCloseTab"), ("⌘=  ⌘−", "set.kZoom"),
		("/", "set.kSkills"), ("↩", "set.kSend"),
	]

	private var actions: [ShortcutAction] {
		let q = query.trimmingCharacters(in: .whitespaces).lowercased()
		return ShortcutAction.allCases.filter { q.isEmpty || $0.title.lowercased().contains(q) || (store.effective($0)?.display.lowercased().contains(q) ?? false) }
	}

	var body: some View {
		Form {
			Section {
				TextField("", text: $query, prompt: Text(L("sc.search")))
				ForEach(actions) { action in row(action) }
				if actions.isEmpty { Text(L("sc.noMatch")).font(.fbCaption).foregroundStyle(FB.textSecondary) }
				Button(L("sc.resetAll")) { store.resetAll(); notice = nil }
					.disabled(!ShortcutAction.allCases.contains { store.isCustomized($0) })
			} header: { Text(L("sc.menu")) } footer: { SettingsNote(L("sc.note")) }

			Section {
				ForEach(fixed, id: \.key) { item in
					LabeledContent(L(item.key)) {
						Text(item.keys).font(.system(size: 12, weight: .medium, design: .monospaced))
							.padding(.horizontal, 8).padding(.vertical, 3)
							.background(RoundedRectangle(cornerRadius: 6).fill(FB.surfaceSecondary))
					}
				}
			} header: { Text(L("sc.fixed")) } footer: { SettingsNote(L("set.kNote")) }
		}
		.alert(L("sc.takeTitle"), isPresented: Binding(get: { taking != nil }, set: { if !$0 { taking = nil } })) {
			Button(L("sc.take")) {
				if let t = taking { store.assign(t.shortcut, to: t.action, taking: true); notice = nil }
				taking = nil
			}
			Button(L("set.cancel"), role: .cancel) { taking = nil }
		} message: {
			if let t = taking { Text(String(format: L("sc.takeBody"), t.shortcut.display, t.other.title, t.action.title)) }
		}
	}

	private func row(_ action: ShortcutAction) -> some View {
		VStack(alignment: .leading, spacing: 3) {
			HStack(spacing: 8) {
				Text(action.title).foregroundStyle(FB.text)
				Spacer(minLength: 0)
				ShortcutRecorder(current: store.effective(action)) { record($0, for: action) }
				if store.effective(action) != nil {
					FBIconButton(icon: "close", variant: .ghost, size: .small, tooltip: L("sc.clear")) { store.clear(action); notice = nil }
				}
				if store.isCustomized(action) {
					FBIconButton(icon: "undo", variant: .ghost, size: .small, tooltip: L("sc.reset")) { store.reset(action); notice = nil }
				}
			}
			if let notice, notice.action == action {
				Text(notice.text).font(.fbCaption).foregroundStyle(FB.warningText)
			}
		}
	}

	private func record(_ shortcut: Shortcut, for action: ShortcutAction) {
		switch store.check(shortcut, for: action) {
		case .ok:
			store.assign(shortcut, to: action)
			notice = nil
		case .needsModifier: notice = (action, L("sc.needsModifier"))
		case .reserved: notice = (action, String(format: L("sc.reserved"), shortcut.display))
		case .conflict(let other): notice = nil; taking = (action, shortcut, other)
		}
	}
}
