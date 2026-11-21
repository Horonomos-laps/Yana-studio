import SwiftUI

// A color for each page and each Settings section, so the rail and the Settings list are told apart at a glance
// instead of every icon repeating the same blue. The hues are chosen to stay readable on white and on glass, and
// the pairing is one place (here), so nothing picks a color by itself.

enum Accent: CaseIterable {
	case blue, violet, green, orange, amber, pink, teal, indigo, red, ink

	var color: Color {
		switch self {
		case .blue: return Color(hex: 0x2F6BEB)
		case .violet: return Color(hex: 0x7C5CFF)
		case .green: return Color(hex: 0x24A864)
		case .orange: return Color(hex: 0xF0762B)
		case .amber: return Color(hex: 0xE5A100)
		case .pink: return Color(hex: 0xE5488F)
		case .teal: return Color(hex: 0x12A9C2)
		case .indigo: return Color(hex: 0x4A55D0)
		case .red: return Color(hex: 0xDD4147)
		case .ink: return Color(hex: 0x56606E)
		}
	}

	// A pale wash of the color, for tiles behind an icon.
	var soft: Color { color.opacity(0.14) }

	static func page(_ id: String) -> Accent {
		switch id {
		case "Chat": return .blue
		case "Overview": return .violet
		case "Tool approvals": return .green
		case "Tasks": return .orange
		case "Skills": return .amber
		case "Plugins": return .pink
		case "Health": return .teal
		case "Usage": return .indigo
		case "Settings": return .ink
		default: return .blue
		}
	}

	static func section(_ section: SettingsSection) -> Accent {
		switch section {
		case .general: return .ink
		case .chat: return .blue
		case .personal: return .pink
		case .memory: return .amber
		case .models: return .violet
		case .terminal: return .ink
		case .studio: return .teal
		case .git: return .orange
		case .worktree: return .green
		case .hooks: return .pink
		case .security: return .red
		case .data: return .indigo
		case .updates: return .green
		case .system: return .ink
		case .shortcuts: return .teal
		case .about: return .blue
		}
	}
}
