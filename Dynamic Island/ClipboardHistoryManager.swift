
import AppKit
import Combine
import Foundation

struct ClipboardEntry: Identifiable {
    enum EntryKind {
        case text
        case url
        case image
    }

    let id = UUID()
    let kind: EntryKind
    let text: String?
    let image: NSImage?
    let signature: String

    var title: String {
        switch kind {
        case .text: return text ?? "Text"
        case .url: return text ?? "URL"
        case .image: return "Image"
        }
    }

    var icon: String {
        switch kind {
        case .text: return "doc.text"
        case .url: return "link"
        case .image: return "photo"
        }
    }
}

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var statusMessage = "Waiting to start"

    private let pasteboard = NSPasteboard.general
    private let maximumEntries = 5
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var pollingTimer: Timer?

    func startMonitoring() {
        guard pollingTimer == nil else { return }

        lastChangeCount = pasteboard.changeCount
        statusMessage = "Monitoring"

        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.4,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }

    func checkForChanges() {
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }

        lastChangeCount = currentCount

        // Read text first because many apps publish URLs as plain text too.
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let isURL: Bool
            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               ["http", "https"].contains(scheme),
               url.host != nil {
                isURL = true
            } else {
                isURL = false
            }

            addEntry(
                kind: isURL ? .url : .text,
                text: trimmed,
                image: nil,
                signature: "\(isURL ? "url" : "text")-\(trimmed)"
            )
            statusMessage = isURL ? "URL detected" : "Text detected"
            return
        }

        // Read images from the pasteboard's available objects.
        if let image = pasteboard.readObjects(
            forClasses: [NSImage.self],
            options: nil
        )?.first as? NSImage {
            let signature = image.tiffRepresentation
                .map { "image-\($0.hashValue)" }
                ?? "image-\(currentCount)"

            addEntry(
                kind: .image,
                text: nil,
                image: image,
                signature: signature
            )
            statusMessage = "Image detected"
            return
        }

        // Fall back to URL objects.
        if let url = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: nil
        )?.first as? URL {
            addEntry(
                kind: .url,
                text: url.absoluteString,
                image: nil,
                signature: "url-\(url.absoluteString)"
            )
            statusMessage = "URL detected"
            return
        }

        statusMessage = "Unsupported clipboard item"
    }

    private func addEntry(
        kind: ClipboardEntry.EntryKind,
        text: String?,
        image: NSImage?,
        signature: String
    ) {
        guard entries.first?.signature != signature else { return }

        entries.insert(
            ClipboardEntry(
                kind: kind,
                text: text,
                image: image,
                signature: signature
            ),
            at: 0
        )

        if entries.count > maximumEntries {
            entries = Array(entries.prefix(maximumEntries))
        }
    }

    func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()

        switch entry.kind {
        case .image:
            if let image = entry.image {
                pasteboard.writeObjects([image])
            }
        case .text, .url:
            if let text = entry.text {
                pasteboard.setString(text, forType: .string)
            }
        }

        lastChangeCount = pasteboard.changeCount
        statusMessage = "Copied entry"
    }

    func remove(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func clearHistory() {
        entries.removeAll()
        statusMessage = "History cleared"
    }
}
