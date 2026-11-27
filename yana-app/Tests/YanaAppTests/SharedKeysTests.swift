import XCTest
@testable import YanaApp

final class SharedKeysTests: XCTestCase {
	// A yana-rt and a local key store in memory. No test touches a real runtime or Keychain.
	private final class World {
		var shared: [String: String] = [:]
		var items: [String: String] = [:]
		var superseded: Set<String> = []
		var calls: [(arguments: [String], input: String?)] = []
		var probe: Int32? = 0
		var statusSilent = false
		var refuse = false
		var removed: Set<String> = []
		var unanswered: Set<String> = []
		var onSet: (() -> Void)?
		var oldRuntime = false

		lazy var keys = SharedKeys { [unowned self] arguments, input, _ in
			let text = input.map { String(decoding: $0, as: UTF8.self) }
			calls.append((arguments, text))
			func reply(_ status: Int32, _ out: String = "", _ error: String = "") -> RuntimeReply {
				RuntimeReply(status: status, output: Data(out.utf8), error: error)
			}
			if arguments.last == "--help" { return probe.map { reply($0, oldRuntime ? "set <PROVIDER>" : "set --if-absent <PROVIDER>") } }
			if arguments[2] == "status" {
				if statusSilent { return nil }
				let rows = shared.keys.map { "{\"provider\":\"\($0)\",\"native_secret_configured\":true}" }
					+ removed.map { "{\"provider\":\"\($0)\",\"native_secret_removed\":true}" }
					+ unanswered.map { "{\"provider\":\"\($0)\",\"native_secret_unknown\":true}" }
				return reply(0, "[\(rows.joined(separator: ","))]")
			}
			if refuse { return reply(2, "", "[os] locked\n") }
			if arguments[2] == "set" {
				onSet?()
				if arguments[3] == "--if-absent" {
					if shared[arguments[4]] != nil { return reply(SharedKeys.alreadyStored) }
					shared[arguments[4]] = text
				} else {
					shared[arguments[3]] = text
				}
			} else {
				shared[arguments[3]] = nil
			}
			return reply(0)
		}

		lazy var local = LocalKeys(
			read: { [unowned self] in items[$0] }, exists: { [unowned self] in items[$0] != nil },
			write: { [unowned self] in items[$1] = $0 }, delete: { [unowned self] in items[$0] = nil },
			superseded: { [unowned self] in superseded }, setSuperseded: { [unowned self] in superseded = $0 })
	}

	func testOnlyCatalogCloudProvidersAreShared() {
		for id in ["openai", "anthropic", "mistral", "ernie"] { XCTAssertTrue(SharedKeys.canShare(id), id) }
		for id in ["custom", "9router", "ollama", "vllm", "custom:together-ai", "", "OpenAI", String(repeating: "a", count: 65536)] {
			XCTAssertFalse(SharedKeys.canShare(id), id)
		}
		for bad in ["", "{}", "not json", "[1,2]", "\u{0}"] { XCTAssertNil(SharedKeys.parseStatus(Data(bad.utf8)), bad) }
	}

	func testStateTellsNoStoreFromNoAnswer() {
		let world = World()
		XCTAssertEqual(world.keys.state(), .known([]))
		world.statusSilent = true
		XCTAssertEqual(world.keys.state(), .unknown)
		world.probe = nil
		XCTAssertEqual(world.keys.state(), .unknown)
		for status: Int32 in [2, SharedKeys.notInstalled] {
			world.probe = status
			XCTAssertEqual(world.keys.state(), .unsupported)
		}
	}

	func testAKeyTravelsOnStdinAndTheLocalCopyGoes() {
		let world = World()
		world.items["openai"] = "old"
		XCTAssertNil(world.keys.save("sk-new", for: "openai", local: world.local).error)
		let set = world.calls.first { $0.arguments.contains("set") && $0.arguments.last != "--help" }
		XCTAssertEqual(set?.arguments, ["os", "credential", "set", "openai"])
		XCTAssertEqual(set?.input, "sk-new")
		XCTAssertNil(world.items["openai"])
	}

	func testWithoutAnAnswerNothingIsWrittenOnlyLocally() {
		let world = World()
		world.statusSilent = true
		XCTAssertNotNil(world.keys.save("sk", for: "openai", local: world.local).error)
		XCTAssertTrue(world.items.isEmpty)
		world.probe = 2
		XCTAssertNil(world.keys.save("sk", for: "openai", local: world.local).error)
		XCTAssertEqual(world.items["openai"], "sk")
	}

	func testRemoveAlsoRemovesAKeyTheOtherAppSavedMeanwhile() {
		let world = World()
		world.shared["openai"] = "saved-by-studio"
		let outcome = world.keys.remove("openai", local: world.local)
		XCTAssertNil(outcome.error)
		XCTAssertTrue(world.shared.isEmpty)
		XCTAssertTrue(world.calls.contains { $0.arguments == ["os", "credential", "remove", "openai"] })
	}

	func testRemoveSaysSoWhenTheSharedKeyMayRemain() {
		let world = World()
		world.statusSilent = true
		XCTAssertNotNil(world.keys.remove("openai", local: world.local).error)
		world.statusSilent = false
		world.refuse = true
		world.items["openai"] = "kept"
		XCTAssertNotNil(world.keys.remove("openai", local: world.local).error)
		XCTAssertEqual(world.items["openai"], "kept")
	}

	func testAnOldLocalKeyNeverComesBack() {
		let world = World()
		world.items["openai"] = "old"
		world.shared["openai"] = "newer"
		world.keys.refresh(world.local)
		XCTAssertEqual(world.items["openai"], "old", "kept, not deleted")
		XCTAssertFalse(world.local.has("openai"))
		world.shared = [:]
		world.keys.refresh(world.local)
		XCTAssertFalse(world.local.has("openai"), "removing the shared key elsewhere does not revive it")
	}

	func testMigrationNeverOverwritesAndKeepsWhatWasRefused() {
		let world = World()
		world.items = ["openai": "mine", "groq": "g", "custom": "c", "9router": "r"]
		world.shared["openai"] = "newer"
		let outcome = world.keys.migrate(local: world.local)
		XCTAssertNil(outcome.error)
		XCTAssertEqual(world.shared["openai"], "newer")
		XCTAssertEqual(world.shared["groq"], "g")
		XCTAssertTrue(world.calls.contains { $0.arguments == ["os", "credential", "set", "--if-absent", "groq"] })
		XCTAssertEqual(outcome.state.held, ["openai", "groq"])
		XCTAssertEqual(Set(world.items.keys), ["openai", "custom", "9router"])
		world.items["kimi"] = "k"
		world.refuse = true
		XCTAssertNotNil(world.keys.migrate(local: world.local).error)
		XCTAssertEqual(world.items["kimi"], "k")
	}

	func testAKeySavedWhileMovingIsNotReplaced() {
		let world = World()
		world.items["groq"] = "older"
		world.onSet = { [unowned world] in world.shared["groq"] = "newer" }
		let outcome = world.keys.migrate(local: world.local)
		XCTAssertNil(outcome.error)
		XCTAssertEqual(world.shared["groq"], "newer")
		XCTAssertEqual(world.items["groq"], "older", "kept")
		XCTAssertFalse(world.local.has("groq"))
		XCTAssertTrue(outcome.state.held.contains("groq"))
	}

	func testAKeyRemovedElsewhereUnseenDoesNotRevive() {
		let world = World()
		world.items["openai"] = "old"
		world.removed = ["openai"]
		world.keys.refresh(world.local)
		XCTAssertFalse(world.local.has("openai"))
		XCTAssertTrue(SharedKeys.hasOldCopy("openai", local: world.local))
		XCTAssertEqual(SharedKeys.movable(.known([]), local: world.local), [])
		SharedKeys.deleteOldCopy("openai", local: world.local)
		XCTAssertNil(world.items["openai"])
		XCTAssertTrue(world.superseded.isEmpty)
		XCTAssertFalse(world.calls.contains { $0.arguments.contains("remove") })
	}

	func testDeletingAnOldCopyLeavesAKeyInUseAlone() {
		let world = World()
		world.items["openai"] = "in-use"
		SharedKeys.deleteOldCopy("openai", local: world.local)
		XCTAssertEqual(world.items["openai"], "in-use")
	}

	func testAnUnansweredProviderMakesTheStateUnknown() {
		let world = World()
		world.unanswered = ["openai"]
		XCTAssertEqual(world.keys.state(), .unknown)
		world.unanswered = []
		world.oldRuntime = true
		XCTAssertEqual(world.keys.state(), .unsupported)
	}
}
