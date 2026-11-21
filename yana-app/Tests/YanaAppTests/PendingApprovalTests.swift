import XCTest
@testable import YanaApp

// The shape below is what `yana-rt authority pending-approvals --json` printed on 2026-11-21 (long fields cut).
// With this entry in the list the Overview and Tool approvals pages showed a red "could not read" error, because
// the model asked for an "id" field and the real one is "approval_id".
final class PendingApprovalTests: XCTestCase {
	private func decode(_ json: String) throws -> [PendingApproval] {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([PendingApproval].self, from: Data(json.utf8))
	}

	private let decided = """
	[{"approval_id":"41f0aeafefc3","context":{"origin":"Desktop","human_initiated":true},"model":"llama3.2","system":null,
	"messages":[{"role":"user","content":"hi"}],"tool_rounds_completed":0,
	"pending_call":{"id":"call_1","name":"write_file","arguments_json":"{}"},
	"authority_reason":"yana_control_plane: capability 'file.write' requires explicit human approval",
	"created_at":"2026-11-07T00:33:28Z","expires_at":"2026-11-07T01:03:28Z","resolved":true,"decision":false,"decided_by":"human:test"}]
	"""

	func testTheRealShapeDecodesInsteadOfFailing() throws {
		let list = try decode(decided)
		XCTAssertEqual(list.count, 1)
		XCTAssertEqual(list[0].id, "41f0aeafefc3")
	}

	func testADecidedEntryIsNotCountedAsWaiting() throws {
		XCTAssertFalse(try decode(decided)[0].isWaiting)
		let open = decided.replacingOccurrences(of: "\"resolved\":true", with: "\"resolved\":false")
		XCTAssertTrue(try decode(open)[0].isWaiting)
	}

	func testTheSummaryNamesTheToolAndTheReason() throws {
		XCTAssertEqual(try decode(decided)[0].summary, "write_file: capability 'file.write' requires explicit human approval")
	}

	func testAnEntryWithOnlyAnIdStillReads() throws {
		let list = try decode("[{\"approval_id\":\"abc\"}]")
		XCTAssertEqual(list[0].summary, "")
		XCTAssertTrue(list[0].isWaiting)
	}

	func testAnEmptyListStillReads() throws {
		XCTAssertTrue(try decode("[]").isEmpty)
	}
}
