import Darwin
import Foundation

// Reads processes through libproc. Read only; a process that refuses to answer is left out.

enum AppProbe {
	static func parents() -> [Int32: Int32] {
		let estimate = proc_listallpids(nil, 0)
		guard estimate > 0 else { return [:] }
		var pids = [Int32](repeating: 0, count: Int(estimate) * 2)   // room for processes started in between
		let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
		guard count > 0 else { return [:] }
		var out: [Int32: Int32] = [:]
		for pid in pids.prefix(Int(count)) where pid > 0 {
			var info = proc_bsdinfo()
			let size = Int32(MemoryLayout<proc_bsdinfo>.size)
			if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size { out[pid] = Int32(info.pbi_ppid) }
		}
		return out
	}

	static func use(of pids: Set<Int32>) -> [Int32: ProcessUse] {
		var timebase = mach_timebase_info_data_t()
		mach_timebase_info(&timebase)
		guard timebase.denom > 0 else { return [:] }
		var out: [Int32: ProcessUse] = [:]
		for pid in pids {
			var info = rusage_info_v4()
			let result = withUnsafeMutablePointer(to: &info) {
				$0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
			}
			guard result == 0 else { continue }
			// The times come in the machine's clock ticks, not in nanoseconds.
			let ticks = info.ri_user_time + info.ri_system_time
			out[pid] = ProcessUse(cpuNanos: ticks * UInt64(timebase.numer) / UInt64(timebase.denom), bytes: info.ri_phys_footprint)
		}
		return out
	}
}
