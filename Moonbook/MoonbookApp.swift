import SwiftUI

@main
struct MoonbookApp: App {
    @StateObject private var library = LibraryStore()
    var body: some Scene {
        WindowGroup {
            LibraryView().environmentObject(library)
                .tint(Color(red: 0.39, green: 0.43, blue: 0.32))
                .onOpenURL { url in Task { await library.importBook(url) } }
        }
    }
}
