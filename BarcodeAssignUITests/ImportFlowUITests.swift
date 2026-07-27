import XCTest

/// P1 取込フロー(S2 → S3 → 保存)の E2E テスト。
/// ペースト取込はキーボード入力で代替する(ペーストボタンは iOS の許可ダイアログが挟まるため)。
/// CSV ファイル取込は Files アプリ連携のため自動化対象外(手動確認)。
final class ImportFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPasteImportFlowSavesProject() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["新しい取込"].tap()

        // S2: 表テキストを入力(1行は書込列が空 → 未登録、1行は既存コードあり → 登録済み)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "S2 のテキストエリアが表示されること")
        editor.tap()
        editor.typeText("sku,name,jan\nA001,shirt,4901234567890\nA002,pants,\n")

        XCTAssertTrue(
            app.staticTexts["2行 × 3列を検出(区切り: カンマ)"].waitForExistence(timeout: 5),
            "行数・列数・区切り文字が即時表示されること"
        )
        attachScreenshot(of: app, name: "S2-取込")

        let nextButton = app.buttons["次へ"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        // S3: 列マッピング(ヘッダー名から自動推定されるので既定値のまま)
        XCTAssertTrue(app.navigationBars["列の設定"].waitForExistence(timeout: 5))
        // LabeledContent の値は結合された accessibility 要素になるため、ラベル側の存在のみ確認する
        // (件数の正しさは取込後の「登録済み 1 / 2 件」で検証される)
        XCTAssertTrue(app.staticTexts["行数"].exists, "行数の集計が表示されること")
        XCTAssertTrue(app.staticTexts["既存コード"].exists, "既存コード件数が表示されること")
        attachScreenshot(of: app, name: "S3-列マッピング")

        app.buttons["取込"].tap()

        // ルートに戻り、保存されたプロジェクトが表示されること
        XCTAssertTrue(
            app.staticTexts["登録済み 1 / 2 件"].firstMatch.waitForExistence(timeout: 5),
            "既存コード 1 件が登録済みとして保存されること"
        )
    }

    /// CSV ファイル取込(S2 → Files ピッカー → 検出表示)。
    /// シミュレータの Files に sample.csv(2行 × 3列・カンマ区切り)を手動配置した場合のみ
    /// 実行される(見つからなければスキップ)。ディスク直書きは fileproviderd に
    /// インデックスされないため、Files アプリへのドラッグ&ドロップで配置すること。
    @MainActor
    func testCSVFileImportDetectsTable() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["新しい取込"].tap()
        app.buttons["CSV ファイル"].tap()

        let chooseButton = app.buttons["ファイルを選択"]
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 5))
        chooseButton.tap()

        // Files ピッカー: 最近使った項目に出なければ「ブラウズ > このiPhone内」を辿る
        // (ファイルはセル単位でタップする。ラベルは「sample, csv, …」形式)
        let filePredicate = NSPredicate(format: "label BEGINSWITH[c] 'sample'")
        var fileCell = app.cells.matching(filePredicate).firstMatch
        if !fileCell.waitForExistence(timeout: 3) {
            let browseTab = app.buttons["ブラウズ"]
            if browseTab.waitForExistence(timeout: 3) { browseTab.tap() }
            let localStorage = app.staticTexts["このiPhone内"]
            if localStorage.waitForExistence(timeout: 3) { localStorage.tap() }
            fileCell = app.cells.matching(filePredicate).firstMatch
        }
        if !fileCell.waitForExistence(timeout: 5) {
            throw XCTSkip("Files に sample.csv が無いためスキップ(手動配置時のみ実行)")
        }
        fileCell.tap()

        XCTAssertTrue(
            app.staticTexts["2行 × 3列を検出(区切り: カンマ)"].waitForExistence(timeout: 5),
            "CSV ファイルから表を検出できること"
        )
        XCTAssertTrue(app.staticTexts["sample.csv"].exists, "読み込んだファイル名が表示されること")
        attachScreenshot(of: app, name: "S2-CSVファイル")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
