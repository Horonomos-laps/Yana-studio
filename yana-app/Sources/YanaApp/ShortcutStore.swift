import AppKit
import SwiftUI

// Rebindable keyboard shortcuts for the menu-bar actions. The defaults are the ones the app always had
// (AppCommands.swift); a person can record a new combination, clear one, or put the default back.
// Choices live in UserDefaults. Shortcuts that belong to the terminal or the system are fixed.

struct Shortcut: Codable, Equatable, Hashable {
	// One lowercase printable character, or one of: return tab space up down left right.
	var key: String
	var command = false
	var shift = false
	var option = false
	var control = false

	private static let named: [String: (equivalent: KeyEquivalent, glyph: String)] = [
		"return": (.return, "↩"), "tab": (.tab, "⇥"), "space": (.space, "␣"),
		"up": (.upArrow, "↑"), "down": (.downArrow, "↓"), "left": (.leftArrow, "←"), "right": (.rightArrow, "→"),
	]
	private static let keyCodes: [UInt16: String] = [36: "return", 48: "tab", 49: "space", 126: "up", 125: "down", 123: "left", 124: "right"]

	var keyEquivalent: KeyEquivalent {
		if let item = Shortcut.named[key] { return item.equivalent }
		return KeyEquivalent(key.first ?? " ")
	}

	var eventModifiers: EventModifiers {
		var m: EventModifiers = []
		if command { m.insert(.command) }
		if shift { m.insert(.shift) }
		if option { m.insert(.option) }
		if control { m.insert(.control) }
		return m
	}

	// Written the way macOS menus write it: control, option, shift, command, then the key.
	var display: String {
		(control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "")
			+ (Shortcut.named[key]?.glyph ?? key.uppercased())
	}

	// A bare key or ⇧ plus a key would fire while typing, so one of ⌘ ⌃ ⌥ is required.
	var hasUsableModifier: Bool { command || control || option }

	// Reads a key press. Nil when it is not a single printable character or a named key.
	static func from(characters: String, keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Shortcut? {
		let f = flags.intersection(.deviceIndependentFlagsMask)
		var key: String
		if let name = keyCodes[keyCode] {
			key = name
		} else {
			let lower = characters.lowercased()
			guard lower.count == 1, let scalar = lower.unicodeScalars.first,
			      !CharacterSet.controlCharacters.contains(scalar), !CharacterSet.whitespacesAndNewlines.contains(scalar)
			else { return nil }
			key = lower
		}
		return Shortcut(key: key, command: f.contains(.command), shift: f.contains(.shift),
		                option: f.contains(.option), control: f.contains(.control))
	}
}

// The actions that can be rebound. Each raw value is also the MenuAction the menu posts (AppCommands.swift).
enum ShortcutAction: String, CaseIterable, Identifiable {
	case newChat, openFolder, openStudio, terminal, toggleChatList, settings
	case page1, page2, page3, page4, page5, page6, page7
	var id: String { rawValue }

	var defaultShortcut: Shortcut {
		switch self {
		case .newChat: return Shortcut(key: "n", command: true)
		case .openFolder: return Shortcut(key: "o", command: true)
		case .openStudio: return Shortcut(key: "e", command: true, shift: true)
		case .terminal: return Shortcut(key: "`", control: true)
		case .toggleChatList: return Shortcut(key: "s", command: true, control: true)
		case .settings: return Shortcut(key: ",", command: true)
		case .page1: return Shortcut(key: "1", command: true)
		case .page2: return Shortcut(key: "2", command: true)
		case .page3: return Shortcut(key: "3", command: true)
		case .page4: return Shortcut(key: "4", command: true)
		case .page5: return Shortcut(key: "5", command: true)
		case .page6: return Shortcut(key: "6", command: true)
		case .page7: return Shortcut(key: "7", command: true)
		}
	}

	var title: String {
		switch self {
		case .newChat: return L("chat.new")
		case .openFolder: return L("menu.openFolder")
		case .openStudio: return L("menu.openStudio")
		case .terminal: return L("nav.Terminal")
		case .toggleChatList: return L("menu.toggleChatList")
		case .settings: return L("nav.Settings")
		default:
			let index = (Int(rawValue.dropFirst(4)) ?? 1) - 1
			return railEntries.indices.contains(index) ? L("nav.\(railEntries[index].id)") : rawValue
		}
	}
}

enum ShortcutResult: Equatable {
	case ok
	case needsModifier
	case reserved
	case conflict(ShortcutAction)
}

final class ShortcutStore: ObservableObject {
	static let shared = ShortcutStore()
	private let defaults: UserDefaults
	private static let customKey = "yana.shortcuts.custom"
	private static let clearedKey = "yana.shortcuts.cleared"

	@Published private(set) var custom: [String: Shortcut]
	@Published private(set) var cleared: Set<String>

	// Combinations that belong to macOS or to the terminal; the app does not let them be taken.
	static let reserved: Set<Shortcut> = [
		Shortcut(key: "q", command: true), Shortcut(key: "h", command: true), Shortcut(key: "h", command: true, option: true),
		Shortcut(key: "m", command: true), Shortcut(key: "c", command: true), Shortcut(key: "v", command: true),
		Shortcut(key: "x", command: true), Shortcut(key: "a", command: true), Shortcut(key: "z", command: true),
		Shortcut(key: "z", command: true, shift: true), Shortcut(key: "w", command: true), Shortcut(key: "t", command: true),
		Shortcut(key: "=", command: true), Shortcut(key: "-", command: true),
	]

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		if let data = defaults.data(forKey: Self.customKey), let saved = try? JSONDecoder().decode([String: Shortcut].self, from: data) {
			custom = saved
		} else {
			custom = [:]
		}
		cleared = Set(defaults.stringArray(forKey: Self.clearedKey) ?? [])
	}

	// What is bound now: nil when the person cleared it.
	func effective(_ action: ShortcutAction) -> Shortcut? {
		if cleared.contains(action.rawValue) { return nil }
		return custom[action.rawValue] ?? action.defaultShortcut
	}

	func isCustomized(_ action: ShortcutAction) -> Bool {
		cleared.contains(action.rawValue) || custom[action.rawValue].map { $0 != action.defaultShortcut } ?? false
	}

	// Another action that already uses this combination.
	func owner(of shortcut: Shortcut, besides action: ShortcutAction) -> ShortcutAction? {
		ShortcutAction.allCases.first { $0 != action && effective($0) == shortcut }
	}

	// Checks a combination without saving it.
	func check(_ shortcut: Shortcut, for action: ShortcutAction) -> ShortcutResult {
		if !shortcut.hasUsableModifier { return .needsModifier }
		if Self.reserved.contains(shortcut) { return .reserved }
		if let other = owner(of: shortcut, besides: action) { return .conflict(other) }
		return .ok
	}

	// Saves a combination. With `taking`, an action that holds it loses it (becomes unassigned).
	@discardableResult
	func assign(_ shortcut: Shortcut, to action: ShortcutAction, taking: Bool = false) -> ShortcutResult {
		let result = check(shortcut, for: action)
		switch result {
		case .ok: break
		case .conflict(let other) where taking: clear(other, persist: false)
		default: return result
		}
		custom[action.rawValue] = shortcut
		cleared.remove(action.rawValue)
		save()
		return .ok
	}

	func clear(_ action: ShortcutAction) { clear(action, persist: true) }

	private func clear(_ action: ShortcutAction, persist: Bool) {
		cleared.insert(action.rawValue)
		custom[action.rawValue] = nil
		if persist { save() }
	}

	func reset(_ action: ShortcutAction) {
		custom[action.rawValue] = nil
		cleared.remove(action.rawValue)
		save()
	}

	func resetAll() {
		custom = [:]
		cleared = []
		save()
	}

	private func save() {
		defaults.set(try? JSONEncoder().encode(custom), forKey: Self.customKey)
		defaults.set(Array(cleared).sorted(), forKey: Self.clearedKey)
	}
}

extension View {
	// Applies a menu shortcut, or leaves the item without one when it was cleared.
	@ViewBuilder func yanaShortcut(_ shortcut: Shortcut?) -> some View {
		if let shortcut { keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.eventModifiers) } else { self }
	}
}
