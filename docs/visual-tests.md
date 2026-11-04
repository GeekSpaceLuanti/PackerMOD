# 画面の自動確認（Windows / WSL）

PowerShell から次の1コマンドで、Luanti実機描画の各画面を `.screenshots/` に出力します。`index.html` で画像を一覧比較できます。

```powershell
.\scripts\visual_tests.ps1
```

Windowsのデスクトップ操作、F12、既存Luantiへのインストールは不要です。WSLのXvfb仮想画面にLuantiを起動し、ウィンドウだけをPNGにします。最新の作業ツリーを直接読み、`LUANTI_USER_PATH` に毎回新しい一時ディレクトリを指定します。ポータブルビルドはこの環境変数を無視するため、実行ファイルも一時領域にコピーして分離します。サンプルPack件数とメニュー準備完了のログを確認してから撮影します。既存の設定・Pack・ワールドには触れません。

対象は空一覧、3件一覧、7件一覧の1／2ページ、Worlds、Multiplayer、Mods、Info、Import、Createの基本情報／ゲーム選択／MOD選択、同じGUIに統合した本体設定（数値・オン／オフ・選択肢・キー・ノイズ・ベクトル・フラグ・パス）、日本語／英語です。各画面のエンジンログもPNGの隣に保存します。Luaエラー・起動失敗があれば非ゼロ終了します。

## 初回セットアップ

Ubuntu 24.04で必要なパッケージを導入します。

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends lua-busted lua5.1 xvfb xauth xdotool x11-apps imagemagick cmake g++ make curl ca-certificates libsqlite3-dev libcurl4-openssl-dev libfreetype6-dev libjpeg-dev libpng-dev libluajit-5.1-dev libsdl2-dev libgl1-mesa-dev zlib1g-dev libzstd-dev libgmp-dev libjsoncpp-dev
```

公式Luanti 5.16.1ソースをユーザーキャッシュ内でビルドします（以降は再利用）。

```powershell
.\scripts\visual_tests.ps1 -Setup
```

独自のLinux版Luantiを使う場合:

```powershell
.\scripts\visual_tests.ps1 -LuantiBin /path/to/luanti -Distribution Ubuntu
.\scripts\visual_tests.ps1 -View library_many -Width 1024 -Height 768
```

## Linux / WSLで個別に撮影

```sh
bash scripts/screenshot_mainmenu.sh library_empty
bash scripts/screenshot_mainmenu.sh library_many
bash scripts/screenshot_mainmenu.sh library_page2
bash scripts/screenshot_mainmenu.sh modal_create_mods
WIN_W=1024 WIN_H=768 bash scripts/screenshot_mainmenu.sh library_many .screenshots/library_1024.png
make screenshot-all
busted spec/
```

Linux描画の検証です。Windows固有のフォント、パス処理、Junctionの互換性までは保証しません。サンプルワールドではゲームを起動せず、メニューを確認します。

## 本体設定の実保存テスト

```powershell
.\scripts\visual_tests.ps1 -View engine_settings_test
.\scripts\visual_tests.ps1 -View engine_settings_noise
.\scripts\visual_tests.ps1 -View engine_settings_keys -Width 1024 -Height 768
.\scripts\visual_tests.ps1 -View settings_controls -Width 1024 -Height 768
.\scripts\visual_tests.ps1 -View settings_audio
.\scripts\visual_tests.ps1 -View settings_interaction
```

本体の設定定義と実際のSettings APIを使い、型ごとの適用、ファイルへの保存、不正値の拒否、初期値への復元、無関係な設定の保持を一時プロファイルで検証します。WSLテスト用ビルドはgettext無効のため、本体由来の説明は英語です。Windows版では本体の日本語翻訳を利用します。

`settings_interaction` は1280×800の固定フィクスチャで実際のマウスドラッグ、オン／オフ、タブ切替、キー入力を実行し、保存された値を照合します。ドラッグ途中での再描画による操作中断も検出します。仮想画面内だけで動作します。

## ContentDBの実通信テスト

通常の一括撮影は固定データを使います。実際の検索・公開版プルダウンと、ゲームの取得・展開・Pack保存は次で検証できます。どちらも一時ユーザーデータだけを使います。

```powershell
.\scripts\visual_tests.ps1 -View contentdb_catalog
.\scripts\visual_tests.ps1 -View contentdb_live
```

## このPCのWindows版へ反映

```powershell
.\scripts\deploy_local.ps1
```

Luantiを通常終了してから実行します。更新前のメニュー・テクスチャ・設定を保存し、Pack・キャッシュ・ワールドが変わっていないことと配置ファイルのハッシュを確認します。

## ワールド設定の隔離と実ゲーム起動

```powershell
.\scripts\visual_tests.ps1 -View settings_movement
.\scripts\visual_tests.ps1 -View settings_hotbar -Width 1024 -Height 768
.\scripts\visual_tests.ps1 -View world_settings
.\scripts\visual_tests.ps1 -View world_settings_test
```

`world_settings_test` は一時領域の2ワールドを実際に起動します。ゲーム内でクリエイティブ、時間速度、重力、シード、水位を照合し、終了後の全体設定とパック内の保存先の復元を確認します。既存ワールドの地形設定を変更できないこと、全体画面にワールド設定が漏れないことも検証します。

## スクロール・倍率・表示制限・個別初期化

```powershell
.\scripts\visual_tests.ps1 -View settings_ui_test
.\scripts\visual_tests.ps1 -View settings_keymap_end -Width 1024 -Height 768
.\scripts\visual_tests.ps1 -View settings_scale_large
.\scripts\visual_tests.ps1 -View library_scale_large
```

`settings_ui_test` は上級者・開発用の非表示条件、検索からの回避防止、独立したキーマップ、各項目の初期化、3種類の倍率の変更・初期化と実ファイルへの保存を検証します。`settings_interaction` は実際のキー入力後に行の「戻す」を押して初期化を確認します。


最大サイズを指定した800×600の言語プルダウン・スライダー・完了ボタンの実操作と、起動後のリサイズを検証できます。

```powershell
.\scripts\visual_tests.ps1 -View settings_scale_dropdown -Width 800 -Height 600
.\scripts\visual_tests.ps1 -View settings_scale_interaction -Width 800 -Height 600
.\scripts\visual_tests.ps1 -View settings_resize
```


GUIサイズの選択肢（800×600では「大」を表示しない）:

```powershell
.\scripts\visual_tests.ps1 -View settings_size_dropdown -Width 800 -Height 600
```


リモート由来の `scripts/measure_ui.py` は計測ツールとして維持しています。`make check-design` は現行のLua幾何テストと実エンジン撮影・計測を行います。`spec/design/library.json` のcyan罫線・composite枠アサーションは旧Synthwave向けの履歴資料で、現行の無彩色UIには適用しません。

計測ツールにはPythonの `numpy` と `Pillow` が必要です。`make measure`／`make check-design` の `PYTHON` 変数で、これらを導入した仮想環境のPython実行ファイルを指定できます。測定画像は `.screenshots/measure_<画面>.png` に保存します。
