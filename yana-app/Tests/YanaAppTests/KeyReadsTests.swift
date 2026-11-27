import XCTest
@testable import YanaApp

final class KeyReadsTests: XCTestCase {
	@MainActor
	func testAReadThatWaitsLeavesTheMainThreadFree() async {
		let answer = DispatchSemaphore(value: 0)
		let reading = Task { await KeyReads.read("openai") { _ in
			XCTAssertFalse(Thread.isMainThread)
			// Stands for the permission question: answered only by work that runs on the main thread.
			return answer.wait(timeout: .now() + 5) == .success ? "key" : nil
		} }
		await Task.yield()
		DispatchQueue.main.async { answer.signal() }
		let value = await reading.value
		XCTAssertEqual(value, "key")
	}

	func testReadsComeOneAtATimeAndKeepOddNames() async {
		for name in ["", "custom:có dấu", String(repeating: "a", count: 65536), "a\u{0}b"] {
			let value = await KeyReads.read(name) { $0 }
			XCTAssertEqual(value, name)
		}
		let none = await KeyReads.read("missing") { _ in nil }
		XCTAssertNil(none)
	}
}
