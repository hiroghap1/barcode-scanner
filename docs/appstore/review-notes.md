# 審査ノート(App Review 向けメモ・下書き)

App Store Connect の「App Review に関する情報 > メモ」欄に貼り付ける(英語推奨のため英日併記)。

## メモ欄に貼る文面

```
This app assigns barcode values to rows of a product list (CSV / spreadsheet data) by scanning with the camera. No login is required and the app works fully offline.

How to test:
1. Launch the app and tap 「新しい取込」 (New Import).
2. Paste the sample data below into the text area (or use any CSV file):

品番,商品名,JAN
A001,サンプル商品1,
A002,サンプル商品2,
A003,サンプル商品3,

3. Tap 「次へ」 (Next), then 「取込」 (Import) in the top-right corner.
4. Tap 「スキャン開始」 (Start Scanning) and point the camera at any EAN-13/JAN barcode (e.g. on a book or retail product). The value is saved to the current row and the app advances to the next row automatically.
5. If no physical barcode is available, tap 「手動入力」 (Manual Entry) to type a value instead.
6. Tap 「出力」 (Export) on the list screen to copy the result as TSV or save it as a CSV file.

The camera is used only for barcode scanning. No data leaves the device.
```

## 補足(自分用)

- ログイン情報の提出は不要(アカウント機能なし)
- カメラ許可ダイアログの文言は設定済み: 「商品のバーコードを読み取るためにカメラを使用します。」
- 審査員が実バーコードを持っていない場合に備え、手動入力の案内を含めている
- 輸出コンプライアンス: 暗号化なし(ITSAppUsesNonExemptEncryption = false 設定済み。質問には「いいえ」で回答)
