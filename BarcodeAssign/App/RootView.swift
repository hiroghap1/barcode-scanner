import SwiftUI
import SwiftData

/// ルート画面。
/// P1 時点では取込フローの入口 + 保存確認用の仮プロジェクト一覧。P2 でホーム(S1)に置き換える。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var isImportPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isImportPresented = true
                    } label: {
                        Label("新しい取込", systemImage: "square.and.arrow.down")
                    }
                }
                if !projects.isEmpty {
                    Section("プロジェクト(仮表示・S1 は P2 で実装)") {
                        ForEach(projects) { project in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                Text("登録済み \(project.registeredCount) / \(project.totalCount) 件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteProjects)
                    }
                }
                Section("P0 技術検証") {
                    NavigationLink("バーコードスキャン スパイク") {
                        SpikeScanView()
                    }
                }
            }
            .navigationTitle("バーコード割当")
            .sheet(isPresented: $isImportPresented) {
                ImportFlowView(onComplete: { isImportPresented = false })
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(projects[index])
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Project.self, Row.self], inMemory: true)
}
