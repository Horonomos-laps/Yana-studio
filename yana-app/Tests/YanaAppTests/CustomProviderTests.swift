import XCTest
@testable import YanaApp

final class CustomProviderTests: XCTestCase {
	private func defaults() -> UserDefaults {
		let name = "yana.tests.prov.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return d
	}

	// MARK: addresses

	func testGoodAddressesAreKeptWithoutTheTrailingSlash() {
		XCTAssertEqual(CustomProviders.normalizedBaseURL("https://api.together.ai/v1/"), "https://api.together.ai/v1")
		XCTAssertEqual(CustomProviders.normalizedBaseURL("  https://api.perplexity.ai \n"), "https://api.perplexity.ai")
		XCTAssertEqual(CustomProviders.normalizedBaseURL("http://127.0.0.1:8000/v1"), "http://127.0.0.1:8000/v1")
		XCTAssertEqual(CustomProviders.normalizedBaseURL("http://localhost:1337/v1"), "http://localhost:1337/v1")
	}

	func testBadAddressesAreRefused() {
		let bad = ["", "   ", "api.together.ai/v1", "ftp://x.com/v1", "file:///etc/passwd", "javascript:alert(1)", "https://",
		           "https://user:pass@api.example.com/v1", "https://api.example.com/v1?key=abc", "https://api.example.com/v1#x",
		           "https://api.example.com/v1 extra", "https://api.example.com/\nv1", String(repeating: "a", count: 400)]
		for raw in bad { XCTAssertNil(CustomProviders.normalizedBaseURL(raw), raw.debugDescription) }
	}

	func testPlainHttpIsOnlyForThisMac() {
		XCTAssertNil(CustomProviders.normalizedBaseURL("http://api.example.com/v1"), "a key would cross the network in the clear")
		XCTAssertNil(CustomProviders.normalizedBaseURL("http://192.168.1.20:8000/v1"))
		XCTAssertNotNil(CustomProviders.normalizedBaseURL("http://[::1]:8000/v1"))
	}

	func testTheModelListAddressFollowsTheSameRuleAsTheBuiltInCustomProvider() {
		XCTAssertEqual(CustomProviders.modelsURL(for: "https://api.together.ai/v1"), "https://api.together.ai/v1/models")
		XCTAssertEqual(CustomProviders.modelsURL(for: "https://x.com/v1/chat/completions"), "https://x.com/v1/models")
		XCTAssertEqual(CustomProviders.modelsURL(for: "https://x.com/v1/"), "https://x.com/v1/models")
	}

	// MARK: names and ids

	func testASlugHasNoAccentsAndStaysShortAndUnique() {
		XCTAssertEqual(CustomProviders.slug(for: "Together AI", taken: []), "together-ai")
		XCTAssertEqual(CustomProviders.slug(for: "Máy chủ của Đạt", taken: []), "may-chu-cua-dat")
		XCTAssertEqual(CustomProviders.slug(for: "Together AI", taken: ["together-ai"]), "together-ai-2")
		XCTAssertEqual(CustomProviders.slug(for: "Together AI", taken: ["together-ai", "together-ai-2"]), "together-ai-3")
		XCTAssertEqual(CustomProviders.slug(for: "🔥🔥", taken: []), "provider")
		XCTAssertLessThanOrEqual(CustomProviders.slug(for: String(repeating: "a", count: 200), taken: []).count, 24)
	}

	func testValidationNamesWhatIsWrong() {
		let one = CustomProvider(id: "custom:a", name: "Alpha", baseURL: "https://a.com/v1", keyless: false)
		XCTAssertEqual(CustomProviders.validate(name: " ", baseURL: "https://a.com", existing: [], editing: nil), .emptyName)
		XCTAssertEqual(CustomProviders.validate(name: String(repeating: "x", count: 41), baseURL: "https://a.com", existing: [], editing: nil), .nameTooLong)
		XCTAssertEqual(CustomProviders.validate(name: "alpha", baseURL: "https://b.com", existing: [one], editing: nil), .nameTaken)
		XCTAssertNil(CustomProviders.validate(name: "alpha", baseURL: "https://b.com", existing: [one], editing: "custom:a"), "renaming itself is fine")
		XCTAssertEqual(CustomProviders.validate(name: "B", baseURL: "not a url", existing: [], editing: nil), .badURL)
		XCTAssertEqual(CustomProviders.validate(name: "B", baseURL: "http://api.example.com/v1", existing: [], editing: nil), .insecureURL)
		XCTAssertNil(CustomProviders.validate(name: "B", baseURL: "https://b.com/v1", existing: [one], editing: nil))
	}

	// MARK: what yana-rt is asked

	func testABuiltInProviderGoesThroughUntouched() {
		XCTAssertEqual(CustomProviders.wire(for: "openai", builtinBase: "", list: []), CustomProviders.Wire(provider: "openai", baseURL: nil))
		XCTAssertFalse(CustomProviders.wire(for: "ollama", builtinBase: "", list: [])!.isCustom)
	}

	func testTheOldSingleCustomProviderKeepsItsOwnAddress() {
		let wire = CustomProviders.wire(for: "custom", builtinBase: "https://mine.example/v1", list: [])
		XCTAssertEqual(wire, CustomProviders.Wire(provider: "custom", baseURL: "https://mine.example/v1"))
	}

	func testAnAddedProviderBecomesCustomWithItsOwnAddress() {
		let item = CustomProvider(id: "custom:together-ai", name: "Together AI", baseURL: "https://api.together.ai/v1", keyless: false)
		let wire = CustomProviders.wire(for: "custom:together-ai", builtinBase: "https://other", list: [item])
		XCTAssertEqual(wire, CustomProviders.Wire(provider: "custom", baseURL: "https://api.together.ai/v1/chat/completions"),
		               "yana-rt posts to exactly this string, so it is the whole chat address")
		XCTAssertTrue(wire!.isCustom)
	}

	func testTheChatAddressGetsItsPathOnlyOnce() {
		XCTAssertEqual(CustomProviders.chatURL(for: "https://api.perplexity.ai"), "https://api.perplexity.ai/chat/completions")
		XCTAssertEqual(CustomProviders.chatURL(for: "https://x.com/v1/"), "https://x.com/v1/chat/completions")
		XCTAssertEqual(CustomProviders.chatURL(for: "https://x.com/v1/chat/completions"), "https://x.com/v1/chat/completions")
		for preset in CustomProviders.presets {
			let chat = CustomProviders.chatURL(for: preset.baseURL)
			XCTAssertTrue(chat.hasSuffix("/chat/completions"), preset.name)
			XCTAssertEqual(chat.components(separatedBy: "/chat/completions").count, 2, preset.name)
		}
	}

	// The model list and the connection test, against a real local server that answers like an OpenAI-style API.
	func testTheConnectionTestTalksToARealOpenAIStyleServer() async throws {
		let python = "/usr/bin/python3"
		try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python), "no python3 to run the test server")
		let port = Int.random(in: 20_000 ... 29_999)
		let script = """
		import json, sys
		from http.server import BaseHTTPRequestHandler, HTTPServer
		class H(BaseHTTPRequestHandler):
		    def log_message(self, *a): pass
		    def do_GET(self):
		        if self.headers.get('Authorization') != 'Bearer k':
		            self.send_response(401); self.end_headers(); return
		        body = json.dumps({'data': [{'id': 'fake-model-1'}, {'id': 'fake-model-2'}, {'id': 'text-embedding-3'}]}).encode()
		        self.send_response(200); self.send_header('Content-Type', 'application/json'); self.end_headers(); self.wfile.write(body)
		HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
		"""
		let server = Process()
		server.executableURL = URL(fileURLWithPath: python)
		server.arguments = ["-I", "-c", script, String(port)]
		try server.run()
		defer { server.terminate() }
		let base = "http://127.0.0.1:\(port)/v1"
		var ready = false
		for _ in 0 ..< 40 {
			let (state, _) = await ModelCatalog.probe(baseURL: base, key: "k")
			if state == .ready { ready = true; break }
			try await Task.sleep(nanoseconds: 100_000_000)
		}
		XCTAssertTrue(ready, "the server never answered")
		let good = await ModelCatalog.probe(baseURL: base, key: "k")
		XCTAssertEqual(good.1, ["fake-model-1", "fake-model-2"], "the embedding model is not a chat model")
		XCTAssertTrue(CustomProviders.probeResult(state: good.0, models: good.1).text.contains("2"))
		let noKey = await ModelCatalog.probe(baseURL: base, key: nil)
		XCTAssertEqual(noKey.0, .failed(L("model.err401")))
		XCTAssertFalse(CustomProviders.probeResult(state: noKey.0, models: noKey.1).ok)
		let down = await ModelCatalog.probe(baseURL: "http://127.0.0.1:1/v1", key: "k")
		XCTAssertEqual(down.0, .failed(L("model.errUnreachable")))
	}

	func testARemovedProviderIsNotSentToAnyoneElse() {
		XCTAssertNil(CustomProviders.wire(for: "custom:gone", builtinBase: "https://other", list: []))
	}

	// MARK: presets

	func testEveryPresetIsAUsableAddressWithAUniqueName() {
		XCTAssertGreaterThanOrEqual(CustomProviders.presets.count, 8)
		XCTAssertEqual(Set(CustomProviders.presets.map(\.name)).count, CustomProviders.presets.count)
		for preset in CustomProviders.presets {
			let url = CustomProviders.normalizedBaseURL(preset.baseURL)
			XCTAssertNotNil(url, preset.name)
			XCTAssertTrue(preset.name.count <= CustomProviders.maxNameLength, preset.name)
			XCTAssertEqual(preset.local, preset.baseURL.hasPrefix("http://"), "only servers on this Mac use http: \(preset.name)")
			XCTAssertEqual(preset.keyless, preset.local, preset.name)
		}
	}

	func testNoPresetClashesWithABuiltInProviderId() {
		let builtIn = Set(providerCatalog.map { $0.id.lowercased() })
		for preset in CustomProviders.presets { XCTAssertFalse(builtIn.contains(preset.name.lowercased()), preset.name) }
	}

	func testTheKeyScreensListEveryProviderWithLocalOnesLast() {
		XCTAssertEqual(keyScreenProviders.map(\.id).sorted(), providerCatalog.map(\.id).sorted())
		let local = keyScreenProviders.map { $0.kind == .local }
		XCTAssertEqual(local, local.sorted { !$0 && $1 })
		XCTAssertEqual(local.filter { $0 }.count, 7)
	}

	// MARK: the store

	@MainActor
	func testAddingGivesAnIdAndItSurvivesARestart() {
		let d = defaults()
		let store = CustomProviderStore(defaults: d)
		XCTAssertNil(store.save(name: "Together AI", baseURL: "https://api.together.ai/v1/", keyless: false))
		XCTAssertEqual(store.items.map(\.id), ["custom:together-ai"])
		XCTAssertEqual(store.items[0].baseURL, "https://api.together.ai/v1")
		XCTAssertEqual(CustomProviderStore(defaults: d).items, store.items, "written to the defaults")
	}

	@MainActor
	func testTwoWithTheSameNameAreRefusedAndTheListIsNotChanged() {
		let store = CustomProviderStore(defaults: defaults())
		store.save(name: "A", baseURL: "https://a.com/v1", keyless: false)
		XCTAssertEqual(store.save(name: "a", baseURL: "https://b.com/v1", keyless: false), .nameTaken)
		XCTAssertEqual(store.items.count, 1)
	}

	@MainActor
	func testEditingKeepsTheIdEvenWhenTheNameChanges() {
		let store = CustomProviderStore(defaults: defaults())
		store.save(name: "Old name", baseURL: "https://a.com/v1", keyless: false)
		let id = store.items[0].id
		XCTAssertNil(store.save(name: "New name", baseURL: "http://127.0.0.1:8000/v1", keyless: true, editing: id))
		XCTAssertEqual(store.items.count, 1)
		XCTAssertEqual(store.items[0].id, id, "chats and the saved key stay attached")
		XCTAssertEqual(store.items[0].name, "New name"); XCTAssertTrue(store.items[0].keyless)
	}

	@MainActor
	func testRemovingTakesItOutOfTheList() {
		let store = CustomProviderStore(defaults: defaults())
		store.save(name: "A", baseURL: "https://a.com/v1", keyless: true)
		store.remove("custom:a")
		XCTAssertTrue(store.items.isEmpty)
		store.remove("custom:nothing")   // nothing to remove, and no crash
	}

	@MainActor
	func testTheDisplayNameIsTheNameThePersonGave() {
		XCTAssertEqual(CustomProviders.displayName("anthropic"), "anthropic")
	}

	// MARK: strings and the connection test

	func testTheConnectionTestExplainsEachOutcome() {
		XCTAssertTrue(CustomProviders.probeResult(state: .ready, models: ["a", "b"]).ok)
		XCTAssertTrue(CustomProviders.probeResult(state: .ready, models: ["a", "b"]).text.contains("2"))
		XCTAssertTrue(CustomProviders.probeResult(state: .failed(L("model.err404")), models: []).ok, "no model list is not a failure")
		XCTAssertFalse(CustomProviders.probeResult(state: .failed(L("model.err401")), models: []).ok, "a wrong key is")
		XCTAssertFalse(CustomProviders.probeResult(state: .failed(L("model.errUnreachable")), models: []).ok)
	}

	func testEveryNewStringExistsInAllThreeLanguages() {
		for row in providerRows { XCTAssertFalse(row.vi.isEmpty || row.en.isEmpty || row.ko.isEmpty, row.key) }
		XCTAssertEqual(Set(allStringRows.map(\.key)).count, allStringRows.count)
	}
}
