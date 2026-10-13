
import Foundation
import Combine
import Darwin
import IOKit.ps

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published private(set) var batteryPercentage: Int?
    @Published private(set) var batteryStatus = "Unavailable"

    private var previousCPUTicks: [UInt32]?

    var memoryUsage: Double {
        guard memoryTotal > 0 else { return 0 }

        return min(
            100,
            Double(memoryUsed) / Double(memoryTotal) * 100
        )
    }

    var memorySummary: String {
        "\(formattedMemory(memoryUsed)) / \(formattedMemory(memoryTotal))"
    }

    private func formattedMemory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .memory
        )
    }

    func refresh() {
        refreshCPU()
        refreshMemory()
        refreshBattery()
    }

    private func refreshCPU() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size
                / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return }

        let ticks: [UInt32] = [
            cpuInfo.cpu_ticks.0,
            cpuInfo.cpu_ticks.1,
            cpuInfo.cpu_ticks.2,
            cpuInfo.cpu_ticks.3
        ]

        if let previous = previousCPUTicks {
            let deltas = zip(ticks, previous).map {
                Double($0.0 &- $0.1)
            }

            let total = deltas.reduce(0, +)
            let idle = deltas[2]

            if total > 0 {
                cpuUsage = min(
                    100,
                    max(0, (total - idle) / total * 100)
                )
            }
        }

        previousCPUTicks = ticks
    }

    private func refreshMemory() {
        memoryTotal = ProcessInfo.processInfo.physicalMemory

        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size
                / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return }

        let availablePages = UInt64(
            statistics.free_count
                + statistics.speculative_count
                + statistics.purgeable_count
        )

        let pageSize = UInt64(vm_page_size)
        let availableBytes = availablePages * pageSize

        memoryUsed = memoryTotal > availableBytes
            ? memoryTotal - availableBytes
            : 0
    }

    private func refreshBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?
            .takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            batteryPercentage = nil
            batteryStatus = "No battery"
            return
        }

        for source in sources {
            guard let unmanagedDescription =
                IOPSGetPowerSourceDescription(snapshot, source),
                  let description = unmanagedDescription
                    .takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let current = (
                description[kIOPSCurrentCapacityKey as String] as? NSNumber
            )?.doubleValue

            let maximum = (
                description[kIOPSMaxCapacityKey as String] as? NSNumber
            )?.doubleValue

            if let current, let maximum, maximum > 0 {
                batteryPercentage = Int(
                    (current / maximum * 100).rounded()
                )
            }

            let charging = (
                description[kIOPSIsChargingKey as String] as? NSNumber
            )?.boolValue ?? false

            let externalPower =
                description[kIOPSPowerSourceStateKey as String] as? String
                == (kIOPSACPowerValue as String)

            if charging {
                batteryStatus = "Charging"
            } else if externalPower {
                batteryStatus = "Power adapter"
            } else {
                batteryStatus = "On battery"
            }

            return
        }

        batteryPercentage = nil
        batteryStatus = "Unavailable"
    }
}
