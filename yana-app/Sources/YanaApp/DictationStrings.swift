import Foundation

// Text for speaking into the chat box (Dictation.swift, ChatHome.swift, Settings > Chat).

let dictationRows: [StringRow] = [
	StringRow("dict.start", "Nhập bằng giọng nói", "Dictate", "음성으로 입력"),
	StringRow("dict.stop", "Dừng nhập giọng nói", "Stop dictating", "음성 입력 중지"),
	StringRow("dict.listening", "Đang nghe… bấm micro để dừng.", "Listening… press the microphone to stop.", "듣는 중… 마이크를 눌러 중지하세요."),
	StringRow("dict.micDenied", "Yana chưa được dùng micro. Bật trong Cài đặt hệ thống, mục Quyền riêng tư và Bảo mật, Micro.", "Yana cannot use the microphone yet. Turn it on in System Settings, Privacy & Security, Microphone.", "Yana가 마이크를 사용할 수 없습니다. 시스템 설정의 개인정보 보호 및 보안, 마이크에서 켜세요."),
	StringRow("dict.speechDenied", "Yana chưa được dùng nhận dạng giọng nói. Bật trong Cài đặt hệ thống, mục Quyền riêng tư và Bảo mật, Nhận dạng giọng nói.", "Yana cannot use speech recognition yet. Turn it on in System Settings, Privacy & Security, Speech Recognition.", "Yana가 음성 인식을 사용할 수 없습니다. 시스템 설정의 개인정보 보호 및 보안, 음성 인식에서 켜세요."),
	StringRow("dict.noOnDevice", "Ngôn ngữ này chưa có nhận dạng ngay trên máy. Tải ngôn ngữ trong Cài đặt hệ thống, Bàn phím, Đọc chính tả, hoặc cho phép máy chủ Apple trong Cài đặt, Trò chuyện.", "This language has no on-device recognition. Download it in System Settings, Keyboard, Dictation, or allow Apple's servers in Settings, Chat.", "이 언어는 기기 내 인식이 없습니다. 시스템 설정의 키보드, 받아쓰기에서 내려받거나 설정의 채팅에서 Apple 서버를 허용하세요."),
	StringRow("dict.unavailable", "Nhận dạng giọng nói đang không dùng được lúc này.", "Speech recognition is not available right now.", "지금은 음성 인식을 사용할 수 없습니다."),
	StringRow("dict.noMic", "Không tìm thấy micro.", "No microphone found.", "마이크를 찾을 수 없습니다."),
	StringRow("dict.openSettings", "Mở Cài đặt hệ thống", "Open System Settings", "시스템 설정 열기"),
	StringRow("set.dict", "Nhập bằng giọng nói", "Dictation", "음성 입력"),
	StringRow("set.dictServer", "Cho phép nhận dạng qua máy chủ của Apple", "Allow Apple's servers for recognition", "인식에 Apple 서버 허용"),
	StringRow("set.dictNote", "Mặc định, giọng nói được chuyển thành chữ ngay trên máy và âm thanh không rời máy. Chỉ khi một ngôn ngữ chưa có bản trên máy, bật mục này mới gửi âm thanh tới Apple. Ngôn ngữ nói theo ngôn ngữ của app.", "By default speech becomes text on this Mac and the audio never leaves it. Only for a language with no on-device version does turning this on send audio to Apple. The spoken language follows the app language.", "기본적으로 음성은 이 Mac에서 텍스트로 변환되며 오디오는 기기를 떠나지 않습니다. 기기 내 버전이 없는 언어에서만 이 옵션을 켜면 오디오가 Apple로 전송됩니다. 말하는 언어는 앱 언어를 따릅니다."),
]
