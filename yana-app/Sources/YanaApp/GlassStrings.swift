import SwiftUI

// Text for Liquid Glass (Settings > General) and the rail's open-page surface.

let glassRows: [StringRow] = [
	StringRow("usage.appChats", "Chat trong ứng dụng", "Chats in this app", "앱 안의 채팅"),
	StringRow("usage.appDaily14", "Chat trong ứng dụng: 14 ngày gần nhất", "Chats in this app: last 14 days", "앱 채팅: 최근 14일"),
	StringRow("usage.appTop", "Chat tốn token nhất", "Chats that used the most tokens", "토큰을 가장 많이 쓴 채팅"),
	StringRow("usage.replies", "câu trả lời", "replies", "답변"),
	StringRow("usage.appNote", "Đếm từ các chat đã lưu trên máy này, chỉ có số token (không ước tính tiền). Chat cũ chưa có giờ riêng từng câu nên tính vào ngày chat được cập nhật lần cuối. Tách riêng khỏi sổ cái yana-rt bên dưới.", "Counted from the chats saved on this Mac, tokens only (no dollar estimate). Older chats have no time for each reply, so they count on the day the chat was last updated. Kept apart from the yana-rt ledger below.", "이 Mac에 저장된 채팅에서 집계한 토큰 수입니다(금액 추정 없음). 이전 채팅은 답변별 시간이 없어 마지막 업데이트 날짜로 계산합니다. 아래 yana-rt 장부와는 별도입니다."),
	StringRow("usage.appEmpty", "Chưa có chat nào ghi số token. Số liệu hiện sau khi anh chat với một mô hình có báo token.", "No chat has recorded tokens yet. Numbers appear after you chat with a model that reports tokens.", "토큰이 기록된 채팅이 아직 없습니다."),
	StringRow("set.back", "Quay lại ứng dụng", "Back to the app", "앱으로 돌아가기"),
	StringRow("set.glass", "Giao diện kính lỏng (Liquid Glass)", "Liquid Glass look", "리퀴드 글래스 스타일"),
	StringRow("set.glassOff", "Đang dùng giao diện phẳng vì Mac chưa lên macOS 26, hoặc đã bật “Giảm độ trong suốt” trong Cài đặt hệ thống.", "The flat look is in use because this Mac is older than macOS 26 or “Reduce transparency” is on in System Settings.", "macOS 26 미만이거나 시스템 설정에서 \"투명도 줄이기\"가 켜져 있어 일반 스타일을 사용 중입니다."),
]

// The surface behind a page in the icon rail. The rail is a plain flat column (no glass, no color): the open page
// is a tile with a neutral gray wash, a page under the pointer gets a lighter one. The page's color stays in its
// icon and name only.
struct RailItemSurface: ViewModifier {
	static let selectedWash = 0.08
	static let hoverWash = 0.04
	static let corner: CGFloat = 12
	let selected: Bool
	let hover: Bool
	var tint: Color = FB.primary

	func body(content: Content) -> some View {
		content.background(
			RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
				.fill(Color.primary.opacity(selected ? Self.selectedWash : hover ? Self.hoverWash : 0))
		)
	}
}
