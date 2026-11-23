import AppKit
import XCTest
@testable import YanaApp

final class ShortcutTests: XCTestCase {
	private func freshStore() -> ShortcutStore {
		let name = "yana.tests.sc.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return ShortcutStore(defaults: d)
	}

	func testDisplayUsesMacOrder() {
		XCTAssertEqual(Shortcut(key: "e", command: true, shift: true).display, "⇧⌘E")
		XCTAssertEqual(Shortcut(key: "s", command: true, control: true).display, "⌃⌘S")
		XCTAssertEqual(Shortcut(key: "`", control: true).display, "⌃`")
		XCTAssertEqual(Shortcut(key: "return", command: true).display, "⌘↩")
	}

	func testKeyPressBecomesAShortcut() {
		let s = Shortcut.from(characters: "K", keyCode: 40, flags: [.command, .shift])
		XCTAssertEqual(s, Shortcut(key: "k", command: true, shift: true))
	}

	func testNamedKeysAreRecognisedByKeyCode() {
		XCTAssertEqual(Shortcut.from(characters: "\r", keyCode: 36, flags: [.command])?.key, "return")
		XCTAssertEqual(Shortcut.from(characters: "", keyCode: 126, flags: [.option])?.key, "up")
	}

	func testNonPrintableOrMultiCharacterPressesAreRejected() {
		XCTAssertNil(Shortcut.from(characters: "", keyCode: 55, flags: [.command]))
		XCTAssertNil(Shortcut.from(characters: "ab", keyCode: 0, flags: [.command]))
		XCTAssertNil(Shortcut.from(characters: "\u{7f}", keyCode: 51, flags: [.command]))
	}

	func testDefaultsMatchTheMenuTheAppAlwaysHad() {
		let store = freshStore()
		XCTAssertEqual(store.effective(.newChat)?.display, "⌘N")
		XCTAssertEqual(store.effective(.openStudio)?.display, "⇧⌘E")
		XCTAssertEqual(store.effective(.terminal)?.display, "⌃`")
		XCTAssertEqual(store.effective(.page3)?.display, "⌘3")
		XCTAssertFalse(ShortcutAction.allCases.contains { store.isCustomized($0) })
	}

	func testNoTwoDefaultsCollideAndNoneIsReserved() {
		let all = ShortcutAction.allCases.map(\.defaultShortcut)
		XCTAssertEqual(Set(all).count, all.count)
		XCTAssertTrue(all.allSatisfy { !ShortcutStore.reserved.contains($0) && $0.hasUsableModifier })
	}

	func testAssignSavesAndSurvivesReload() {
		let name = "yana.tests.sc.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		let store = ShortcutStore(defaults: d)
		XCTAssertEqual(store.assign(Shortcut(key: "j", command: true), to: .newChat), .ok)
		XCTAssertEqual(ShortcutStore(defaults: d).effective(.newChat)?.display, "⌘J")
		XCTAssertTrue(store.isCustomized(.newChat))
	}

	func testShiftAloneOrBareKeyIsRefused() {
		let store = freshStore()
		XCTAssertEqual(store.assign(Shortcut(key: "j", shift: true), to: .newChat), .needsModifier)
		XCTAssertEqual(store.assign(Shortcut(key: "j"), to: .newChat), .needsModifier)
		XCTAssertEqual(store.effective(.newChat)?.display, "⌘N")
	}

	func testSystemShortcutsCannotBeTaken() {
		let store = freshStore()
		XCTAssertEqual(store.assign(Shortcut(key: "q", command: true), to: .newChat), .reserved)
		XCTAssertEqual(store.assign(Shortcut(key: "t", command: true), to: .terminal), .reserved)
	}

	func testConflictIsReportedAndNothingChanges() {
		let store = freshStore()
		XCTAssertEqual(store.assign(Shortcut(key: "o", command: true), to: .newChat), .conflict(.openFolder))
		XCTAssertEqual(store.effective(.newChat)?.display, "⌘N")
		XCTAssertEqual(store.effective(.openFolder)?.display, "⌘O")
	}

	func testTakingMovesTheShortcutAndLeavesTheOtherUnassigned() {
		let store = freshStore()
		XCTAssertEqual(store.assign(Shortcut(key: "o", command: true), to: .newChat, taking: true), .ok)
		XCTAssertEqual(store.effective(.newChat)?.display, "⌘O")
		XCTAssertNil(store.effective(.openFolder))
		XCTAssertTrue(store.isCustomized(.openFolder))
	}

	func testClearResetAndResetAll() {
		let store = freshStore()
		store.clear(.settings)
		XCTAssertNil(store.effective(.settings))
		store.reset(.settings)
		XCTAssertEqual(store.effective(.settings)?.display, "⌘,")
		store.assign(Shortcut(key: "j", command: true), to: .newChat)
		store.clear(.terminal)
		store.resetAll()
		XCTAssertFalse(ShortcutAction.allCases.contains { store.isCustomized($0) })
	}

	func testAClearedShortcutCanBeTakenByAnotherAction() {
		let store = freshStore()
		store.clear(.openFolder)
		XCTAssertEqual(store.assign(Shortcut(key: "o", command: true), to: .newChat), .ok)
	}

	func testReassigningTheSameShortcutToTheSameActionIsNotAConflict() {
		let store = freshStore()
		XCTAssertEqual(store.assign(Shortcut(key: "n", command: true), to: .newChat), .ok)
		XCTAssertFalse(store.isCustomized(.newChat))
	}

	func testEveryActionMapsToAMenuAction() {
		for action in ShortcutAction.allCases { XCTAssertNotNil(MenuAction(rawValue: action.rawValue), action.rawValue) }
	}
}
