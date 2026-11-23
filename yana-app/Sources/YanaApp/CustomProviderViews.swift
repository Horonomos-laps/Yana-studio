import SwiftUI

// Settings > Models and keys: the list of providers the person added, and the sheet that adds or changes one.

struct ProviderSheetTarget: Identifiable {
	let id = UUID()
	let editing: CustomProvider?
}

extension CustomProviders {
	// What the Test connection button tells the person. An endpoint that answers but has no model list is still a
	// working one (Perplexity, GitHub Models): the model name is typed when it is chosen.
	static func probeResult(state: ProviderModels.State, models: [String]) -> (ok: Bool, text: String) {
		switch state {
		case .ready:
			return models.isEmpty ? (true, L("prov.testNoList")) : (true, String(format: L("prov.testOK"), models.count))
		case .failed(let reason):
			return isListingUnsupported(reason) ? (true, L("prov.testNoList")) : (false, reason)
		case .loading, .manual:
			return (false, "")
		}
	}

	static func message(for issue: Issue) -> String {
		switch issue {
		case .emptyName: return L("prov.errName")
		case .nameTooLong: return L("prov.errNameLong")
		case .nameTaken: return L("prov.errNameTaken")
		case .badURL: return L("prov.errURL")
		case .insecureURL: return L("prov.errInsecure")
		}
	}
}

struct CustomProviderSheet: View {
	let editing: CustomProvider?
	let close: () -> Void
	@ObservedObject private var store = CustomProviderStore.shared
	@State private var name = ""
	@State private var url = ""
	@State private var key = ""
	@State private var keyless = false
	@State private var reveal = false
	@State private var testing = false
	@State private var result: (ok: Bool, text: String)? = nil
	@State private var issue: CustomProviders.Issue? = nil

	private var hosted: [ProviderPreset] { CustomProviders.presets.filter { !$0.local } }
	private var local: [ProviderPreset] { CustomProviders.presets.filter(\.local) }

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 12) {
				FBIcon(name: "cpu", size: 20, color: FB.primaryText)
					.frame(width: 40, height: 40)
					.background(RoundedRectangle(cornerRadius: 10).fill(FB.primarySubtle))
				VStack(alignment: .leading, spacing: 2) {
					Text(L(editing == nil ? "prov.sheetAdd" : "prov.sheetEdit")).font(.system(size: 16, weight: .semibold)).foregroundStyle(FB.text)
					Text(L("prov.sheetSub")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				}
			}

			if editing == nil {
				VStack(alignment: .leading, spacing: 8) {
					Text(L("prov.quick")).font(.fbBodyMedium).foregroundStyle(FB.text)
					chips(L("prov.hosted"), hosted)
					chips(L("prov.localGroup"), local)
				}
			}

			VStack(alignment: .leading, spacing: 10) {
				field(L("prov.name")) { TextField(L("prov.namePrompt"), text: $name).textFieldStyle(.roundedBorder) }
				field(L("prov.url")) {
					TextField("https://…/v1", text: $url).textFieldStyle(.roundedBorder).font(.system(size: 13, design: .monospaced))
				}
				Toggle(L("prov.keyless"), isOn: $keyless)
				if !keyless {
					field(L("prov.key")) {
						HStack(spacing: 8) {
							Group { if reveal { TextField("sk-…", text: $key) } else { SecureField("sk-…", text: $key) } }
								.textFieldStyle(.roundedBorder).font(.system(size: 13, design: .monospaced))
							FBIconButton(icon: reveal ? "eye-off" : "eye", variant: .ghost, size: .small,
							             tooltip: reveal ? L("set.keyHide") : L("set.keyShow")) { reveal.toggle() }
						}
					}
					if editing != nil { Text(L("prov.keyKeep")).font(.fbCaption).foregroundStyle(FB.textSecondary) }
				}
			}

			if let issue { Text(CustomProviders.message(for: issue)).font(.fbCaption).foregroundStyle(FB.errorText) }
			if let result, !result.text.isEmpty {
				Text(result.text).font(.fbCaption).foregroundStyle(result.ok ? FB.successText : FB.errorText)
					.fixedSize(horizontal: false, vertical: true)
			}

			HStack(spacing: 8) {
				FBButton(title: L(testing ? "prov.testing" : "prov.test"), variant: .secondary, size: .small) { test() }
					.disabled(testing || CustomProviders.normalizedBaseURL(url) == nil)
				Spacer()
				FBButton(title: L("store.cancel"), variant: .secondary, size: .small, action: close)
				FBButton(title: L("history.save"), variant: .primary, size: .small, action: save)
			}
		}
		.padding(24)
		.frame(width: 540)
		.onAppear {
			guard let editing else { return }
			name = editing.name; url = editing.baseURL; keyless = editing.keyless
		}
		.onChange(of: name) { _, _ in issue = nil }
		.onChange(of: url) { _, _ in issue = nil; result = nil }
	}

	private func field<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(title).font(.fbBodyMedium).foregroundStyle(FB.text)
			content()
		}
	}

	private func chips(_ title: String, _ presets: [ProviderPreset]) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title).font(.fbCaption).foregroundStyle(FB.textTertiary)
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
				ForEach(presets) { preset in
					let chosen = url == preset.baseURL && name == preset.name
					Button { apply(preset) } label: {
						Text(preset.name).font(.fbCaption).lineLimit(1)
							.foregroundStyle(chosen ? FB.onPrimary : FB.text)
							.padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: 28)
							.background(Capsule().fill(chosen ? FB.primary : FB.surfaceTertiary))
					}
					.buttonStyle(.plain)
					.help(preset.baseURL)
				}
			}
		}
	}

	private func apply(_ preset: ProviderPreset) {
		name = preset.name; url = preset.baseURL; keyless = preset.keyless
		result = nil; issue = nil
	}

	private func test() {
		guard let base = CustomProviders.normalizedBaseURL(url) else { issue = .badURL; return }
		let typed = key.trimmingCharacters(in: .whitespacesAndNewlines)
		let keyValue = keyless ? nil : (typed.isEmpty ? editing.flatMap { AppSettings.shared.apiKey($0.id) } : typed)
		testing = true
		result = nil
		Task {
			let (state, models) = await ModelCatalog.probe(baseURL: base, key: keyValue)
			testing = false
			result = CustomProviders.probeResult(state: state, models: models)
		}
	}

	private func save() {
		if let problem = store.save(name: name, baseURL: url, keyless: keyless, editing: editing?.id) { issue = problem; return }
		guard let id = editing?.id ?? store.items.last?.id else { return }
		let typed = key.trimmingCharacters(in: .whitespacesAndNewlines)
		if keyless { AppSettings.shared.removeKey(id) } else if !typed.isEmpty { AppSettings.shared.saveKey(typed, for: id) }
		close()
	}
}

let providerRows: [StringRow] = [
	StringRow("prov.header", "Nhà cung cấp riêng", "Your own providers", "내 공급자"),
	StringRow("prov.footer", "Thêm bất kỳ dịch vụ nào tương thích OpenAI (hoặc server chạy trên máy) mà không cần cập nhật yana-rt. Khóa lưu trong Keychain và chỉ gửi đến đúng nhà cung cấp đó.",
	          "Add any OpenAI-compatible service (or a server on this Mac) without updating yana-rt. The key is kept in the Keychain and sent only to that provider.",
	          "yana-rt를 업데이트하지 않고 OpenAI 호환 서비스(또는 이 Mac의 서버)를 추가하세요. 키는 키체인에 저장되며 해당 공급자에게만 전송됩니다."),
	StringRow("prov.add", "Thêm nhà cung cấp…", "Add a provider…", "공급자 추가…"),
	StringRow("prov.edit", "Sửa", "Edit", "편집"),
	StringRow("prov.none", "Chưa có nhà cung cấp riêng nào.", "No providers of your own yet.", "아직 추가한 공급자가 없습니다."),
	StringRow("prov.sheetAdd", "Thêm nhà cung cấp", "Add a provider", "공급자 추가"),
	StringRow("prov.sheetEdit", "Sửa nhà cung cấp", "Edit the provider", "공급자 편집"),
	StringRow("prov.sheetSub", "Dùng được với mọi dịch vụ có API kiểu OpenAI (/chat/completions).", "Works with any service that has an OpenAI-style API (/chat/completions).", "OpenAI 방식 API(/chat/completions)를 제공하는 모든 서비스에서 작동합니다."),
	StringRow("prov.quick", "Chọn nhanh", "Quick pick", "빠른 선택"),
	StringRow("prov.hosted", "Dịch vụ trên mạng", "Hosted services", "온라인 서비스"),
	StringRow("prov.localGroup", "Chạy trên máy bạn", "On this Mac", "이 Mac에서 실행"),
	StringRow("prov.name", "Tên", "Name", "이름"),
	StringRow("prov.namePrompt", "Ví dụ: Together AI", "For example: Together AI", "예: Together AI"),
	StringRow("prov.url", "Đường dẫn API (base URL)", "API address (base URL)", "API 주소(base URL)"),
	StringRow("prov.key", "Khóa API", "API key", "API 키"),
	StringRow("prov.keyKeep", "Để trống để giữ khóa đang lưu.", "Leave blank to keep the saved key.", "비워 두면 저장된 키를 유지합니다."),
	StringRow("prov.keyless", "Không cần khóa (server chạy trên máy)", "No key needed (a server on this Mac)", "키 불필요(이 Mac의 서버)"),
	StringRow("prov.test", "Thử kết nối", "Test connection", "연결 테스트"),
	StringRow("prov.testing", "Đang thử…", "Testing…", "테스트 중…"),
	StringRow("prov.testOK", "Kết nối được, có %d mô hình.", "Connected, %d models found.", "연결되었습니다. 모델 %d개를 찾았습니다."),
	StringRow("prov.testNoList", "Kết nối được, nhưng nhà cung cấp không liệt kê mô hình. Gõ tên mô hình khi chọn trong thanh chat.", "Connected, but the provider does not list its models. Type the model name when you pick it in the chat bar.", "연결되었지만 공급자가 모델 목록을 제공하지 않습니다. 채팅창에서 선택할 때 모델 이름을 입력하세요."),
	StringRow("prov.errName", "Hãy đặt tên cho nhà cung cấp.", "Give the provider a name.", "공급자 이름을 입력하세요."),
	StringRow("prov.errNameLong", "Tên quá dài (tối đa 40 ký tự).", "The name is too long (40 characters at most).", "이름이 너무 깁니다(최대 40자)."),
	StringRow("prov.errNameTaken", "Đã có nhà cung cấp tên này.", "A provider with this name already exists.", "같은 이름의 공급자가 이미 있습니다."),
	StringRow("prov.errURL", "Đường dẫn chưa đúng. Cần dạng https://… và không kèm tên đăng nhập hay tham số.", "That address does not look right. Use https://… with no username or parameters.", "주소가 올바르지 않습니다. 사용자 이름이나 매개변수 없이 https://… 형식을 사용하세요."),
	StringRow("prov.errInsecure", "Chỉ server trên máy bạn (127.0.0.1, localhost) được dùng http. Dịch vụ trên mạng cần https để khóa không bị lộ.", "Only a server on this Mac (127.0.0.1, localhost) may use http. Online services need https so the key is not exposed.", "이 Mac의 서버(127.0.0.1, localhost)만 http를 쓸 수 있습니다. 온라인 서비스는 키가 노출되지 않도록 https가 필요합니다."),
	StringRow("prov.removed", "Nhà cung cấp này đã bị xóa. Hãy chọn nhà cung cấp khác ở thanh chat.", "This provider was removed. Pick another one in the chat bar.", "이 공급자는 삭제되었습니다. 채팅창에서 다른 공급자를 선택하세요."),
]
