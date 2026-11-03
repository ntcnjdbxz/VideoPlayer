import SwiftUI

@main
struct StreamShelfApp: App {
    @StateObject private var history = HistoryStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(history)
        }
    }
}
