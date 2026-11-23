import SwiftUI

// Style and tone for replies (the part of ChatGPT's Personalization page that Yana lacked), and the project's
// AGENTS.md edited from Settings. A style choice becomes one plain sentence added to the system instruction
// (Personalization.instruction); a choice left on its default adds nothing.

enum StyleLevel: String, CaseIterable, Identifiable {
	case less, normal, more
	var id: String { rawValue }
}

enum BaseTone: String, CaseIterable, Identifiable {
	case standard, professional, friendly, candid, efficient, playful
	var id: String { rawValue }

	var sentence: String? {
		switch self {
		case .standard: return nil
		case .professional: return "Use a polished, professional tone: precise and measured."
		case .friendly: return "Use a warm, friendly, conversational tone."
		case .candid: return "Be direct and candid: say plainly what is wrong or risky, without padding or flattery."
		case .efficient: return "Be concise and efficient: short answers, no preamble, and no closing summary unless asked."
		case .playful: return "Use a light, playful tone with some humor, while staying accurate."
		}
	}
}

struct PersonalStyle: Equatable {
	static let toneKey = "yana.personal.tone"
	static let warmKey = "yana.personal.warm"
	static let enthusiasticKey = "yana.personal.enthusiastic"
	static let emojiKey = "yana.personal.emoji"
	static let structureKey = "yana.personal.structure"
	static let visualKey = "yana.personal.visual"
	static let allKeys = [toneKey, warmKey, enthusiasticKey, emojiKey, structureKey, visualKey]

	var tone = BaseTone.standard
	var warm = StyleLevel.normal
	var enthusiastic = StyleLevel.normal
	var emoji = StyleLevel.normal
	var structure = StyleLevel.normal
	var visual = false

	var isDefault: Bool { self == PersonalStyle() }

	static func current(_ d: UserDefaults = .standard) -> PersonalStyle {
		func level(_ key: String) -> StyleLevel { d.string(forKey: key).flatMap(StyleLevel.init(rawValue:)) ?? .normal }
		return PersonalStyle(tone: d.string(forKey: toneKey).flatMap(BaseTone.init(rawValue:)) ?? .standard,
		                     warm: level(warmKey), enthusiastic: level(enthusiasticKey), emoji: level(emojiKey),
		                     structure: level(structureKey), visual: d.bool(forKey: visualKey))
	}

	// One sentence per choice that is not the default, in a fixed order.
	var sentences: [String] {
		var out: [String] = []
		if let line = tone.sentence { out.append(line) }
		switch warm {
		case .more: out.append("Be noticeably warm and encouraging.")
		case .less: out.append("Be reserved: skip pleasantries and encouragement.")
		case .normal: break
		}
		switch enthusiastic {
		case .more: out.append("Show more enthusiasm and energy.")
		case .less: out.append("Keep an even, calm tone, without exclamation marks.")
		case .normal: break
		}
		switch emoji {
		case .more: out.append("Use emoji freely where they add warmth.")
		case .less: out.append("Do not use emoji.")
		case .normal: break
		}
		switch structure {
		case .more: out.append("Prefer headings and bullet lists to organize longer answers.")
		case .less: out.append("Prefer flowing prose; avoid headings and bullet lists unless asked.")
		case .normal: break
		}
		if visual { out.append("When it helps, present comparisons and structured data as Markdown tables.") }
		return out
	}
}

// The AGENTS.md of the project folder: instructions for agents working in that folder, read by yana-rt and others.
enum AgentsFile {
	static let fileName = "AGENTS.md"
	static let maxChars = 100_000

	enum Failure: Error, Equatable { case noFolder, tooLong }

	// The file's place, or nil when the project folder does not exist.
	static func url(workspace: String) -> URL? {
		var isDirectory: ObjCBool = false
		guard !workspace.isEmpty, FileManager.default.fileExists(atPath: workspace, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
		return URL(fileURLWithPath: workspace, isDirectory: true).appendingPathComponent(fileName)
	}

	static func read(workspace: String) -> (text: String, exists: Bool)? {
		guard let url = url(workspace: workspace) else { return nil }
		guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return ("", false) }
		return (text, true)
	}

	static func save(_ text: String, workspace: String) throws {
		guard let url = url(workspace: workspace) else { throw Failure.noFolder }
		guard text.count <= maxChars else { throw Failure.tooLong }
		try Data(text.utf8).write(to: url, options: .atomic)
	}
}

struct AgentsFileSheet: View {
	let workspace: String
	let close: () -> Void
	@State private var text = ""
	@State private var existed = false
	@State private var failure: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(AgentsFile.fileName).font(.system(size: 16, weight: .semibold)).foregroundStyle(FB.text)
			Text(L(existed ? "per.agentsSub" : "per.agentsNew")).font(.fbCaption).foregroundStyle(FB.textSecondary)
			Text(AgentsFile.url(workspace: workspace)?.path ?? workspace).font(.system(size: 11, design: .monospaced))
				.foregroundStyle(FB.textTertiary).lineLimit(1).truncationMode(.middle)
			TextEditor(text: $text).font(.system(size: 13, design: .monospaced)).scrollContentBackground(.hidden)
				.padding(8).frame(minHeight: 280)
				.background(RoundedRectangle(cornerRadius: 8).fill(FB.surfaceSecondary))
				.overlay(RoundedRectangle(cornerRadius: 8).stroke(FB.divider))
			if text.count > AgentsFile.maxChars {
				Text(L("per.agentsLong")).font(.fbCaption).foregroundStyle(FB.warningText)
			}
			if let failure { Text(failure).font(.fbCaption).foregroundStyle(FB.errorText) }
			HStack {
				Spacer()
				FBButton(title: L("store.cancel"), variant: .secondary, size: .small, action: close)
				FBButton(title: L("history.save"), variant: .primary, size: .small, action: save)
					.disabled(text.count > AgentsFile.maxChars)
			}
		}
		.padding(24).frame(width: 600)
		.onAppear {
			if let found = AgentsFile.read(workspace: workspace) { text = found.text; existed = found.exists }
		}
	}

	private func save() {
		do { try AgentsFile.save(text, workspace: workspace); close() }
		catch { failure = "\(L("per.agentsFail")): \(error.localizedDescription)" }
	}
}

let personalStyleRows: [StringRow] = [
	StringRow("per.style", "Phong cách và giọng điệu", "Style and tone", "스타일과 어조"),
	StringRow("per.styleNote", "Chỉ thêm một câu hướng dẫn cho mỗi lựa chọn khác mặc định. Để mặc định thì không gửi gì.", "Each choice other than the default adds one sentence of guidance. Left on default, nothing is sent.", "기본값이 아닌 선택마다 안내 문장이 하나씩 추가됩니다. 기본값이면 아무것도 보내지 않습니다."),
	StringRow("per.tone", "Giọng điệu cơ bản", "Base tone", "기본 어조"),
	StringRow("per.tone.standard", "Mặc định", "Default", "기본"),
	StringRow("per.tone.professional", "Chuyên nghiệp", "Professional", "전문적"),
	StringRow("per.tone.friendly", "Thân thiện", "Friendly", "친근함"),
	StringRow("per.tone.candid", "Thẳng thắn", "Candid", "솔직함"),
	StringRow("per.tone.efficient", "Ngắn gọn", "Efficient", "간결함"),
	StringRow("per.tone.playful", "Vui vẻ", "Playful", "유쾌함"),
	StringRow("per.warm", "Thân thiện", "Warmth", "따뜻함"),
	StringRow("per.enthusiastic", "Nhiệt tình", "Enthusiasm", "열정"),
	StringRow("per.emoji", "Biểu tượng cảm xúc", "Emoji", "이모지"),
	StringRow("per.structure", "Tiêu đề và danh sách", "Headings and lists", "제목과 목록"),
	StringRow("per.level.less", "Ít hơn", "Less", "적게"),
	StringRow("per.level.normal", "Mặc định", "Default", "기본"),
	StringRow("per.level.more", "Nhiều hơn", "More", "많이"),
	StringRow("per.visual", "Trình bày bằng bảng khi hữu ích", "Use tables when they help", "도움이 될 때 표 사용"),
	StringRow("per.styleReset", "Về mặc định", "Reset to default", "기본값으로"),
	StringRow("per.agents", "AGENTS.md của dự án", "The project's AGENTS.md", "프로젝트 AGENTS.md"),
	StringRow("per.agentsBody", "Hướng dẫn cho mọi agent làm việc trong thư mục dự án này. Tệp nằm trong thư mục dự án, nên mọi công cụ khác đọc được.", "Instructions for any agent working in this project folder. The file lives in the project folder, so other tools read it too.", "이 프로젝트 폴더에서 작업하는 모든 에이전트를 위한 지침입니다. 파일이 프로젝트 폴더에 있어 다른 도구도 읽을 수 있습니다."),
	StringRow("per.agentsEdit", "Chỉnh sửa AGENTS.md", "Edit AGENTS.md", "AGENTS.md 편집"),
	StringRow("per.agentsNoFolder", "Chưa có thư mục dự án hợp lệ. Chọn trong Cài đặt → Chung.", "There is no valid project folder yet. Pick one in Settings → General.", "유효한 프로젝트 폴더가 없습니다. 설정 → 일반에서 선택하세요."),
	StringRow("per.agentsSub", "Đang sửa tệp có sẵn. Bấm Lưu mới ghi vào dự án.", "Editing the existing file. Nothing is written until you press Save.", "기존 파일을 편집 중입니다. 저장을 눌러야 프로젝트에 기록됩니다."),
	StringRow("per.agentsNew", "Dự án chưa có tệp này. Nó chỉ được tạo khi bạn bấm Lưu.", "This project has no such file yet. It is created only when you press Save.", "이 프로젝트에는 아직 이 파일이 없습니다. 저장을 누를 때만 만들어집니다."),
	StringRow("per.agentsLong", "Quá dài (tối đa 100.000 ký tự).", "Too long (100,000 characters at most).", "너무 깁니다(최대 100,000자)."),
	StringRow("per.agentsFail", "Không ghi được tệp", "Could not write the file", "파일을 쓸 수 없습니다"),
	StringRow("per.extra", "Tùy chọn bổ sung", "More options", "추가 옵션"),
	StringRow("per.suggestions", "Hiện gợi ý ở màn chat trống", "Show suggestions on the empty chat", "빈 채팅 화면에 추천 표시"),
]
