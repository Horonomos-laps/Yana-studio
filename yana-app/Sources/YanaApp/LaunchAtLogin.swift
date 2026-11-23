import ServiceManagement
import SwiftUI

// "Open Yana when I log in". macOS keeps the real state (the user can also change it in System Settings), so the switch
// reads it each time and never trusts a stored copy. It only works for an installed .app; from a bare debug binary
// macOS refuses, and the switch then shows why instead of pretending.

enum LaunchAtLogin {
	enum Outcome: Equatable { case on, off, needsApproval, unavailable(String) }

	static func outcome(for status: SMAppService.Status) -> Outcome {
		switch status {
		case .enabled: .on
		case .requiresApproval: .needsApproval
		case .notRegistered: .off
		case .notFound: .unavailable("notFound")
		@unknown default: .unavailable("unknown")
		}
	}

	static var current: Outcome { outcome(for: SMAppService.mainApp.status) }

	static func set(_ on: Bool) -> Outcome {
		do {
			if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
		} catch {
			return .unavailable(error.localizedDescription)
		}
		return current
	}
}

struct LaunchAtLoginRow: View {
	@State private var outcome = LaunchAtLogin.current

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Toggle(L("set.launchAtLogin"), isOn: Binding(
				get: { outcome == .on || outcome == .needsApproval },
				set: { outcome = LaunchAtLogin.set($0) }))
			switch outcome {
			case .needsApproval: SettingsNote(L("set.launchApprove"))
			case .unavailable: SettingsNote(L("set.launchUnavailable"))
			default: EmptyView()
			}
		}
		.onAppear { outcome = LaunchAtLogin.current }
	}
}

let launchAtLoginRows: [StringRow] = [
	StringRow("set.launchAtLogin", "Mở Yana khi đăng nhập máy", "Open Yana when I log in", "로그인할 때 Yana 열기"),
	StringRow("set.launchApprove", "Cần bật Yana trong Cài đặt hệ thống → Chung → Mục đăng nhập.", "Turn Yana on in System Settings → General → Login Items.", "시스템 설정 → 일반 → 로그인 항목에서 Yana를 켜 주세요."),
	StringRow("set.launchUnavailable", "Chỉ dùng được với ứng dụng đã cài vào Applications, không dùng được khi chạy bản thử.", "Only works for the installed app in Applications, not for a development build.", "Applications에 설치된 앱에서만 사용할 수 있으며 개발용 빌드에서는 안 됩니다."),
]
