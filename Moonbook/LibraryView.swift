import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var showImporter = false
    @State private var renaming: Book?
    @State private var title = ""
    @State private var deleting: Book?
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 24)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MOONBOOK").font(.caption.weight(.semibold)).tracking(5)
                        Text("把故事，留给自己。")
                            .font(.system(.title, design: .serif)).bold()
                        Text("\(library.books.count) 本藏书 · 一段安静的阅读时光")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 16)
                    if library.books.isEmpty {
                        ContentUnavailableView {
                            Label("你的第一本书", systemImage: "book.closed")
                        } description: {
                            Text("导入 TXT 或 EPUB 小说，随时离线阅读。")
                        } actions: {
                            Button("导入小说", systemImage: "plus") { showImporter = true }
                                .buttonStyle(.borderedProminent)
                        }.padding(.top, 50)
                    } else {
                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(library.books) { book in
                                NavigationLink { ReaderView(book: book) } label: { BookCard(book: book) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("重命名", systemImage: "pencil") { title = book.title; renaming = book }
                                        Button("删除", systemImage: "trash", role: .destructive) { deleting = book }
                                    }
                            }
                        }
                    }
                }.padding(24)
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .navigationTitle("书架").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入小说", systemImage: "plus") { showImporter = true }.disabled(library.importing)
                }
            }
            .overlay { if library.importing { ProgressView("正在整理书籍…").padding(28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
            .fileImporter(isPresented: $showImporter,
                allowedContentTypes: [.plainText, UTType(filenameExtension: "epub") ?? .data]) { result in
                switch result {
                case .success(let url): Task { await library.importBook(url) }
                case .failure(let error): library.errorMessage = error.localizedDescription
                }
            }
            .alert("提示", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
                Button("知道了") { library.errorMessage = nil }
            } message: { Text(library.errorMessage ?? "") }
            .alert("重命名", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("书名", text: $title)
                Button("保存") { if let book = renaming { library.rename(book.id, to: title) }; renaming = nil }
                Button("取消", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("删除书籍及其本机文件？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("删除", role: .destructive) { if let book = deleting { library.delete(book) }; deleting = nil }
            }
        }
    }
}

private struct BookCard: View {
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.29, green: 0.36, blue: 0.32).gradient)
                Rectangle().fill(.white.opacity(0.12)).frame(width: 5).padding(.leading, 8)
                VStack(alignment: .leading, spacing: 15) {
                    Image(systemName: "moon.stars").font(.title3)
                    Text(book.title).font(.system(.title3, design: .serif)).bold().lineLimit(4)
                    Spacer()
                    Text(book.format).font(.caption2).tracking(3)
                }.padding(22).foregroundStyle(.white.opacity(0.9))
            }.frame(height: 210).shadow(color: .black.opacity(0.12), radius: 6, y: 4)
            Text(book.title).font(.subheadline.weight(.medium)).lineLimit(1)
            Text(book.chapterIndex == 0 && book.paragraphIndex == 0 ? "未开始阅读" : "第 \(book.chapterIndex + 1) / \(book.chapterCount) 节")
                .font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}
