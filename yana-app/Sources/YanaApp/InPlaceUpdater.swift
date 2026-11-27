import AppKit
import Foundation
import Sparkle

// Updates the app where it is, with Sparkle: it downloads only what changed when it can, checks the update's EdDSA
// signature, replaces the app and opens it again. It runs only in a packaged build that carries a feed address and a
// public key (scripts/package.sh adds both). Without them AppUpdater's download-and-drag path stays in use.

@MainActor
final class InPlaceUpdater: NSObject, SPUUpdaterDelegate {
	static let shared = InPlaceUpdater()

	private var controller: SPUStandardUpdaterController?

	var isOn: Bool { controller != nil }

	nonisolated static func isConfigured(_ info: [String: Any]) -> Bool {
		guard let feed = info["SUFeedURL"] as? String, let url = URL(string: feed), url.host != nil,
		      let key = info["SUPublicEDKey"] as? String, let bytes = Data(base64Encoded: key) else { return false }
		return bytes.count == 32 && (url.scheme == "https" || (url.scheme == "http" && url.host == "127.0.0.1"))
	}

	func start() {
		guard controller == nil, Self.isConfigured(Bundle.main.infoDictionary ?? [:]) else { return }
		controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
		// Debug: YANA_UPDATE_CHECK=1 looks for an update right away, to try the whole path without clicking.
		if ProcessInfo.processInfo.environment["YANA_UPDATE_CHECK"] == "1" {
			DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
				self?.controller?.updater.checkForUpdatesInBackground()
			}
		}
	}

	func check() { controller?.checkForUpdates(nil) }

	// A restart waits while Yana is writing a reply or waiting for a yes or no.
	func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
	             untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
		guard YanaActivity.shared.run.isActive else { return false }
		waitForQuiet(installHandler)
		return true
	}

	private func waitForQuiet(_ proceed: @escaping () -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
			if YanaActivity.shared.run.isActive { self?.waitForQuiet(proceed) } else { proceed() }
		}
	}
}
