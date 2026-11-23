import Foundation

// Text for personalization, forking and archiving chats, data controls and the Settings search.

let featureRows: [StringRow] = [
	StringRow("set.section.personal", "Cá nhân hóa", "Personalization", "개인 맞춤 설정"),
	StringRow("set.about.personal", "Điều Yana luôn nên biết về bạn và cách bạn muốn được trả lời.", "What Yana should always know about you and how you want it to answer.", "Yana가 항상 알아야 할 내용과 원하는 답변 방식."),
	StringRow("per.name", "Tên gọi", "Name", "이름"),
	StringRow("per.namePrompt", "Yana nên gọi bạn là gì?", "What should Yana call you?", "Yana가 어떻게 부를까요?"),
	StringRow("per.about", "Về bạn", "About you", "사용자 정보"),
	StringRow("per.aboutPrompt", "Công việc, ngôn ngữ lập trình hay dùng, những gì cần nhớ…", "Your work, the languages you use, what to keep in mind…", "하는 일, 주로 쓰는 언어, 기억할 점…"),
	StringRow("per.rules", "Hướng dẫn luôn áp dụng", "Standing instructions", "항상 적용할 지침"),
	StringRow("per.rulesPrompt", "Ví dụ: trả lời ngắn gọn, giải thích bằng tiếng Việt, luôn viết test…", "For example: answer briefly, explain in Vietnamese, always write tests…", "예: 짧게 답하기, 한국어로 설명하기, 항상 테스트 작성…"),
	StringRow("per.note", "Gửi kèm làm chỉ dẫn hệ thống ở mỗi lượt chat tới model bạn chọn. Để trống thì không gửi gì. Chỉ lưu trên máy này.", "Sent as a system instruction on every chat turn to the model you pick. Leave empty to send nothing. Kept on this Mac only.", "선택한 모델에 매 채팅 턴마다 시스템 지침으로 전송됩니다. 비워 두면 아무것도 보내지 않습니다. 이 Mac에만 저장됩니다."),

	StringRow("history.fork", "Tách thành đoạn chat mới", "Branch into a new chat", "새 채팅으로 분기"),
	StringRow("history.forkTitle", "%@ (nhánh)", "%@ (branch)", "%@ (분기)"),
	StringRow("history.archive", "Lưu trữ", "Archive", "보관"),
	StringRow("history.unarchive", "Bỏ lưu trữ", "Unarchive", "보관 해제"),
	StringRow("chat.archived", "Lưu trữ", "Archived", "보관됨"),
	StringRow("chat.archivedShow", "Xem lưu trữ (%d)", "Show archived (%d)", "보관함 보기 (%d)"),
	StringRow("chat.archivedHide", "Ẩn lưu trữ", "Hide archived", "보관함 숨기기"),

	StringRow("data.chats", "Đoạn chat đã lưu", "Saved chats", "저장된 채팅"),
	StringRow("data.counts", "%d đoạn chat, %d đã lưu trữ", "%d chats, %d archived", "채팅 %d개, 보관 %d개"),
	StringRow("data.export", "Xuất tất cả ra Markdown…", "Export all as Markdown…", "모두 Markdown으로 내보내기…"),
	StringRow("data.exportDone", "Đã xuất %d đoạn chat.", "Exported %d chats.", "채팅 %d개를 내보냈습니다."),
	StringRow("data.exportFailed", "Không xuất được", "Could not export", "내보내지 못했습니다"),
	StringRow("data.archiveAll", "Lưu trữ tất cả", "Archive all", "모두 보관"),
	StringRow("data.deleteAll", "Xóa tất cả đoạn chat…", "Delete all chats…", "모든 채팅 삭제…"),
	StringRow("data.deleteTitle", "Xóa tất cả đoạn chat?", "Delete all chats?", "모든 채팅을 삭제할까요?"),
	StringRow("data.deleteBody", "Việc này xóa mọi đoạn chat đã lưu trên máy, kể cả đã lưu trữ và đã ghim. Không thể hoàn tác. Khuyên bạn xuất ra trước.", "This deletes every saved chat on this Mac, including archived and pinned ones. It cannot be undone. Export first if you want a copy.", "이 Mac에 저장된 모든 채팅(보관·고정 포함)을 삭제합니다. 되돌릴 수 없습니다. 먼저 내보내기를 권장합니다."),
	StringRow("data.deleteConfirm", "Xóa tất cả", "Delete all", "모두 삭제"),

	StringRow("set.search", "Tìm trong Cài đặt", "Search settings", "설정 검색"),
	StringRow("set.noMatch", "Không có mục nào khớp.", "Nothing matches.", "일치하는 항목이 없습니다."),
]
