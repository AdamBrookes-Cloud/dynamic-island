import Foundation

enum WidgetSize: String, Codable, CaseIterable {
    case small
    case medium
    case large
}

struct IslandWidget: Identifiable, Codable {
    var id: UUID
    var title: String
    var size: WidgetSize
    var isEnabled: Bool
    var column: Int
    var row: Int

    init(
        id: UUID = UUID(),
        title: String,
        size: WidgetSize = .small,
        isEnabled: Bool = true,
        column: Int,
        row: Int
    ) {
        self.id = id
        self.title = title
        self.size = size
        self.isEnabled = isEnabled
        self.column = column
        self.row = row
    }
}
