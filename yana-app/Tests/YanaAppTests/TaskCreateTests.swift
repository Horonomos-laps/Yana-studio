import XCTest
@testable import YanaApp

final class TaskCreateTests: XCTestCase {
	func testATypedNameIsTrimmedAndKeptOnOneLine() {
		XCTAssertEqual(TaskDraft.clean("  Viết test  cho   trang Sử dụng \n"), "Viết test cho trang Sử dụng")
		XCTAssertEqual(TaskDraft.clean("dòng một\ndòng hai"), "dòng một dòng hai")
	}

	func testNothingTypedGivesNothing() {
		for raw in ["", "   ", "\n\n", "---", " -  - "] { XCTAssertNil(TaskDraft.clean(raw), raw.debugDescription) }
	}

	func testLeadingDashesAreDroppedSoTheyAreNotReadAsAnOption() {
		XCTAssertEqual(TaskDraft.clean("--json"), "json")
		XCTAssertEqual(TaskDraft.clean("-x sửa lỗi"), "x sửa lỗi")
		XCTAssertEqual(TaskDraft.clean("sửa lỗi --nhanh"), "sửa lỗi --nhanh", "dashes inside are fine")
	}

	func testALongNameIsCutAtTheLimit() {
		let cut = TaskDraft.clean(String(repeating: "a", count: 5000))
		XCTAssertEqual(cut?.count, TaskDraft.maxLength)
		XCTAssertEqual(TaskDraft.clean(String(repeating: "a", count: 65_536))?.count, TaskDraft.maxLength)
	}

	func testControlAndOddCharactersSurvive() {
		XCTAssertEqual(TaskDraft.clean("tìm lỗi ở '; rm -rf /"), "tìm lỗi ở '; rm -rf /", "passed as one argument, never through a shell")
		XCTAssertNotNil(TaskDraft.clean("🔥 khẩn"))
	}

	func testAnEmptyNameGivesAMessageInsteadOfRunningAnything() {
		XCTAssertEqual(RtClient.createTask(name: "   "), L("tasks.emptyName"))
	}

	func testTheStringsExistInAllThreeLanguages() {
		for key in ["tasks.addPrompt", "tasks.add", "tasks.emptyName", "tasks.createFailed", "tasks.noTasks"] {
			let row = allStringRows.first { $0.key == key }
			XCTAssertNotNil(row, key)
			if let row { XCTAssertFalse(row.vi.isEmpty || row.en.isEmpty || row.ko.isEmpty, key) }
		}
	}
}
