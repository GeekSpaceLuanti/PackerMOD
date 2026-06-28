# WORKLOG

## 記入ルール

- `git push` ごとに1セクション追記する
- 新しいエントリは「記入ルール」セクションの**直下=先頭**に追加(逆時系列・最新が上)
- 各エントリ書式:
  - 見出し: `## YYYY-MM-DD HH:MM (ブランチ名)`
  - **変更概要**: 何を・なぜ
  - **主な変更ファイル**: 箇条書き
  - **コミット**: コミットハッシュ(push 後に追記してよい)
  - **次のTODO**: あれば

## 2026-06-28 19:25 (main)

**変更概要**:
ユーザー指摘: 「Pack id の入力欄に Base id という表示が被ってる」。
直前まで通っていた重なり検出 spec ですり抜けていたバグ。

調査で確定: Luanti `lua_api.md:3288` の field 仕様
「`label`, if not blank, will be text printed on the top left **above** the field」。
formspec v6 では field の label は box の **上** に描画される(box の y より
約 0.4 単位はみ出す)。私の Layout は field の縦スペースを box 高さだけで
予約していて、上方向の label band を考慮していなかった。結果として、
Pack id field の真下に置いた Base id field の「Base id」文字が Pack id の
入力欄に侵食していた。

修正:
- `Field` widget が `label != ""` のとき、measure で実効 h に
  `FIELD_LABEL_H = 0.4` を加算 (`w._label_h` / `w._box_h` に内訳を保持)
- render は box を `_y + label_h` から描画し、Luanti が label band を上に
  描いても他要素と衝突しない
- spec に Field-Field 縦並びの再現テストを 3 件追加 (RED → GREEN)

連鎖修正:
- field 高さが +0.4 されて Create タブが従来の TAB_H=7.1 に入らなく
  なったため、`PACKERMOD_TAB_H` を 8.0 に拡張
- Create タブのカラム area と textlists を `flex=1` に切り替えて、
  textlist が残りの縦スペースに自動追従するように

busted 68 件 pass、4 タブ目視確認で Pack id ↔ Base id の被りが解消、
Import の Source field と status label の被りも解消(副作用で見つけたバグ)。

**主な変更ファイル**:
- `mainmenu/lib/layout.lua` (Field の measure / render に label band 反映)
- `mainmenu/init.lua` (PACKERMOD_TAB_H 7.1 → 8.0)
- `mainmenu/tabs/tab_create.lua` (textlists を flex 化)
- `spec/layout_spec.lua` (Field label band の 3 件追加)

## 2026-06-28 19:12 (main)

**変更概要**:
直前コミットの残 TODO 2 件を片付け。

1. PMLayout に **flex** を追加: HBox/VBox 子の `flex` で余り空間を比率分配。
   default align を `stretch` に変更し、container と Spacer/TextList は
   cross 軸を自動充填するように(leaf は naturalsize 維持で意図しない伸長を防ぐ)。
   tab_packs/tab_import/tab_settings の手動 `Spacer{w=INNER_W - ...}` を
   `Spacer{flex=1}` に置換、`INNER_W` 算出も不要に。
2. screenshot のタブ切替を **設定駆動**に: init.lua が
   `packermod_initial_tab` 設定を読んで `tv:set_tab(...)` を呼ぶように。
   `scripts/screenshot_mainmenu.sh` は xdotool クリック座標(壊れやすい)
   を捨てて、conf に書く→撮る→消す方式へ。

flex の spec を `spec/layout_spec.lua` に 4 件追加 (RED → GREEN)、
busted 全 65 件 / E2E 1 件 pass。4 タブを撮影し直して
レイアウトに異常がないことを目視確認。

**主な変更ファイル**:
- `mainmenu/lib/layout.lua` (flex 分配 + stretchable kind + class default)
- `mainmenu/init.lua` (packermod_initial_tab フック)
- `mainmenu/tabs/tab_packs.lua`, `tab_import.lua`, `tab_settings.lua` (flex 移行)
- `scripts/screenshot_mainmenu.sh` (設定駆動切替)
- `spec/layout_spec.lua` (flex 仕様)

## 2026-06-28 18:58 (main)

**変更概要**:
Main menu の UI 崩れ修正。formspec v6 の `label` は宣言高さが無いのに実描画 0.5
単位を取るため、Create タブで label と直下の入力欄/textlist が 4 箇所重なって
いた(視覚的に「Query」が「ContentDB search」に被り、「Add」ボタンが mod_list
の裏に隠れる)。

座標数学を人手から外すため、薄い宣言型 layout lib `mainmenu/lib/layout.lua`
を新規追加(VBox / HBox / Stack / Field / Label / Button / TextList / Spacer
など、約 200 行・core 依存ゼロ・他 MOD 再利用可能)。全 4 タブを宣言 API へ
書き換え。

再現テストは `spec/layout_spec.lua` に追加: AABB 重なり検出器 +
formspec パーサ +「旧 Create スナップショット」リテラルで検出器自体の
回帰防止 + 現行 4 タブの「重なり 0 / size 内収まり」アサート。busted で 8
追加 / 合計 61 pass。

視覚検証は Xvfb + Luanti F12 (PR #16749, Luanti 5.16+) を `scripts/screenshot_mainmenu.sh`
にまとめ、`make screenshot TAB=<name>` で実行可能。Before/After PNG を
`/tmp/mainmenu_<tab>_{before,after}.png` に保存して目視確認済み。

**主な変更ファイル**:
- 新規: `mainmenu/lib/layout.lua` (宣言型 formspec layout)
- 新規: `spec/layout_spec.lua` (重なり検出 + 全タブ回帰)
- 新規: `scripts/screenshot_mainmenu.sh` (Xvfb スクショ)
- `mainmenu/init.lua` (layout を `packermod.layout` として公開)
- `mainmenu/tabs/tab_create.lua` (全面書き換え、4 件の重なりを根治)
- `mainmenu/tabs/tab_packs.lua` (書き換え、2 件の重なりを根治)
- `mainmenu/tabs/tab_import.lua` (書き換え)
- `mainmenu/tabs/tab_settings.lua` (書き換え)
- `Makefile` (`screenshot` ターゲット追加)

**次のTODO**:
- HBox/VBox に `flex` を入れて Spacer の手動幅指定を不要にする (任意)
- スクショ click 座標を window resolution から自動算出 (固定ピクセル依存をやめる)

## 2026-06-28 17:24 (main)

**変更概要**:
Plan 手順 6〜10 を完走。Issue #1〜#7 全部 close。

- ContentDB HTTP+JSON クライアント(release pin)
- mod 配置パイプライン(contentdb cache / bundle / url → `<world>/worldmods/`)
- pack_launcher で world 作成 + mod 配置を統合、Packs タブ Play から呼出
- Pack importer(URL / zip / yaml、temp-extract-then-validate で packs/ を汚さない)
- Pack builder(tabdata → manifest 構築、重複 mod 拒否)
- Create タブ本実装(ContentDB 検索 + release id pin で mod 追加 + Export)
- Windows install.ps1 / uninstall.ps1(copy デフォルト、symlink は Developer Mode 落ち)
- E2E ランナー(throwaway $HOME で install → Luanti boot → log 検証)+ Makefile
- PackerMOD-Base scaffold 別リポジトリ(<https://github.com/GeekSpaceLuanti/PackerMOD-Base>)+ docs/packermod-base.md

busted 計 53 テスト + E2E 1 件すべて pass。Luanti 起動 ERROR/WARNING ゼロ。

**主な変更ファイル**:
- `mainmenu/contentdb.lua` `mainmenu/mod_installer.lua` `mainmenu/pack_launcher.lua`
- `mainmenu/pack_importer.lua` `mainmenu/pack_builder.lua`
- `mainmenu/world_builder.lua`(read_file / delete_dir / copy_dir / extract_zip を default_fs に追加)
- `mainmenu/init.lua`(全モジュールを packermod 名前空間で束ね)
- `mainmenu/tabs/{tab_packs,tab_import,tab_create}.lua`
- `spec/{contentdb,mod_installer,pack_launcher,pack_importer,pack_builder}_spec.lua`
- `spec/e2e/run.sh`、`Makefile`
- `install/install.ps1`、`install/uninstall.ps1`
- `docs/packermod-base.md`

**コミット**: 9b0d9a2, 341acfd, 34c3c7b, 6bba785, f07c7c7, 2b6544f

**次のTODO**:
- VoxeLibre 0.91 を PackerMOD-Base へ取り込み(Issue #8)
- Windows install.ps1 の実機検証(Issue #6 残課題)
- ContentDB ブラウザを mainmenu 自前実装(現状は公式 mainmenu に戻さないと使えない)
- formspec UI ブラッシュアップ(Create タブのレイアウトが密)

## 2026-06-28 16:51 (main)

**変更概要**:
PackerMOD の初期スケルトン + MVP コアロジックを実装。Luanti(旧 Minetest)のメインメニューを `main_menu_script` 経由で差し替え、Pack(YAML manifest)を読み込んで base game + 追加 MOD 構成で world を自動生成して起動する一連の流れを動作させた。Plan(`~/.claude/plans/luanit-mod-mod-merry-stroustrup.md`)の手順 1〜5 を消化。

- subset YAML パーサと manifest schema 検証(busted で 22 テスト)
- `world_builder` で manifest → `world.mt` 生成。busted の fake FS でユニットテスト
- 改造 mainmenu スケルトン(Packs / Import / Create / Settings タブ)
- ダミー base game `~/.minetest/games/packerbase_0_91/`(game.conf + 空 mods/)を smoke 用に配置
- インストーラ(symlink モード)で `~/.minetest/PackerMOD/mainmenu` → 開発ディレクトリ
- ユーザー目視確認: Smoke Test Pack を Play → 世界に入れることを確認

途中で `core.create_dir` が `/home` への書き込みでブロックされる不具合を、サンドボックス模擬テストで再現してから修正(`mkdir` を leaf 1 階層のみに変更)。再現テスト先行ルールを失念して直接修正に走ったところをユーザーから指摘され、`feedback_repro_test_first.md` として memory に保存。

**主な変更ファイル**:
- `mainmenu/init.lua` — エントリポイント、4 タブ登録、グローバル定数
- `mainmenu/yaml.lua` — subset YAML parser/dumper
- `mainmenu/manifest.lua` — schema 検証、Luanti と busted の両環境で require/dofile 自動切替
- `mainmenu/world_builder.lua` — world.mt 生成 + create_world、_default_fs を公開してテスト可能化
- `mainmenu/pack_manager.lua` — `<user-data>/PackerMOD/packs/` 列挙
- `mainmenu/tabs/tab_packs.lua` — 一覧 + Play(world 作成 + `gamedata.selected_world` + `core.start()`)
- `mainmenu/tabs/{tab_import,tab_create,tab_settings}.lua` — placeholder
- `spec/{yaml,manifest,world_builder}_spec.lua` — busted テスト(計 23)
- `test_fixtures/sample_pack.yaml` — 3 source 全部入りサンプル
- `install/install.sh` — `main_menu_script` 設定書き込み、symlink/copy モード
- `install/uninstall.sh` — `main_menu_script` 復元
- `.gitignore`

**コミット**: 19e2352

**次のTODO**:
- `mainmenu/contentdb.lua`: ContentDB HTTP API クライアント(release pin による DL)
- Import タブ実装(URL / ローカル zip からの取り込み + manifest 検証)
- Create タブ本実装(ContentDB 検索、mod 選択 UI、manifest export)
- PackerMOD-Base 別リポジトリ(VoxeLibre fork)
- Pack 起動時の mod 配置パイプライン(cache → world `worldmods/` 配置 / `load_mod_*`)
- Windows 用 `install/install.ps1`
- E2E テスト(クリーン環境 → install → Smoke 起動 → uninstall)
