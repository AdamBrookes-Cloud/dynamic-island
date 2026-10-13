
import Foundation
import Combine

@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var durationMinutes: Int
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isRunning = false

    private let availableDurations = [12, 25, 50]

    private var deadline: Date?
    private var ticker: Task<Void, Never>?

    init() {
        let savedDuration = UserDefaults.standard.integer(
            forKey: "pomodoroDurationMinutes"
        )

        let duration = availableDurations.contains(savedDuration)
            ? savedDuration
            : 25

        durationMinutes = duration
        remainingSeconds = duration * 60
    }

    var formattedTime: String {
        String(
            format: "%02d:%02d",
            remainingSeconds / 60,
            remainingSeconds % 60
        )
    }

    var progress: Double {
        let totalSeconds = durationMinutes * 60
        guard totalSeconds > 0 else { return 0 }

        return 1 - Double(remainingSeconds) / Double(totalSeconds)
    }

    func selectNextDuration() {
        let currentIndex = availableDurations.firstIndex(
            of: durationMinutes
        ) ?? 1

        setDuration(
            availableDurations[
                (currentIndex + 1) % availableDurations.count
            ]
        )
    }

    func selectPreviousDuration() {
        let currentIndex = availableDurations.firstIndex(
            of: durationMinutes
        ) ?? 1

        let previousIndex =
            (currentIndex - 1 + availableDurations.count)
            % availableDurations.count

        setDuration(availableDurations[previousIndex])
    }

    func startPause() {
        if isRunning {
            updateRemainingTime()
            ticker?.cancel()
            ticker = nil
            deadline = nil
            isRunning = false
            return
        }

        guard remainingSeconds > 0 else {
            reset()
            return
        }

        deadline = Date().addingTimeInterval(
            TimeInterval(remainingSeconds)
        )
        isRunning = true

        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: 250_000_000
                )

                guard !Task.isCancelled, let self else {
                    return
                }

                self.updateRemainingTime()

                if !self.isRunning {
                    return
                }
            }
        }
    }

    func reset() {
        ticker?.cancel()
        ticker = nil
        deadline = nil
        isRunning = false
        remainingSeconds = durationMinutes * 60
    }

    private func setDuration(_ minutes: Int) {
        guard availableDurations.contains(minutes) else { return }

        reset()
        durationMinutes = minutes
        remainingSeconds = minutes * 60

        UserDefaults.standard.set(
            minutes,
            forKey: "pomodoroDurationMinutes"
        )
    }

    private func updateRemainingTime() {
        guard isRunning, let endDate = deadline else { return }

        remainingSeconds = max(
            0,
            Int(ceil(endDate.timeIntervalSinceNow))
        )

        if remainingSeconds == 0 {
            ticker?.cancel()
            ticker = nil
            deadline = nil
            isRunning = false
        }
    }

    deinit {
        ticker?.cancel()
    }
}
