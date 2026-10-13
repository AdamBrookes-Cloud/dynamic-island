import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var spotify = SpotifyController()
    @StateObject private var systemMonitor = SystemMonitor()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var pomodoro = PomodoroTimer()

    @State private var isHovering = false
    @State private var isPinned = false
    @State private var hoverExitToken = UUID()

    private var isExpanded: Bool {
        isHovering || isPinned
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    private var cardBackground: Color {
        Color.white.opacity(0.09)
    }

    private var panelBackground: Color {
        Color.white.opacity(0.055)
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 8) {
                    musicWidget
                    systemWidget
                    networkPomodoroWidget
                    DownloadsWidget()
                    WeatherWidget()
                }
                .transition(.opacity)
                .onHover { hovering in
                    updateHover(hovering)
                }
            }
        }
        .padding(isExpanded ? 14 : 4)
        .frame(width: isExpanded ? 600 : 300, alignment: .top)
        .background {
            RoundedRectangle(
                cornerRadius: isExpanded ? 24 : 17,
                style: .continuous
            )
            .fill(.black)
        }
        .frame(width: 600, height: 200, alignment: .top)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .foregroundStyle(.white)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.85),
            value: isExpanded
        )
        .task {
            while !Task.isCancelled {
                spotify.refresh()
                systemMonitor.refresh()
                networkMonitor.refresh()

                try? await Task.sleep(
                    nanoseconds: 2_000_000_000
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))

            Text("Dynamic Island")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 300)

            if isExpanded {
                Button {
                    isPinned.toggle()

                    if !isPinned && !isHovering {
                        updateHover(false)
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin dashboard" : "Keep dashboard open")
            } else {
                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isExpanded ? 4 : 10)
        .frame(height: isExpanded ? 20 : 26)
        .contentShape(Rectangle())
        .onHover { hovering in
            updateHover(hovering)
        }
        .onTapGesture {
            if isPinned {
                isPinned = false
                updateHover(false)
            } else {
                isPinned = true
                isHovering = true
            }
        }
    }

    // MARK: - Hover Behaviour

    private func updateHover(_ hovering: Bool) {
        if hovering {
            hoverExitToken = UUID()
            isHovering = true
            return
        }

        let exitToken = UUID()
        hoverExitToken = exitToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard hoverExitToken == exitToken, !isPinned else {
                return
            }

            isHovering = false
        }
    }

    // MARK: - Music

    private var musicWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetTitle("Music", icon: "music.note")

            Button {
                openApplication("com.spotify.client")
            } label: {
                HStack(spacing: 6) {
                    albumArtwork

                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            spotify.trackName.isEmpty
                                ? "Not Playing"
                                : spotify.trackName
                        )
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(
                            spotify.artistName.isEmpty
                                ? "Spotify"
                                : spotify.artistName
                        )
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Spotify")

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                playbackButton(
                    symbol: "backward.fill",
                    help: "Previous track",
                    action: spotify.previousTrack
                )

                Spacer(minLength: 0)

                playbackButton(
                    symbol: spotify.isPlaying ? "pause.fill" : "play.fill",
                    help: spotify.isPlaying ? "Pause" : "Play",
                    action: spotify.togglePlayback
                )

                Spacer(minLength: 0)

                playbackButton(
                    symbol: "forward.fill",
                    help: "Next track",
                    action: spotify.nextTrack
                )
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(
                        spotify.isPlaying
                            ? .green
                            : .white.opacity(0.4)
                    )
                    .frame(width: 5, height: 5)

                Text(spotify.isPlaying ? "Playing" : "Paused")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .padding(8)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var albumArtwork: some View {
        Group {
            if let artwork = spotify.albumArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.08))

                    Image(systemName: "music.note")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
    }

    private func playbackButton(
        symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 23, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - System

    private var systemWidget: some View {
        Button {
            openApplication("com.apple.ActivityMonitor")
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                widgetTitle("System", icon: "cpu")

                systemMetric(
                    title: "CPU",
                    value: "\(Int(systemMonitor.cpuUsage.rounded()))%",
                    progress: systemMonitor.cpuUsage
                )

                systemMetric(
                    title: "Memory",
                    value: "\(Int(systemMonitor.memoryUsage.rounded()))%",
                    progress: systemMonitor.memoryUsage
                )

                HStack(spacing: 5) {
                    Image(
                        systemName: systemMonitor.batteryStatus == "Charging"
                            ? "battery.100percent.bolt"
                            : "battery.75percent"
                    )
                    .font(.system(size: 10))

                    Text("Battery")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.65))

                    Spacer(minLength: 0)

                    Text(
                        systemMonitor.batteryPercentage.map { "\($0)%" }
                            ?? "N/A"
                    )
                    .font(.system(size: 8, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 112)
            .padding(8)
            .background(
                cardBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            "Open Activity Monitor\n"
                + "Memory: \(systemMonitor.memorySummary)\n"
                + "Battery: \(systemMonitor.batteryStatus)"
        )
    }

    private func systemMetric(
        title: String,
        value: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(title)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer(minLength: 0)

                Text(value)
                    .foregroundStyle(.white)
            }
            .font(.system(size: 8, weight: .medium))

            ProgressView(
                value: min(100, max(0, progress)),
                total: 100
            )
            .tint(.white.opacity(0.85))
            .scaleEffect(x: 1, y: 0.65, anchor: .center)
        }
    }

    // MARK: - Network and Pomodoro

    private var networkPomodoroWidget: some View {
        VStack(spacing: 7) {
            Button {
                openApplication("com.apple.ActivityMonitor")
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    widgetTitle("Network", icon: "network")

                    metricRow(
                        title: "Down",
                        value: String(
                            format: "%.1f Mbps",
                            networkMonitor.downloadMbps
                        )
                    )

                    metricRow(
                        title: "Up",
                        value: String(
                            format: "%.1f Mbps",
                            networkMonitor.uploadMbps
                        )
                    )

                    metricRow(
                        title: "Ping",
                        value: networkMonitor.latencyMilliseconds.map {
                            String(format: "%.0f ms", $0)
                        } ?? "—"
                    )
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    panelBackground,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Activity Monitor")

            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))

                    Text("Pomodoro")
                        .font(.system(size: 9, weight: .semibold))

                    Spacer(minLength: 1)

                    Button {
                        pomodoro.selectPreviousDuration()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .help("Previous duration")
                    .buttonStyle(.plain)

                    Button {
                        pomodoro.selectNextDuration()
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .help("Next duration")
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white.opacity(0.8))
                .font(.system(size: 9))

                Button {
                    pomodoro.startPause()
                } label: {
                    Text(pomodoro.formattedTime)
                        .font(
                            .system(
                                size: 15,
                                weight: .semibold,
                                design: .monospaced
                            )
                        )
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Start or pause timer")

                HStack(spacing: 14) {
                    Button {
                        pomodoro.startPause()
                    } label: {
                        Image(
                            systemName: pomodoro.isRunning
                                ? "pause.fill"
                                : "play.fill"
                        )
                    }
                    .help(pomodoro.isRunning ? "Pause" : "Start")
                    .buttonStyle(.plain)

                    Button {
                        pomodoro.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset timer")
                    .buttonStyle(.plain)
                }
                .font(.system(size: 9))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                cardBackground,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .frame(height: 148)
    }

    // MARK: - Shortcuts

    private var shortcutsWidget: some View {
        VStack(alignment: .leading, spacing: 9) {
            widgetTitle("Shortcuts", icon: "command")

            Spacer(minLength: 0)

            Button {
                openApplication("com.apple.shortcuts")
            } label: {
                Label("Shortcuts", systemImage: "bolt.fill")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                openApplication("com.apple.systempreferences")
            } label: {
                Label("Settings", systemImage: "gear")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(height: 112)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - Shared Helpers

    private func widgetTitle(
        _ title: String,
        icon: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))

            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    private func metricRow(
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundStyle(.white.opacity(0.55))

            Spacer(minLength: 2)

            Text(value)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 9))
    }

    private func openApplication(_ bundleIdentifier: String) {
        guard let applicationURL = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            print("Could not find application: \(bundleIdentifier)")
            return
        }

        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                print("Could not open \(bundleIdentifier): \(error)")
            }
        }
    }
}
