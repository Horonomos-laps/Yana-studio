import AppKit
import SwiftUI

// Used by --stats only: real readings over a few seconds, then the menu bar label and the panel as a PNG, once light
// and once dark (the second file ends in -dark.png).

@MainActor
func renderStatsPanel(to path: String) {
	let monitor = SystemMonitor.shared
	monitor.start()
	RunLoop.main.run(until: Date().addingTimeInterval(SystemMonitor.interval * 4 + SystemMonitor.firstDelay))
	writePanel(monitor, appearance: .aqua, to: path)
	writePanel(monitor, appearance: .darkAqua, to: path.replacingOccurrences(of: ".png", with: "-dark.png"))
	let sample = monitor.sample
	print("cpu=\(String(describing: sample.cpu)) gpu=\(String(describing: sample.gpu)) celsius=\(String(describing: sample.celsius))")
	print("memory=\(String(describing: sample.memory)) disk=\(String(describing: sample.disk))")
	print("yana=\(monitor.apps.yana) studio=\(monitor.apps.studio)")
	monitor.stop()
}

@MainActor
private func writePanel(_ monitor: SystemMonitor, appearance: NSAppearance.Name, to path: String) {
	let view = VStack(alignment: .leading, spacing: 8) {
		Image(nsImage: MenuBarLabel.frames[0]).padding(.horizontal, 14).padding(.top, 8)
		MenuBarPanel(monitor: monitor)
	}
	.background(Color(nsColor: .windowBackgroundColor))
	.environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
	let host = NSHostingView(rootView: view)
	host.frame = NSRect(origin: .zero, size: host.fittingSize)
	let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
	window.appearance = NSAppearance(named: appearance)
	window.contentView = host
	host.layoutSubtreeIfNeeded()
	RunLoop.main.run(until: Date().addingTimeInterval(0.3))
	guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { exit(1) }
	host.cacheDisplay(in: host.bounds, to: rep)
	do {
		guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
		try png.write(to: URL(fileURLWithPath: path))
	} catch {
		FileHandle.standardError.write(Data("cannot write \(path): \(error)\n".utf8))
		exit(1)
	}
}
