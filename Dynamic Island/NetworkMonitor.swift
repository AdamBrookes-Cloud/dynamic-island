
import Foundation
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var downloadMbps: Double = 0
    @Published private(set) var uploadMbps: Double = 0
    @Published private(set) var latencyMilliseconds: Double?
    @Published private(set) var isConnected = false

    private var previousDownloadBytes: UInt64?
    private var previousUploadBytes: UInt64?
    private var previousSampleDate: Date?
    private var lastLatencyCheck = Date.distantPast
    private var isCheckingLatency = false

    func refresh() {
        let now = Date()

        guard let counters = readNetworkCounters() else {
            isConnected = false
            downloadMbps = 0
            uploadMbps = 0
            return
        }

        isConnected = true

        if let previousDownloadBytes,
           let previousUploadBytes,
           let previousSampleDate {
            let elapsed = now.timeIntervalSince(previousSampleDate)

            if elapsed > 0 {
                let downloaded = counters.download >= previousDownloadBytes
                    ? counters.download - previousDownloadBytes : 0

                let uploaded = counters.upload >= previousUploadBytes
                    ? counters.upload - previousUploadBytes : 0

                downloadMbps = Double(downloaded) * 8 / elapsed / 1_000_000
                uploadMbps = Double(uploaded) * 8 / elapsed / 1_000_000
            }
        }

        previousDownloadBytes = counters.download
        previousUploadBytes = counters.upload
        previousSampleDate = now

        if now.timeIntervalSince(lastLatencyCheck) >= 5,
           !isCheckingLatency {
            checkLatency()
        }
    }

    private func readNetworkCounters() -> (
        download: UInt64,
        upload: UInt64
    )? {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-ibn"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else {
                return nil
            }

            let lines = text.components(separatedBy: .newlines)

            guard let headerLine = lines.first(where: {
                $0.contains("Ibytes") && $0.contains("Obytes")
            }) else {
                return nil
            }

            let headers = headerLine.split(
                whereSeparator: { $0.isWhitespace }
            ).map(String.init)

            guard let inputIndex = headers.firstIndex(of: "Ibytes"),
                  let outputIndex = headers.firstIndex(of: "Obytes") else {
                return nil
            }

            guard let interfaceLine = lines.first(where: {
                let fields = $0.split(
                    whereSeparator: { $0.isWhitespace }
                )
                return fields.first == "en0"
                    && fields.count > max(inputIndex, outputIndex)
            }) else {
                return nil
            }

            let fields = interfaceLine.split(
                whereSeparator: { $0.isWhitespace }
            )

            guard let received = UInt64(fields[inputIndex]),
                  let sent = UInt64(fields[outputIndex]) else {
                return nil
            }

            return (download: received, upload: sent)
        } catch {
            return nil
        }
    }

    private func checkLatency() {
        isCheckingLatency = true
        lastLatencyCheck = Date()

        Task.detached(priority: .utility) { [weak self] in
            let process = Process()
            let output = Pipe()

            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "1500", "1.1.1.1"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            var result: Double?

            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if process.terminationStatus == 0,
                   let text = String(data: data, encoding: .utf8),
                   let range = text.range(
                    of: #"time[=<]([0-9.]+)"#,
                    options: .regularExpression
                   ) {
                    let match = String(text[range])
                    let number = match
                        .replacingOccurrences(of: "time=", with: "")
                        .replacingOccurrences(of: "time<", with: "")

                    result = Double(number)
                }
            } catch {
                result = nil
            }

            await MainActor.run {
                self?.latencyMilliseconds = result
                self?.isCheckingLatency = false
            }
        }
    }
}
