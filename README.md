# PackerMOD

Luanti(旧 Minetest)のメインメニューを置き換える Modpack 管理ツール。CurseForge / Modrinth 風の UI で、Pack(= Mod とサーバー設定をまとめた単位)を切り替えながら遊ぶ運用を想定している。

## できること

- Pack 一覧から選択 → 同画面で詳細(Worlds / Multiplayer / Mods / Info)を確認
- 1 つの Pack に複数 World を作成して使い分け
- Pack ごとのお気に入りサーバー一覧(マイクラ式: サーバー側 Mod 要件への適合は Luanti のハンドシェイクが処理)
- ContentDB から Mod を検索して Pack に追加・削除(既存 Pack の編集も新規作成も可)
- Pack の Import(URL / ローカル zip)
- Pack の新規 Create

タブはなく Library 1 画面に集約、Import / Create / Settings は modal で開く。

## 必要要件

- Luanti 5.16 以降(formspec v6 と `main_menu_script` を使うため)
- 動作確認は Linux + Luanti 5.16.1。Windows は `install/install.ps1` あり、未テスト

## インストール

```sh
./install/install.sh symlink   # 推奨: リポジトリの mainmenu/ を ~/.minetest 下に symlink
./install/install.sh copy      # symlink でなく実体コピーする場合
```

以下を `~/.minetest`(Linux)に配置・上書きする:

- `~/.minetest/PackerMOD/mainmenu` → repo の `mainmenu/` への symlink(or コピー)
- `~/.minetest/PackerMOD/packs` / `cache` 空ディレクトリ
- `~/.minetest/textures/packermod_icon_*.png` → repo の `textures/` 配下の symlink(or コピー)
- `~/.minetest/minetest.conf` に `main_menu_script = .../PackerMOD/mainmenu/init.lua` を追記(既存があれば backup コメント化)

アンインストール: `./install/uninstall.sh`

## Pack の作り方

Pack は 1 ディレクトリ = 1 Pack。最小構成:

```
<pack_id>/
  manifest.yaml   # 必須
  bundled_mods/   # source: bundle 用(任意)
  servers.yaml    # マルチプレイ用(任意、Library 上で編集される)
```

`manifest.yaml` のサンプル(`test_fixtures/sample_pack.yaml`):

```yaml
schema_version: 1
id: sample_pack
name: Sample Pack
version: "1.0.0"
description: |
  Sample pack used as a test fixture.
author: bacon

base_game:
  id: packerbase
  version: "0.91"

mods:
  - name: mesecons
    source: contentdb
    package: Jeija/mesecons
    release: 12345
  - name: my_custom_mod
    source: bundle
    path: bundled_mods/my_custom_mod
  - name: external_mod
    source: url
    url: https://example.com/mod.zip
    sha256: abc123def

settings:
  enable_damage: true
  creative_mode: false
  mg_name: v7
```

`mods[].source` は `contentdb` / `bundle` / `url` の 3 種。`base_game` は対応する Game(`~/.minetest/games/<base_id>_<base_version>/`)が必要。

## 画面の概要

```
┌─ Pack Library (左) ─────┬─ Pack Detail (右) ────────────────┐
│ ・MyPack                 │ MyPack v1.2 / base: packerbase/0.91│
│ ・Adventure  ◀ 選択中    │ [Worlds][Multiplayer][Mods][Info]  │
│ ・Tech                   │ ──────────────────────────────     │
│                          │ < 選択中サブタブの中身 >           │
│ [Import][Create][⚙]      │                                    │
└──────────────────────────┴────────────────────────────────────┘
```

| サブタブ | 内容 |
|---|---|
| Worlds | この Pack の World 一覧 / New World / Play |
| Multiplayer | `<pack>/servers.yaml` のサーバー一覧 / Add / Remove / Connect |
| Mods | manifest.mods の表示 + ContentDB 検索→追加・削除 |
| Info | name / version / description の編集 → manifest.yaml 保存 |

## ディレクトリ構成

```
mainmenu/
  init.lua                  # Luanti が main_menu_script として読み込むエントリ
  library.lua               # Library 画面の formspec 構築・イベント処理
  pack_manager.lua          # <user>/PackerMOD/packs/ の列挙 / Pack ↔ World 紐付け
  pack_launcher.lua         # 新規 World 起動 / 既存 World 起動 / サーバー接続
  pack_editor.lua           # 既存 Pack の Mod 追加・削除・メタ編集
  pack_builder.lua          # 新規 Pack の manifest 構築(Create modal が使用)
  pack_importer.lua         # URL / zip / manifest.yaml からの Pack 取込
  mod_installer.lua         # ContentDB / bundle / url から Mod を world に配置
  world_builder.lua         # world.mt 生成(packermod_pack_id を埋込)
  server_list.lua           # <pack>/servers.yaml の CRUD
  contentdb.lua             # ContentDB HTTP API クライアント
  manifest.lua / yaml.lua   # manifest 検証 / 軽量 YAML パーサ
  dialogs/
    dlg_import.lua          # Import modal
    dlg_create.lua          # Create modal(新規 Pack の組立)
    dlg_settings.lua        # Settings modal
  ui/
    library.yml             # Library 画面の DSL
    detail_*.yml(なし)     # Worlds/Multi/Mods/Info は library.yml に inline
    modal_*.yml             # 3 modal 用 DSL
  lib/
    layout.lua              # PMLayout: 軽量 VBox/HBox flex/align/padding
    ui_loader.lua           # YAML/DSL → PMLayout tree
    theme.lua               # 配色・spacing・style_type 統合
    icons.lua               # アイコン名 → texture path
```

## 開発

```sh
make test           # busted spec/ (Lua 単体テスト)
make e2e            # Xvfb 上で Luanti を 4 秒起動、ERROR/Mod security を grep
make screenshot SUBTAB=library          # Library 画面の screenshot
make screenshot SUBTAB=worlds|multi|mods|info
make screenshot SUBTAB=modal_import|modal_create|modal_settings
make screenshot-all                     # 全ページ取得
make icons          # vendor/pixelarticons の SVG → textures/*.png 再生成
make vendor-icons   # vendor/pixelarticons の SVG を vendoring
```

spec は 163 件(+1 pending = #15)、回帰検出に `spec/library_spec.lua` の overlap+OOB 検査も使う。

## ライセンス / クレジット

- 本体: 未定(検討中)
- アイコン: [Pixelarticons](https://github.com/halfmage/pixelarticons) MIT License(Copyright Gerrit Halfmann)
- Luanti / Minetest: LGPL-2.1+(本ツールが拡張する対象)

## ロードマップ

進行中・未着手は GitHub Issue で管理:

- #8 Fork VoxeLibre 0.91 content into PackerMOD-Base
- #15 layout: 子の natural h が parent inner h を超えると OOB(shrink-to-fit 無し)
- #16 アイコン PNG を accent 色で再生成(#10 のフォロー)
- #17 Settings dialog の Luanti core 設定を実装
- #18 Library に Pack の Delete UI
- #19 Worlds サブタブに Configure ボタン
- #20 e2e/run.sh を Library 構造に追従

進捗は `WORKLOG.md`(逆時系列)に push ごとに 1 セクション追記される。
