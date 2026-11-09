import Foundation
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published var books: [Book] = []
    @Published var importing = false
    @Published var errorMessage: String?
    private let root: URL
    private var indexURL: URL { root.appendingPathComponent("library.json") }

    init(root: URL? = nil) {
        self.root = root ?? URL.documentsDirectory.appendingPathComponent("Moonbook", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: indexURL))
            }
        } catch { errorMessage = "书架读取失败：\(error.localizedDescription)" }
    }

    func importBook(_ url: URL) async {
        guard !importing else { return }
        importing = true
        defer { importing = false }
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            let document = try await Task.detached(priority: .userInitiated) {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let parsed = try BookImporter.read(url)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                do {
                    try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent("original." + url.pathExtension.lowercased()))
                    try JSONEncoder().encode(parsed).write(to: folder.appendingPathComponent("content.json"), options: .atomic)
                } catch {
                    try? FileManager.default.removeItem(at: folder)
                    throw error
                }
                return parsed
            }.value
            let book = Book(id: id, title: url.deletingPathExtension().lastPathComponent,
                format: url.pathExtension.uppercased(), addedAt: Date(), chapterCount: document.chapters.count)
            books.insert(book, at: 0)
            do { try persist() }
            catch {
                books.removeAll { $0.id == id }
                try? FileManager.default.removeItem(at: folder)
                throw error
            }
        } catch { errorMessage = "导入失败：\(error.localizedDescription)" }
    }

    func document(for book: Book) async throws -> BookDocument {
        let url = root.appendingPathComponent(book.id.uuidString).appendingPathComponent("content.json")
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(BookDocument.self, from: Data(contentsOf: url))
        }.value
    }

    func updatePosition(_ id: UUID, chapter: Int, paragraph: Int) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].chapterIndex = chapter
        books[index].paragraphIndex = paragraph
        save()
    }

    func rename(_ id: UUID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].title = title
        save()
    }

    func delete(_ book: Book) {
        let oldBooks = books
        books.removeAll { $0.id == book.id }
        do { try persist() }
        catch { books = oldBooks; errorMessage = "删除失败：\(error.localizedDescription)"; return }
        do { try FileManager.default.removeItem(at: root.appendingPathComponent(book.id.uuidString)) }
        catch { errorMessage = "书架已移除，清理文件失败：\(error.localizedDescription)" }
    }

    private func persist() throws {
        try JSONEncoder().encode(books).write(to: indexURL, options: .atomic)
    }
    private func save() {
        do { try persist() } catch { errorMessage = "保存失败：\(error.localizedDescription)" }
    }
}
