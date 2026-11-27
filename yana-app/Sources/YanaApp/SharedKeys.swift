import Foundation

// Provider API keys shared with Yana Studio: yana-rt keeps them in the macOS Keychain, so a key entered once works
// in both apps. This app writes, removes and asks about them through `yana-rt os credential`; it never reads a shared
// key back. A key goes to yana-rt on stdin, never as an argument.
//
// Not shared: "custom" and added providers (their address is the person's own), and 9router (plain http). Those, and
// every provider when the installed yana-rt is too old, stay in this app's own Keychain items as before.
//
// The other app changes the store too, so every change asks yana-rt for the current state first. A key this app kept
// from before is never deleted just because a shared one exists; it is marked superseded and ignored, so removing the
// shared key does not bring an old one back.

struct RuntimeReply {
	let status: Int32
	let output: Data
	let error: String
}

enum SharedState: Equatable {
	case unsupported // no yana-rt, or one without a shared store
	case unknown // it has one, or may have, but did not answer
	case known(Set<String>)

	var held: Set<String> { if case .known(let set) = self { return set } else { return [] } }
}

// This app's own Keychain items, and the providers whose item is superseded.
struct LocalKeys {
	var read: (String) -> String?
	var exists: (String) -> Bool
	var write: (String, String) -> Void
	var delete: (String) -> Void
	var superseded: () -> Set<String>
	var setSuperseded: (Set<String>) -> Void

	func has(_ provider: String) -> Bool { !superseded().contains(provider) && exists(provider) }

	func supersede(_ provider: String, _ yes: Bool) {
		var set = superseded()
		if yes { set.insert(provider) } else { set.remove(provider) }
		setSuperseded(set)
	}
}

struct KeyOutcome: Equatable {
	var state: SharedState
	var error: String? = nil
}

struct SharedKeys {
	// Runs yana-rt with these arguments and this stdin. Status 127 when it is not installed; nil when it does not
	// answer in time.
	typealias Runner = (_ arguments: [String], _ input: Data?, _ timeout: TimeInterval) -> RuntimeReply?

	static let notShared: Set<String> = ["custom", "9router"]
	static let notInstalled: Int32 = 127
	// yana-rt's exit status for `set --if-absent` when a key is already there.
	static let alreadyStored: Int32 = 3
	// yana-rt's own limit for a key.
	static let maxKeyBytes = 8 * 1024
	private static let probeTimeout: TimeInterval = 20
	// A change or a status can wait on a Keychain dialog; killing a change halfway could lose the key.
	private static let changeTimeout: TimeInterval = 120
	// yana-rt may wait 60 s for the Keychain, then as long as 90 s for the provider.
	private static let listTimeout: TimeInterval = 180

	let run: Runner

	static func canShare(_ provider: String) -> Bool {
		!notShared.contains(provider) && providerCatalog.contains { $0.id == provider && $0.kind == .cloud }
	}

	func state() -> SharedState {
		// The newest command this app needs: a runtime without it has only part of the store.
		look().state
	}

	// The state, and the providers whose key was removed from the store and not saved again.
	private func look() -> (state: SharedState, removed: Set<String>) {
		guard let probe = run(["os", "credential", "set", "--help"], nil, Self.probeTimeout) else { return (.unknown, []) }
		guard probe.status == 0, String(decoding: probe.output, as: UTF8.self).contains("--if-absent") else { return (.unsupported, []) }
		guard let reply = run(["os", "credential", "status", "--json"], nil, Self.changeTimeout), reply.status == 0,
		      let held = Self.parseStatus(reply.output) else { return (.unknown, []) }
		return (.known(held), Self.parseRemoved(reply.output))
	}

	// Nil when the answer cannot be read, or when the store did not answer for a provider: then "no key" is not known.
	static func parseStatus(_ data: Data) -> Set<String>? {
		guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
		if rows.contains(where: { ($0["native_secret_unknown"] as? Bool) == true }) { return nil }
		return flagged("native_secret_configured", in: rows)
	}

	static func parseRemoved(_ data: Data) -> Set<String> {
		guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
		return flagged("native_secret_removed", in: rows)
	}

	private static func flagged(_ flag: String, in rows: [[String: Any]]) -> Set<String> {
		let names = rows.compactMap { row -> String? in
			(row[flag] as? Bool) == true ? row["provider"] as? String : nil
		}
		return Set(names.filter(canShare))
	}

	@discardableResult
	func refresh(_ local: LocalKeys) -> SharedState {
		let (now, removed) = look()
		for provider in now.held.union(removed) where local.exists(provider) { local.supersede(provider, true) }
		return now
	}

	// An older copy this app keeps but no longer uses.
	static func hasOldCopy(_ provider: String, local: LocalKeys) -> Bool {
		local.superseded().contains(provider) && local.exists(provider)
	}

	// Deletes only that copy; the shared store is not touched.
	static func deleteOldCopy(_ provider: String, local: LocalKeys) {
		guard hasOldCopy(provider, local: local) else { return }
		local.delete(provider)
		local.supersede(provider, false)
	}

	func save(_ key: String, for provider: String, local: LocalKeys) -> KeyOutcome {
		let now = refresh(local)
		guard key.utf8.count <= Self.maxKeyBytes else { return KeyOutcome(state: now, error: L("keys.tooLong")) }
		switch now {
		case .unsupported:
			local.write(key, provider)
			local.supersede(provider, false)
			return KeyOutcome(state: now)
		case .unknown:
			// Writing only here could leave an older shared key in use.
			return KeyOutcome(state: now, error: L("keys.runtimeSilent"))
		case .known(var held):
			if let reason = failure(run(["os", "credential", "set", provider], Data(key.utf8), Self.changeTimeout)) {
				return KeyOutcome(state: refresh(local), error: reason)
			}
			local.delete(provider)
			local.supersede(provider, false)
			held.insert(provider)
			return KeyOutcome(state: .known(held))
		}
	}

	func remove(_ provider: String, local: LocalKeys) -> KeyOutcome {
		let now = refresh(local)
		switch now {
		case .unsupported, .unknown:
			local.delete(provider)
			local.supersede(provider, false)
			return KeyOutcome(state: now, error: now == .unknown ? L("keys.removeIncomplete") : nil)
		case .known(var held):
			// Asked even when the status did not list it: removing what is not there is not an error.
			if let reason = failure(run(["os", "credential", "remove", provider], nil, Self.changeTimeout)) {
				return KeyOutcome(state: refresh(local), error: reason)
			}
			local.delete(provider)
			local.supersede(provider, false)
			held.remove(provider)
			return KeyOutcome(state: .known(held))
		}
	}

	static func movable(_ state: SharedState, local: LocalKeys) -> [String] {
		guard case .known(let held) = state else { return [] }
		return providerCatalog.map(\.id).filter { canShare($0) && !held.contains($0) && local.has($0) }
	}

	// Moves each key only this app holds. One already shared is left alone: the shared one may be newer. A local copy
	// is deleted only after the store took it.
	func migrate(local: LocalKeys) -> KeyOutcome {
		let now = refresh(local)
		guard case .known(var held) = now else { return KeyOutcome(state: now, error: L("keys.runtimeSilent")) }
		var failed: [String] = []
		for provider in Self.movable(now, local: local) {
			guard let key = local.read(provider), !key.isEmpty else { failed.append("\(provider): \(L("keys.unreadable"))"); continue }
			let reply = run(["os", "credential", "set", "--if-absent", provider], Data(key.utf8), Self.changeTimeout)
			if reply?.status == Self.alreadyStored {
				// Saved by the other app meanwhile: that one stays, this copy is kept and ignored.
				local.supersede(provider, true)
				held.insert(provider)
			} else if let reason = failure(reply) {
				failed.append("\(provider): \(reason)")
			} else {
				local.delete(provider)
				held.insert(provider)
			}
		}
		return KeyOutcome(state: .known(held), error: failed.isEmpty ? nil : failed.joined(separator: "\n"))
	}

	// The provider's own model list, fetched by yana-rt with the shared key.
	func modelList(for provider: String) -> RuntimeReply? {
		run(["os", "credential", "models", provider], nil, Self.listTimeout)
	}

	private func failure(_ reply: RuntimeReply?) -> String? {
		guard let reply else { return L("keys.runtimeSilent") }
		if reply.status == 0 { return nil }
		let text = reply.error.trimmingCharacters(in: .whitespacesAndNewlines)
		return text.isEmpty ? "yana-rt: \(reply.status)" : String(text.prefix(300))
	}

	// Changes run one at a time, off the main thread.
	private static let changes = DispatchQueue(label: "yana.shared-keys")

	static func serial<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
		await withCheckedContinuation { done in changes.async { done.resume(returning: work()) } }
	}

	// For a request that may take long and changes nothing.
	static func background<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
		await withCheckedContinuation { done in DispatchQueue.global().async { done.resume(returning: work()) } }
	}

	static var live: SharedKeys {
		SharedKeys { arguments, input, timeout in
			guard let binary = RtClient.binaryPath() else { return RuntimeReply(status: notInstalled, output: Data(), error: "") }
			let process = Process()
			process.executableURL = URL(fileURLWithPath: binary)
			process.arguments = arguments
			let out = Pipe(), err = Pipe(), stdin = Pipe()
			process.standardOutput = out
			process.standardError = err
			process.standardInput = stdin
			do { try process.run() } catch { return RuntimeReply(status: notInstalled, output: Data(), error: "") }
			let killer = DispatchWorkItem { process.terminate() }
			DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
			// A child that exits before reading its stdin must not end the app. Set on this pipe only: a process-wide
			// setting would be inherited by every shell the built-in terminal starts.
			_ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
			if let input { try? stdin.fileHandleForWriting.write(contentsOf: input) }
			try? stdin.fileHandleForWriting.close()
			// Output is read before waiting: a long model list would fill the pipe and stall the child. Errors are short.
			let output = out.fileHandleForReading.readDataToEndOfFile()
			let error = err.fileHandleForReading.readDataToEndOfFile()
			process.waitUntilExit()
			killer.cancel()
			guard process.terminationReason == .exit else { return nil }
			return RuntimeReply(status: process.terminationStatus, output: output, error: String(decoding: error, as: UTF8.self))
		}
	}
}
