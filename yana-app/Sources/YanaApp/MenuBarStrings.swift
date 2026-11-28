import Foundation

let menuBarRows: [StringRow] = [
	StringRow("bar.ssdFree", "SSD còn trống", "SSD free", "SSD 여유 공간"),
	StringRow("bar.temperature", "Nhiệt độ", "Temperature", "온도"),
	StringRow("bar.thermalNominal", "Bình thường", "Normal", "정상"),
	StringRow("bar.thermalFair", "Hơi ấm", "Warm", "약간 높음"),
	StringRow("bar.thermalSerious", "Nóng", "Hot", "높음"),
	StringRow("bar.thermalCritical", "Quá nóng", "Too hot", "매우 높음"),
	StringRow("bar.open", "Mở Yana", "Open Yana", "Yana 열기"),
	StringRow("bar.quit", "Thoát Yana", "Quit Yana", "Yana 종료"),
	StringRow("bar.openStudio", "Mở Yana Studio", "Open Yana Studio", "Yana Studio 열기"),
	StringRow("bar.notRunning", "Chưa mở", "Not running", "실행 중 아님"),
	StringRow("bar.sessions", "Claude Code: %d đang làm, %d chờ duyệt", "Claude Code: %d working, %d waiting", "Claude Code: 작업 중 %d, 승인 대기 %d"),
	StringRow("set.menuBar", "Hiện Yana trên thanh menu", "Show Yana in the menu bar", "메뉴 막대에 Yana 표시"),
	StringRow("set.menuBarDock", "Giữ biểu tượng Dock khi đóng cửa sổ", "Keep the Dock icon when the window is closed", "창을 닫아도 Dock 아이콘 유지"),
	StringRow("set.menuBarNote", "Đóng cửa sổ thì Yana vẫn chạy nền; bấm Yana trên thanh menu để xem CPU, GPU, RAM, SSD, nhiệt độ hoặc mở lại. ⌘Q thoát hẳn.", "Closing the window leaves Yana running; click Yana in the menu bar to see CPU, GPU, RAM, SSD and temperature, or to open it again. ⌘Q quits.", "창을 닫아도 Yana는 계속 실행됩니다. 메뉴 막대의 Yana를 누르면 CPU, GPU, RAM, SSD, 온도를 보거나 다시 열 수 있습니다. ⌘Q로 종료합니다."),
]
