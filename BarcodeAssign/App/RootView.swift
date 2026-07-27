import SwiftUI
import SwiftData

/// ルート画面。ホーム(S1)を起点に、プロジェクト選択・取込完了でレコード一覧(S4)へ遷移する。
struct RootView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Project.self) { project in
                    RecordListView(project: project)
                }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Project.self, Row.self], inMemory: true)
}
