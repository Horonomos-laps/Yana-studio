import XCTest
@testable import YanaApp

final class YanaRunTests: XCTestCase {
	private func line(_ role: ChatLine.Role, _ text: String, ask: ApprovalAsk? = nil, tokens: (Int, Int) = (0, 0)) -> ChatLine {
		var l = ChatLine(role: role, text: text)
		l.approval = ask; l.inputTokens = tokens.0; l.outputTokens = tokens.1
		return l
	}

	func testAnEmptyChatIsIdle() {
		let run = YanaRun.make(lines: [], running: false)
		XCTAssertEqual(run, YanaRun()); XCTAssertFalse(run.isActive)
	}

	func testWhileTheReplyIsWrittenItIsWorkingWithTheLastQuestionAndAnswer() {
		let lines = [line(.user, "first"), line(.assistant, "old answer"), line(.user, "second\nquestion"), line(.assistant, "")]
		let run = YanaRun.make(lines: lines, running: true)
		XCTAssertEqual(run.state, .working); XCTAssertEqual(run.question, "second question", "one line, no breaks")
		XCTAssertEqual(run.reply, "old answer", "an empty reply being started is skipped")
	}

	func testAnOpenApprovalCardMeansWaitingEvenWhenNothingIsRunning() {
		let ask = ApprovalAsk(id: "a1", capability: "shell.run", reason: "r")
		let run = YanaRun.make(lines: [line(.user, "do it"), line(.assistant, "", ask: ask)], running: false)
		XCTAssertEqual(run.state, .waiting); XCTAssertEqual(run.waitingFor, "shell.run"); XCTAssertEqual(run.askCount, 1)
	}

	func testADecidedCardIsNotWaitingAnymore() {
		var ask = ApprovalAsk(id: "a1", capability: "shell.run", reason: "r"); ask.decided = true
		let run = YanaRun.make(lines: [line(.assistant, "", ask: ask)], running: false)
		XCTAssertEqual(run.state, .idle); XCTAssertNil(run.waitingFor); XCTAssertEqual(run.askCount, 1)
	}

	func testTokensAreSummedAcrossTheChat() {
		let run = YanaRun.make(lines: [line(.assistant, "a", tokens: (100, 20)), line(.assistant, "b", tokens: (1500, 300))], running: false)
		XCTAssertEqual(run.inputTokens, 1600); XCTAssertEqual(run.outputTokens, 320)
	}

	func testLongTextIsCutWithAnEllipsisAndShortNumbersFitAChip() {
		let long = String(repeating: "x", count: 500)
		let run = YanaRun.make(lines: [line(.user, long), line(.assistant, long)], running: false)
		XCTAssertEqual(run.question.count, YanaRun.maxQuestion); XCTAssertTrue(run.question.hasSuffix("…"))
		XCTAssertEqual(run.reply.count, YanaRun.maxReply)
		XCTAssertEqual(YanaRun.short(950), "950"); XCTAssertEqual(YanaRun.short(1500), "1.5k"); XCTAssertEqual(YanaRun.short(25_000), "25k")
	}
}
