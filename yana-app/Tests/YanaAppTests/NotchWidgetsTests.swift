import XCTest
@testable import YanaApp

final class NotchWidgetsTests: XCTestCase {
	private let sep = NowPlaying.separator

	func testSpotifyLineIsParsedWithMillisecondsConvertedToSeconds() {
		let raw = ["playing", "Song | with bar", "Artist", "215000", "43,5", "https://i.scdn.co/image/abc"].joined(separator: sep)
		let now = NowPlaying.parse(raw, source: .spotify)
		XCTAssertEqual(now?.title, "Song | with bar", "a bar in the title does not split it")
		XCTAssertEqual(now?.duration, 215); XCTAssertEqual(now?.position ?? 0, 43.5, accuracy: 0.001)
		XCTAssertEqual(now?.playing, true); XCTAssertNotNil(now?.artworkURL)
		XCTAssertEqual(now?.progress ?? 0, 43.5 / 215, accuracy: 0.001)
	}

	func testMusicAppLineUsesSecondsAndHasNoArtwork() {
		let now = NowPlaying.parse(["paused", "T", "A", "200", "10"].joined(separator: sep), source: .music)
		XCTAssertEqual(now?.duration, 200); XCTAssertEqual(now?.playing, false); XCTAssertNil(now?.artworkURL)
	}

	func testEmptyStoppedOrShortLinesGiveNothing() {
		XCTAssertNil(NowPlaying.parse("", source: .spotify))
		XCTAssertNil(NowPlaying.parse("playing\(sep)x", source: .spotify))
		XCTAssertNil(NowPlaying.parse(["stopped", "T", "A", "1", "1"].joined(separator: sep), source: .music))
		XCTAssertNil(NowPlaying.parse(["playing", "  ", "A", "1", "1"].joined(separator: sep), source: .music), "no title")
		let junk = NowPlaying.parse(["playing", "T", "A", "x", "y", "file:///etc/passwd"].joined(separator: sep), source: .spotify)
		XCTAssertEqual(junk?.duration, 0); XCTAssertEqual(junk?.progress, 0); XCTAssertNil(junk?.artworkURL, "only web addresses")
	}

	func testThePlayingPlayerWinsWhenBothAnswer() {
		let a = NowPlaying.parse(["paused", "A", "x", "1", "0"].joined(separator: sep), source: .spotify)!
		let b = NowPlaying.parse(["playing", "B", "x", "1", "0"].joined(separator: sep), source: .music)!
		XCTAssertEqual(NowPlaying.choose([a, b])?.title, "B")
		XCTAssertEqual(NowPlaying.choose([a])?.title, "A"); XCTAssertNil(NowPlaying.choose([]))
	}

	func testClockText() {
		XCTAssertEqual(clockText(0), "0:00"); XCTAssertEqual(clockText(65), "1:05"); XCTAssertEqual(clockText(1500), "25:00")
		XCTAssertEqual(clockText(3725), "1:02:05"); XCTAssertEqual(clockText(-5), "0:00"); XCTAssertEqual(clockText(0.2), "0:01")
	}

	func testClipboardKeepsNewestFirstWithoutDuplicatesAndCapsTheList() {
		var items: [ClipItem] = []
		items = ClipboardHistory.insert(items, text: "a"); items = ClipboardHistory.insert(items, text: "b")
		items = ClipboardHistory.insert(items, text: "a")
		XCTAssertEqual(items.map(\.text), ["a", "b"])
		for i in 0 ..< 50 { items = ClipboardHistory.insert(items, text: "t\(i)") }
		XCTAssertEqual(items.count, ClipboardHistory.limit); XCTAssertEqual(items.first?.text, "t49")
	}

	func testClipboardIgnoresBlankHugeAndPasswordManagerCopies() {
		XCTAssertEqual(ClipboardHistory.insert([], text: "  \n ").count, 0)
		XCTAssertEqual(ClipboardHistory.insert([], text: String(repeating: "x", count: ClipboardHistory.maxChars + 1)).count, 0)
		XCTAssertEqual(ClipboardHistory.insert([], text: String(repeating: "x", count: ClipboardHistory.maxChars)).count, 1)
		XCTAssertFalse(ClipboardHistory.shouldKeep(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
		XCTAssertTrue(ClipboardHistory.shouldKeep(types: ["public.utf8-plain-text"]))
	}

	func testTodoAddToggleRemoveAndClear() {
		var items = TodoList.add([], title: "  buy milk ")
		XCTAssertEqual(items.map(\.title), ["buy milk"]); XCTAssertEqual(TodoList.add(items, title: "   ").count, 1)
		XCTAssertEqual(TodoList.add([], title: String(repeating: "x", count: 500)).first?.title.count, TodoList.maxTitle)
		items = TodoList.add(items, title: "b")
		items = TodoList.toggle(items, id: items[0].id)
		XCTAssertEqual(TodoList.openCount(items), 1); XCTAssertTrue(items[0].done)
		items = TodoList.clearDone(items); XCTAssertEqual(items.map(\.title), ["b"])
		XCTAssertEqual(TodoList.remove(items, id: items[0].id).count, 0)
		XCTAssertEqual(TodoList.toggle(items, id: UUID()), items, "an unknown id changes nothing")
	}

	func testCountdownTimerRemainingAndDone() {
		let now = Date(timeIntervalSince1970: 1000)
		let t = CountdownTimer(total: 60, endsAt: now.addingTimeInterval(60))
		XCTAssertEqual(t.remaining(now: now.addingTimeInterval(20)), 40); XCTAssertFalse(t.isDone(now: now))
		XCTAssertTrue(t.isDone(now: now.addingTimeInterval(60))); XCTAssertEqual(t.remaining(now: now.addingTimeInterval(500)), 0)
	}

	func testPomodoroRunsFocusThenBreaksAndALongBreakAfterFourRounds() {
		var p = Pomodoro(); var now = Date(timeIntervalSince1970: 0)
		XCTAssertEqual(p.phase, .focus); XCTAssertEqual(p.remaining(now: now), 25 * 60); XCTAssertFalse(p.isRunning)
		var phases: [Pomodoro.Phase] = []
		for _ in 0 ..< 8 {
			p.start(now: now); now = now.addingTimeInterval(p.length)
			XCTAssertTrue(p.finishIfDue(now: now)); phases.append(p.phase)
			XCTAssertFalse(p.isRunning, "it waits for a start after each phase")
			p.start(now: now); now = now.addingTimeInterval(p.length); XCTAssertTrue(p.finishIfDue(now: now))
		}
		XCTAssertEqual(Array(phases.prefix(4)), [.shortBreak, .shortBreak, .shortBreak, .longBreak])
		XCTAssertEqual(p.completedFocus, 8)
	}

	func testPomodoroPauseKeepsTheTimeLeftAndNotDueEarly() {
		var p = Pomodoro(); let t0 = Date(timeIntervalSince1970: 0)
		p.start(now: t0); XCTAssertFalse(p.finishIfDue(now: t0.addingTimeInterval(10)))
		p.pause(now: t0.addingTimeInterval(600)); XCTAssertEqual(p.remaining(now: t0.addingTimeInterval(9999)), 25 * 60 - 600)
		p.start(now: t0.addingTimeInterval(1000)); XCTAssertEqual(p.remaining(now: t0.addingTimeInterval(1000)), 25 * 60 - 600)
		p.skipTest(); XCTAssertEqual(p.phase, .shortBreak)
		p.reset(); XCTAssertEqual(p, Pomodoro())
	}
}

private extension Pomodoro { mutating func skipTest() { advance() } }
