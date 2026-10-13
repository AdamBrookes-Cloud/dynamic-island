import SwiftUI
import AppKit

struct DownloadsWidget: View {
    @StateObject private var manager = DownloadsManager()
    @State private var itemToDelete: DownloadItem?

    private let cardBackground = Color.white.opacity(0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10, weight: .semibold))

                Text("Downloads")
                    .font(.system(size: 9, weight: .semibold))

                Spacer(minLength: 0)

                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Refresh downloads")

                Button {
                    manager.openDownloadsFolder()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Open Downloads folder")

                Button {
                    manager.browseFiles()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Browse files")
            }
            .foregroundStyle(.white.opacity(0.85))

            if manager.items.isEmpty {
                Spacer(minLength: 0)

                Text(manager.errorMessage ?? "No files in Downloads")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(manager.items.prefix(8)) { item in
                            downloadRow(item)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 8))
                    .foregroundStyle(.red.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 148)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .task {
            while !Task.isCancelled {
                manager.refresh()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .confirmationDialog(
            "Move this item to Trash?",
            isPresented: Binding(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = itemToDelete {
                Button("Move to Trash", role: .destructive) {
                    manager.moveToTrash(item)
                    itemToDelete = nil
                }
            }

            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete {
                Text(item.name)
            }
        }
    }

    private func downloadRow(_ item: DownloadItem) -> some View {
        HStack(spacing: 4) {
            Group {
                if let preview = item.imagePreview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 19, height: 19)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Button {
                manager.open(item)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 8, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.fileSizeLabel)
                        .font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open \(item.name)")

            if item.kind == .image {
                Button {
                    manager.copyImage(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Copy image to clipboard")
            }

            Button {
                itemToDelete = item
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .help("Move to Trash")
        }
        .foregroundStyle(.white)
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open") {
                manager.open(item)
            }

            if item.kind == .image {
                Button("Copy Image") {
                    manager.copyImage(item)
                }
            }

            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }

            Button("Move to Trash", role: .destructive) {
                itemToDelete = item
            }
        }
    }
}
