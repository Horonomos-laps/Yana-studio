import AppKit
import SwiftUI

// The widgets inside the open notch. Cards sit side by side on the Home tab; the clipboard has its own tab.

private let cardFill = Color.white.opacity(0.08)
private let dim = Color.white.opacity(0.55)

struct WidgetCard<Content: View>: View {
	let title: String
	@ViewBuilder var content: Content
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(dim).textCase(.uppercase)
			content
			Spacer(minLength: 0)
		}
		.padding(10)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}

private struct IconButton: View {
	let system: String
	let action: () -> Void
	var size: CGFloat = 13
	var body: some View {
		Button(action: action) { Image(systemName: system).font(.system(size: size, weight: .semibold)) }
			.buttonStyle(.plain).foregroundStyle(.white)
	}
}

// MARK: Music

struct MusicCard: View {
	@ObservedObject private var store = MusicStore.shared
	var body: some View {
		WidgetCard(title: L("notch.music")) {
			if let now = store.nowPlaying {
				HStack(spacing: 8) {
					artwork(now)
					VStack(alignment: .leading, spacing: 1) {
						Text(now.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
						Text(now.artist).font(.system(size: 11)).foregroundStyle(dim).lineLimit(1)
					}
				}
				ProgressView(value: now.progress).tint(.white).scaleEffect(y: 0.6)
				HStack(spacing: 18) {
					Spacer()
					IconButton(system: "backward.fill", action: store.previous)
					IconButton(system: now.playing ? "pause.fill" : "play.fill", action: store.playPause, size: 16)
					IconButton(system: "forward.fill", action: store.next)
					Spacer()
				}
			} else {
				Text(store.denied ? L("notch.musicDenied") : L("notch.musicNone")).font(.system(size: 11)).foregroundStyle(dim)
			}
		}
	}

	@ViewBuilder private func artwork(_ now: NowPlaying) -> some View {
		let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
		Group {
			if let url = now.artworkURL {
				AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.white.opacity(0.1) }
			} else {
				ZStack { Color.white.opacity(0.1); Image(systemName: "music.note").foregroundStyle(dim) }
			}
		}
		.frame(width: 38, height: 38).clipShape(shape)
	}
}

// MARK: Timers and Pomodoro

struct TimerCard: View {
	@ObservedObject private var store = TimerStore.shared
	var body: some View {
		WidgetCard(title: L("notch.timer")) {
			TimelineView(.periodic(from: .now, by: 1)) { context in
				let p = store.pomodoro
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text(phaseName(p.phase)).font(.system(size: 11, weight: .medium)).foregroundStyle(dim)
						Spacer()
						Text("\(p.completedFocus)").font(.system(size: 11)).foregroundStyle(dim)
						Image(systemName: "checkmark.circle").font(.system(size: 10)).foregroundStyle(dim)
					}
					Text(clockText(p.remaining(now: context.date)))
						.font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(.white)
					HStack(spacing: 14) {
						IconButton(system: p.isRunning ? "pause.fill" : "play.fill") { p.isRunning ? store.pausePomodoro() : store.startPomodoro() }
						IconButton(system: "forward.end.fill", action: store.skipPomodoro)
						IconButton(system: "arrow.counterclockwise", action: store.resetPomodoro)
					}
					ForEach(store.timers) { timer in
						HStack {
							Image(systemName: "timer").font(.system(size: 10))
							Text(clockText(timer.remaining(now: context.date))).font(.system(size: 11).monospacedDigit())
							Spacer()
							IconButton(system: "xmark", action: { store.removeTimer(timer.id) }, size: 9)
						}.foregroundStyle(.white)
					}
					HStack(spacing: 6) {
						ForEach([5, 10, 15], id: \.self) { minutes in
							Button("\(minutes)′") { store.addTimer(minutes: minutes) }.buttonStyle(.plain)
								.font(.system(size: 10, weight: .medium)).foregroundStyle(.white)
								.padding(.horizontal, 6).padding(.vertical, 2).background(Color.white.opacity(0.12), in: Capsule())
						}
					}
				}
			}
		}
	}

	private func phaseName(_ phase: Pomodoro.Phase) -> String {
		switch phase {
		case .focus: L("notch.focus")
		case .shortBreak: L("notch.shortBreak")
		case .longBreak: L("notch.longBreak")
		}
	}
}

// MARK: To-do

struct TodoCard: View {
	@ObservedObject private var store = TodoStore.shared
	@State private var draft = ""
	let typing: (Bool) -> Void
	@FocusState private var focused: Bool

	var body: some View {
		WidgetCard(title: L("notch.todo")) {
			ScrollView {
				VStack(alignment: .leading, spacing: 4) {
					ForEach(store.items) { item in
						HStack(spacing: 6) {
							IconButton(system: item.done ? "checkmark.circle.fill" : "circle", action: { store.toggle(item.id) })
							Text(item.title).font(.system(size: 11)).strikethrough(item.done).lineLimit(2)
								.foregroundStyle(item.done ? dim : .white)
							Spacer(minLength: 0)
							IconButton(system: "xmark", action: { store.remove(item.id) }, size: 8)
						}
					}
				}
			}
			TextField(L("notch.todoAdd"), text: $draft).textFieldStyle(.plain).font(.system(size: 11)).foregroundStyle(.white)
				.focused($focused).onChange(of: focused) { _, now in typing(now) }
				.onSubmit { store.add(draft); draft = "" }
		}
	}
}

// MARK: Notes

struct NotesCard: View {
	@ObservedObject private var store = NotesStore.shared
	let typing: (Bool) -> Void
	@FocusState private var focused: Bool

	var body: some View {
		WidgetCard(title: L("notch.notes")) {
			TextEditor(text: $store.text).scrollContentBackground(.hidden).font(.system(size: 11)).foregroundStyle(.white)
				.focused($focused).onChange(of: focused) { _, now in typing(now) }
		}
	}
}

// MARK: Clipboard

struct ClipboardTab: View {
	@ObservedObject private var store = ClipboardStore.shared
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Text(L("notch.clipboard")).font(.system(size: 10, weight: .semibold)).foregroundStyle(dim).textCase(.uppercase)
				Spacer()
				if !store.items.isEmpty { Button(L("notch.clear"), action: store.clear).buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(dim) }
			}
			if store.items.isEmpty {
				Text(L("notch.clipboardEmpty")).font(.system(size: 11)).foregroundStyle(dim)
			}
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					ForEach(store.items) { item in
						Button { store.copy(item) } label: {
							Text(item.text).font(.system(size: 11)).foregroundStyle(.white).lineLimit(5).multilineTextAlignment(.leading)
								.frame(width: 150, height: 90, alignment: .topLeading).padding(8)
								.background(cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
						}.buttonStyle(.plain)
					}
				}
			}
		}
	}
}
