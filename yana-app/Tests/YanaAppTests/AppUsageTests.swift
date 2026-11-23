import XCTest
@testable import YanaApp

final class AppUsageTests: XCTestCase {
	private func date(_ s: String) -> Date {
		let f = ISO8601DateFormatter()
		return f.date(from: s)!
	}

	private func chat(_ id: String, model: String?, updated: String, lines: [SavedLine]) -> SavedChat {
		SavedChat(id: id, title: "chat \(id)", updated: date(updated), provider: "anthropic", model: model, lines: lines)
	}

	private func reply(_ i: Int, _ o: Int, at: String? = nil) -> SavedLine {
		var l = SavedLine(user: false, text: "ok", error: nil, inputTokens: i, outputTokens: o)
		l.at = at.map(date)
		return l
	}

	func testOnlyRepliesWithTokensCount() {
		let c = chat("a", model: "m1", updated: "2026-11-20T10:00:00Z", lines: [
			SavedLine(user: true, text: "hi", error: nil, inputTokens: 999, outputTokens: 999),
			reply(10, 5), reply(0, 0)])
		let e = AppUsage.entries(from: [c])
		XCTAssertEqual(e.count, 1, "a question is not a spend, and a reply with no numbers is not an entry")
		XCTAssertEqual(e[0].tokens, 15)
	}

	func testAReplyCountsOnItsOwnDayAndAnOldOneOnTheChatsDay() {
		let c = chat("a", model: "m1", updated: "2026-11-20T10:00:00Z", lines: [
			reply(1, 1, at: "2026-11-18T23:59:00Z"), reply(2, 2)])
		let e = AppUsage.entries(from: [c])
		XCTAssertEqual(e.map(\.day), ["2026-11-18", "2026-11-20"])
	}

	func testTheDayIsUTCLikeTheLedger() {
		let c = chat("a", model: nil, updated: "2026-11-20T23:30:00Z", lines: [reply(1, 1)])
		XCTAssertEqual(AppUsage.entries(from: [c])[0].day, "2026-11-20")
	}

	func testAChatWithoutAModelFallsBackToItsProvider() {
		let c = chat("a", model: nil, updated: "2026-11-20T10:00:00Z", lines: [reply(1, 1)])
		XCTAssertEqual(AppUsage.entries(from: [c])[0].model, "anthropic")
	}

	func testTotalsByDayModelAndChat() {
		let a = chat("a", model: "m1", updated: "2026-11-20T10:00:00Z", lines: [reply(10, 5), reply(20, 10)])
		let b = chat("b", model: "m2", updated: "2026-11-21T10:00:00Z", lines: [reply(100, 50)])
		let e = AppUsage.entries(from: [a, b])
		let t = AppUsage.total(e)
		XCTAssertEqual(t.replies, 3); XCTAssertEqual(t.input, 130); XCTAssertEqual(t.output, 65)
		XCTAssertEqual(AppUsage.byDay(e), ["2026-11-20": 45, "2026-11-21": 150])
		XCTAssertEqual(AppUsage.byModel(e).map(\.model), ["m2", "m1"], "most tokens first")
		XCTAssertEqual(AppUsage.topChats(e, limit: 1).first?.chat, "chat b")
	}

	func testNoChatsGivesNothing() {
		XCTAssertTrue(AppUsage.entries(from: []).isEmpty)
		XCTAssertEqual(AppUsage.total([]).replies, 0)
	}

	func testTheTimeOfAReplySurvivesSavingAndLoading() throws {
		let line = reply(3, 4, at: "2026-11-19T08:00:00Z")
		// The store writes and reads dates as ISO 8601 (ChatHistory.swift), so the test does the same.
		let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
		let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
		let back = try decoder.decode(SavedLine.self, from: encoder.encode(line))
		XCTAssertEqual(back.at, line.at)
		// A chat written before the time existed still loads.
		let old = #"{"user":false,"text":"x","inputTokens":1,"outputTokens":2}"#
		XCTAssertNil(try decoder.decode(SavedLine.self, from: Data(old.utf8)).at)
	}
}
