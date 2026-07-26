import Foundation
import SwiftData

/// 取込 1 回分の表データ(作業単位)
@Model
final class Project {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    var columnNames: [String]
    var identifierColumnIndex: Int
    var displayColumnIndex: Int
    var barcodeColumnIndex: Int

    /// 次にスキャンする行(再開位置)
    var currentPosition: Int

    @Relationship(deleteRule: .cascade, inverse: \Row.project)
    var rows: [Row]

    init(
        name: String,
        columnNames: [String],
        identifierColumnIndex: Int,
        displayColumnIndex: Int,
        barcodeColumnIndex: Int
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        self.columnNames = columnNames
        self.identifierColumnIndex = identifierColumnIndex
        self.displayColumnIndex = displayColumnIndex
        self.barcodeColumnIndex = barcodeColumnIndex
        self.currentPosition = 0
        self.rows = []
    }
}

extension Project {
    var sortedRows: [Row] {
        rows.sorted { $0.sortIndex < $1.sortIndex }
    }

    var registeredCount: Int { rows.filter { $0.status == .registered }.count }
    var skippedCount: Int { rows.filter { $0.status == .skipped }.count }
    var pendingCount: Int { rows.filter { $0.status == .pending }.count }
    var totalCount: Int { rows.count }
}
