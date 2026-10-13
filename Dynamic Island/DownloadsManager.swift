
import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

struct DownloadItem: Identifiable {
    enum FileKind {
        case image
        case diskImage
        case folder
        case other
    }

    let url: URL
    let name: String
    let modifiedDate: Date
    let fileSize: Int64
    let kind: FileKind
    let imagePreview: NSImage?

    var id: URL { url }

    var icon: String {
        switch kind {
        case .image: return "photo"
        case .diskImage: return "externaldrive"
        case .folder: return "folder"
        case .other: return "doc"
        }
    }

    var fileSizeLabel: String {
        ByteCountFormatter.string(
            fromByteCount: fileSize,
            countStyle: .file
        )
    }
}

@MainActor
final class DownloadsManager: ObservableObject {
    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var errorMessage: String?

    private let fileManager = FileManager.default
    private let maximumItems = 30

    private var downloadsURL: URL? {
        fileManager.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first
    }

    init() {
        refresh()
    }

    func refresh() {
        guard let downloadsURL else {
            items = []
            errorMessage = "Downloads folder not found."
            return
        }

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isHiddenKey
                ],
                options: [.skipsHiddenFiles]
            )

            let recentItems = urls.compactMap {
                url -> DownloadItem? in

                do {
                    let values = try url.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .contentModificationDateKey,
                        .fileSizeKey,
                        .isHiddenKey
                    ])

                    guard values.isHidden != true else {
                        return nil
                    }

                    let isDirectory = values.isDirectory == true
                    let fileExtension = url.pathExtension.lowercased()
                    let contentType = UTType(
                        filenameExtension: fileExtension
                    )

                    let kind: DownloadItem.FileKind

                    if isDirectory {
                        kind = .folder
                    } else if contentType?.conforms(to: .image) == true {
                        kind = .image
                    } else if fileExtension == "dmg" {
                        kind = .diskImage
                    } else {
                        kind = .other
                    }

                    let preview = kind == .image
                        ? NSImage(contentsOf: url)
                        : nil

                    return DownloadItem(
                        url: url,
                        name: url.lastPathComponent,
                        modifiedDate: values.contentModificationDate
                            ?? .distantPast,
                        fileSize: Int64(values.fileSize ?? 0),
                        kind: kind,
                        imagePreview: preview
                    )
                } catch {
                    return nil
                }
            }

            items = Array(
                recentItems
                    .sorted { $0.modifiedDate > $1.modifiedDate }
                    .prefix(maximumItems)
            )

            errorMessage = nil
        } catch {
            items = []
            errorMessage = "Couldn't read Downloads."
            print("Downloads refresh failed: \(error)")
        }
    }

    func open(_ item: DownloadItem) {
        NSWorkspace.shared.open(item.url)
    }

    func copyImage(_ item: DownloadItem) {
        guard item.kind == .image,
              let image = NSImage(contentsOf: item.url) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func moveToTrash(_ item: DownloadItem) {
        do {
            try fileManager.trashItem(
                at: item.url,
                resultingItemURL: nil
            )
            refresh()
        } catch {
            errorMessage = "Couldn't move \(item.name) to Trash."
            print("Could not trash download: \(error)")
        }
    }

    func openDownloadsFolder() {
        guard let downloadsURL else { return }
        NSWorkspace.shared.open(downloadsURL)
    }

    func browseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose a file"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            NSWorkspace.shared.open(url)
        }
    }
}
