import AVFoundation
import Foundation
import Speech

// Speaking into the chat box. Apple's Speech framework turns the microphone into text, on this Mac by
// default: audio only goes to Apple's servers when the person allows it in Settings > Chat, and only for a
// language that has no on-device model. Two permissions are asked the first time: microphone and speech
// recognition (the reasons are in Info.plist).

enum DictationFailure: Equatable {
	case micDenied, speechDenied, noOnDevice, unavailable, noMic
	case other(String)

	// The key of the text shown to the person (DictationStrings.swift).
	var messageKey: String? {
		switch self {
		case .micDenied: return "dict.micDenied"
		case .speechDenied: return "dict.speechDenied"
		case .noOnDevice: return "dict.noOnDevice"
		case .unavailable: return "dict.unavailable"
		case .noMic: return "dict.noMic"
		case .other: return nil
		}
	}

	// Which pane of System Settings fixes it, when it is a permission.
	var settingsURL: URL? {
		switch self {
		case .micDenied: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
		case .speechDenied: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
		default: return nil
		}
	}
}

// Pure helpers, kept apart so they can be tested without a microphone.
enum DictationText {
	// The draft with the spoken words after it: one space between, none at the ends, nothing added for silence.
	static func merge(base: String, spoken: String) -> String {
		let said = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !said.isEmpty else { return base }
		if base.isEmpty || base.last?.isWhitespace == true { return base + said }
		return base + " " + said
	}

	// The speech language follows the app language.
	static func localeIdentifier(for language: Lang) -> String {
		switch language {
		case .vi: return "vi-VN"
		case .en: return "en-US"
		case .ko: return "ko-KR"
		}
	}
}

extension Notification.Name {
	// Sent by the menu once the chat page is showing; the chat box starts or stops dictating.
	static let yanaDictateNow = Notification.Name("ai.yana.dictateNow")
}

@MainActor
final class DictationEngine: ObservableObject {
	enum State: Equatable { case idle, listening, failed(DictationFailure) }

	@Published private(set) var state: State = .idle
	var listening: Bool { state == .listening }

	// A run stops by itself after this long, so a forgotten microphone does not stay open.
	static let maxSeconds: UInt64 = 120
	// After the person stops, the last words still arrive for up to this long.
	private static let settleNanos: UInt64 = 2_000_000_000

	private var audio: AVAudioEngine?
	private var request: SFSpeechAudioBufferRecognitionRequest?
	private var task: SFSpeechRecognitionTask?
	private var base = ""
	private var lastApplied = ""
	private var apply: ((String) -> Void)?
	private var limit: Task<Void, Never>?
	private var settle: Task<Void, Never>?

	// YANA_DICTATION_PREVIEW=listening|micDenied|noOnDevice shows a state without a microphone or a permission
	// prompt, to check how the chat box looks in it.
	private var previewHold = false

	init() {
		switch ProcessInfo.processInfo.environment["YANA_DICTATION_PREVIEW"] {
		case "listening": state = .listening; previewHold = true // no microphone behind it, so nothing may end it
		case "micDenied": state = .failed(.micDenied)
		case "noOnDevice": state = .failed(.noOnDevice)
		default: break
		}
	}

	// Starts or stops. `apply` receives the whole draft each time the recognized words change.
	func toggle(draft: String, language: Lang, allowServer: Bool, apply: @escaping (String) -> Void) {
		if listening { stop(); return }
		Task { await start(draft: draft, language: language, allowServer: allowServer, apply: apply) }
	}

	// The person typed while listening: stop, so the next recognized words do not overwrite their edit.
	func userEdited(_ text: String) {
		if listening, text != lastApplied { stop() }
	}

	func stop() {
		guard !previewHold, audio != nil || state == .listening else { return }
		limit?.cancel()
		audio?.stop()
		audio?.inputNode.removeTap(onBus: 0)
		request?.endAudio()
		audio = nil
		state = .idle
		// The recognizer may still deliver the last words; wait a moment, then close it for good.
		settle = Task { [weak self] in
			try? await Task.sleep(nanoseconds: Self.settleNanos)
			self?.finish()
		}
	}

	func clearFailure() { if case .failed = state { state = .idle } }

	private func finish() {
		settle?.cancel()
		task?.cancel()
		task = nil
		request = nil
		apply = nil
	}

	private func start(draft: String, language: Lang, allowServer: Bool, apply: @escaping (String) -> Void) async {
		finish()
		state = .idle
		// Without the reasons in Info.plist, macOS ends the app when a permission is asked for.
		guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil,
		      Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil else {
			state = .failed(.other("Info.plist has no microphone or speech reason")); return
		}
		guard await Self.speechAllowed() else { state = .failed(.speechDenied); return }
		guard await Self.microphoneAllowed() else { state = .failed(.micDenied); return }

		let locale = Locale(identifier: DictationText.localeIdentifier(for: language))
		guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { state = .failed(.unavailable); return }
		let onDevice = recognizer.supportsOnDeviceRecognition
		if !onDevice && !allowServer { state = .failed(.noOnDevice); return }

		let request = SFSpeechAudioBufferRecognitionRequest()
		request.shouldReportPartialResults = true
		request.requiresOnDeviceRecognition = onDevice

		let engine = AVAudioEngine()
		let input = engine.inputNode
		let format = input.outputFormat(forBus: 0)
		guard format.sampleRate > 0, format.channelCount > 0 else { state = .failed(.noMic); return }
		input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in request.append(buffer) }
		engine.prepare()
		do { try engine.start() } catch {
			input.removeTap(onBus: 0)
			state = .failed(.other(error.localizedDescription))
			return
		}

		self.audio = engine
		self.request = request
		self.base = draft
		self.lastApplied = draft
		self.apply = apply
		task = recognizer.recognitionTask(with: request) { [weak self] result, error in
			let text = result?.bestTranscription.formattedString
			let done = (result?.isFinal ?? false) || error != nil
			Task { @MainActor in self?.heard(text, done: done) }
		}
		state = .listening
		limit = Task { [weak self] in
			try? await Task.sleep(nanoseconds: Self.maxSeconds * 1_000_000_000)
			if !Task.isCancelled { self?.stop() }
		}
	}

	private func heard(_ text: String?, done: Bool) {
		if let text, let apply {
			let merged = DictationText.merge(base: base, spoken: text)
			lastApplied = merged
			apply(merged)
		}
		if done { if listening { stop() }; finish() }
	}

	private static func speechAllowed() async -> Bool {
		switch SFSpeechRecognizer.authorizationStatus() {
		case .authorized: return true
		case .notDetermined:
			return await withCheckedContinuation { continuation in
				SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
			}
		default: return false
		}
	}

	private static func microphoneAllowed() async -> Bool {
		switch AVCaptureDevice.authorizationStatus(for: .audio) {
		case .authorized: return true
		case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
		default: return false
		}
	}
}
