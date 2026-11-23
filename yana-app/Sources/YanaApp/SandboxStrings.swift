import Foundation

// Text for the terminal sandbox (TerminalSandbox.swift, Settings > Terminal).

let sandboxRows: [StringRow] = [
	StringRow("sbx.title", "Sandbox cho terminal", "Terminal sandbox", "터미널 샌드박스"),
	StringRow("sbx.enable", "Chạy terminal trong sandbox", "Run the terminal in a sandbox", "샌드박스에서 터미널 실행"),
	StringRow("sbx.noNetwork", "Chặn cả mạng", "Also block the network", "네트워크도 차단"),
	StringRow("sbx.unavailable", "Máy này không có sandbox-exec, nên terminal vẫn chạy không có sandbox.", "This Mac has no sandbox-exec, so the terminal runs without a sandbox.", "이 Mac에는 sandbox-exec가 없어 터미널이 샌드박스 없이 실행됩니다."),
	StringRow("sbx.note", "Shell chỉ ghi được trong thư mục dự án, thư mục tạm và vài thư mục cache; đọc thì không bị giới hạn. Áp dụng cho tab terminal mở sau khi đổi, tab có biểu tượng khóa. Chặn mạng sẽ làm git push, npm install và các lệnh cần internet không chạy được. Chỉ áp dụng cho terminal trong app; lệnh do AI chạy vẫn do yana-rt hỏi bạn duyệt như thường.", "The shell can write only in the project folder, the temp folders and a few cache folders; reading is not limited. It applies to terminal tabs opened after the change, shown with a lock. Blocking the network stops git push, npm install and anything that needs the internet. It covers the app's terminal only; commands the AI runs are still approved through yana-rt as usual.", "셸은 프로젝트 폴더, 임시 폴더, 일부 캐시 폴더에만 쓸 수 있고 읽기는 제한되지 않습니다. 변경 후 여는 터미널 탭에 적용되며 자물쇠로 표시됩니다. 네트워크를 차단하면 git push, npm install 등 인터넷이 필요한 명령이 동작하지 않습니다. 앱의 터미널에만 적용되며, AI가 실행하는 명령은 기존처럼 yana-rt 승인을 거칩니다."),
	StringRow("sbx.tabHelp", "Tab này chạy trong sandbox", "This tab runs in a sandbox", "이 탭은 샌드박스에서 실행 중"),
]
