import Foundation

// Reading a saved key can make macOS ask the person for permission, and the call does not return until they answer.
// Work that happens on its own, like listing models at launch, reads keys here, away from the main thread, so the
// window keeps working. One queue means one question at a time.

enum KeyReads {
	private static let queue = DispatchQueue(label: "yana.key-reads", qos: .userInitiated)

	static func read(_ account: String, using reader: @escaping @Sendable (String) -> String? = { Keychain.read($0) }) async -> String? {
		await withCheckedContinuation { done in queue.async { done.resume(returning: reader(account)) } }
	}
}
