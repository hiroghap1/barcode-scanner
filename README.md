# Barcode Assignment App(仮称)

CSV やコピー＆ペーストで取り込んだ表データに、iPhone のカメラでバーコードを順番に割り当てる iOS アプリ。

- 要件: [docs/PRD.md](docs/PRD.md)
- 設計: [docs/DESIGN.md](docs/DESIGN.md)
- 開発計画: [docs/PLAN.md](docs/PLAN.md)

## 構成

| パス | 内容 |
|------|------|
| `BarcodeAssign/` | アプリ本体(SwiftUI + SwiftData、iOS 17+) |
| `BarcodeAssignCore/` | UI 非依存のコアロジック(CSV/TSV パーサ・列推定・エクスポータ)。ローカル Swift パッケージ |
| `project.yml` | XcodeGen プロジェクト定義 |
| `docs/` | ドキュメント |

## 開発環境セットアップ

必要なもの:

- **Xcode 16 以降**(SwiftData / iOS 17 SDK が必要)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)(`brew install xcodegen`)

手順:

```bash
# 1. Xcode プロジェクトを生成(project.yml 変更後も同じ)
xcodegen generate

# 2. 開く
open BarcodeAssign.xcodeproj
```

Xcode 上で Signing & Capabilities → Team を自分の Apple ID に設定すれば実機で実行できる。
`*.xcodeproj` は生成物のため git 管理外(`project.yml` が正)。

## コアロジックのテスト

アプリのビルドとは独立して実行できる:

```bash
cd BarcodeAssignCore
swift test
```

## カメラについて

- バーコード読取は VisionKit `DataScannerViewController`(A12 以降)を第一候補とし、非対応端末では AVFoundation にフォールバックする
- カメラはシミュレータでは動作しないため、スキャン検証は実機で行う(検証記録: `docs/notes/scanner-spike.md`)
