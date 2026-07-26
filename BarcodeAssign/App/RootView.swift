import SwiftUI

/// ルート画面。
/// P0 時点ではスパイク画面への入口のみ。P2 でホーム(S1)に置き換える。
struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("P0 技術検証") {
                    NavigationLink("バーコードスキャン スパイク") {
                        SpikeScanView()
                    }
                }
                Section {
                    Text("MVP 画面は P1 以降で実装予定")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("バーコード割当")
        }
    }
}

#Preview {
    RootView()
}
