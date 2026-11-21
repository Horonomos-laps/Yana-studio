import SwiftUI

// The cards under the empty chat box: four ways to start, each one a ready sentence. A click puts the sentence in
// the box and does not send it, so the person can change it first. They only name things that work in any folder
// (read the project, look for a bug, add tests, check safety), so none of them depends on what the folder holds.

struct ChatSuggestion: Identifiable, Equatable {
	let id: String
	let icon: String
	// The text on the card and the sentence it puts in the box; both are keys of the string table.
	var titleKey: String { "sugg.\(id).title" }
	var promptKey: String { "sugg.\(id).prompt" }

	static let all = [
		ChatSuggestion(id: "explain", icon: "folder"),
		ChatSuggestion(id: "bug", icon: "search"),
		ChatSuggestion(id: "tests", icon: "terminal"),
		ChatSuggestion(id: "safety", icon: "shield"),
	]

	// The cards show only while the chat is empty and nothing is typed, so they never sit on top of a draft.
	static func visible(chatIsEmpty: Bool, draft: String) -> Bool {
		chatIsEmpty && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
}

struct SuggestionCards: View {
	let pick: (String) -> Void
	private static let cardHeight: CGFloat = 76
	private static let spacing: CGFloat = 10
	// One row of four while it fits, two rows of two otherwise, never three and one.
	private static let rowMinWidth: CGFloat = 640

	var body: some View {
		ViewThatFits(in: .horizontal) {
			grid(columns: ChatSuggestion.all.count).frame(minWidth: Self.rowMinWidth)
			grid(columns: 2)
		}
	}

	private func grid(columns: Int) -> some View {
		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: columns), spacing: Self.spacing) {
			ForEach(ChatSuggestion.all) { item in
				Button { pick(L(item.promptKey)) } label: {
					VStack(alignment: .leading, spacing: 8) {
						FBIcon(name: item.icon, size: 16, color: FB.primary)
						Text(L(item.titleKey)).font(.fbBodyMedium).foregroundStyle(FB.text).lineLimit(2)
							.multilineTextAlignment(.leading)
					}
					.padding(12)
					.frame(maxWidth: .infinity, minHeight: Self.cardHeight, alignment: .topLeading)
					.yanaGlass(in: RoundedRectangle(cornerRadius: 14), interactive: true)
				}
				.buttonStyle(.plain)
				.accessibilityLabel(L(item.titleKey))
			}
		}
	}
}

let suggestionRows: [StringRow] = [
	StringRow("sugg.explain.title", "Giải thích dự án này", "Explain this project", "이 프로젝트 설명"),
	StringRow("sugg.explain.prompt", "Hãy đọc thư mục này và giải thích dự án làm gì, cấu trúc ra sao và nên bắt đầu đọc từ đâu.",
	          "Read this folder and explain what the project does, how it is laid out and where to start reading.",
	          "이 폴더를 읽고 프로젝트가 무엇을 하는지, 구조는 어떤지, 어디서부터 읽으면 되는지 설명해 줘."),
	StringRow("sugg.bug.title", "Tìm lỗi có thể có", "Look for a likely bug", "버그 찾기"),
	StringRow("sugg.bug.prompt", "Tìm những chỗ dễ lỗi nhất trong code, giải thích vì sao và đề xuất cách sửa. Chưa sửa gì cho tới khi tôi đồng ý.",
	          "Find the places most likely to break, explain why and suggest a fix. Change nothing until I agree.",
	          "코드에서 가장 깨지기 쉬운 곳을 찾아 이유와 해결 방법을 알려 줘. 내가 동의하기 전에는 아무것도 바꾸지 마."),
	StringRow("sugg.tests.title", "Thêm test còn thiếu", "Add the missing tests", "빠진 테스트 추가"),
	StringRow("sugg.tests.prompt", "Xem phần nào của code chưa có test, rồi viết test cho phần quan trọng nhất và chạy thử.",
	          "See which part of the code has no tests, write tests for the most important part and run them.",
	          "테스트가 없는 코드 부분을 찾아 가장 중요한 부분의 테스트를 작성하고 실행해 줘."),
	StringRow("sugg.safety.title", "Rà soát an toàn", "Check for safety problems", "안전 점검"),
	StringRow("sugg.safety.prompt", "Rà soát code xem có chỗ nào lộ khóa bí mật, nhận dữ liệu không kiểm tra hoặc chạy lệnh nguy hiểm không, và liệt kê theo mức độ.",
	          "Check the code for leaked secrets, unchecked input or dangerous commands, and list what you find by severity.",
	          "비밀 키 노출, 검증 없는 입력, 위험한 명령이 있는지 코드를 점검하고 심각도 순으로 나열해 줘."),
]
