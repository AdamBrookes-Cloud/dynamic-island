import SwiftUI

struct ContentView: View {
    @State private var isHovering = false
    @State private var isPinned = false
    @State private var hoverExitToken = UUID()

    @StateObject private var spotify = SpotifyController()

    private var isExpanded: Bool {
        isHovering || isPinned
    }

    private let widgets: [IslandWidget] = [
        IslandWidget(title: "Music", column: 0, row: 0),
        IslandWidget(title: "System", column: 1, row: 0),
        IslandWidget(title: "Calendar", column: 2, row: 0),
        IslandWidget(title: "Downloads", column: 3, row: 0),
        IslandWidget(title: "Shortcuts", column: 4, row: 0)
    ]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    var body: some View {
        VStack(spacing: 12) {
            header

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(widgets.filter { $0.isEnabled }) { widget in
                        if widget.title == "Music" {
                            musicCard
                        } else {
                            widgetCard(widget)
                        }
                    }
                }
                .transition(.opacity)
                .onHover { hovering in
                    updateHover(hovering)
                }
            }
        }
        .padding(isExpanded ? 14 : 4)
        .frame(
            width: isExpanded ? 600 : 220,
            alignment: .top
        )
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
        .animation(
            .spring(response: 0.3, dampingFraction: 0.85),
            value: isExpanded
        )
        .task {
            while !Task.isCancelled {
                spotify.refresh()

                do {
                    try await Task.sleep(
                        nanoseconds: 2_000_000_000
                    )
                } catch {
                    break
                }
            }
        }
    }

    private var headerContent: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))

            Text("Dynamic Island")
                .font(.system(size: 11, weight: .semibold))

            Spacer(minLength: 4)

            if isExpanded {
                Button {
                    isPinned.toggle()
                } label: {
                    Image(
                        systemName: isPinned
                            ? "pin.fill"
                            : "pin"
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(
                    isPinned
                        ? "Unpin dashboard"
                        : "Keep dashboard open"
                )
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
    }

    private var header: some View {
        Group {
            if isExpanded {
                headerContent
            } else {
                headerContent
                    .onTapGesture {
                        isPinned.toggle()
                    }
            }
        }
        .onHover { hovering in
            updateHover(hovering)
        }
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer(minLength: 0)

                Button {
                    spotify.previousTrack()
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .help("Previous track")
                .accessibilityLabel("Previous track")

                Button {
                    spotify.togglePlayback()
                } label: {
                    Image(
                        systemName: spotify.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                }
                .help(spotify.isPlaying ? "Pause" : "Play")
                .accessibilityLabel(
                    spotify.isPlaying ? "Pause" : "Play"
                )

                Button {
                    spotify.nextTrack()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .help("Next track")
                .accessibilityLabel("Next track")
            }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text(spotify.trackName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(spotify.artistName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 76)
        .padding(9)
        .background(
            Color.white.opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }

    private func widgetCard(
        _ widget: IslandWidget
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon(for: widget.title))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))

            Text(widget.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 76)
        .padding(9)
        .background(
            Color.white.opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }

    private func icon(for title: String) -> String {
        switch title {
        case "System":
            return "cpu"
        case "Calendar":
            return "calendar"
        case "Downloads":
            return "arrow.down.circle"
        case "Shortcuts":
            return "command"
        default:
            return "square.grid.2x2"
        }
    }

    private func updateHover(_ hovering: Bool) {
        if hovering {
            hoverExitToken = UUID()
            isHovering = true
            return
        }

        let exitToken = UUID()
        hoverExitToken = exitToken

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.2
        ) {
            guard hoverExitToken == exitToken, !isPinned else {
                return
            }

            isHovering = false
        }
    }
}
