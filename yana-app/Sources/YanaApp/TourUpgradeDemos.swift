import SwiftUI

// The drawn demos for the notch, the file shelf, the shared keys and in-place updates. Symbols only, so they read the
// same in every language.

// A dark notch shape that opens at the top of a small screen.
private struct MiniNotch<Content: View>: View {
	let open: Double   // 0 closed, 1 open
	@ViewBuilder let content: Content

	var body: some View {
		let width = 90 + 190 * open, height = 18 + 92 * open
		NotchShape(topRadius: 8, bottomRadius: 12 + 8 * open).fill(Color.black)
			.frame(width: width, height: height)
			.overlay { content.opacity(max(0, open * 2 - 1)).padding(.top, 14) }
	}
}

struct NotchTourDemo: View {
	let t: Double
	var body: some View {
		let p = phase(t, 6)
		let open = ramp(p, 0.8, 0.5) - ramp(p, 5.0, 0.4)
		let page = Int(min(max((p - 1.8) / 1.0, 0), 2))
		MiniWindow {
			VStack(spacing: 10) {
				MiniNotch(open: open) {
					VStack(spacing: 8) {
						HStack(spacing: 6) {
							ForEach(0 ..< 4, id: \.self) { Circle().fill(Color.white.opacity($0 == page ? 1 : 0.3)).frame(width: 6, height: 6) }
						}
						Image(systemName: ["sparkles", "timer", "tray.full"][page]).font(.system(size: 26)).foregroundStyle(.white)
					}
				}
				Spacer(minLength: 0)
				Image(systemName: "hand.draw").font(.system(size: 22)).foregroundStyle(FB.primary)
					.offset(x: CGFloat(-30 * ramp(p, 1.8, 2.4)), y: CGFloat(-10 * open))
			}
			.padding(.bottom, 14)
		}
	}
}

struct ShelfTourDemo: View {
	let t: Double
	var body: some View {
		let p = phase(t, 6)
		let lift = ramp(p, 0.6, 1.2)
		let open = ramp(p, 1.4, 0.4) - ramp(p, 5.2, 0.4)
		MiniWindow {
			VStack(spacing: 10) {
				MiniNotch(open: open) {
					HStack(spacing: 12) {
						Image(systemName: "doc.fill").opacity(ramp(p, 2.0))
						Image(systemName: "dot.radiowaves.left.and.right").opacity(ramp(p, 2.8))
						Image(systemName: "paperclip").opacity(ramp(p, 3.4))
					}
					.font(.system(size: 22)).foregroundStyle(.white)
				}
				Spacer(minLength: 0)
				Image(systemName: "doc.fill").font(.system(size: 30)).foregroundStyle(FB.primary)
					.offset(y: CGFloat(-90 * lift)).opacity(1 - ramp(p, 1.8))
			}
			.padding(.bottom, 14)
		}
	}
}

struct KeysTourDemo: View {
	let t: Double
	var body: some View {
		let p = phase(t, 6)
		HStack(spacing: 14) {
			card("Yana", done: p > 1.4)
			Image(systemName: "key.fill").font(.system(size: 20)).foregroundStyle(FB.primary)
				.opacity(ramp(p, 1.4)).offset(x: CGFloat(-18 + 36 * ramp(p, 1.8, 1.2))).zIndex(1)
			card("Studio", done: p > 3.0)
		}
	}

	private func card(_ name: String, done: Bool) -> some View {
		MiniWindow {
			VStack(spacing: 10) {
				Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(FB.text)
				Text("••••••••").font(.system(size: 14, design: .monospaced)).foregroundStyle(FB.textSecondary).opacity(done ? 1 : 0.2)
				Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed").font(.system(size: 22))
					.foregroundStyle(done ? FB.successText : FB.textTertiary)
			}
		}
		.frame(width: 112, height: 150)
	}
}

struct UpdateTourDemo: View {
	let t: Double
	var body: some View {
		let p = phase(t, 6)
		let progress = ramp(p, 1.4, 2.2)
		MiniWindow {
			VStack(spacing: 14) {
				Image(systemName: progress >= 1 ? "checkmark.circle.fill" : "arrow.down.circle").font(.system(size: 38))
					.foregroundStyle(progress >= 1 ? FB.successText : FB.primary)
				Capsule().fill(FB.borderStrong).frame(width: 180, height: 6)
					.overlay(alignment: .leading) { Capsule().fill(FB.primary).frame(width: CGFloat(180 * progress), height: 6) }
					.opacity(p > 1.2 ? 1 : 0)
				Text(L("upd.inPlaceButton")).font(.system(size: 12, weight: .semibold)).foregroundStyle(FB.onPrimary)
					.padding(.horizontal, 16).padding(.vertical, 7).background(Capsule().fill(FB.primary))
					.scaleEffect(p > 0.9 && p < 1.2 ? 0.92 : 1).opacity(progress >= 1 ? 0.35 : 1)
			}
		}
	}
}
