import Foundation

// Reading what any app is playing, system-wide. macOS 15.4 and later no longer let an ordinary app read "now playing",
// but /usr/bin/perl is allowed to, and the third-party MediaRemote Adapter (BSD-3, bundled unchanged in
// Resources/MediaRemote, see its README) is a script that perl runs to print the information as JSON lines. Yana only
// starts it, reads its lines and sends it commands. This file holds the pure parts: where the files are, the arguments,
// and turning the lines into a NowPlaying. The process handling is in MusicStore.

enum MediaRemoteAdapter {
	struct Paths: Equatable {
		let script: URL, framework: URL, testClient: URL
	}

	static let perl = URL(fileURLWithPath: "/usr/bin/perl")
	// Microseconds instead of dates, so the numbers need no parsing of date formats; a short debounce merges bursts.
	static let streamOptions = ["--micros", "--debounce=80"]

	static func paths(in directory: URL) -> Paths? {
		let script = directory.appendingPathComponent("mediaremote-adapter.pl")
		let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework")
		let client = directory.appendingPathComponent("MediaRemoteAdapterTestClient")
		let files = FileManager.default
		guard files.fileExists(atPath: script.path), files.fileExists(atPath: framework.path), files.fileExists(atPath: client.path)
		else { return nil }
		return Paths(script: script, framework: framework, testClient: client)
	}

	// In the packaged app the files are in its Resources folder. In a development build they are found by walking up from
	// the program toward the project's Resources/MediaRemote, or from the folder named by YANA_MEDIAREMOTE_DIR.
	static func locate(bundle: URL? = Bundle.main.resourceURL, executable: URL = URL(fileURLWithPath: CommandLine.arguments[0]),
	                   environment: [String: String] = ProcessInfo.processInfo.environment) -> Paths? {
		var candidates: [URL] = []
		if let forced = environment["YANA_MEDIAREMOTE_DIR"] { candidates.append(URL(fileURLWithPath: forced)) }
		if let bundle { candidates.append(bundle.appendingPathComponent("MediaRemote")) }
		var up = executable.deletingLastPathComponent()
		for _ in 0 ..< 6 {
			candidates.append(up.appendingPathComponent("Resources/MediaRemote"))
			up = up.deletingLastPathComponent()
		}
		return candidates.lazy.compactMap { paths(in: $0) }.first
	}

	static func arguments(_ paths: Paths, _ rest: [String]) -> [String] { [paths.script.path, paths.framework.path] + rest }

	// The numbers of the adapter's "send" command.
	static func commandID(_ command: BrowserMusic.Command) -> Int {
		switch command { case .playPause: 2; case .next: 4; case .previous: 5 }
	}
}

// What the adapter has said so far. Its lines are {"type":"data","diff":bool,"payload":{...}}: a full payload replaces
// everything, a diff updates only the keys it names, and a key set to null is gone.
struct MediaRemoteState {
	private(set) var values: [String: Any] = [:]

	// Takes one output line; false when it is not a data line.
	@discardableResult
	mutating func apply(line: String) -> Bool {
		guard let data = line.data(using: .utf8),
		      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
		      json["type"] as? String == "data", let payload = json["payload"] as? [String: Any] else { return false }
		if json["diff"] as? Bool == true {
			for (key, value) in payload {
				if value is NSNull { values[key] = nil } else { values[key] = value }
			}
		} else {
			values = payload.filter { !($0.value is NSNull) }
		}
		return true
	}

	private func number(_ key: String) -> Double? { (values[key] as? NSNumber)?.doubleValue }

	// The current track, or nil when nothing with a title is playing. The position is brought up to date from the moment
	// the adapter noted it, while it plays.
	func nowPlaying(at now: Date = Date()) -> NowPlaying? {
		guard let title = (values["title"] as? String)?.trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }
		let playing = values["playing"] as? Bool ?? false
		let duration = (number("durationMicros") ?? 0) / 1_000_000
		var position = (number("elapsedTimeMicros") ?? 0) / 1_000_000
		if playing, let stamp = number("timestampEpochMicros") {
			position += max(0, now.timeIntervalSince1970 - stamp / 1_000_000)
		}
		if duration > 0 { position = min(position, duration) }
		var info = NowPlaying(source: .system, title: title, artist: (values["artist"] as? String) ?? "", playing: playing,
		                      duration: max(0, duration), position: max(0, position), artworkURL: nil)
		info.appBundleID = values["bundleIdentifier"] as? String
		if let base64 = values["artworkData"] as? String, base64.count < 4_000_000 { info.artworkData = Data(base64Encoded: base64) }
		return info
	}
}
