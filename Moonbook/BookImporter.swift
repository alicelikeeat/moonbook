import Foundation
import CoreFoundation
import ZIPFoundation

enum ImportFailure: LocalizedError {
    case unsupported, unreadable, empty, oversized, invalidEPUB
    var errorDescription: String? {
        switch self {
        case .unsupported: "请选择 TXT 或 EPUB 文件。"
        case .unreadable: "无法读取文字编码，请将文件转换为 UTF-8 后重试。"
        case .empty: "这本书中没有可阅读的文字。"
        case .oversized: "文件过大，第一版支持 50 MB 以内的书籍。"
        case .invalidEPUB: "无法解析此 EPUB，文件可能损坏、加密或使用了不支持的格式。"
        }
    }
}

enum BookImporter {
    static func read(_ url: URL) throws -> BookDocument {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 50 * 1_024 * 1_024 else { throw ImportFailure.oversized }
        switch url.pathExtension.lowercased() {
        case "txt": return try textDocument(Data(contentsOf: url))
        case "epub": return try epubDocument(url)
        default: throw ImportFailure.unsupported
        }
    }

    static func textDocument(_ data: Data) throws -> BookDocument {
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let encodings: [String.Encoding] = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
            ? [.utf16, .utf8, gb18030] : [.utf8, gb18030]
        guard let text = encodings.lazy.compactMap({ String(data: data, encoding: $0) }).first else {
            throw ImportFailure.unreadable
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\u{FEFF}", with: "")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportFailure.empty }
        let pattern = #"(?m)^[\t 　]*(?:第[零〇一二三四五六七八九十百千万两0-9]+[章回节卷部集].{0,60}|(?:Chapter|CHAPTER)\s+\d+.{0,60})[\t 　]*$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = normalized as NSString
        let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length))
        var chapters: [Chapter] = []
        func append(_ title: String, _ range: NSRange) {
            let content = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { chapters.append(Chapter(id: chapters.count, title: title, text: content)) }
        }
        if let first = matches.first, first.range.location > 0 {
            append("序言", NSRange(location: 0, length: first.range.location))
        }
        for (index, match) in matches.enumerated() {
            let start = NSMaxRange(match.range)
            let end = index + 1 < matches.count ? matches[index + 1].range.location : ns.length
            let title = ns.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            // Keep empty chapters so titles and navigation remain faithful to the file.
            chapters.append(Chapter(id: chapters.count, title: title,
                text: ns.substring(with: NSRange(location: start, length: end - start))
                    .trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if matches.isEmpty {
            // Split long TXT files into manageable reading sections.
            var chunk = ""
            for line in normalized.components(separatedBy: "\n") {
                chunk += line + "\n"
                if chunk.utf16.count >= 20_000 {
                    chapters.append(Chapter(id: chapters.count, title: "正文 · \(chapters.count + 1)", text: chunk))
                    chunk = ""
                }
            }
            if !chunk.isEmpty { chapters.append(Chapter(id: chapters.count, title: "正文 · \(chapters.count + 1)", text: chunk)) }
        }
        return BookDocument(chapters: chapters)
    }

    private static func epubDocument(_ url: URL) throws -> BookDocument {
        let archive = try Archive(url: url, accessMode: .read)
        var extractedBytes = 0
        func data(_ path: String) throws -> Data {
            guard let entry = archive[path], entry.type == .file,
                  entry.uncompressedSize <= 20 * 1_024 * 1_024 else { throw ImportFailure.invalidEPUB }
            var result = Data()
            _ = try archive.extract(entry) { chunk in
                extractedBytes += chunk.count
                guard extractedBytes <= 100 * 1_024 * 1_024 else { throw ImportFailure.oversized }
                result.append(chunk)
            }
            return result
        }
        let container = XMLCollector()
        try container.parse(data("META-INF/container.xml"))
        guard let packagePath = container.rootFile else { throw ImportFailure.invalidEPUB }
        let package = XMLCollector()
        try package.parse(data(packagePath))
        let directory = (packagePath as NSString).deletingLastPathComponent
        var chapters: [Chapter] = []
        for id in package.spine {
            guard let item = package.items[id], item.type == "application/xhtml+xml" else { continue }
            let href = item.href.components(separatedBy: "#")[0].removingPercentEncoding ?? item.href
            let path = directory.isEmpty ? href : directory + "/" + href
            let canonical = (path as NSString).standardizingPath
            guard !canonical.hasPrefix("/"), !canonical.hasPrefix("../") else { throw ImportFailure.invalidEPUB }
            let page = XMLCollector()
            try page.parse(data(canonical))
            let text = page.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                chapters.append(Chapter(id: chapters.count,
                    title: page.heading.isEmpty ? "第 \(chapters.count + 1) 节" : page.heading,
                    text: text))
            }
        }
        guard !chapters.isEmpty else { throw ImportFailure.empty }
        return BookDocument(chapters: chapters)
    }
}

private final class XMLCollector: NSObject, XMLParserDelegate {
    var rootFile: String?
    var items: [String: (href: String, type: String)] = [:]
    var spine: [String] = []
    var body = ""
    var heading = ""
    private var inBody = false
    private var headingDepth = 0
    private var ignoredDepth = 0
    func parse(_ data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw ImportFailure.invalidEPUB }
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        if name == "rootfile", rootFile == nil { rootFile = attributes["full-path"] }
        if name == "item", let id = attributes["id"], let href = attributes["href"] {
            items[id] = (href, attributes["media-type"] ?? "")
        }
        if name == "itemref", let id = attributes["idref"], attributes["linear"] != "no" { spine.append(id) }
        if name == "body" { inBody = true }
        if name == "script" || name == "style" { ignoredDepth += 1 }
        if inBody && ignoredDepth == 0 {
            if ["p", "div", "br", "h1", "h2", "h3", "li"].contains(name) { body += "\n" }
            if ["h1", "h2", "h3"].contains(name), heading.isEmpty { headingDepth = 1 }
            else if headingDepth > 0 { headingDepth += 1 }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inBody && ignoredDepth == 0 { body += string }
        if headingDepth > 0 { heading += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        if headingDepth > 0 { headingDepth -= 1 }
        if name == "script" || name == "style" { ignoredDepth = max(0, ignoredDepth - 1) }
        if inBody && ["p", "div", "h1", "h2", "h3", "li"].contains(name) { body += "\n" }
        if name == "body" { inBody = false }
    }
}
