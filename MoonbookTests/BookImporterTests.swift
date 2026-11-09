import XCTest
import CoreFoundation
@testable import Moonbook

final class BookImporterTests: XCTestCase {
    func testChineseChapterTitlesAndPreamble() throws {
        let document = try BookImporter.textDocument(Data("前言\r\n第一章 初见\r\n你好。\r\n第二章 再会\r\n再见。".utf8))
        XCTAssertEqual(document.chapters.map(\.title), ["序言", "第一章 初见", "第二章 再会"])
        XCTAssertEqual(document.chapters[1].text, "你好。")
        XCTAssertEqual(document.chapters.map(\.id), [0, 1, 2])
    }

    func testGB18030AndUTF16() throws {
        let text = "第一章 月亮\n今晚月色很美。"
        let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        for encoding in [gb, .utf16] {
            let data = try XCTUnwrap(text.data(using: encoding))
            let document = try BookImporter.textDocument(data)
            XCTAssertEqual(document.chapters.first?.text, "今晚月色很美。")
        }
    }

    func testEmptyAndUnsupportedFilesAreRejected() throws {
        XCTAssertThrowsError(try BookImporter.textDocument(Data(" \n\t".utf8)))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try Data("example".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try BookImporter.read(file))
    }

    func testLongTextWithoutHeadingsIsSplitWithoutDataLoss() throws {
        let text = String(repeating: "一段很长的小说正文。\n", count: 5_000)
        let document = try BookImporter.textDocument(Data(text.utf8))
        XCTAssertGreaterThan(document.chapters.count, 1)
        XCTAssertEqual(document.chapters.map(\.text).joined().trimmingCharacters(in: .newlines), text.trimmingCharacters(in: .newlines))
    }

    func testEPUBUsesSpineOrderAndExcludesHeadAndScripts() throws {
        let encoded = "UEsDBBQAAAAIAGELaV2gYCw2UAAAAGcAAAAWAAAATUVUQS1JTkYvY29udGFpbmVyLnhtbLOxr8jNUShLLSrOzM+zVTLUM1Cyt7NJzs8rSczMSy2ysynKzy9Jy8xJLUYwFdJKc3J0CxJLMmyV/AOC9ZPy87P18gvSlPTtbPSR1OsjjAEAUEsDBBQAAAAIAGELaV0xPXzwbgAAAN8AAAAMAAAAT1BTL2Jvb2sub3BmlY/BDYAwCEVXaXo12gWqu6CiEm0lykG3t2lt7NUbgf8eYBmGFWbsrANPE57SWRJ0isZW91otB06haK5F3KaVw5Gglpux1cC80QBCuzdxXF0hYgoeMg+/ePOdcjJ5TMYgCtKky1uKXh/JN2/yVw9QSwMEFAAAAAgAYQtpXZdIk/+EAAAAoQAAAAsAAABPUFMvYS54aHRtbLPJKMnNUajIzckrtlXKKCkpsNLXLy8v1ys31ssvStc3tLS01K8AqVGys8lITUyxsynJLMlJtcvITElJzbPRh/Bs9CFySfkplUB1hnbP16x5sqPh+eoFQBlDO5sCu2dzOp62dj5uaLLRL7CzKU4uyiwogRqiAOHZ6ENFbfQhxuiDrLUDAFBLAwQUAAAACABhC2ld8eVTH1sAAABhAAAACwAAAE9QUy9iLnhodG1ss8koyc1RqMjNySu2VcooKSmw0tcvLy/XKzfWyy9K1ze0tLTUrwCpUbKzScpPqbSzyTC0e75mzZNdPc9XL7DRB/JsCuyezZj/tLXzcUOTjX6BnY0+RKE+SJsdAFBLAQIUAxQAAAAIAGELaV2gYCw2UAAAAGcAAAAWAAAAAAAAAAAAAACAAQAAAABNRVRBLUlORi9jb250YWluZXIueG1sUEsBAhQDFAAAAAgAYQtpXTE9fPBuAAAA3wAAAAwAAAAAAAAAAAAAAIABhAAAAE9QUy9ib29rLm9wZlBLAQIUAxQAAAAIAGELaV2XSJP/hAAAAKEAAAALAAAAAAAAAAAAAACAARwBAABPUFMvYS54aHRtbFBLAQIUAxQAAAAIAGELaV3x5VMfWwAAAGEAAAALAAAAAAAAAAAAAACAAckBAABPUFMvYi54aHRtbFBLBQYAAAAABAAEAPAAAABNAgAAAAA="
        let data = try XCTUnwrap(Data(base64Encoded: encoded))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let document = try BookImporter.read(file)
        XCTAssertEqual(document.chapters.map(\.title), ["第一章", "第二章"])
        XCTAssertTrue(document.chapters[0].text.contains("月光。"))
        XCTAssertFalse(document.chapters[0].text.contains("hidden"))
    }

    func testEmptyChapterIsPreserved() throws {
        let document = try BookImporter.textDocument(Data("第一章\n第二章\n正文".utf8))
        XCTAssertEqual(document.chapters.count, 2)
        XCTAssertEqual(document.chapters[0].text, "")
    }

    @MainActor
    func testImportedFileSurvivesSourceRemovalAndProgressReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }
        try Data("第一章 开始\n第一段\n第二段\n第二章 后来\n第三段".utf8).write(to: source)
        let store = LibraryStore(root: root)
        await store.importBook(source)
        XCTAssertNil(store.errorMessage)
        let book = try XCTUnwrap(store.books.first)
        try FileManager.default.removeItem(at: source)
        store.updatePosition(book.id, chapter: 1, paragraph: 0)
        let reloaded = LibraryStore(root: root)
        XCTAssertEqual(reloaded.books.first?.chapterIndex, 1)
        let document = try await reloaded.document(for: book)
        XCTAssertEqual(document.chapters[1].text, "第三段")
        reloaded.delete(book)
        XCTAssertTrue(LibraryStore(root: root).books.isEmpty)
    }
}
