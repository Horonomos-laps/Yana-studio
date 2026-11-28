import XCTest
@testable import YanaApp

final class MenuBarTests: XCTestCase {
	private let english = Locale(identifier: "en")

	func testCpuPercentIsTheBusyShareBetweenTwoReadings() {
		let old = CpuTicks(busy: 100, total: 1000)
		XCTAssertEqual(SystemStats.cpuPercent(from: old, to: CpuTicks(busy: 125, total: 1100)), 25)
		XCTAssertNil(SystemStats.cpuPercent(from: old, to: old))
		XCTAssertNil(SystemStats.cpuPercent(from: old, to: CpuTicks(busy: 50, total: 1100)), "wrapped counter")
	}

	func testMemoryUsedNeverGoesBelowWiredAndCompressed() {
		XCTAssertEqual(SystemStats.memoryUsed(internalPages: 10, purgeablePages: 4, wiredPages: 3,
		                                      compressedPages: 1, pageSize: 100), 1000)
		XCTAssertEqual(SystemStats.memoryUsed(internalPages: 1, purgeablePages: 4, wiredPages: 3,
		                                      compressedPages: 1, pageSize: 100), 400)
	}

	func testHistoryKeepsTheLastReadingsAndSkipsMissingOnes() {
		var history: [Double] = []
		for value in 0 ..< 40 { history = SystemStats.appended(history, Double(value)) }
		XCTAssertEqual(history.count, SystemStats.historyLength)
		XCTAssertEqual(history.last, 39)
		XCTAssertEqual(SystemStats.appended(history, nil), history)
	}

	func testMissingValuesShowAsADashNotZero() {
		XCTAssertEqual(SystemStats.percent(nil), "—")
		XCTAssertEqual(SystemStats.memory(nil, locale: english), "—")
		XCTAssertEqual(SystemStats.diskFree(nil, locale: english), "—")
		XCTAssertEqual(SystemStats.diskFree(Capacity(used: 2, total: 1), locale: english), "—")
		XCTAssertNil(SystemStats.degrees(nil))
	}

	func testTextForRealValues() {
		let memory = Capacity(used: 12_025_908_429, total: 17_179_869_184)
		XCTAssertEqual(SystemStats.memory(memory, locale: english), "11.2 / 16 GB")
		XCTAssertEqual(SystemStats.memory(memory, locale: Locale(identifier: "vi")), "11,2 / 16 GB")
		XCTAssertEqual(SystemStats.diskFree(Capacity(used: 355_000_000_000, total: 460_000_000_000), locale: english), "105 GB")
		XCTAssertEqual(SystemStats.percent(7.6), "8%")
		XCTAssertEqual(SystemStats.degrees(47.6), "48°C")
	}

	func testChipTemperatureAveragesOnlyPlausibleDieSensors() {
		let readings: [(name: String, celsius: Double)] = [
			("PMU tdie1", 40), ("PMU tdie2", 50), ("PMU tdie3", -30), ("PMU tdie4", 900), ("gas gauge battery", 20),
		]
		XCTAssertEqual(SystemStats.chipTemperature(readings), 45)
		XCTAssertNil(SystemStats.chipTemperature([("gas gauge battery", 20)]))
		XCTAssertNil(SystemStats.chipTemperature([]))
	}

	func testTheDockIconHidesOnlyWhenTheMenuBarItemCanReplaceIt() {
		XCTAssertTrue(BackgroundMode.hidesDockIcon(menuBarOn: true, keepDockIcon: false))
		XCTAssertFalse(BackgroundMode.hidesDockIcon(menuBarOn: true, keepDockIcon: true))
		XCTAssertFalse(BackgroundMode.hidesDockIcon(menuBarOn: false, keepDockIcon: false))
	}

	func testThisMacAnswersTheBasicReadings() {
		XCTAssertNotNil(SystemProbe.cpuTicks())
		let memory = SystemProbe.memory()
		XCTAssertNotNil(memory)
		XCTAssertLessThanOrEqual(memory?.used ?? .max, memory?.total ?? 0)
		XCTAssertNotNil(SystemProbe.disk())
	}

	func testAppTreeFollowsDescendantsOnly() {
		let parents: [Int32: Int32] = [10: 1, 11: 10, 12: 11, 20: 1, 30: 30]
		XCTAssertEqual(AppStats.tree(roots: [10], parents: parents), [10, 11, 12])
		XCTAssertEqual(AppStats.tree(roots: [], parents: parents), [])
		XCTAssertEqual(AppStats.tree(roots: [30], parents: parents), [30])
	}

	func testAppUseCountsOnlyProcessesSeenTwice() {
		let before = [Int32(1): ProcessUse(cpuNanos: 0, bytes: 5)]
		let now = [Int32(1): ProcessUse(cpuNanos: 1_000_000_000, bytes: 10), 2: ProcessUse(cpuNanos: 9_000_000_000, bytes: 20)]
		XCTAssertEqual(AppStats.use(now: now, before: before, seconds: 2, cores: 10), AppUse(cpu: 5, bytes: 30))
		XCTAssertNil(AppStats.use(now: now, before: nil, seconds: 0, cores: 10).cpu)
	}

	func testAppSizeAndSessionCounts() {
		XCTAssertEqual(AppStats.size(188_743_680, locale: english), "180 MB")
		XCTAssertEqual(AppStats.size(1_610_612_736, locale: english), "1.5 GB")
		func session(_ id: String, _ state: AgentSession.State, _ app: String?) -> AgentSession {
			AgentSession(id: id, tool: .claude, cwd: "/p", state: state, message: nil, updated: Date(), appBundleID: app)
		}
		let all = [session("a", .working, "x"), session("b", .waiting, "x"), session("c", .done, "x"),
		           session("d", .working, "y"), session("e", .working, nil)]
		let counts = AppStats.sessions(all, app: "x")
		XCTAssertEqual(counts.working, 1)
		XCTAssertEqual(counts.waiting, 1)
	}

	func testThisProcessReportsItsOwnUse() {
		let me = ProcessInfo.processInfo.processIdentifier
		XCTAssertNotNil(AppProbe.parents()[me])
		XCTAssertGreaterThan(AppProbe.use(of: [me])[me]?.bytes ?? 0, 0)
	}

	func testRainbowFramesCoverOneLoopAndStayInRange() {
		XCTAssertEqual(MenuBarLabel.frames.count, MenuBarLabel.frameCount)
		let loop = RainbowText.loopSeconds, last = MenuBarLabel.frameCount - 1
		for always in [true, false] {
			XCTAssertEqual(MenuBarLabel.frame(at: 0, always: always), 0)
			XCTAssertEqual(MenuBarLabel.frame(at: loop - 0.001, always: always), last)
			XCTAssertEqual(MenuBarLabel.frame(at: loop, always: always), 0)
			for time in [-7.3, 0.01, 12_345.678, 1e9] {
				XCTAssertTrue((0 ... last).contains(MenuBarLabel.frame(at: time, always: always)), "time \(time)")
			}
		}
	}

	func testClosedPanelColoursRestBetweenLoops() {
		let loop = RainbowText.loopSeconds, period = loop + MenuBarLabel.restSeconds
		XCTAssertEqual(MenuBarLabel.frame(at: loop + 1.5, always: false), 0, "resting")
		XCTAssertNotEqual(MenuBarLabel.frame(at: loop + 1.5, always: true), 0, "open panel keeps running")
		XCTAssertEqual(MenuBarLabel.frame(at: period + 1.5, always: false), MenuBarLabel.frame(at: 1.5, always: false))
	}

	func testEveryStringExistsInAllLanguages() {
		for row in menuBarRows {
			XCTAssertFalse(row.vi.isEmpty); XCTAssertFalse(row.en.isEmpty); XCTAssertFalse(row.ko.isEmpty)
		}
	}
}
