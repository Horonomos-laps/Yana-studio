import XCTest
@testable import YanaApp

final class ExtraSettingsTests: XCTestCase {
	private func defaults() -> UserDefaults {
		let name = "yana.tests.extra.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return d
	}

	// MARK: code font

	func testTheCodeSizeIsKeptInRange() {
		XCTAssertEqual(CodeFont.clampedSize(3), CodeFont.sizeRange.lowerBound)
		XCTAssertEqual(CodeFont.clampedSize(99), CodeFont.sizeRange.upperBound)
		XCTAssertEqual(CodeFont.clampedSize(13.5), 13.5)
		XCTAssertTrue(CodeFont.sizeRange.contains(CodeFont.defaultSize))
	}

	func testOnlyInstalledFontsAreOffered() {
		for choice in CodeFont.choices { XCTAssertNotNil(NSFont(name: choice.id, size: 12), choice.id) }
		XCTAssertFalse(CodeFont.choices.isEmpty, "Menlo and Monaco ship with macOS")
	}

	// MARK: notifications

	func testTheOldSwitchStillMeansNothingIsSentWhenOff() {
		let prefs = NotifyPrefs(enabled: false)
		XCTAssertFalse(prefs.shouldNotify(appActive: false, elapsed: 999, needsPerson: true))
		XCTAssertFalse(prefs.shouldNotify(appActive: false, elapsed: 999, needsPerson: false))
	}

	func testNothingIsSentWhileTheAppIsInFront() {
		XCTAssertFalse(NotifyPrefs().shouldNotify(appActive: true, elapsed: 999, needsPerson: true))
	}

	func testAFinishedTurnNeedsItsSwitchAndEnoughTime() {
		let prefs = NotifyPrefs(minSeconds: 30)
		XCTAssertFalse(prefs.shouldNotify(appActive: false, elapsed: 10, needsPerson: false))
		XCTAssertTrue(prefs.shouldNotify(appActive: false, elapsed: 30, needsPerson: false))
		XCTAssertFalse(NotifyPrefs(onDone: false).shouldNotify(appActive: false, elapsed: 999, needsPerson: false))
		XCTAssertTrue(NotifyPrefs(minSeconds: 0).shouldNotify(appActive: false, elapsed: 0, needsPerson: false), "every time")
	}

	func testAWaitForApprovalFollowsOnlyItsOwnSwitch() {
		XCTAssertTrue(NotifyPrefs(onDone: false).shouldNotify(appActive: false, elapsed: 0, needsPerson: true))
		XCTAssertFalse(NotifyPrefs(onApproval: false).shouldNotify(appActive: false, elapsed: 999, needsPerson: true))
	}

	func testPreferencesReadFromDefaultsWithTheOldDefaultsWhenNothingIsStored() {
		let d = defaults()
		XCTAssertEqual(NotifyPrefs.current(d), NotifyPrefs())
		d.set(false, forKey: Notifier.defaultsKey); d.set(60.0, forKey: NotifyPrefs.minSecondsKey); d.set(false, forKey: NotifyPrefs.soundKey)
		let read = NotifyPrefs.current(d)
		XCTAssertFalse(read.enabled); XCTAssertEqual(read.minSeconds, 60); XCTAssertFalse(read.sound)
		XCTAssertTrue(read.onDone && read.onApproval)
	}

	func testTheDefaultMinimumIsOneOfTheChoices() {
		XCTAssertTrue(NotifyPrefs.minChoices.contains(NotifyPrefs.defaultMinSeconds))
	}

	// MARK: keeping the Mac awake

	func testTheMacIsHeldAwakeOnlyWhileWorkingAndOnlyWhenAsked() {
		XCTAssertTrue(SleepGuard.shouldHold(enabled: true, running: true))
		XCTAssertFalse(SleepGuard.shouldHold(enabled: true, running: false))
		XCTAssertFalse(SleepGuard.shouldHold(enabled: false, running: true))
	}

	@MainActor
	func testTheHoldIsTakenAndReleasedForReal() {
		let guardian = SleepGuard()
		guardian.update(enabled: true, running: true)
		XCTAssertTrue(guardian.isHolding)
		guardian.update(enabled: true, running: true)
		XCTAssertTrue(guardian.isHolding, "asking twice holds once")
		guardian.update(enabled: true, running: false)
		XCTAssertFalse(guardian.isHolding)
		guardian.update(enabled: true, running: true)
		guardian.update(enabled: false, running: true)
		XCTAssertFalse(guardian.isHolding, "switching it off lets go at once")
	}

	// MARK: sections and strings

	func testTheTwoNewSectionsAreInTheListWithTheirOwnNames() {
		XCTAssertTrue(SettingsSection.allCases.contains(.appearance))
		XCTAssertTrue(SettingsSection.allCases.contains(.notifications))
		for section in [SettingsSection.appearance, .notifications] {
			XCTAssertNotEqual(section.title, "set.section.\(section.rawValue)")
			XCTAssertNotEqual(section.subtitle, "set.about.\(section.rawValue)")
		}
		XCTAssertTrue(SettingsSection.matching("thong bao").contains(.notifications), "found without accents")
		XCTAssertTrue(SettingsSection.matching("phong chu").contains(.appearance))
	}

	func testEveryNewStringExistsInAllThreeLanguages() {
		for row in extraSettingsRows { XCTAssertFalse(row.vi.isEmpty || row.en.isEmpty || row.ko.isEmpty, row.key) }
		XCTAssertEqual(Set(allStringRows.map(\.key)).count, allStringRows.count, "no key defined twice")
	}
}
