import XCTest

/// P1 取込フロー(S2 → S3 → 保存)の E2E テスト。
/// ペースト取込はキーボード入力で代替する(ペーストボタンは iOS の許可ダイアログが挟まるため)。
/// CSV ファイル取込は Files アプリ連携のため自動化対象外(手動確認)。
final class ImportFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// スプラッシュを省略した状態でアプリを用意する(タップの妨げ防止)
    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-disableSplash"]
        return app
    }

    @MainActor
    func testPasteImportFlowSavesProject() throws {
        let app = makeApp()
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

        // 取込確定でレコード一覧(S4)へ遷移すること
        XCTAssertTrue(
            app.staticTexts["登録 1 ・ スキップ 0 ・ 残り 1"].waitForExistence(timeout: 5),
            "既存コード 1 件が登録済みとして集計されること"
        )
        XCTAssertTrue(app.staticTexts["A001"].exists, "行が表示されること")
        XCTAssertTrue(app.staticTexts["4901234567890"].exists, "既存コードが行に表示されること")
        attachScreenshot(of: app, name: "S4-レコード一覧")

        // 再起動しても、ホーム(S1)から同じデータを開き直せること(P2 完了条件)
        app.terminate()
        app.launch()
        let card = app.staticTexts["登録済み 1 / 2 件"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "再起動後もホームにプロジェクトが表示されること")
        attachScreenshot(of: app, name: "S1-ホーム")
        card.tap()
        XCTAssertTrue(
            app.staticTexts["登録 1 ・ スキップ 0 ・ 残り 1"].waitForExistence(timeout: 5),
            "ホームから同じデータを開き直せること"
        )
    }

    /// CSV ファイル取込(S2 → Files ピッカー → 検出表示)。
    /// シミュレータの Files に sample.csv(2行 × 3列・カンマ区切り)を手動配置した場合のみ
    /// 実行される(見つからなければスキップ)。ディスク直書きは fileproviderd に
    /// インデックスされないため、Files アプリへのドラッグ&ドロップで配置すること。
    @MainActor
    func testCSVFileImportDetectsTable() throws {
        let app = makeApp()
        app.launch()

        app.buttons["新しい取込"].tap()
        app.buttons["CSV ファイル"].tap()

        let chooseButton = app.buttons["ファイルを選択"]
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 5))
        chooseButton.tap()

        guard let fileCell = locateFileCell(in: app, prefix: "sample") else {
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

    /// 5,000 行規模の取込とスクロール(P5 の負荷確認。P2 の 1,000 行条件も包含)。
    /// シミュレータの Files に large.csv(5000 行 × 3 列・カンマ区切り)を配置した場合のみ
    /// 実行される(見つからなければスキップ)。
    /// ペースト経由は iOS の許可アラート(UIPasteboard 同期読取のメインスレッドブロック)が
    /// 自動化を不安定にするため、CSV ファイル経由で行う。
    @MainActor
    func testLargeCSVImportAndScroll() throws {
        let app = makeApp()
        app.launch()

        app.buttons["新しい取込"].tap()
        app.buttons["CSV ファイル"].tap()
        let chooseButton = app.buttons["ファイルを選択"]
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 5))
        chooseButton.tap()

        guard let fileCell = locateFileCell(in: app, prefix: "large") else {
            throw XCTSkip("Files に large.csv が無いためスキップ(手動配置時のみ実行)")
        }
        fileCell.tap()

        // SwiftUI の Text 補間は Int を桁区切り付きで表示する("5,000行")
        XCTAssertTrue(
            app.staticTexts["5,000行 × 3列を検出(区切り: カンマ)"].waitForExistence(timeout: 30),
            "5,000 行の CSV を読み込めること"
        )

        app.buttons["次へ"].tap()
        XCTAssertTrue(app.navigationBars["列の設定"].waitForExistence(timeout: 5))
        app.buttons["取込"].tap()

        // 5,000 行の保存と一覧表示が完了すること
        XCTAssertTrue(
            app.staticTexts["登録 0 ・ スキップ 0 ・ 残り 5,000"].waitForExistence(timeout: 60),
            "5,000 行の取込が完了して一覧に集計が表示されること"
        )

        // スクロールが完走すること(致命的な性能問題がないことの確認)
        for _ in 0..<10 {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(app.buttons["スキャン開始"].exists, "スクロール後も画面が応答すること")
        attachScreenshot(of: app, name: "S4-1000行")
    }

    /// スキャンフロー(S5)の E2E。カメラの読取はシミュレータで動かないため、
    /// 手動入力(⌨)で「登録 → 自動送り → 重複警告 → スキップ → 完了」を検証する。
    @MainActor
    func testScanFlowWithManualEntry() throws {
        let app = makeApp()
        app.launch()

        // 3 行(すべて未登録)のプロジェクトを作る
        app.buttons["新しい取込"].tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("sku,name,jan\nA001,shirt,\nA002,pants,\nA003,cap,\n")
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.navigationBars["列の設定"].waitForExistence(timeout: 5))
        app.buttons["取込"].tap()
        XCTAssertTrue(app.staticTexts["登録 0 ・ スキップ 0 ・ 残り 3"].waitForExistence(timeout: 5))

        // スキャン開始 → S5(カメラ権限アラートが出たら許可)
        app.buttons["スキャン開始"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["OK", "許可", "Allow"] {
            let button = springboard.alerts.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                break
            }
        }
        XCTAssertTrue(app.staticTexts["shirt"].waitForExistence(timeout: 5), "先頭の未登録行が表示されること")

        // 手動入力で登録 → 次の行へ自動送り
        enterManualCode(app, code: "4901111111111")
        XCTAssertTrue(app.staticTexts["pants"].waitForExistence(timeout: 5), "登録後に次の未登録行へ進むこと")
        attachScreenshot(of: app, name: "S5-スキャン")

        // 同じコードは重複警告 → キャンセルで登録しない
        enterManualCode(app, code: "4901111111111")
        XCTAssertTrue(
            app.staticTexts["このバーコードは既に登録されています"].waitForExistence(timeout: 5),
            "重複警告が表示されること"
        )
        attachScreenshot(of: app, name: "S5-重複警告")
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.staticTexts["pants"].waitForExistence(timeout: 5), "キャンセル後は同じ行に留まること")

        // 別のコードで登録 → 最終行へ
        enterManualCode(app, code: "4902222222222")
        XCTAssertTrue(app.staticTexts["cap"].waitForExistence(timeout: 5))

        // 最後の行をスキップ → 全行完了
        app.buttons["scan.skip"].tap()
        XCTAssertTrue(
            app.staticTexts["すべて完了しました 🎉"].waitForExistence(timeout: 5),
            "未登録行がなくなると完了画面が表示されること"
        )
        attachScreenshot(of: app, name: "S5-完了")
        app.buttons["一覧へ戻る"].tap()

        // S4 に反映されていること
        XCTAssertTrue(
            app.staticTexts["登録 2 ・ スキップ 1 ・ 残り 0"].waitForExistence(timeout: 5),
            "スキャン結果が一覧の集計に反映されること"
        )
    }

    /// 出力シート(S6)の表示とクリップボードコピー。
    /// ファイル保存・共有はシステム UI のため手動確認(スプレッドシート貼り付けは P4 完了条件)。
    @MainActor
    func testExportSheetShowsPreviewAndCopies() throws {
        let app = makeApp()
        app.launch()

        // 既存コード 1 件を含む 2 行を取り込む
        app.buttons["新しい取込"].tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("sku,name,jan\nB001,mug,4909999999991\nB002,plate,\n")
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.navigationBars["列の設定"].waitForExistence(timeout: 5))
        app.buttons["取込"].tap()
        XCTAssertTrue(app.staticTexts["登録 1 ・ スキップ 0 ・ 残り 1"].waitForExistence(timeout: 5))

        // 出力シートを開く
        app.buttons["出力"].tap()
        XCTAssertTrue(app.navigationBars["出力"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["4909999999991"].exists, "既存コードがプレビューに合成されること")
        XCTAssertTrue(
            app.staticTexts["未登録 1 件・スキップ 0 件が残っています(出力は可能です)。"].exists,
            "未登録残りの注意が表示されること"
        )
        attachScreenshot(of: app, name: "S6-出力")

        // 書込列のみに切り替えてもプレビューが表示されること
        // (列削減の正しさは ExportTableBuilderTests で担保。背後の S4 にも
        //  商品名が表示されるため、ここでは他列の非表示は検証しない)
        let barcodeOnlyToggle = app.switches["書込列のみ"].firstMatch
        // Form の Toggle は要素が行全体を覆い中央タップでは切り替わらないため、
        // スイッチ実体がある右端を座標でタップする
        barcodeOnlyToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(barcodeOnlyToggle.value as? String, "1", "書込列のみが ON になること")
        XCTAssertTrue(app.staticTexts["4909999999991"].waitForExistence(timeout: 3))

        // コピー実行 → フィードバック表示
        app.buttons["クリップボードにコピー"].tap()
        XCTAssertTrue(app.buttons["コピーしました"].waitForExistence(timeout: 3), "コピー完了の表示が出ること")
    }

    /// S5 の手動入力アラートにコードを入力して登録する
    @MainActor
    private func enterManualCode(_ app: XCUIApplication, code: String) {
        app.buttons["scan.manual"].tap()
        let field = app.textFields["バーコードの値"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "手動入力アラートが表示されること")
        field.tap()
        field.typeText(code)
        app.buttons["登録"].tap()
    }

    /// Files ピッカーで指定名のファイルセルを探す。
    /// 最近使った項目に出なければ「ブラウズ > このiPhone内」を辿る
    /// (ファイルはセル単位でタップする。ラベルは「sample, csv, …」形式)。
    @MainActor
    private func locateFileCell(in app: XCUIApplication, prefix: String) -> XCUIElement? {
        let predicate = NSPredicate(format: "label BEGINSWITH[c] %@", prefix)
        var cell = app.cells.matching(predicate).firstMatch
        if cell.waitForExistence(timeout: 3) { return cell }

        let browseTab = app.buttons["ブラウズ"]
        if browseTab.waitForExistence(timeout: 3) { browseTab.tap() }
        let localStorage = app.staticTexts["このiPhone内"]
        if localStorage.waitForExistence(timeout: 3) { localStorage.tap() }
        cell = app.cells.matching(predicate).firstMatch
        return cell.waitForExistence(timeout: 5) ? cell : nil
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
