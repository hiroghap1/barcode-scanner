# CLAUDE.md

iPhone カメラで表データにバーコードを順番に割り当てる iOS アプリ(SwiftUI + SwiftData、iOS 17+)。

## 必読ドキュメント

- `docs/PRD.md` — 要件
- `docs/DESIGN.md` — 機能・画面設計(S1〜S6 の画面 ID はここで定義)
- `docs/PLAN.md` — 開発計画(P0〜P6 のフェーズ定義と完了条件)
- `docs/notes/scanner-spike.md` — P0 実機スキャン検証の記録

## コマンド

```bash
# コアロジックのテスト(Xcode のバージョンに依存しない)
cd BarcodeAssignCore && swift test

# Xcode プロジェクト再生成(project.yml 変更後に必須)
xcodegen generate

# UI テスト(シミュレータ。CSV ファイル取込テストは Files に sample.csv が無ければ自動スキップ)
xcodebuild test -project BarcodeAssign.xcodeproj -scheme BarcodeAssign \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BarcodeAssignUITests
```

## 構成上のルール

- `*.xcodeproj` は生成物(gitignore 済み)。**project.yml が正** — ターゲット設定・Info.plist はここを編集する
- UI 非依存のロジック(パース・エクスポート・推定など)は `BarcodeAssignCore` パッケージに置き、単体テストを付ける
- UI 文言・コード内ドキュメントは日本語
- アプリ本体のビルドには **Xcode 16 以降が必要**(SwiftData / iOS 17 SDK)

## 技術メモ(ハマりどころ)

- Swift の `String` では CRLF(`\r\n`)が 1 つの `Character` になる。改行判定は `"\r\n"` も明示するか `isNewline` を使う(TableParser で対応済み)
- UPC-A は VisionKit / AVFoundation とも **EAN-13(先頭 0 付き)として検出される**。独立したシンボロジー指定はない
- VisionKit `DataScannerViewController` は A12 以降 + 実機のみ。シミュレータではスキャン検証不可
