 import Foundation
import AppKit
import Combine

@MainActor
final class SpotifyController: ObservableObject {
    @Published private(set) var trackName = "Open Spotify"
    @Published private(set) var artistName = "to start playback"
    @Published private(set) var isPlaying = false

    private let currentTrackScript = """
    if application "Spotify" is running then
        tell application "Spotify"
            set trackName to name of current track
            set artistName to artist of current track
            set stateText to player state as string
            return trackName & tab & artistName & tab & stateText
        end tell
    else
        return "NOT_RUNNING"
    end if
    """

    func refresh() {
        guard let script = NSAppleScript(source: currentTrackScript) else {
            showUnavailableState()
            return
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            print("Spotify AppleScript error: \(error)")
            showUnavailableState()
            return
        }

        guard let value = result.stringValue else {
            print("Spotify returned no track information.")
            showUnavailableState()
            return
        }

        if value == "NOT_RUNNING" {
            trackName = "Open Spotify"
            artistName = "to start playback"
            isPlaying = false
            return
        }

        let fields = value.components(separatedBy: "\t")

        guard fields.count >= 3 else {
            print("Unexpected Spotify response: \(value)")
            showUnavailableState()
            return
        }

        trackName = fields[0]
        artistName = fields[1]
        isPlaying = fields[2].lowercased() == "playing"
    }

    func togglePlayback() {
        executeSpotifyCommand("playpause")
    }

    func nextTrack() {
        executeSpotifyCommand("next track")
    }

    func previousTrack() {
        executeSpotifyCommand("previous track")
    }

    private func executeSpotifyCommand(_ command: String) {
        let source = """
        tell application "Spotify" to \(command)
        """

        guard let script = NSAppleScript(source: source) else {
            return
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        if let error {
            print("Spotify command error: \(error)")
        }

        refresh()
    }

    private func showUnavailableState() {
        trackName = "Spotify unavailable"
        artistName = "Check macOS permissions"
        isPlaying = false
    }
}
