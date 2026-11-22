import Combine
import Foundation

// Providers the person adds themselves, with no change to yana-rt. yana-rt already talks to any OpenAI-compatible
// endpoint through its "custom" provider (a base URL and a key in each request), so a provider added here is a record
// (name, base URL, key in the Keychain) that is turned into a "custom" request when a message is sent. Nothing is
// guessed: the presets below are base URLs taken from each provider's own documentation, and the Test connection
// button asks the endpoint for its model list so a wrong URL or key shows up before the first message.

struct CustomProvider: Codable, Identifiable, Equatable {
	// "custom:<slug>": also the Keychain account the key is saved under, and what the chat bar remembers.
	let id: String
	var name: String
	var baseURL: String
	// A local server with no key (vLLM, Jan...): nothing is sent as a key.
	var keyless: Bool
}

struct ProviderPreset: Identifiable, Equatable {
	let name: String
	let baseURL: String
	var keyless = false
	// Where it runs: a hosted service, or a server on this Mac.
	var local = false
	var id: String { name }
}

enum CustomProviders {
	static let prefix = "custom:"
	static let storeKey = "yana.customProviders"
	static let maxNameLength = 40
	static let maxURLLength = 300

	static func isCustom(_ id: String) -> Bool { id.hasPrefix(prefix) }

	// MARK: presets (each base URL is from the provider's documentation, checked 2026-11-22)

	static let presets: [ProviderPreset] = [
		ProviderPreset(name: "Together AI", baseURL: "https://api.together.ai/v1"),
		ProviderPreset(name: "Fireworks AI", baseURL: "https://api.fireworks.ai/inference/v1"),
		ProviderPreset(name: "Mistral AI", baseURL: "https://api.mistral.ai/v1"),
		ProviderPreset(name: "Cerebras", baseURL: "https://api.cerebras.ai/v1"),
		ProviderPreset(name: "SambaNova", baseURL: "https://api.sambanova.ai/v1"),
		ProviderPreset(name: "DeepInfra", baseURL: "https://api.deepinfra.com/v1/openai"),
		ProviderPreset(name: "Hyperbolic", baseURL: "https://api.hyperbolic.xyz/v1"),
		ProviderPreset(name: "Perplexity", baseURL: "https://api.perplexity.ai"),
		ProviderPreset(name: "Nebius", baseURL: "https://api.studio.nebius.com/v1"),
		ProviderPreset(name: "Venice AI", baseURL: "https://api.venice.ai/api/v1"),
		ProviderPreset(name: "GitHub Models", baseURL: "https://models.github.ai/inference"),
		ProviderPreset(name: "Qwen (Intl)", baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"),
		ProviderPreset(name: "Qwen (CN)", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1"),
		ProviderPreset(name: "SiliconFlow (Intl)", baseURL: "https://api.siliconflow.com/v1"),
		ProviderPreset(name: "SiliconFlow (CN)", baseURL: "https://api.siliconflow.cn/v1"),
		ProviderPreset(name: "vLLM", baseURL: "http://127.0.0.1:8000/v1", keyless: true, local: true),
		ProviderPreset(name: "Jan", baseURL: "http://127.0.0.1:1337/v1", keyless: true, local: true),
		ProviderPreset(name: "LiteLLM proxy", baseURL: "http://127.0.0.1:4000", keyless: true, local: true),
	]

	// MARK: names and addresses

	// A short, stable id from a name: lower case, no accents, letters and digits joined by dashes; unique among `taken`.
	static func slug(for name: String, taken: Set<String>) -> String {
		let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en_US_POSIX"))
			.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d")
		var out = ""
		for scalar in folded.lowercased().unicodeScalars {
			if (scalar.value >= 97 && scalar.value <= 122) || (scalar.value >= 48 && scalar.value <= 57) { out.unicodeScalars.append(scalar) }
			else if !out.hasSuffix("-") { out.append("-") }
		}
		out = String(out.trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(24))
		if out.isEmpty { out = "provider" }
		var candidate = out, n = 2
		while taken.contains(candidate) { candidate = "\(out)-\(n)"; n += 1 }
		return candidate
	}

	private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

	// The address as it will be used, or nil when it is not a usable one: http or https with a host, no credentials in
	// it, no query or fragment, and plain http only for this Mac (a key would otherwise cross the network in the clear).
	static func normalizedBaseURL(_ raw: String) -> String? {
		let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty, text.count <= maxURLLength, !text.contains(where: { $0.isWhitespace || $0.isNewline || $0 == "\0" }),
		      let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
		      let host = url.host?.lowercased(), !host.isEmpty,
		      url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
		if scheme == "http", !loopbackHosts.contains(host) { return nil }
		return text.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
	}

	// What the chat asks the endpoint for its models: the base plus /models (a base that ends in /chat/completions is
	// first cut back), the same rule the model list uses for the built-in custom provider.
	static func modelsURL(for base: String) -> String {
		let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		return (trimmed.hasSuffix("/chat/completions") ? String(trimmed.dropLast("/chat/completions".count)) : trimmed) + "/models"
	}

	// What yana-rt is sent as `base_url`. For its "custom" provider that is the whole chat address: it posts to exactly
	// this string, so the path is added here (checked 2026-11-22 against a local OpenAI-style server).
	static func chatURL(for base: String) -> String {
		let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		return trimmed.hasSuffix("/chat/completions") ? trimmed : trimmed + "/chat/completions"
	}

	enum Issue: Equatable { case emptyName, nameTooLong, nameTaken, badURL, insecureURL }

	static func validate(name: String, baseURL: String, existing: [CustomProvider], editing: String?) -> Issue? {
		let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
		if clean.isEmpty { return .emptyName }
		if clean.count > maxNameLength { return .nameTooLong }
		let key = clean.lowercased()
		if existing.contains(where: { $0.id != editing && $0.name.lowercased() == key }) { return .nameTaken }
		if normalizedBaseURL(baseURL) == nil {
			let lower = baseURL.lowercased()
			return lower.hasPrefix("http://") && URL(string: baseURL)?.host != nil ? .insecureURL : .badURL
		}
		return nil
	}

	// MARK: what yana-rt is asked

	struct Wire: Equatable {
		let provider: String      // the id yana-rt knows
		let baseURL: String?
		var isCustom: Bool { baseURL != nil }
	}

	// A built-in provider goes through as it is, the old single "custom" provider keeps its own address, and one added
	// here becomes "custom" with its own address. Nil for an added provider that has since been removed.
	static func wire(for id: String, builtinBase: String, list: [CustomProvider]) -> Wire? {
		if id == "custom" { return Wire(provider: "custom", baseURL: builtinBase) }
		guard isCustom(id) else { return Wire(provider: id, baseURL: nil) }
		guard let item = list.first(where: { $0.id == id }) else { return nil }
		return Wire(provider: "custom", baseURL: chatURL(for: item.baseURL))
	}

	// The wording for the result of asking an endpoint for its models.
	static func isListingUnsupported(_ reason: String) -> Bool {
		reason == L("model.err404") || reason == L("model.err400") || reason == "HTTP 405"
	}

	@MainActor
	static func displayName(_ id: String) -> String {
		CustomProviderStore.shared.items.first { $0.id == id }?.name ?? id
	}
}

@MainActor
final class CustomProviderStore: ObservableObject {
	static let shared = CustomProviderStore()
	@Published private(set) var items: [CustomProvider]
	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		items = (defaults.data(forKey: CustomProviders.storeKey).flatMap { try? JSONDecoder().decode([CustomProvider].self, from: $0) }) ?? []
	}

	func item(_ id: String) -> CustomProvider? { items.first { $0.id == id } }

	// Adds one, or changes the one with `editing`. Nil when it was saved, otherwise what is wrong.
	@discardableResult
	func save(name: String, baseURL: String, keyless: Bool, editing: String? = nil) -> CustomProviders.Issue? {
		if let issue = CustomProviders.validate(name: name, baseURL: baseURL, existing: items, editing: editing) { return issue }
		let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = CustomProviders.normalizedBaseURL(baseURL) else { return .badURL }
		if let editing, let index = items.firstIndex(where: { $0.id == editing }) {
			items[index].name = cleanName; items[index].baseURL = url; items[index].keyless = keyless
		} else {
			let slug = CustomProviders.slug(for: cleanName, taken: Set(items.map { String($0.id.dropFirst(CustomProviders.prefix.count)) }))
			items.append(CustomProvider(id: CustomProviders.prefix + slug, name: cleanName, baseURL: url, keyless: keyless))
		}
		persist()
		return nil
	}

	// Removes it and its key; a chat bar still pointing at it goes back to a local provider.
	func remove(_ id: String) {
		guard items.contains(where: { $0.id == id }) else { return }
		items.removeAll { $0.id == id }
		AppSettings.shared.removeKey(id)
		if AppSettings.shared.provider == id {
			AppSettings.shared.provider = "ollama"
			AppSettings.shared.model = ""
		}
		persist()
	}

	private func persist() {
		if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: CustomProviders.storeKey) }
	}
}
