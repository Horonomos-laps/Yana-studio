import Foundation

// The numbers behind the menu bar panel. Reading them (`SystemProbe`) is kept apart from the arithmetic and the text
// (`SystemStats`), which the tests cover. A value macOS does not give is nil and shows as a dash, never as zero.

struct CpuTicks: Equatable {
	var busy: UInt64
	var total: UInt64
}

struct Capacity: Equatable {
	var used: UInt64
	var total: UInt64
}

enum SystemStats {
	static let historyLength = 30

	// The share of busy ticks between two readings. The kernel counters are 32-bit and wrap; a reading that went
	// backwards gives nil instead of a wrong number.
	static func cpuPercent(from old: CpuTicks, to new: CpuTicks) -> Double? {
		guard new.total > old.total, new.busy >= old.busy else { return nil }
		return min(100, Double(new.busy - old.busy) / Double(new.total - old.total) * 100)
	}

	// What Activity Monitor calls "Memory Used": app memory, wired memory and the compressor.
	static func memoryUsed(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64,
	                       compressedPages: UInt64, pageSize: UInt64) -> UInt64 {
		let app = internalPages > purgeablePages ? internalPages - purgeablePages : 0
		return (app + wiredPages + compressedPages) * pageSize
	}

	static func appended(_ history: [Double], _ value: Double?) -> [Double] {
		guard let value else { return history }
		return Array((history + [value]).suffix(historyLength))
	}

	static func percent(_ value: Double?) -> String {
		guard let value else { return "—" }
		return "\(Int(value.rounded()))%"
	}

	// Memory is counted in binary gigabytes (a "16 GB" Mac), disks in decimal ones, as macOS shows them.
	static func memory(_ capacity: Capacity?, locale: Locale) -> String {
		guard let capacity else { return "—" }
		let unit = 1_073_741_824.0
		return "\(number(Double(capacity.used) / unit, 1, locale)) / \(number(Double(capacity.total) / unit, 0, locale)) GB"
	}

	static func diskFree(_ capacity: Capacity?, locale: Locale) -> String {
		guard let capacity, capacity.total >= capacity.used else { return "—" }
		return "\(number(Double(capacity.total - capacity.used) / 1e9, 0, locale)) GB"
	}

	static func degrees(_ value: Double?) -> String? {
		value.map { "\(Int($0.rounded()))°C" }
	}

	// The chip reports many sensors. The die sensors ("tdie") describe the processor; battery and storage ones do not.
	// A reading outside the plausible range is a sensor that is switched off.
	static func chipTemperature(_ readings: [(name: String, celsius: Double)]) -> Double? {
		let die = readings.filter { $0.name.lowercased().contains("tdie") && $0.celsius > 0 && $0.celsius < 130 }
		guard !die.isEmpty else { return nil }
		return die.map(\.celsius).reduce(0, +) / Double(die.count)
	}

	private static func number(_ value: Double, _ digits: Int, _ locale: Locale) -> String {
		value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
	}
}
