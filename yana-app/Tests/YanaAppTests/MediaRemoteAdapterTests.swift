import XCTest
@testable import YanaApp

final class MediaRemoteAdapterTests: XCTestCase {
	private func line(diff: Bool, _ payload: String) -> String { "{\"type\":\"data\",\"diff\":\(diff),\"payload\":\(payload)}" }

	func testAFullPayloadGivesTheTrackWithTimesInSeconds() {
		var state = MediaRemoteState()
		XCTAssertTrue(state.apply(line: line(diff: false, "{\"bundleIdentifier\":\"com.google.Chrome\",\"playing\":true,\"title\":\"Bai hat\",\"artist\":\"Ca si\",\"durationMicros\":200000000,\"elapsedTimeMicros\":50000000,\"timestampEpochMicros\":1000000000000}")))
		let now = state.nowPlaying(at: Date(timeIntervalSince1970: 1_000_000 + 10))
		XCTAssertEqual(now?.title, "Bai hat"); XCTAssertEqual(now?.artist, "Ca si"); XCTAssertEqual(now?.source, .system)
		XCTAssertEqual(now?.duration, 200); XCTAssertEqual(now?.position ?? 0, 60, accuracy: 0.001, "50 s plus 10 s since it was noted")
		XCTAssertEqual(now?.appBundleID, "com.google.Chrome"); XCTAssertTrue(now?.playing == true)
	}

	func testAPausedTrackKeepsItsPositionAndNeverRunsPastItsEnd() {
		var state = MediaRemoteState()
		state.apply(line: line(diff: false, "{\"playing\":false,\"title\":\"T\",\"durationMicros\":100000000,\"elapsedTimeMicros\":30000000,\"timestampEpochMicros\":1000000000000}"))
		XCTAssertEqual(state.nowPlaying(at: Date(timeIntervalSince1970: 9_999_999))?.position, 30)
		state.apply(line: line(diff: true, "{\"playing\":true}"))
		XCTAssertEqual(state.nowPlaying(at: Date(timeIntervalSince1970: 9_999_999))?.position, 100, "capped at the duration")
	}

	func testADiffUpdatesOnlyItsKeysAndANullRemovesOne() {
		var state = MediaRemoteState()
		state.apply(line: line(diff: false, "{\"playing\":true,\"title\":\"A\",\"artist\":\"X\"}"))
		state.apply(line: line(diff: true, "{\"title\":\"B\"}"))
		XCTAssertEqual(state.nowPlaying()?.title, "B"); XCTAssertEqual(state.nowPlaying()?.artist, "X")
		state.apply(line: line(diff: true, "{\"artist\":null}"))
		XCTAssertEqual(state.nowPlaying()?.artist, "")
		state.apply(line: line(diff: false, "{}"))
		XCTAssertNil(state.nowPlaying(), "an empty payload means nothing is playing")
	}

	func testGarbageAndOtherLinesAreIgnoredAndTitleIsRequired() {
		var state = MediaRemoteState()
		XCTAssertFalse(state.apply(line: "")); XCTAssertFalse(state.apply(line: "not json"))
		XCTAssertFalse(state.apply(line: "{\"type\":\"other\",\"payload\":{}}"))
		state.apply(line: line(diff: false, "{\"playing\":true,\"title\":\"   \"}"))
		XCTAssertNil(state.nowPlaying(), "media without a title is not shown")
	}

	func testArtworkComesFromBase64ButAnAbsurdlyLargeOneIsDropped() {
		var state = MediaRemoteState()
		let png = Data([1, 2, 3, 4]).base64EncodedString()
		state.apply(line: line(diff: false, "{\"playing\":true,\"title\":\"T\",\"artworkData\":\"\(png)\"}"))
		XCTAssertEqual(state.nowPlaying()?.artworkData, Data([1, 2, 3, 4]))
		let huge = String(repeating: "A", count: 4_000_004)
		state.apply(line: line(diff: false, "{\"playing\":true,\"title\":\"T\",\"artworkData\":\"\(huge)\"}"))
		XCTAssertNil(state.nowPlaying()?.artworkData)
	}

	func testTheFilesAreFoundByWalkingUpFromTheProgramAndAMissingFileMeansNoAdapter() throws {
		let temp = FileManager.default.temporaryDirectory.appendingPathComponent("mra-\(UUID().uuidString)")
		let dir = temp.appendingPathComponent("Resources/MediaRemote")
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: temp) }
		XCTAssertNil(MediaRemoteAdapter.paths(in: dir), "empty folder")
		for name in ["mediaremote-adapter.pl", "MediaRemoteAdapter.framework", "MediaRemoteAdapterTestClient"] {
			FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data())
		}
		XCTAssertNotNil(MediaRemoteAdapter.paths(in: dir))
		let exe = temp.appendingPathComponent(".build/arm64/debug/YanaApp")
		XCTAssertEqual(MediaRemoteAdapter.locate(bundle: nil, executable: exe, environment: [:])?.script.lastPathComponent, "mediaremote-adapter.pl")
		XCTAssertNil(MediaRemoteAdapter.locate(bundle: nil, executable: URL(fileURLWithPath: "/nowhere/x/y/App"), environment: [:]))
	}

	func testCommandNumbersAndTheCommandLine() {
		XCTAssertEqual(MediaRemoteAdapter.commandID(.playPause), 2); XCTAssertEqual(MediaRemoteAdapter.commandID(.next), 4)
		XCTAssertEqual(MediaRemoteAdapter.commandID(.previous), 5)
		let paths = MediaRemoteAdapter.Paths(script: URL(fileURLWithPath: "/a/s.pl"), framework: URL(fileURLWithPath: "/a/F.framework"), testClient: URL(fileURLWithPath: "/a/T"))
		XCTAssertEqual(MediaRemoteAdapter.arguments(paths, ["send", "2"]), ["/a/s.pl", "/a/F.framework", "send", "2"])
		XCTAssertEqual(MediaRemoteAdapter.perl.path, "/usr/bin/perl")
	}
}
