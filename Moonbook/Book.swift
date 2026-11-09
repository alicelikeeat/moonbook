import Foundation

struct Chapter: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var text: String
}

struct Book: Codable, Identifiable {
    var id: UUID
    var title: String
    var format: String
    var addedAt: Date
    var chapterIndex: Int = 0
    var paragraphIndex: Int = 0
    var chapterCount: Int

    var progress: Double {
        Double(chapterIndex) / Double(max(chapterCount, 1))
    }
}

struct BookDocument: Codable {
    var chapters: [Chapter]
}

enum ReadingTheme: String, CaseIterable, Identifiable {
    case paper, sepia, night
    var id: String { rawValue }
    var title: String {
        switch self { case .paper: "纸白"; case .sepia: "暖杏"; case .night: "夜读" }
    }
}
