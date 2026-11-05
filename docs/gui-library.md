# GUIライブラリ

一覧・パック詳細・取り込み・パック作成・ワールド作成・削除確認・設定（詳細編集を含む）はPMUI 2を使用します。

部品の共通設定は`mainmenu/ui/controls.lua`にあります。ボタンの高さ・文字サイズ・角丸を変更すると、画面ごとのCSSへ同じ指定を書かずに全画面へ適用できます。
通常ボタンは`button`、入力欄は`field`、複数行入力は`textarea`、選択欄は`dropdown`、スライダーは`slider`として設定します。
キー入力ボタンと切替ボタンには、個別指定がなければ通常ボタンの設定を継承します。
主要操作・削除・控えめな操作は`variant = "primary" / "danger" / "quiet"`で役割を指定し、色は共通テーマで決まります。

実行時には`packermod.pmui.configure_control("button", { ["min-height"] = 48 })`でも一括変更できます。

- 共通ライブラリとAPI説明：`mainmenu/lib/pmui/modern/README.md`
- 全画面共通の部品設定：`mainmenu/ui/controls.lua`
- 画面構成：`mainmenu/ui/pack_detail.lua`
- CSS：`mainmenu/ui/pack_detail.css`
- 他MOD向けサンプル：`examples/pmui_demo`
- 画像の再生成：`python scripts/build_modern_gui.py`
- 回帰テスト：`make test`
- 独立MODのゲーム内検証：`bash scripts/test_modern_gui.sh`
- 本体の撮影：`scripts/visual_tests.ps1 -View worlds_empty`
- 自動配置した部品の実操作：`scripts/visual_tests.ps1 -View gui_controls_test`

旧実装ではformspec単位の固定寸法とフォントの倍率が別々に決まり、画像・ボタン・余白だけが大きくなる場合がありました。
HTMLモックの角丸・アイコン・内容幅のタブも旧描画経路へ移植されていなかったため、折り返しを追加しても同じ外観になりませんでした。
PMUI 2はCSS pxを基準に同時に寸法を計算し、パネル・ボタン・テキスト・入力・タブを共通の描画経路で出力します。
PackerMOD固有のデータ・翻訳・イベント処理は呼び出し側に残し、ゲーム内MODでも同じライブラリを利用できます。
