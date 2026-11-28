import Darwin
import Foundation
import IOKit

// Reads the machine. Every function returns nil when macOS gives nothing.

enum SystemProbe {
	static func cpuTicks() -> CpuTicks? {
		var info = host_cpu_load_info()
		var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
		let host = mach_host_self()
		defer { mach_port_deallocate(mach_task_self_, host) }
		let result = withUnsafeMutablePointer(to: &info) {
			$0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
		}
		guard result == KERN_SUCCESS else { return nil }
		let (user, system, idle, nice) = info.cpu_ticks
		let busy = UInt64(user) + UInt64(system) + UInt64(nice)
		return CpuTicks(busy: busy, total: busy + UInt64(idle))
	}

	static func memory() -> Capacity? {
		var info = vm_statistics64()
		var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
		let host = mach_host_self()
		defer { mach_port_deallocate(mach_task_self_, host) }
		let result = withUnsafeMutablePointer(to: &info) {
			$0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
		}
		var pageSize: vm_size_t = 0
		guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
		let used = SystemStats.memoryUsed(
			internalPages: UInt64(info.internal_page_count), purgeablePages: UInt64(info.purgeable_count),
			wiredPages: UInt64(info.wire_count), compressedPages: UInt64(info.compressor_page_count),
			pageSize: UInt64(pageSize))
		return Capacity(used: used, total: ProcessInfo.processInfo.physicalMemory)
	}

	// The startup disk. "Available for important usage" counts space macOS can free by itself, as Finder does.
	static func disk() -> Capacity? {
		let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
		guard let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys),
		      let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacityForImportantUsage,
		      total > 0, free >= 0, Int64(total) >= free else { return nil }
		return Capacity(used: UInt64(Int64(total) - free), total: UInt64(total))
	}

	// The graphics driver publishes its own load in the IO registry.
	static func gpuPercent() -> Double? {
		var iterator: io_iterator_t = 0
		guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS
		else { return nil }
		defer { IOObjectRelease(iterator) }
		var best: Double?
		var entry = IOIteratorNext(iterator)
		while entry != 0 {
			let property = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)
			let statistics = property?.takeRetainedValue() as? [String: Any]
			if let load = (statistics?["Device Utilization %"] as? NSNumber)?.doubleValue {
				best = max(best ?? 0, min(100, max(0, load)))
			}
			IOObjectRelease(entry)
			entry = IOIteratorNext(iterator)
		}
		return best
	}

	// macOS's own four-step answer, used when the sensors cannot be read.
	static func thermalState() -> ProcessInfo.ThermalState { ProcessInfo.processInfo.thermalState }
}
