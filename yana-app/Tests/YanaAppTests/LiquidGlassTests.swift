import XCTest
@testable import YanaApp

final class LiquidGlassTests: XCTestCase {
	func testTheWhiteLayerUnderGlassIsStrongEnoughToKeepWhitesWhiteButLeavesTheGlass() {
		XCTAssertGreaterThanOrEqual(LiquidGlass.whiteBacking, 0.5)
		XCTAssertLessThan(LiquidGlass.whiteBacking, 1)
	}

	func testItIsOnOnlyWhenEveryConditionHolds() {
		XCTAssertTrue(LiquidGlass.isActive(enabled: true, osMajor: 26, reduceTransparency: false, rendering: false))
		XCTAssertTrue(LiquidGlass.isActive(enabled: true, osMajor: 27, reduceTransparency: false, rendering: false))
	}

	func testEachConditionAloneSwitchesItOff() {
		XCTAssertFalse(LiquidGlass.isActive(enabled: false, osMajor: 27, reduceTransparency: false, rendering: false), "turned off")
		XCTAssertFalse(LiquidGlass.isActive(enabled: true, osMajor: 25, reduceTransparency: false, rendering: false), "older macOS")
		XCTAssertFalse(LiquidGlass.isActive(enabled: true, osMajor: 14, reduceTransparency: false, rendering: false), "macOS 14")
		XCTAssertFalse(LiquidGlass.isActive(enabled: true, osMajor: 27, reduceTransparency: true, rendering: false), "reduce transparency")
		XCTAssertFalse(LiquidGlass.isActive(enabled: true, osMajor: 27, reduceTransparency: false, rendering: true), "drawing an image")
	}

	func testTheSettingDefaultsToOnAndReadsTheStoredChoice() {
		let name = "yana.tests.glass.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		XCTAssertTrue(LiquidGlass.enabledSetting(d))
		d.set(false, forKey: LiquidGlass.enabledKey)
		XCTAssertFalse(LiquidGlass.enabledSetting(d))
	}

	func testTheSettingsTextExists() {
		for key in ["set.glass", "set.glassOff"] { XCTAssertNotEqual(L(key), key, key) }
	}
}
