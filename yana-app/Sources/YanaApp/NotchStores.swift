import AppKit
import SwiftUI

// The live state behind the notch's widgets. Each store keeps its data in UserDefaults (small, per user, no files to
// manage) and the rules live in NotchWidgetsLogic.swift. They only work while the notch is switched on.

private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
	UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
}

private func save<T: Encodable>(_ value: T, key: String) {
	if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
}

// MARK: Music (Spotify and Apple Music, through their own scripting interface)

@MainActor
final class MusicStore: ObservableObject {
	static let shared = MusicStore()
	@Published private(set) var nowPlaying: NowPlaying?
	@Published private(set) var denied = false   // macOS refused the first request to control the player
	@Published private(set) var problem: BrowserMusic.Problem?   // a browser is open but cannot be read yet
	private var timer: Timer?
	private let queue = DispatchQueue(label: "yana.notch.music", qos: .utility)

	func start() {
		guard timer == nil else { return }
		refresh()
		timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
			Task { @MainActor in self?.refresh() }
		}
	}

	func stop() { timer?.invalidate(); timer = nil; nowPlaying = nil }

	// One script per player. It says nothing when the app is not running, so asking never launches it.
	private static func script(for source: NowPlaying.Source) -> String {
		if source.isBrowser { return BrowserMusic.script(app: source.rawValue, js: BrowserMusic.readJS) }
		let sep = "(character id 31)"
		let tail = source == .spotify ? "& \(sep) & (artwork url of current track)" : ""
		return """
		if application "\(source.rawValue)" is running then
			tell application "\(source.rawValue)"
				if player state is stopped then return ""
				return (player state as string) & \(sep) & (name of current track) & \(sep) & (artist of current track) & \(sep) & (duration of current track) & \(sep) & (player position) \(tail)
			end tell
		end if
		return ""
		"""
	}

	func refresh() {
		queue.async { [weak self] in
			var found: [NowPlaying] = []
			var refused = false
			var problem: BrowserMusic.Problem?
			for source in NowPlaying.Source.all {
				var error: NSDictionary?
				let result = NSAppleScript(source: Self.script(for: source))?.executeAndReturnError(&error)
				if let code = error?[NSAppleScript.errorNumber] as? Int {
					let message = error?[NSAppleScript.errorMessage] as? String ?? ""
					if code == -1743 { refused = true }
					if source.isBrowser, problem == nil { problem = BrowserMusic.problem(code: code, message: message, app: source.rawValue) }
				}
				if let text = result?.stringValue, let info = NowPlaying.parse(text, source: source) { found.append(info) }
			}
			let chosen = NowPlaying.choose(found), denied = refused, issue = problem
			Task { @MainActor in
				self?.nowPlaying = chosen
				self?.denied = denied && chosen == nil
				self?.problem = chosen == nil ? issue : nil
			}
		}
	}

	func send(_ command: BrowserMusic.Command) {
		guard let source = nowPlaying?.source else { return }
		queue.async { [weak self] in
			var error: NSDictionary?
			if source.isBrowser {
				NSAppleScript(source: BrowserMusic.script(app: source.rawValue, js: BrowserMusic.js(for: command)))?.executeAndReturnError(&error)
			} else {
				let word: String
				switch command { case .playPause: word = "playpause"; case .next: word = "next track"; case .previous: word = "previous track" }
				NSAppleScript(source: "tell application \"\(source.rawValue)\" to \(word)")?.executeAndReturnError(&error)
			}
			Task { @MainActor in self?.refresh() }
		}
	}

	func playPause() { send(.playPause) }
	func next() { send(.next) }
	func previous() { send(.previous) }
}

// MARK: Timers and Pomodoro

@MainActor
final class TimerStore: ObservableObject {
	static let shared = TimerStore()
	private static let key = "yana.notch.timers", pomoKey = "yana.notch.pomodoro", dayKey = "yana.notch.pomodoroDay"
	@Published private(set) var timers: [CountdownTimer] = load([CountdownTimer].self, key: key) ?? []
	@Published private(set) var pomodoro = load(Pomodoro.self, key: pomoKey) ?? Pomodoro()
	private var ticker: Timer?

	func start() {
		guard ticker == nil else { return }
		resetOnNewDay()
		tick()
		ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			Task { @MainActor in self?.tick() }
		}
	}

	func stop() { ticker?.invalidate(); ticker = nil }

	func addTimer(minutes: Int) {
		timers.append(CountdownTimer(total: Double(minutes) * 60, endsAt: Date().addingTimeInterval(Double(minutes) * 60)))
		persist()
	}

	func removeTimer(_ id: UUID) { timers.removeAll { $0.id == id }; persist() }
	func startPomodoro() { pomodoro.start(now: Date()); persist() }
	func pausePomodoro() { pomodoro.pause(now: Date()); persist() }
	func skipPomodoro() { pomodoro.advance(); persist() }
	func resetPomodoro() { pomodoro.reset(); persist() }

	private func tick() {
		let now = Date()
		var changed = false
		if pomodoro.finishIfDue(now: now) { NSSound(named: "Glass")?.play(); changed = true }
		let finished = timers.filter { $0.isDone(now: now) }
		if !finished.isEmpty {
			NSSound(named: "Glass")?.play()
			timers.removeAll { $0.isDone(now: now) }
			changed = true
		}
		if changed { persist() }
	}

	// The count of finished focus rounds is for today only.
	private func resetOnNewDay() {
		let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
		let saved = UserDefaults.standard.double(forKey: Self.dayKey)
		if saved != today, saved != 0 { pomodoro.completedFocus = 0 }
		UserDefaults.standard.set(today, forKey: Self.dayKey)
	}

	private func persist() { save(timers, key: Self.key); save(pomodoro, key: Self.pomoKey) }
}

// MARK: To-do and notes

@MainActor
final class TodoStore: ObservableObject {
	static let shared = TodoStore()
	private static let key = "yana.notch.todo"
	@Published private(set) var items: [TodoItem] = load([TodoItem].self, key: key) ?? []
	func add(_ title: String) { set(TodoList.add(items, title: title)) }
	func toggle(_ id: UUID) { set(TodoList.toggle(items, id: id)) }
	func remove(_ id: UUID) { set(TodoList.remove(items, id: id)) }
	func clearDone() { set(TodoList.clearDone(items)) }
	private func set(_ new: [TodoItem]) { items = new; save(new, key: Self.key) }
}

@MainActor
final class NotesStore: ObservableObject {
	static let shared = NotesStore()
	private static let key = "yana.notch.notes"
	@Published var text = UserDefaults.standard.string(forKey: key) ?? "" {
		didSet { UserDefaults.standard.set(text, forKey: Self.key) }
	}
}

// MARK: Clipboard history

@MainActor
final class ClipboardStore: ObservableObject {
	static let shared = ClipboardStore()
	private static let key = "yana.notch.clipboard"
	@Published private(set) var items: [ClipItem] = load([ClipItem].self, key: key) ?? []
	private var timer: Timer?
	private var lastCount = NSPasteboard.general.changeCount

	func start() {
		guard timer == nil else { return }
		lastCount = NSPasteboard.general.changeCount
		timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
			Task { @MainActor in self?.poll() }
		}
	}

	func stop() { timer?.invalidate(); timer = nil }

	private func poll() {
		let board = NSPasteboard.general
		guard board.changeCount != lastCount else { return }
		lastCount = board.changeCount
		let types = (board.types ?? []).map(\.rawValue)
		guard ClipboardHistory.shouldKeep(types: types), let text = board.string(forType: .string) else { return }
		items = ClipboardHistory.insert(items, text: text)
		save(items, key: Self.key)
	}

	// Choosing an item puts it back on the pasteboard (and moves it to the top).
	func copy(_ item: ClipItem) {
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(item.text, forType: .string)
		lastCount = NSPasteboard.general.changeCount
		items = ClipboardHistory.insert(items, text: item.text)
		save(items, key: Self.key)
	}

	func clear() { items = []; save(items, key: Self.key) }
}
