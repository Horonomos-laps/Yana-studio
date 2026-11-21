import SwiftUI

// Drawn demos for the guide pages about the chat list, voice and screen capture, shortcuts, and the look. They use
// the same building blocks as TourDemos.swift (MiniWindow, phase, ramp) and read the time from the TimelineView
// that hosts them.

// A chat gets pinned and moves into the pinned group; then the row's menu shows what else it can do.
struct ChatsDemo: View {
	let t: Double
	private let firstPinned = "Kế hoạch quý 4"
	private let recent = ["Sửa lỗi đăng nhập", "Viết email cho khách", "Tóm tắt báo cáo"]
	private let menuItems = [("pin", "Ghim"), ("share", "Xuất"), ("archive", "Lưu trữ")]

	var body: some View {
		let p = phase(t, 7)
		let pinnedNow = p >= 3
		let pinned = pinnedNow ? [firstPinned, recent[0]] : [firstPinned]
		let rest = pinnedNow ? Array(recent.dropFirst()) : recent
		MiniWindow {
			HStack(spacing: 0) {
				VStack(alignment: .leading, spacing: 5) {
					groupTitle("Đã ghim")
					ForEach(pinned, id: \.self) { row($0, pin: true, hover: false) }
					groupTitle("Gần đây").padding(.top, 6)
					ForEach(rest, id: \.self) { row($0, pin: false, hover: p >= 1.4 && p < 3 && $0 == recent[0]) }
					Spacer(minLength: 0)
				}
				.padding(12).frame(width: 200, alignment: .leading)
				FB.divider.frame(width: 1)
				VStack(alignment: .leading, spacing: 4) {
					if p >= 4.6 {
						ForEach(menuItems, id: \.1) { item in
							Label(item.1, systemImage: "circle.fill").labelStyle(MenuLabel(icon: item.0))
						}
						.transition(.opacity)
					}
					Spacer(minLength: 0)
				}
				.padding(12).frame(maxWidth: .infinity, alignment: .leading)
			}
		}
	}

	private func groupTitle(_ text: String) -> some View {
		Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(FB.textTertiary)
	}

	private func row(_ name: String, pin: Bool, hover: Bool) -> some View {
		HStack(spacing: 6) {
			Text(name).font(.system(size: 11)).foregroundStyle(FB.text).lineLimit(1)
			Spacer(minLength: 0)
			if pin || hover { FBIcon(name: "pin", size: 11, color: pin ? FB.primary : FB.textSecondary) }
		}
		.padding(.horizontal, 8).padding(.vertical, 5)
		.background(RoundedRectangle(cornerRadius: 6).fill(hover ? FB.surfaceTertiary : .clear))
	}
}

private struct MenuLabel: LabelStyle {
	let icon: String
	func makeBody(configuration: Configuration) -> some View {
		HStack(spacing: 6) {
			FBIcon(name: icon, size: 12, color: FB.textSecondary)
			configuration.title.font(.system(size: 11)).foregroundStyle(FB.text)
		}
		.padding(.horizontal, 8).padding(.vertical, 5)
		.frame(width: 120, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 6).fill(FB.surfaceSecondary))
	}
}

// The mic pulses while a sentence is typed into the box; then a picture of the window behind Yana is attached.
struct VoiceDemo: View {
	let t: Double
	private let spoken = "Nhắc mình gửi báo cáo lúc 9 giờ sáng mai"

	var body: some View {
		let p = phase(t, 8)
		let listening = p >= 0.6 && p < 4.2
		let typed = Int(Double(spoken.count) * ramp(p, 0.9, 3.2))
		MiniWindow {
			VStack(alignment: .leading, spacing: 10) {
				Spacer(minLength: 0)
				if p >= 5 {
					HStack(spacing: 6) {
						FBIcon(name: "image", size: 12, color: FB.primaryText)
						Text("Cửa sổ Safari").font(.system(size: 11)).foregroundStyle(FB.primaryText)
					}
					.padding(.horizontal, 10).padding(.vertical, 5)
					.background(Capsule().fill(FB.primarySubtle))
				}
				VStack(alignment: .leading, spacing: 10) {
					Text(typed == 0 ? "Làm việc với Yana" : String(spoken.prefix(typed)))
						.font(.system(size: 12)).foregroundStyle(typed == 0 ? FB.textTertiary : FB.text).lineLimit(2)
					HStack(spacing: 8) {
						Spacer()
						ZStack {
							if listening { Circle().fill(FB.error.opacity(0.18)).frame(width: 34, height: 34).scaleEffect(0.8 + 0.2 * abs(sin(t * 4))) }
							Circle().fill(listening ? FB.error : FB.surfaceTertiary).frame(width: 26, height: 26)
							FBIcon(name: "mic", size: 13, color: listening ? .white : FB.textSecondary)
						}
					}
				}
				.padding(12)
				.background(RoundedRectangle(cornerRadius: 12).fill(FB.canvas))
				.overlay(RoundedRectangle(cornerRadius: 12).stroke(FB.border))
			}
			.padding(14)
		}
	}
}

// The default shortcuts, one after the other lit up. The list is the real defaults, so it cannot drift from the app.
struct ShortcutsDemo: View {
	let t: Double
	private let actions: [ShortcutAction] = [.newChat, .toggleChatList, .pinChat, .dictate, .appshot]

	var body: some View {
		let p = phase(t, 7.5)
		let lit = min(Int(p / 1.4), actions.count - 1)
		MiniWindow {
			VStack(alignment: .leading, spacing: 6) {
				ForEach(actions.indices, id: \.self) { i in
					HStack {
						Text(actions[i].title).font(.system(size: 12)).foregroundStyle(FB.text).lineLimit(1)
						Spacer(minLength: 8)
						Text(actions[i].defaultShortcut.display)
							.font(.system(size: 12, weight: .medium, design: .rounded))
							.foregroundStyle(i == lit ? FB.onPrimary : FB.textSecondary)
							.padding(.horizontal, 8).padding(.vertical, 3)
							.background(RoundedRectangle(cornerRadius: 6).fill(i == lit ? FB.primary : FB.surfaceTertiary))
					}
					.padding(.horizontal, 10).padding(.vertical, 4)
					.background(RoundedRectangle(cornerRadius: 8).fill(i == lit ? FB.primarySubtle : .clear))
				}
				Spacer(minLength: 0)
			}
			.padding(14)
		}
	}
}

// The same small window in the light and the dark look, and the three choices that switch between them.
struct LookDemo: View {
	let t: Double

	var body: some View {
		let p = phase(t, 6)
		let selected = p < 2 ? 0 : (p < 4 ? 1 : 2)
		MiniWindow {
			VStack(spacing: 12) {
				HStack(spacing: 10) {
					swatch(dark: false)
					swatch(dark: true)
				}
				HStack(spacing: 4) {
					ForEach(0 ..< 3, id: \.self) { i in
						HStack(spacing: 5) {
							if i < 2 { FBIcon(name: i == 0 ? "sun" : "moon", size: 12, color: i == selected ? FB.onPrimary : FB.textSecondary) }
							Text(["Sáng", "Tối", "Theo hệ thống"][i]).font(.system(size: 11, weight: .medium))
								.foregroundStyle(i == selected ? FB.onPrimary : FB.textSecondary)
						}
						.padding(.horizontal, 10).padding(.vertical, 5)
						.background(Capsule().fill(i == selected ? FB.primary : FB.surfaceTertiary))
					}
				}
				Spacer(minLength: 0)
			}
			.padding(14)
		}
	}

	// A fixed light or dark card, drawn from the two halves of the palette, whatever look the guide itself is in.
	private func swatch(dark: Bool) -> some View {
		func c(_ pair: TokenPair) -> Color { Color(hex: pair.hex(dark: dark)) }
		return VStack(alignment: .leading, spacing: 6) {
			RoundedRectangle(cornerRadius: 3).fill(c(FBPair.text)).frame(width: 60, height: 6)
			RoundedRectangle(cornerRadius: 3).fill(c(FBPair.textSecondary)).frame(width: 90, height: 5)
			Spacer(minLength: 0)
			HStack(spacing: 5) {
				Circle().fill(FB.primary).frame(width: 14, height: 14)
				RoundedRectangle(cornerRadius: 3).fill(c(FBPair.surfaceTertiary)).frame(height: 10)
			}
		}
		.padding(10).frame(maxWidth: .infinity).frame(height: 92)
		.background(RoundedRectangle(cornerRadius: 10).fill(c(FBPair.surface)))
		.overlay(RoundedRectangle(cornerRadius: 10).stroke(c(FBPair.border)))
	}
}
