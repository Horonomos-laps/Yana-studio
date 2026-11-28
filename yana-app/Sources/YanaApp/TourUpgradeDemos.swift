import SwiftUI

// The drawn demos for the notch, the file shelf, the wallpaper, the shared keys and in-place updates. Symbols only,
// so they read the same in every language.

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

// An editor window whose backdrop moves through three real scenes (their sky and floor colors come from the Studio
// catalog), then to the person's own picture.
struct WallpaperTourDemo: View {
	let t: Double

	private static let scenes: [(sky: Color, floor: Color)] = [
		(Color(red: 0.71, green: 0.85, blue: 0.93), Color(red: 0.80, green: 0.92, blue: 0.97)),   // Cloud Drift
		(Color(red: 0.96, green: 0.87, blue: 0.91), Color(red: 0.98, green: 0.93, blue: 0.95)),   // Sakura
		(Color(red: 0.02, green: 0.07, blue: 0.13), Color(red: 0.05, green: 0.13, blue: 0.20)),   // Aurora
	]
	private static let lineWidths: [CGFloat] = [120, 84, 146, 62]

	var body: some View {
		let p = phase(t, 8)
		let own = ramp(p, 6.0, 0.5) - ramp(p, 7.6, 0.4)
		let picked = own > 0.5 ? Self.scenes.count : min(Int(p / 2.0), Self.scenes.count - 1)
		VStack(spacing: 12) {
			MiniWindow {
				ZStack {
					ForEach(Self.scenes.indices, id: \.self) { i in
						LinearGradient(colors: [Self.scenes[i].sky, Self.scenes[i].floor], startPoint: .top, endPoint: .bottom)
							.opacity(i == 0 ? 1 : ramp(p, Double(i) * 2.0, 0.6) - ramp(p, 7.6, 0.4))
					}
					Image(systemName: "photo").font(.system(size: 40)).foregroundStyle(.white).padding(.trailing, 14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
						.background(FB.primary).opacity(own)
					code
				}
				.clipShape(RoundedRectangle(cornerRadius: 8)).padding([.horizontal, .bottom], 8)
			}
			.frame(width: 250, height: 150)
			swatches(picked: picked)
		}
	}

	private var code: some View {
		VStack(alignment: .leading, spacing: 9) {
			ForEach(Self.lineWidths.indices, id: \.self) { i in
				Capsule().fill(FB.canvas.opacity(0.9)).frame(width: Self.lineWidths[i], height: 7).padding(.leading, i % 2 == 0 ? 0 : 18)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
	}

	private func swatches(picked: Int) -> some View {
		HStack(spacing: 10) {
			ForEach(0 ... Self.scenes.count, id: \.self) { i in
				ZStack {
					if i < Self.scenes.count { Circle().fill(Self.scenes[i].sky) } else {
						Circle().fill(FB.surfaceTertiary)
						Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(FB.text)
					}
				}
				.frame(width: 22, height: 22)
				.overlay(Circle().stroke(i == picked ? FB.primary : FB.borderStrong, lineWidth: i == picked ? 3 : 1))
			}
		}
	}
}

// Yana hands the folder to Yana Studio, which opens on it.
struct BridgeTourDemo: View {
	let t: Double
	private static let travel: CGFloat = 150

	var body: some View {
		let p = phase(t, 6)
		let move = ramp(p, 1.2, 1.4)
		let arrived = ramp(p, 2.6, 0.4) - ramp(p, 5.4, 0.4)
		ZStack {
			HStack(spacing: 40) {
				window("Yana", icon: "bubble.left.and.bubble.right.fill", lit: 1)
				window("Studio", icon: "chevron.left.forwardslash.chevron.right", lit: 0.35 + 0.65 * arrived)
					.overlay(alignment: .topTrailing) {
						Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(FB.successText).opacity(arrived).padding(6)
					}
			}
			Image(systemName: "folder.fill").font(.system(size: 28)).foregroundStyle(FB.primary)
				.offset(x: Self.travel * CGFloat(move) - Self.travel / 2, y: 44)
				.opacity(ramp(p, 0.6) - ramp(p, 5.4, 0.4))
		}
	}

	private func window(_ name: String, icon: String, lit: Double) -> some View {
		MiniWindow {
			VStack(spacing: 10) {
				Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(FB.text)
				Image(systemName: icon).font(.system(size: 24)).foregroundStyle(FB.primary)
				Spacer(minLength: 0)
			}
			.opacity(lit).padding(.top, 4)
		}
		.frame(width: 124, height: 150)
	}
}
