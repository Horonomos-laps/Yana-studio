import AppKit
import SwiftUI

// Each reading has one colour, used for its icon and its graph. The numbers stay in the normal text colour, so they
// read the same in light and dark.
enum Metric {
	case cpu, gpu, memory, disk, temperature

	var color: Color {
		switch self {
		case .cpu: .blue
		case .gpu: .teal
		case .memory: .green
		case .disk: .orange
		case .temperature: .pink
		}
	}

	var symbol: String {
		switch self {
		case .cpu: "cpu"
		case .gpu: "cube.fill"
		case .memory: "memorychip.fill"
		case .disk: "internaldrive.fill"
		case .temperature: "thermometer.medium"
		}
	}

	// Temperature also says how warm: green, then orange, then red. Without degrees, macOS's own level decides.
	static func heat(celsius: Double?, state: ProcessInfo.ThermalState) -> Color {
		if let celsius { return celsius < 60 ? .green : celsius < 85 ? .orange : .red }
		switch state {
		case .nominal: return .green
		case .fair: return .orange
		default: return .red
		}
	}
}

struct MenuBarPanel: View {
	static let width: CGFloat = 280

	@ObservedObject private var loc = Loc.shared
	@ObservedObject var monitor: SystemMonitor

	var body: some View {
		let sample = monitor.sample
		let locale = Locale(identifier: loc.lang.rawValue)
		VStack(alignment: .leading, spacing: 10) {
			row("CPU", .cpu, SystemStats.percent(sample.cpu), history: monitor.cpuHistory)
			row("GPU", .gpu, SystemStats.percent(sample.gpu), history: monitor.gpuHistory)
			row("RAM", .memory, SystemStats.memory(sample.memory, locale: locale), fill: share(sample.memory))
			row(L("bar.ssdFree"), .disk, SystemStats.diskFree(sample.disk, locale: locale), fill: share(sample.disk))
			row(L("bar.temperature"), .temperature, SystemStats.degrees(sample.celsius) ?? L(Self.thermalKey(sample.thermal)),
			    tint: Metric.heat(celsius: sample.celsius, state: sample.thermal))
			Divider()
			MenuBarApps(monitor: monitor.apps, canOpenStudio: monitor.editorURL != nil) {
				MenuBarController.shared.close()
				monitor.openEditor()
			}
			Divider()
			HStack {
				Button(L("bar.open")) { openApp() }.buttonStyle(.borderedProminent).tint(.blue)
				Spacer()
				Button(L("bar.quit")) { NSApplication.shared.terminate(nil) }
			}
		}
		.padding(14)
		.frame(width: Self.width)
		.fontDesign(.rounded)
	}

	static func thermalKey(_ state: ProcessInfo.ThermalState) -> String {
		switch state {
		case .nominal: "bar.thermalNominal"
		case .fair: "bar.thermalFair"
		case .serious: "bar.thermalSerious"
		case .critical: "bar.thermalCritical"
		@unknown default: "bar.thermalCritical"
		}
	}

	private func row(_ title: String, _ metric: Metric, _ value: String, history: [Double]? = nil, fill: Double? = nil,
	                 tint: Color? = nil) -> some View {
		let color = tint ?? metric.color
		return HStack(alignment: .top, spacing: 10) {
			Image(systemName: metric.symbol)
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(color)
				.frame(width: 24, height: 24)
				.background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
			VStack(alignment: .leading, spacing: 5) {
				HStack(spacing: 8) {
					Text(title)
					Spacer()
					if let history { Sparkline(values: history, color: color).frame(width: 70, height: 16) }
					Text(value).fontWeight(.semibold).monospacedDigit().frame(minWidth: 44, alignment: .trailing)
				}
				.frame(minHeight: 24)
				if let fill { Meter(share: fill, color: color).frame(height: 5) }
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(title) \(value)")
	}

	private func share(_ capacity: Capacity?) -> Double? {
		guard let capacity, capacity.total > 0 else { return nil }
		return min(1, Double(capacity.used) / Double(capacity.total))
	}

	private func openApp() {
		MenuBarController.shared.close()
		BackgroundMode.windowShown()
		_ = WindowKeeper.show()
	}
}

// How full something is, 0 to 1.
struct Meter: View {
	let share: Double
	let color: Color

	var body: some View {
		GeometryReader { space in
			ZStack(alignment: .leading) {
				Capsule().fill(color.opacity(0.18))
				Capsule().fill(color.gradient).frame(width: max(5, space.size.width * min(1, max(0, share))))
			}
		}
		.accessibilityHidden(true)
	}
}

// Percent values over time, oldest on the left, on a fixed 0 to 100 scale. The faint line marks the full width, so a
// graph with only a few readings does not look broken.
struct Sparkline: View {
	let values: [Double]
	let color: Color

	var body: some View {
		Canvas { context, size in
			let slots = CGFloat(SystemStats.historyLength)
			let step = size.width / slots
			context.fill(Path(CGRect(x: 0, y: size.height - 1, width: size.width, height: 1)), with: .color(color.opacity(0.25)))
			for (index, value) in values.enumerated() {
				let height = max(2, size.height * CGFloat(min(100, max(0, value)) / 100))
				let x = size.width - CGFloat(values.count - index) * step
				let bar = CGRect(x: x, y: size.height - height, width: max(1.2, step - 0.6), height: height)
				context.fill(Path(roundedRect: bar, cornerRadius: 0.8), with: .color(color))
			}
		}
		.accessibilityHidden(true)
	}
}
