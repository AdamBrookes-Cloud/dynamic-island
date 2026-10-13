
import SwiftUI
import AppKit

struct ClipboardHistoryWidget: View {
    @StateObject private var manager = ClipboardHistoryManager()

    private let background = Color.white.opacity(0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "clipboard")
                    .font(.system(size: 10, weight: .semibold))

                Text("Clipboard")
                    .font(.system(size: 9, weight: .semibold))

                Spacer(minLength: 0)

                Button {
                    manager.clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Clear clipboard history")
            }
            .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 4) {
                Text(manager.statusMessage)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Text("C:\(NSPasteboard.general.changeCount)")
                    .fixedSize()
            }
            .font(.system(size: 7))
            .foregroundStyle(.white.opacity(0.6))

            if manager.entries.isEmpty {
                Spacer(minLength: 0)

                Text("Copy text, URLs or images")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(manager.entries) { entry in
                            entryRow(entry)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .background(
            background,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .onAppear {
            manager.startMonitoring()
        }
    }

    private func entryRow(_ entry: ClipboardEntry) -> some View {
        HStack(spacing: 5) {
            if let image = entry.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: entry.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 22, height: 22)
            }

            Button {
                manager.copy(entry)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 8, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("Click to copy")
                        .font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                manager.remove(entry)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help("Remove entry")
        }
        .foregroundStyle(.white)
        .contextMenu {
            Button("Copy") {
                manager.copy(entry)
            }

            Button("Remove from History", role: .destructive) {
                manager.remove(entry)
            }
        }
    }
}
