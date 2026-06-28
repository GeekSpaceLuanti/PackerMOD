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

## 2026-06-28 23:20 (main)

**変更概要**:
メインメニュー再設計 Phase 8。タブビューを撤廃し、CurseForge / Modrinth 風の単一画面(Library + Pack 詳細)に置き換え。Worlds サブタブで複数ワールド一覧表示・新規ワールド作成 + Play まで動くようになった。Multiplayer / Mods / Info サブタブはプレースホルダ(Phase 9/10/11 で実装)。
- `mainmenu/library.lua` + `mainmenu/ui/library.yml` を新設。`dialog_create("packermod_library", ...)` で formspec を出す
- `init.lua` から tabview を削除(`library.show()` に置換)。旧 `tabs/tab_*.lua` + `ui/tab_*.yml` は Phase 11 でモーダル化するときに転用するので残置
- レイアウト: page > row[col(w=5.0) Pack list + Imp/Cre/Set 3 ボタン | col(flex=1) 詳細パネル(タイトル + サブナビ + Worlds/Multi/Mods/Info の when 切替セクション)]
- サブナビボタンの「アクティブ表示」は `variant: primary/secondary` を ctx で動的に切替
- 起動時 subtab 指定: `core.settings:packermod_initial_subtab` → screenshot スクリプトが利用
- `scripts/screenshot_mainmenu.sh` と Makefile を tab 概念から subtab 概念に書き換え。引数は `library | worlds | multi | mods | info`。`packermod_initial_tab` 互換削除予定の cleanup も入れた
- `install/install.sh` に `textures/packermod_icon_*.png` の symlink 追加(以前から `~/.minetest/textures` にコピーされておらず icon-button が背景 blank になっていた)
- 実機(Xvfb)で Sample Pack 選択 → Worlds サブタブ表示 → Mods サブタブ切替を確認。アイコン PNG が白系で background に同化して見えにくいのは別 issue
- 全 137 spec 緑(+10 件: library 純粋ロジック 5 件 + library.yml ui_loader 展開 3 件 + format_pack_label/format_world_label 2 件)

**主な変更ファイル**:
- mainmenu/library.lua (新規)
- mainmenu/ui/library.yml (新規)
- mainmenu/lib/ui_loader.lua (ui_yaml_path 追加 — tab_ プレフィックス無しの YAML 用)
- mainmenu/init.lua (tabview → library.show())
- scripts/screenshot_mainmenu.sh (tab → subtab、`packermod_initial_subtab` driven)
- Makefile (TAB → SUBTAB, `screenshot-all` の対象を library/worlds/multi/mods/info に)
- install/install.sh (textures/packermod_icon_*.png を user textures dir に installed)
- spec/library_spec.lua (新規, 10 case)

**コミット**: 57192be

**次のTODO**: Phase 9 = Multiplayer サブタブ。`<pack_root>/servers.yaml` の編集 UI(モーダル or 詳細パネル内)+ `core.start` を address/port 付きで呼ぶ接続実装。アイコン PNG の視認性問題(白系 → ボタン背景に同化)も Phase 9 のついでに対応(stroke/fill 反転 or accent 色)。

## 2026-06-28 23:00 (main)

**変更概要**:
メインメニュー再設計 Phase 7。CurseForge / Modrinth 風の「Library + Pack 詳細」構造に向けたデータモデル基盤を追加。UI は現状維持(回帰なし)。
- ユーザ要望: タブが使いづらい、Pack 選択しても複数ワールド・マルチプレイが選べない、Import/Create/Settings がタブで枠を取りすぎ。プランファイル: `~/.claude/plans/pack-import-createto-effervescent-sun.md`
- 識別子設計: `world.mt` に `packermod_pack_id = <id>` を埋め込んで Pack ↔ World を識別。gameid(`<base_id>_<base_ver>`)は複数 Pack で衝突しうるため別フィールドが必要だった
- `world_builder.create_world` が任意 `opts.world_name` を受け取れるよう拡張(衝突時はエラー)。既存 autogen `<pack_id>__<ts>` は default のまま
- `pack_manager.list_worlds(pack_id)` を追加。`core.get_worlds()` を回して各 `world.mt` の `packermod_pack_id` で filter
- `mainmenu/server_list.lua` 新設。Pack ごとの `<pack_root>/servers.yaml` に load/save/add/remove/update。YAML は `{ servers: [...] }` 形式、後方互換で top-level array も受ける
- `pack_launcher` に `new_world` / `list_worlds` / `list_servers` を追加。既存 `launch(pack)` は `new_world(pack)` の alias として残置(`tab_packs.lua` は無改修で動く)
- 全 127 spec 緑(108 → 127, +19 件追加)。手動 UI 確認は Phase 8 で左右分割レイアウトに着手するときにまとめて行う

**主な変更ファイル**:
- mainmenu/world_builder.lua (opts.world_name 対応、packermod_pack_id 埋込)
- mainmenu/pack_manager.lua (list_worlds 追加)
- mainmenu/server_list.lua (新規)
- mainmenu/pack_launcher.lua (new_world / list_worlds / list_servers, launch は alias)
- mainmenu/init.lua (server_list の dofile と launcher への inject)
- spec/world_builder_spec.lua (4 case 追加)
- spec/pack_manager_spec.lua (新規, 4 case)
- spec/server_list_spec.lua (新規, 7 case)
- spec/pack_launcher_spec.lua (4 case 追加)

**コミット**: bca975f

**次のTODO**: Phase 8 = 左右分割レイアウト + Worlds サブタブ。`library.yml` / `library.lua` を新設し、tabview を撤去。実機の formspec 動作確認(`screenshot` script を library 画面に対応)はこのタイミングで。

## 2026-06-28 22:50 (main)

**変更概要**:
Phase 6 仕上げ。YAML を一次情報源に寄せる小改良。
- `ui_loader.handlers.page` が `body.size.{w,h}` を root VBox の w/h に伝播するように。これで YAML だけ見ればタブのキャンバスサイズが分かる。
- 4 つのタブ Lua から `w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H` を削除。layout.lua の compute は opts.w/h が無いとき root.w/h を尊重するので、サイズは YAML から流れる。
- 動作は変わらず (108 spec すべて緑、live-tabs 4 タブ overlap/OOB なし)

実機での目視確認は人手 (Xvfb での screenshot もユーザ側で実行可能): `make screenshot TAB=packs|import|create|settings` または `make screenshot-all`。テーマトークン (色・spacing) の微調整は `mainmenu/lib/theme.lua` の M.colors / M.spacing / M.button を直接いじれば即反映される。

**4 タブ YAML 化 + マイクラ風テーマ + Pixelarticons アイコン化** がこれで完成。

**主な変更ファイル**:
- mainmenu/lib/ui_loader.lua (page.size 反映)
- mainmenu/tabs/tab_packs.lua / tab_import.lua / tab_create.lua / tab_settings.lua (w/h 重複削除)
- spec/ui_loader_spec.lua (page.size の 1 case 追加)

**コミット**: 4e21f16

**次のTODO**: 実機で配色・サイズの微調整(必要であれば)。9-slice 石/木テクスチャに進化させる案は Phase 6 以降の課題として保留。

## 2026-06-28 22:30 (main)

**変更概要**:
Phase 5 Create タブを YAML 化。4 タブのうち最も複雑(7 field + 2 column + 検索 row + mod list + 6 button)を `mainmenu/ui/tab_create.yml` に置き換え、`tab_create.lua` は動的データの集約とハンドラだけに薄くした。これで 4 タブすべて YAML/DSL に移行済み。
- 構造: page > [card(Pack identity: 2 row × field), row(flex) > card(ContentDB search) + card(Current mods)]
- アイコン: Search=search, Add=plus (secondary), Remove=trash (danger), Export=save (primary)
- 横幅調整: 右カード actions の Remove/Export と左カード search row の Query/Release/Search/Add の w を縮めて、page の内側 14.7 unit に 2 card + spacing が収まるように
- バグ修正: `spec/layout_spec.lua` の `setup_mocks` で `PACKERMOD_TAB_H = 7.1` が残っていたのを `8.0` に更新(init.lua は前のセッションで 7.1→8.0 にしたが spec の mock 値が追従していなかった)。 これが Create タブで「label OOB」のエラーを引き起こしていた本当の原因
- 全 107 spec 緑、live-tabs 4 タブ overlap/OOB なし

**主な変更ファイル**:
- mainmenu/ui/tab_create.yml (新規, 約 130 行)
- mainmenu/tabs/tab_create.lua (簡素化, 177 → 145 行)
- spec/layout_spec.lua (setup_mocks の TAB_H 修正)

**コミット**: 8bfa9c5

**次のTODO**: Phase 6 仕上げ (実機目視確認、YAML 内の size 指定を ui_loader に取り込み)

## 2026-06-28 22:00 (main)

**変更概要**:
Phase 3 と Phase 4: Import タブと Settings タブを YAML 化。Packs と同じパターン (page > card > section > {label/field/list/actions}) を踏襲。タブ Lua は動的データを ctx に詰めて ui_loader を呼ぶだけになる。
- Import: Source field + Import (download アイコン, primary)。下に status と spacer(flex=1) を置いて status の伸びに依存しない高さ確保
- Settings: パス/バージョン情報を 3 行ラベル → spacer(flex=1) → 右下に Open Luanti settings (sliders アイコン → 内部で settings-2 に解決, secondary)。マイクラの options 画面っぽい配置
- 全 107 spec 緑、live-tabs 4 タブ全部 (packs/import/create/settings) overlap / OOB なし

**主な変更ファイル**:
- mainmenu/ui/tab_import.yml (新規)
- mainmenu/ui/tab_settings.yml (新規)
- mainmenu/tabs/tab_import.lua (簡素化, 45 → 41 行)
- mainmenu/tabs/tab_settings.lua (簡素化, 32 → 32 行)

**コミット**: 0447cdf

**次のTODO**: Phase 5 Create タブ YAML 化 (最も複雑)

## 2026-06-28 21:45 (main)

**変更概要**:
Phase 2 Packs タブを YAML 化。Lua 直書きの widget 木を `mainmenu/ui/tab_packs.yml` のセマンティック DSL に移行し、`tab_packs.lua` は動的データ収集 + ハンドラの薄い殻にした。新しい theme/icons 経由でアイコン付きカード UI になる。
- YAML: `page > card > section(Installed Packs) > list / status / actions(Refresh + Play)`。Play は `when: ${has_selection}` で空のとき隠れる。Refresh = reload アイコン (secondary), Play = play アイコン (primary)
- ui_loader に `M.tab_yaml_path(name)` を追加(`mainmenu/lib/ui_loader.lua` の相対位置から `../ui/tab_<name>.yml` を解決)
- `spec/layout_spec.lua` の `setup_mocks` に `packermod.theme/icons/ui_loader` を追加して live-tabs テストが YAML 経路を通せるように
- `parse_formspec` から `box[]` を除外。card 背景の box が「前景要素」扱いされて全てと overlap する誤検出を防ぐ
- 全 107 spec 緑、live-tabs (Packs) は overlap / OOB なし

**主な変更ファイル**:
- mainmenu/ui/tab_packs.yml (新規)
- mainmenu/tabs/tab_packs.lua (簡素化, 93 → 84 行)
- mainmenu/lib/ui_loader.lua (tab_yaml_path 追加)
- spec/layout_spec.lua (setup_mocks 拡張, parse_formspec 改修)

**コミット**: d853445

**次のTODO**: Phase 3 Import タブ YAML 化

## 2026-06-28 21:25 (main)

**変更概要**:
Phase 1 アイコンパイプライン。Pixelarticons (MIT, 24px ピクセルアート) のサブセット 12 個を vendor 取り込み、PNG 3 サイズ (24/48/72) にラスタライズして `textures/` に同梱。pixel art を formspec の `image[]` / `image_button[]` から名前で引けるように `mainmenu/lib/icons.lua` を追加。
- アイコン候補: `play / reload / download / search / plus / trash / save / settings-2 / folder / cloud / package / box` (sliders と cube は upstream に存在せず、icons.lua のエイリアスで `sliders→settings-2`, `cube→box` にマップ)
- `scripts/vendor_pixelarticons.sh` でサブセットを sparse-checkout (`--no-cone` でファイル単位指定) → `vendor/pixelarticons/svg/` + LICENSE
- `scripts/build_icons.sh` で `rsvg-convert --stylesheet path{fill:#FFFFFF}` を当てて白塗り PNG をラスタライズ。3 サイズ × 12 = 36 ファイル
- `lib/icons.lua`: `icons.path(name, size="md")` → `packermod_icon_<resolved>_<size>.png`。alias テーブルで人間に優しい命名を許す
- `Makefile` に `vendor-icons` / `icons` / `screenshot-all` ターゲット
- end-user は rsvg-convert を要求されない (PNG を repo にコミット)
- spec 5 追加、全 107 緑

**主な変更ファイル**:
- mainmenu/lib/icons.lua (新規)
- mainmenu/init.lua (icons 配線)
- scripts/vendor_pixelarticons.sh (新規)
- scripts/build_icons.sh (新規)
- vendor/pixelarticons/svg/*.svg (12 ファイル, MIT)
- vendor/pixelarticons/LICENSE
- textures/packermod_icon_*.png (36 ファイル)
- Makefile (ターゲット追加)
- spec/icons_spec.lua (新規, 5 case)

**コミット**: (push 後に追記)

**次のTODO**: Phase 2 Packs タブ YAML 化

## 2026-06-28 21:00 (main)

**変更概要**:
MainMenu UI モダン化 (マイクラ風 + YAML DSL) の Phase 0 基盤。UI 出力は変えず、後段フェーズで使う 3 つのライブラリと既存 PMLayout の後方互換拡張だけを入れる。
- `mainmenu/lib/theme.lua` (新規): 色・spacing・アイコンサイズ・ボタン variant のトークンと style[] 出力 API
- `mainmenu/lib/ui_loader.lua` (新規): YAML/テーブルのセマンティック DSL (page/card/section/actions/row/col/label/text/status/field/button/icon-button/icon/list/spacer) を PMLayout ツリーに展開、`${var}` と `${list | fmt}` バインディング、`when:` 条件で child skip
- `mainmenu/lib/layout.lua` 拡張: widget に `style="primary"` を受ける、`build_formspec(opts.theme=...)` で theme prelude (bgcolor[]/style_type[]) を挿入、VBox/HBox/Stack の `bgcolor` で box[] 背景塗り、新 widget Icon / IconButton。**theme 未指定時の出力は現行とバイト一致** (既存テスト維持)
- `mainmenu/init.lua` で `packermod.theme` / `packermod.ui_loader` を公開

再現テスト先行で書き、全 102 spec 緑。Phase 1 以降のアイコンパイプラインとタブ YAML 化はこの上に積む。

**主な変更ファイル**:
- mainmenu/lib/theme.lua (新規)
- mainmenu/lib/ui_loader.lua (新規)
- mainmenu/lib/layout.lua (style/theme/bgcolor/Icon/IconButton 対応)
- mainmenu/init.lua (theme + ui_loader 配線)
- spec/theme_spec.lua (新規、11 case)
- spec/ui_loader_spec.lua (新規、15 case)
- spec/layout_spec.lua (theme/Icon 系 8 case 追加)

**コミット**: c193d41

**次のTODO**: Phase 1 アイコンパイプライン (Pixelarticons MIT サブセット → PNG ラスタライズ → `lib/icons.lua` 配線)

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
