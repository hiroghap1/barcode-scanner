import SwiftUI
import SwiftData

/// S1 ホーム(プロジェクト一覧)。
/// 作業の再開・新規取込・削除・名前変更の入口。
struct HomeView: View {
    /// 取込完了時に S4 へ遷移するためのナビゲーションパス
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @State private var isImportPresented = false
    @State private var projectToDelete: Project?
    @State private var projectToRename: Project?
    @State private var renameText = ""

    var body: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("ピッと登録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ブランドロゴ(ライト/ダークで自動切替)。タイトル文字列は戻るボタン用に残す
            ToolbarItem(placement: .principal) {
                Image("LogoHeader")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                    .accessibilityLabel("ピッと登録")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isImportPresented = true
            } label: {
                Label("新しい取込", systemImage: "plus")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            // CTA は両モードともブランドの濃い緑 + 白太字(視認性を実機確認済み)
            .tint(Color("BrandGreen"))
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $isImportPresented) {
            ImportFlowView { project in
                isImportPresented = false
                path.append(project)
            }
        }
        .confirmationDialog(
            "「\(projectToDelete?.name ?? "")」を削除しますか?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let project = projectToDelete {
                    modelContext.delete(project)
                }
                projectToDelete = nil
            }
            Button("キャンセル", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("取り込んだデータと割り当てたコードがすべて削除されます。")
        }
        .alert(
            "名前を変更",
            isPresented: Binding(
                get: { projectToRename != nil },
                set: { if !$0 { projectToRename = nil } }
            )
        ) {
            TextField("プロジェクト名", text: $renameText)
            Button("変更") {
                if let project = projectToRename {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        project.name = trimmed
                        project.updatedAt = .now
                    }
                }
                projectToRename = nil
            }
            Button("キャンセル", role: .cancel) { projectToRename = nil }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("プロジェクトがありません", systemImage: "square.and.arrow.down")
        } description: {
            Text("CSV やコピーした表を取り込んで始めましょう")
        }
    }

    private var projectList: some View {
        List {
            Section {
                ForEach(projects) { project in
                    NavigationLink(value: project) {
                        ProjectCardView(project: project)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            projectToDelete = project
                        }
                        // 削除は確認ダイアログを挟むため destructive でも自動実行させない
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("名前を変更", systemImage: "pencil") {
                            renameText = project.name
                            projectToRename = project
                        }
                        Button("削除", systemImage: "trash", role: .destructive) {
                            projectToDelete = project
                        }
                    }
                }
            }
        }
    }
}

/// ホームのプロジェクトカード(名前・進捗バー・件数・更新日)
struct ProjectCardView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.headline)
            ProgressView(value: progress)
                .tint(isCompleted ? .green : .accentColor)
            HStack {
                Text(isCompleted
                     ? "完了 \(project.registeredCount)/\(project.totalCount)"
                     : "登録済み \(project.registeredCount) / \(project.totalCount) 件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(project.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(project.name) 登録済み \(project.registeredCount) / \(project.totalCount) 件"
        )
    }

    private var progress: Double {
        project.totalCount == 0 ? 0 : Double(project.registeredCount) / Double(project.totalCount)
    }

    private var isCompleted: Bool {
        project.totalCount > 0 && project.pendingCount == 0
    }
}

#Preview {
    NavigationStack {
        HomeView(path: .constant(NavigationPath()))
    }
    .modelContainer(for: [Project.self, Row.self], inMemory: true)
}
