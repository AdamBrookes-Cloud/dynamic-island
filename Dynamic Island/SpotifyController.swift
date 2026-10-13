
import Foundation
import AppKit
import Combine

@MainActor
final class SpotifyController: ObservableObject {
    @Published private(set) var trackName = "Open Spotify"
    @Published private(set) var artistName = "to start playback"
    @Published private(set) var isPlaying = false
    @Published private(set) var albumArtwork: NSImage?

    private var lastArtworkKey = ""

    private let currentTrackScript = """
    if application "Spotify" is running then
        tell application "Spotify"
            set trackName to name of current track
            set artistName to artist of current track
            set stateText to player state as string
            set trackID to id of current track as string
            set artworkURL to artwork url of current track as string
            return trackName & tab & artistName & tab & stateText & tab & trackID & tab & artworkURL
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
            showUnavailableState()
            return
        }

        if value == "NOT_RUNNING" {
            trackName = "Open Spotify"
            artistName = "to start playback"
            isPlaying = false
            albumArtwork = nil
            lastArtworkKey = ""
            return
        }

        let fields = value.components(separatedBy: "\t")

        guard fields.count >= 5 else {
            print("Unexpected Spotify response: \(value)")
            showUnavailableState()
            return
        }

        trackName = fields[0]
        artistName = fields[1]
        isPlaying = fields[2].lowercased() == "playing"

        let trackID = fields[3]
        let artworkURL = fields[4]

        if trackID != lastArtworkKey {
            lastArtworkKey = trackID
            albumArtwork = nil

            if !artworkURL.isEmpty {
                loadArtwork(from: artworkURL, forTrack: trackID)
            } else {
                print("Spotify returned no artwork URL.")
            }
        }
    }

    private func loadArtwork(from urlString: String, forTrack trackID: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid Spotify artwork URL: \(urlString)")
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                if let response = response as? HTTPURLResponse,
                   !(200...299).contains(response.statusCode) {
                    print("Artwork download failed: HTTP \(response.statusCode)")
                    return
                }

                guard let image = NSImage(data: data) else {
                    print("Downloaded Spotify artwork is not a valid image.")
                    return
                }

                guard lastArtworkKey == trackID else {
                    return
                }

                albumArtwork = image
            } catch {
                print("Spotify artwork download error: \(error)")
            }
        }
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
