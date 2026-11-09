import SwiftUI

private struct ReadingBookmark: Codable, Identifiable {
    var chapter: Int
    var paragraph: Int
    var id: String { "\(chapter):\(paragraph)" }
}

struct ReaderView: View {
    let book: Book
    @EnvironmentObject private var library: LibraryStore
    @AppStorage("reader.fontSize") private var fontSize = 21.0
    @AppStorage("reader.lineSpacing") private var lineSpacing = 10.0
    @AppStorage("reader.theme") private var themeName = "paper"
    @AppStorage private var bookmarkData: String
    @State private var document: BookDocument?
    @State private var chapterIndex = 0
    @State private var paragraphID: Int?
    @State private var showContents = false
    @State private var showSettings = false
    @State private var loadError: String?
    @State private var loaded = false

    init(book: Book) {
        self.book = book
        _bookmarkData = AppStorage(wrappedValue: "[]", "bookmarks.\(book.id.uuidString)")
    }

    private var theme: ReadingTheme { ReadingTheme(rawValue: themeName) ?? .paper }
    private var background: Color {
        switch theme {
        case .paper: Color(red: 0.98, green: 0.97, blue: 0.94)
        case .sepia: Color(red: 0.93, green: 0.87, blue: 0.75)
        case .night: Color(red: 0.10, green: 0.12, blue: 0.12)
        }
    }
    private var foreground: Color { theme == .night ? Color(white: 0.78) : Color(white: 0.19) }
    private var chapters: [Chapter] { document?.chapters ?? [] }
    private var bookmarks: [ReadingBookmark] {
        (try? JSONDecoder().decode([ReadingBookmark].self, from: Data(bookmarkData.utf8))) ?? []
    }
    private var currentBookmark: ReadingBookmark { ReadingBookmark(chapter: chapterIndex, paragraph: paragraphID ?? 0) }
    private var isBookmarked: Bool { bookmarks.contains { $0.id == currentBookmark.id } }

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                ContentUnavailableView("打开失败", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if loaded, chapters.indices.contains(chapterIndex) {
                readingBody
            } else { ProgressView("正在打开…").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background(background).foregroundStyle(foreground)
        .preferredColorScheme(theme == .night ? .dark : .light)
        .navigationTitle(book.title).navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if loaded {
                readingControls.padding(.horizontal, 20).padding(.bottom, 8)
            }
        }
        .task {
            guard !loaded else { return }
            do {
                let result = try await library.document(for: book)
                guard !result.chapters.isEmpty else { throw ImportFailure.empty }
                document = result
                chapterIndex = min(max(0, book.chapterIndex), result.chapters.count - 1)
                loaded = true
            } catch { loadError = error.localizedDescription }
        }
        .onChange(of: paragraphID) { _, value in
            if loaded, let value { library.updatePosition(book.id, chapter: chapterIndex, paragraph: value) }
        }
        .sheet(isPresented: $showContents) { contents }
        .sheet(isPresented: $showSettings) {
            settings.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }

    private var readingControls: some View {
        VStack(spacing: 4) {
            Text("第 \(chapterIndex + 1) / \(chapters.count) 节")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            HStack(spacing: 4) {
                dockButton("上一章", symbol: "chevron.left") { jump(to: chapterIndex - 1) }
                    .disabled(chapterIndex == 0)
                dockButton("目录", symbol: "list.bullet") { showContents = true }
                dockButton(isBookmarked ? "移除书签" : "添加书签",
                    symbol: isBookmarked ? "bookmark.fill" : "bookmark") { toggleBookmark() }
                dockButton("阅读设置", symbol: "textformat.size") { showSettings = true }
                dockButton("下一章", symbol: "chevron.right") { jump(to: chapterIndex + 1) }
                    .disabled(chapterIndex + 1 >= chapters.count)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: 420).moonbookGlass(radius: 30)
    }

    private func dockButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }

    private var readingBody: some View {
        let chapter = chapters[chapterIndex]
        let paragraphs = chapter.text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(chapter.title).font(.system(.title2, design: .serif)).bold().padding(.top, 20)
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        Text(paragraph).font(.system(size: fontSize, design: .serif))
                            .lineSpacing(lineSpacing).frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled).id(index)
                    }
                }.scrollTargetLayout()
                if paragraphs.isEmpty { Text("本章暂无正文").foregroundStyle(.secondary) }
            }.padding(.horizontal, 26).padding(.bottom, 32).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $paragraphID, anchor: .top)
        .id(chapterIndex)
        .onAppear {
            if paragraphID == nil {
                paragraphID = min(max(0, book.chapterIndex == chapterIndex ? book.paragraphIndex : 0), max(0, paragraphs.count - 1))
            }
        }
    }

    private var contents: some View {
        NavigationStack {
            List {
                if !bookmarks.isEmpty {
                    Section("书签") {
                        ForEach(bookmarks) { mark in
                            if chapters.indices.contains(mark.chapter) {
                                Button {
                                    jump(to: mark.chapter, paragraph: mark.paragraph)
                                    showContents = false
                                } label: { Label("\(chapters[mark.chapter].title) · 第 \(mark.paragraph + 1) 段", systemImage: "bookmark") }
                            }
                        }.onDelete { offsets in
                            var values = bookmarks
                            values.remove(atOffsets: offsets)
                            writeBookmarks(values)
                        }
                    }
                }
                Section("章节") {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                        Button { jump(to: index); showContents = false } label: {
                            HStack {
                                Text(chapter.title).foregroundStyle(.primary)
                                Spacer()
                                if index == chapterIndex { Image(systemName: "speaker.wave.1").accessibilityLabel("当前章节") }
                            }
                        }
                    }
                }
            }.navigationTitle("目录与书签").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("完成") { showContents = false } }
        }
    }

    private var settings: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("排版").font(.headline)
                        LabeledContent("字号", value: "\(Int(fontSize))")
                        Slider(value: $fontSize, in: 16...34, step: 1).accessibilityLabel("字号")
                        LabeledContent("行距", value: "\(Int(lineSpacing))")
                        Slider(value: $lineSpacing, in: 4...20, step: 1).accessibilityLabel("行距")
                    }.padding(20).moonbookGlass()
                    VStack(alignment: .leading, spacing: 14) {
                        Text("阅读主题").font(.headline)
                        Picker("阅读主题", selection: $themeName) {
                            ForEach(ReadingTheme.allCases) { Text($0.title).tag($0.rawValue) }
                        }.pickerStyle(.segmented)
                    }.padding(20).moonbookGlass()
                    Text("月色入书，片刻安静。")
                        .font(.system(size: fontSize, design: .serif)).lineSpacing(lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20).background(background, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(foreground).accessibilityLabel("排版预览：月色入书，片刻安静。")
                }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.navigationTitle("阅读设置").navigationBarTitleDisplayMode(.inline)
                .background(background)
                .toolbar { Button("完成") { showSettings = false } }
        }
    }

    private func jump(to index: Int, paragraph: Int = 0) {
        guard chapters.indices.contains(index) else { return }
        chapterIndex = index
        paragraphID = paragraph
        library.updatePosition(book.id, chapter: index, paragraph: paragraph)
    }

    private func toggleBookmark() {
        var values = bookmarks
        if isBookmarked { values.removeAll { $0.id == currentBookmark.id } }
        else { values.append(currentBookmark) }
        writeBookmarks(values)
    }

    private func writeBookmarks(_ values: [ReadingBookmark]) {
        if let data = try? JSONEncoder().encode(values), let string = String(data: data, encoding: .utf8) { bookmarkData = string }
    }
}
