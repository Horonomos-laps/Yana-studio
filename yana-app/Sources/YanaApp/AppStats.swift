import Foundation

// What the two Yana apps use: each app's process and everything it started (helpers, yana-rt, whatever runs in its
// terminal). The arithmetic is here and tested; `AppProbe` reads the processes.

struct ProcessUse: Equatable {
	var cpuNanos: UInt64
	var bytes: UInt64
}

struct AppUse: Equatable {
	var cpu: Double?        // percent of the whole machine; nil until there are two readings
	var bytes: UInt64
}

enum AppStats {
	// The roots and all their descendants. `parents` maps a process to its parent.
	static func tree(roots: [Int32], parents: [Int32: Int32]) -> Set<Int32> {
		var children: [Int32: [Int32]] = [:]
		for (pid, parent) in parents where pid != parent { children[parent, default: []].append(pid) }
		var found = Set<Int32>(), queue = roots
		while let pid = queue.popLast() {
			guard found.insert(pid).inserted else { continue }
			queue += children[pid] ?? []
		}
		return found
	}

	// Only processes seen both times count toward CPU, so one that just started does not add its whole life at once.
	static func use(now: [Int32: ProcessUse], before: [Int32: ProcessUse]?, seconds: Double, cores: Int) -> AppUse {
		let bytes = now.values.reduce(0) { $0 + $1.bytes }
		guard let before, seconds > 0, cores > 0 else { return AppUse(cpu: nil, bytes: bytes) }
		let spent = now.reduce(UInt64(0)) { total, entry in
			guard let old = before[entry.key], entry.value.cpuNanos >= old.cpuNanos else { return total }
			return total + (entry.value.cpuNanos - old.cpuNanos)
		}
		return AppUse(cpu: min(100, Double(spent) / (seconds * 1e9 * Double(cores)) * 100), bytes: bytes)
	}

	static func size(_ bytes: UInt64, locale: Locale) -> String {
		let megabytes = Double(bytes) / 1_048_576
		if megabytes < 1024 { return "\(Int(megabytes.rounded())) MB" }
		return "\((megabytes / 1024).formatted(.number.precision(.fractionLength(1)).locale(locale))) GB"
	}

	// How many coding-agent sessions under one app are working, and how many wait for the person.
	static func sessions(_ all: [AgentSession], app: String) -> (working: Int, waiting: Int) {
		let own = all.filter { $0.appBundleID == app }
		return (own.filter { $0.state == .working }.count, own.filter { $0.state == .waiting }.count)
	}
}
