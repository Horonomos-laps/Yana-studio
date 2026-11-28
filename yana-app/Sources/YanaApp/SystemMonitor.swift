import Foundation

// Samples the machine every two seconds, only while the menu bar panel is on screen, so a closed panel costs nothing.

struct SystemSample {
	var cpu: Double?
	var gpu: Double?
	var memory: Capacity?
	var disk: Capacity?
	var celsius: Double?
	var thermal: ProcessInfo.ThermalState = .nominal
}

@MainActor
final class SystemMonitor: ObservableObject {
	static let shared = SystemMonitor()
	static let interval: TimeInterval = 2
	static let firstDelay: TimeInterval = 0.5   // CPU load needs two readings; the second comes quickly

	@Published private(set) var sample = SystemSample()
	@Published private(set) var cpuHistory: [Double] = []
	@Published private(set) var gpuHistory: [Double] = []

	let apps = AppsMonitor()
	private let editor = EditorLauncher()
	var editorURL: URL? { editor.appURL }
	func openEditor() { editor.open(folder: RtClient.workspace()) }

	private var timer: Timer?
	private var lastTicks: CpuTicks?
	private lazy var sensors = TemperatureSensors()

	var running: Bool { timer != nil }

	func start() {
		guard timer == nil else { return }
		lastTicks = SystemProbe.cpuTicks()
		cpuHistory = []
		gpuHistory = []
		apps.reset()
		refresh()
		DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstDelay) { [weak self] in
			guard let self, self.running else { return }
			self.refresh()
		}
		let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
			Task { @MainActor in self?.refresh() }
		}
		RunLoop.main.add(timer, forMode: .common)   // keeps counting while a menu is being tracked
		self.timer = timer
	}

	func stop() {
		timer?.invalidate()
		timer = nil
	}

	func refresh() {
		let ticks = SystemProbe.cpuTicks()
		var cpu = sample.cpu
		if let old = lastTicks, let new = ticks, let value = SystemStats.cpuPercent(from: old, to: new) {
			cpu = value
			cpuHistory = SystemStats.appended(cpuHistory, value)
			lastTicks = new
		}
		let gpu = SystemProbe.gpuPercent()
		gpuHistory = SystemStats.appended(gpuHistory, gpu)
		sample = SystemSample(cpu: cpu, gpu: gpu, memory: SystemProbe.memory(), disk: SystemProbe.disk(),
		                      celsius: sensors.flatMap { SystemStats.chipTemperature($0.readings()) },
		                      thermal: SystemProbe.thermalState())
		apps.refresh(editor: editorURL)
	}
}
