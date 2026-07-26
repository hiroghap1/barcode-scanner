import SwiftUI
import SwiftData

@main
struct BarcodeAssignApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Project.self, Row.self])
    }
}
