import SwiftUI

// The API keys without a trip to Settings: a key button in the chat bar next to the model chip opens this list.
// Each provider shows whether a key is saved and offers add, replace or remove; the same dialog as Settings
// (APIKeySheet) does the typing, and saving a key reloads the model list (ModelCatalog watches keyVersion).

struct ApiKeysPopover: View {
	@ObservedObject private var settings = AppSettings.shared
	let edit: (String) -> Void
	// False when no Yana Studio is installed: the set up button is then off and the reason is shown.
	let studioAvailable: Bool
	let setUp: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(L("keys.title")).font(.fbHeading5).foregroundStyle(FB.text)
			Text(L("keys.sub")).font(.fbCaption).foregroundStyle(FB.textSecondary).fixedSize(horizontal: false, vertical: true)
			ScrollView {
				VStack(spacing: 0) {
					ForEach(keyScreenProviders) { provider in row(provider) }
				}
			}
			.frame(height: 260)
			if !studioAvailable {
				Text(L("ide.notFound")).font(.fbCaption).foregroundStyle(FB.errorText).fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(14)
		.frame(width: 380)
		.background(FB.canvas)
	}

	private func row(_ provider: ProviderInfo) -> some View {
		let id = provider.id
		// A local server takes no key, so nothing is looked up or offered for it.
		let local = provider.kind == .local
		let saved = !local && settings.keyVersion >= 0 && settings.hasKey(id)
		return HStack(spacing: 8) {
			Text(id).font(.fbBodyMedium).foregroundStyle(FB.text)
			Spacer(minLength: 4)
			if local {
				Text(L("keys.notNeeded")).font(.fbCaption).foregroundStyle(FB.textSecondary)
				Button(L("keys.setUpInStudio")) { setUp() }.disabled(!studioAvailable)
			} else {
				Text(saved ? L("set.keySaved") : L("set.keyNone")).font(.fbCaption)
					.foregroundStyle(saved ? FB.successText : FB.textSecondary)
				Button(saved ? L("set.keyReplace") : L("set.keyAdd")) { edit(id) }
				if saved { Button(L("set.remove")) { settings.removeKey(id) } }
			}
		}
		.frame(height: 32)
	}
}
