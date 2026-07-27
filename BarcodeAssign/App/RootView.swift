import SwiftUI
import SwiftData

/// ルート画面。ホーム(S1)を起点に、プロジェクト選択・取込完了でレコード一覧(S4)へ遷移する。
/// 起動時は短いスプラッシュアニメーションを挟む。
struct RootView: View {
    @State private var path = NavigationPath()
    /// UI テストは "-disableSplash" でスプラッシュを省略する(タップの妨げになるため)
    @State private var isSplashVisible = !ProcessInfo.processInfo.arguments.contains("-disableSplash")

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                HomeView(path: $path)
                    .navigationDestination(for: Project.self) { project in
                        RecordListView(project: project)
                    }
            }
            if isSplashVisible {
                SplashView {
                    // ロゴ完成の余韻からホームへゆっくり切り替える
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isSplashVisible = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Project.self, Row.self], inMemory: true)
}
