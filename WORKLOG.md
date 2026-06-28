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
