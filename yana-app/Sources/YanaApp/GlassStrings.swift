import SwiftUI

// Text for Liquid Glass (Settings > General) and the rail's open-page surface.

let glassRows: [StringRow] = [
	StringRow("set.glass", "Giao diện kính lỏng (Liquid Glass)", "Liquid Glass look", "리퀴드 글래스 스타일"),
	StringRow("set.glassOff", "Đang dùng giao diện phẳng vì Mac chưa lên macOS 26, hoặc đã bật “Giảm độ trong suốt” trong Cài đặt hệ thống.", "The flat look is in use because this Mac is older than macOS 26 or “Reduce transparency” is on in System Settings.", "macOS 26 미만이거나 시스템 설정에서 \"투명도 줄이기\"가 켜져 있어 일반 스타일을 사용 중입니다."),
]

// The surface behind a page in the icon rail: glass tinted blue when it is the open page, a light wash on hover.
struct RailItemSurface: ViewModifier {
	let selected: Bool
	let hover: Bool
	var tint: Color = FB.primary

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		if LiquidGlass.active, #available(macOS 26.0, *) {
			if selected {
				content.glassEffect(.regular.tint(tint.opacity(0.22)).interactive(), in: shape)
			} else {
				content.background(shape.fill(hover ? tint.opacity(0.10) : .clear))
			}
		} else {
			content
				.background(RoundedRectangle(cornerRadius: 12).fill(selected ? FB.canvas : hover ? FB.hoverOnChrome : .clear))
				.overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? tint.opacity(0.45) : .clear, lineWidth: 1))
		}
	}
}
