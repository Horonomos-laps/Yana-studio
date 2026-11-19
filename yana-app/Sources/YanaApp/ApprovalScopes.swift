import Foundation

// How long an approval is remembered. "once" is the old behavior and the only thing every older yana-rt understands.
enum ApprovalScope: String {
	case once, session, always
}

extension RtClient {
	// The first yana-rt that reads the `scope` field when a paused turn resumes. An older one refuses the whole
	// request ("unknown field"), so the app offers "this session" and "always" only when the installed runtime is
	// at least this version. Raise it if the release that carries the change gets a different number.
	static let approvalScopesMinimumVersion = [1, 5, 5]

	// The tool name a paused command carries in the approval event. Only a command can be remembered: the
	// runtime refuses to remember any other tool.
	static let rememberableTool = "run_command"

	// Asked once per launch, the first time an approval card is shown.
	static let supportsApprovalScopes: Bool = {
		guard let binary = binaryPath(), let version = runtimeVersion(binary) else { return false }
		return !version.lexicographicallyPrecedes(approvalScopesMinimumVersion)
	}()

	// `yana-rt --version` prints "yana-rt X.Y.Z". Anything else (a pre-release suffix, no output) is "unknown",
	// and unknown means the new choices stay hidden.
	static func runtimeVersion(_ binary: String) -> [Int]? {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: binary)
		process.arguments = ["--version"]
		let out = Pipe()
		process.standardOutput = out
		process.standardError = Pipe()
		do { try process.run() } catch { return nil }
		let deadline = Date().addingTimeInterval(5)
		while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
		if process.isRunning { process.terminate(); return nil }
		let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		guard let last = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).last else { return nil }
		let parts = last.split(separator: ".").compactMap { Int($0) }
		return parts.count == 3 ? parts : nil
	}
}
