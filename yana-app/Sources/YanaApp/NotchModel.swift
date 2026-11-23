import AppKit
import Combine
import SwiftUI

// What one screen's notch is doing. The controller changes it from mouse events; the view only draws it.

enum NotchTab: Int, Equatable, CaseIterable { case yana, home, clipboard }

@MainActor
final class NotchModel: ObservableObject {
	@Published var isOpen = false
	@Published var hovering = false
	@Published var tab: NotchTab = .yana
	@Published var typing = false   // a text field has the keyboard: do not close under the person's hands
	// Set from YanaActivity: something is happening (a reply is being written or a command waits for a decision).
	@Published var hasActivity = false
	@Published var glancing = false
	@Published var music: NowPlaying?            // the track playing now, nil when nothing plays
	@Published var musicTint: UInt32 = ArtworkTint.fallback
	private var yanaActive = false
	private var musicCancellable: AnyCancellable?

	let geometry: NotchGeometry
	private var cancellable: AnyCancellable?
	let displayID: CGDirectDisplayID

	init(screen: NSScreen) {
		let size = NotchGeometry.notch(topInset: screen.safeAreaInsets.top, screenWidth: screen.frame.width,
		                               leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
		                               rightAreaWidth: screen.auxiliaryTopRightArea?.width)
		geometry = NotchGeometry(notch: size)
		displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
		// Yana's own work drives the closed look: wings while busy, and a line under them while it waits for a decision.
		cancellable = YanaActivity.shared.$run.receive(on: RunLoop.main).sink { [weak self] run in
			withAnimation(.notchOpen) {
				self?.yanaActive = run.isActive
				self?.glancing = run.state == .waiting
				self?.refreshActivity()
			}
		}
		// Music playing grows the closed pill: the cover on the left wing, moving bars in the cover's color on the right.
		musicCancellable = MusicStore.shared.$nowPlaying.receive(on: RunLoop.main).sink { [weak self] track in
			guard let self else { return }
			let playing = track?.playing == true ? track : nil
			if playing?.title != self.music?.title || playing?.artworkData != self.music?.artworkData {
				self.musicTint = ArtworkTint.average(playing?.artworkData)
			}
			withAnimation(.notchOpen) { self.music = playing; self.refreshActivity() }
		}
	}

	// Yana's own work wins; otherwise a playing track is the activity.
	private func refreshActivity() { hasActivity = yanaActive || music != nil }

	var look: NotchLook {
		// Hovering a playing track (with Yana idle) slides its title out under the pill.
		NotchGeometry.look(open: isOpen, hovering: hovering, hasActivity: hasActivity,
		                   glancing: glancing || (hovering && !yanaActive && music != nil))
	}

	func open() {
		guard !isOpen else { return }
		withAnimation(.notchOpen) { isOpen = true }
		if !NotchPrefs.quiet { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
	}

	func close() {
		guard isOpen else { return }
		withAnimation(.notchClose) { isOpen = false }
	}

	func setHovering(_ value: Bool) {
		guard value != hovering else { return }
		withAnimation(.notchHover) { hovering = value }
	}
}

enum NotchPrefs {
	static let enabledKey = "yana.notch.enabled"
	static let quietKey = "yana.notch.noHaptics"
	static let hoverKey = "yana.notch.openOnHover"
	static let solidKey = "yana.notch.solid"
	static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
	static var quiet: Bool { UserDefaults.standard.bool(forKey: quietKey) }
	// On unless switched off: resting the pointer on the notch opens it.
	static var openOnHover: Bool { UserDefaults.standard.object(forKey: hoverKey) as? Bool ?? true }
	// The open panel is see-through frosted glass unless the person wants it solid black.
	static var solid: Bool { UserDefaults.standard.bool(forKey: solidKey) }
}
