import SwiftUI

// Settings > Appearance and Settings > Notifications, the two sections ChatGPT and Claude have that the app lacked.

struct AppearanceSettings: View {
	@ObservedObject private var settings = AppSettings.shared
	@AppStorage(LiquidGlass.enabledKey) private var liquidGlass = true

	var body: some View {
		Form {
			Section {
				Picker(L("set.appearance"), selection: $settings.appearance) {
					Text(L("set.appearanceLight")).tag(Appearance.light)
					Text(L("set.appearanceDark")).tag(Appearance.dark)
					Text(L("set.appearanceSystem")).tag(Appearance.system)
				}
				Toggle(L("set.glass"), isOn: $liquidGlass)
				if liquidGlass && !LiquidGlass.active {
					Text(L("set.glassOff")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				}
			} header: { Text(L("set.look")) }

			Section {
				Picker(L("set.codeFont"), selection: $settings.codeFontName) {
					Text(L("set.codeFontSystem")).tag("")
					ForEach(CodeFont.choices, id: \.id) { Text($0.label).tag($0.id) }
				}
				Stepper(value: $settings.codeFontSize, in: CodeFont.sizeRange, step: CodeFont.sizeStep) {
					Text("\(L("set.codeSize")): \(String(format: "%.1f", settings.codeFontSize)) pt")
				}
				Text(CodeFont.sample).font(CodeFont.font(name: settings.codeFontName, size: settings.codeFontSize))
					.foregroundStyle(FB.text).textSelection(.enabled)
					.padding(12).frame(maxWidth: .infinity, alignment: .leading)
					.background(RoundedRectangle(cornerRadius: 10).fill(FB.surfaceTertiary))
					.overlay(RoundedRectangle(cornerRadius: 10).stroke(FB.divider, lineWidth: 1))
				Button(L("set.reset")) {
					settings.codeFontName = ""
					settings.codeFontSize = CodeFont.defaultSize
				}
				.disabled(settings.codeFontName.isEmpty && settings.codeFontSize == CodeFont.defaultSize)
			} header: { Text(L("set.code")) } footer: { SettingsNote(L("set.codeNote")) }
		}
	}
}

struct NotificationSettings: View {
	@AppStorage(Notifier.defaultsKey) private var enabled = true
	@AppStorage(NotifyPrefs.doneKey) private var onDone = true
	@AppStorage(NotifyPrefs.approvalKey) private var onApproval = true
	@AppStorage(NotifyPrefs.minSecondsKey) private var minSeconds = NotifyPrefs.defaultMinSeconds
	@AppStorage(NotifyPrefs.soundKey) private var sound = true

	private func label(_ seconds: Double) -> String {
		switch seconds {
		case 0: return L("set.notifyAlways")
		case ..<60: return "\(Int(seconds)) \(L("set.notifySeconds"))"
		default: return "\(Int(seconds / 60)) \(L("set.notifyMinutes"))"
		}
	}

	var body: some View {
		Form {
			Section {
				Toggle(L("set.notify"), isOn: $enabled)
			} footer: { SettingsNote(L("set.notifyNote")) }

			Section {
				Toggle(L("set.notifyDone"), isOn: $onDone)
				Picker(L("set.notifyMin"), selection: $minSeconds) {
					ForEach(NotifyPrefs.minChoices, id: \.self) { Text(label($0)).tag($0) }
				}
				.disabled(!onDone)
				Toggle(L("set.notifyApproval"), isOn: $onApproval)
				Toggle(L("set.notifySound"), isOn: $sound)
			} header: { Text(L("set.notifyWhen")) }
				.disabled(!enabled)
		}
	}
}

let extraSettingsRows: [StringRow] = [
	StringRow("set.section.appearance", "Giao diện", "Appearance", "화면"),
	StringRow("set.about.appearance", "Sáng, tối, kính lỏng, phông chữ và cỡ chữ của code.", "Light, dark, liquid glass, and the font and size of code.", "라이트, 다크, 리퀴드 글래스, 코드 글꼴과 크기."),
	StringRow("set.section.notifications", "Thông báo", "Notifications", "알림"),
	StringRow("set.about.notifications", "Khi nào Yana báo bạn lúc ứng dụng ở nền, và có âm thanh không.", "When Yana tells you while the app is in the background, and whether with a sound.", "앱이 백그라운드일 때 Yana가 알리는 시점과 소리 여부."),
	StringRow("set.look", "Hiển thị", "Display", "표시"),
	StringRow("set.code", "Code trong câu trả lời", "Code in replies", "답변 속 코드"),
	StringRow("set.codeFont", "Phông chữ code", "Code font", "코드 글꼴"),
	StringRow("set.codeFontSystem", "Mặc định của hệ thống (SF Mono)", "System default (SF Mono)", "시스템 기본값 (SF Mono)"),
	StringRow("set.codeSize", "Cỡ chữ code", "Code size", "코드 크기"),
	StringRow("set.codeNote", "Áp dụng cho khối code trong câu trả lời. Ô trên là bản xem trước.", "Applies to code blocks in replies. The box above is a preview.", "답변의 코드 블록에 적용됩니다. 위 상자는 미리보기입니다."),
	StringRow("set.notifyNote", "Chỉ báo khi ứng dụng không ở phía trước. Lần đầu macOS sẽ hỏi quyền gửi thông báo.", "Only when the app is not in front. The first time, macOS asks for permission to notify.", "앱이 앞에 있지 않을 때만 알립니다. 처음에는 macOS가 알림 권한을 묻습니다."),
	StringRow("set.notifyWhen", "Báo khi", "Notify when", "알림 시점"),
	StringRow("set.notifyDone", "Yana trả lời xong", "Yana finishes a reply", "Yana가 답변을 끝냈을 때"),
	StringRow("set.notifyMin", "Chỉ khi chạy lâu hơn", "Only if it took longer than", "다음보다 오래 걸린 경우만"),
	StringRow("set.notifyAlways", "Mọi lần", "Every time", "항상"),
	StringRow("set.notifySeconds", "giây", "seconds", "초"),
	StringRow("set.notifyMinutes", "phút", "minutes", "분"),
	StringRow("set.notifyApproval", "Cần bạn duyệt", "Yana needs your approval", "승인이 필요할 때"),
	StringRow("set.notifySound", "Có âm thanh", "Play a sound", "소리 재생"),
	StringRow("set.keepAwake", "Giữ máy không ngủ khi Yana đang làm việc", "Keep the Mac awake while Yana is working", "Yana가 작업하는 동안 Mac 잠자기 방지"),
	StringRow("set.keepAwakeNote", "Chỉ giữ trong lúc Yana đang trả lời; xong là máy lại được phép ngủ.", "Only while Yana is replying; when it finishes the Mac may sleep again.", "Yana가 답변하는 동안만 유지하며, 끝나면 Mac이 다시 잠들 수 있습니다."),
]
