import Foundation
import Darwin

@Observable
class SystemMonitor {
    static let shared = SystemMonitor()

    var cpuUsage: Double = 0        // 0–100
    var memoryUsed: Double = 0      // GB
    var memoryTotal: Double = 0     // GB

    var memoryPercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return (memoryUsed / memoryTotal) * 100
    }

    private var pollTimer: Timer?
    private var previousCPUInfo: host_cpu_load_info?

    private init() {
        memoryTotal = Self.physicalMemoryGB()
        fetchCPU()
        fetchMemory()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchCPU()
            self?.fetchMemory()
        }
    }

    // MARK: - CPU (Mach host_processor_info)

    private func fetchCPU() {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &cpuLoad) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(host, HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let user = Double(cpuLoad.cpu_ticks.0)    // CPU_STATE_USER
        let system = Double(cpuLoad.cpu_ticks.1)  // CPU_STATE_SYSTEM
        let idle = Double(cpuLoad.cpu_ticks.2)    // CPU_STATE_IDLE
        let nice = Double(cpuLoad.cpu_ticks.3)    // CPU_STATE_NICE

        if let prev = previousCPUInfo {
            let prevUser = Double(prev.cpu_ticks.0)
            let prevSystem = Double(prev.cpu_ticks.1)
            let prevIdle = Double(prev.cpu_ticks.2)
            let prevNice = Double(prev.cpu_ticks.3)

            let totalDelta = (user - prevUser) + (system - prevSystem) + (idle - prevIdle) + (nice - prevNice)
            let usedDelta = (user - prevUser) + (system - prevSystem) + (nice - prevNice)

            if totalDelta > 0 {
                cpuUsage = (usedDelta / totalDelta) * 100
            }
        }
        previousCPUInfo = cpuLoad
    }

    // MARK: - Memory (Mach host_statistics64)

    private func fetchMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        // "Used" = active + wired + compressed (same as Activity Monitor)
        memoryUsed = (active + wired + compressed) / 1_073_741_824 // bytes → GB
    }

    private static func physicalMemoryGB() -> Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    }
}
