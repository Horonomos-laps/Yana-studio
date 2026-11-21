import AppKit
import CoreGraphics
import ScreenCaptureKit

// Appshot: one press attaches a picture of the window the person was just looking at, so the AI can see it.
// It takes the topmost window of another app (the one behind Yana's own window), never Yana's. The picture
// lands in the chat box as an ordinary image attachment with a thumbnail, so it can be removed before sending.
// Nothing is sent until the person sends the message. macOS asks once for Screen Recording permission.

struct AppshotWindow: Equatable {
	let id: CGWindowID
	let owner: String
	let title: String
	let pid: pid_t
	let layer: Int
	let alpha: Double
	let width: Double
	let height: Double
}

enum AppshotFailure: Error, Equatable {
	case needsPermission, noWindow, captureFailed(String)

	var messageKey: String? {
		switch self {
		case .needsPermission: return "appshot.needsPermission"
		case .noWindow: return "appshot.noWindow"
		case .captureFailed: return nil
		}
	}

	static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
}

enum Appshot {
	// Parts of macOS that own windows but are not something to show the AI.
	static let ignoredOwners: Set<String> = ["Window Server", "Dock", "WindowManager", "Control Center", "Notification Center",
	                                         "SystemUIServer", "Spotlight", "loginwindow"]
	// A window smaller than this in either direction is a badge or a tooltip, not a window.
	static let minSide = 120.0

	// `windows` is front to back, the order the window list gives. Returns the first real window that is
	// not ours, or nil when there is none.
	static func pickTarget(from windows: [AppshotWindow], excludingPID own: pid_t) -> AppshotWindow? {
		windows.first { w in
			w.pid != own && w.layer == 0 && w.alpha > 0.01 && w.width >= minSide && w.height >= minSide
				&& !ignoredOwners.contains(w.owner)
		}
	}

	// A file name for the attachment: "Appshot - Safari - Page title.png", without path characters.
	static func fileName(owner: String, title: String) -> String {
		let bad = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
		func clean(_ s: String) -> String { s.components(separatedBy: bad).joined(separator: " ").trimmingCharacters(in: .whitespaces) }
		let parts = [clean(owner), String(clean(title).prefix(60))].filter { !$0.isEmpty }
		return (["Appshot"] + parts).joined(separator: " - ") + ".png"
	}

	// The on-screen windows, front to back. Titles are filled in only when Screen Recording is allowed.
	static func onScreenWindows() -> [AppshotWindow] {
		guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
		else { return [] }
		return list.compactMap { info in
			guard let number = info[kCGWindowNumber as String] as? UInt32,
			      let pid = info[kCGWindowOwnerPID as String] as? Int32,
			      let bounds = info[kCGWindowBounds as String] as? [String: Double] else { return nil }
			return AppshotWindow(id: number, owner: info[kCGWindowOwnerName as String] as? String ?? "",
			                     title: info[kCGWindowName as String] as? String ?? "", pid: pid,
			                     layer: info[kCGWindowLayer as String] as? Int ?? 0,
			                     alpha: info[kCGWindowAlpha as String] as? Double ?? 1,
			                     width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
		}
	}

	// Takes the picture. Asks for Screen Recording permission the first time (macOS shows its own dialog).
	@MainActor
	static func capture() async -> Result<(image: NSImage, name: String), AppshotFailure> {
		guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else { return .failure(.needsPermission) }
		guard let target = pickTarget(from: onScreenWindows(), excludingPID: ProcessInfo.processInfo.processIdentifier) else {
			return .failure(.noWindow)
		}
		do {
			let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
			guard let window = content.windows.first(where: { $0.windowID == target.id }) else { return .failure(.noWindow) }
			let filter = SCContentFilter(desktopIndependentWindow: window)
			let config = SCStreamConfiguration()
			// Real pixels of the window, at the screen's scale, so text stays readable; ChatImages scales it down later.
			let scale = NSScreen.main?.backingScaleFactor ?? 2
			config.width = max(1, Int(window.frame.width * scale))
			config.height = max(1, Int(window.frame.height * scale))
			config.showsCursor = false
			let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
			let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
			return .success((image, fileName(owner: target.owner, title: window.title ?? target.title)))
		} catch {
			return .failure(.captureFailed(error.localizedDescription))
		}
	}
}

extension Notification.Name {
	// Sent by the menu once the chat page is showing; the chat box attaches the picture.
	static let yanaAppshotNow = Notification.Name("ai.yana.appshotNow")
}
