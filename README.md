# PackerMOD

Luanti(旧 Minetest)のメインメニューを置き換える Modpack 管理ツール。CurseForge / Modrinth / Minecraft 公式ランチャー風の UI で、Pack(= Mod とサーバー設定をまとめた単位)を切り替えながら遊ぶ運用を想定している。

> **注意**: PackerMOD は通常の MOD(world で読み込まれるアドオン)ではなく、**Luanti のメインメニュー UI そのものを差し替える**スクリプト。`minetest.conf` の `main_menu_script` を書き換えてインストールし、組み込みの「Singleplayer / Join Game / Settings」タブの代わりに Pack グリッド画面を出す。

## できること

- 画面1: Pack を 3 列グリッドで一覧(サムネイル + 名前 + base game version)
- 画面2: Pack を選ぶとドリルダウンで詳細(Worlds / Multiplayer / Mods / Info の subtab)
- 1 つの Pack に複数 World を作って自由な名前で管理 (同 Pack 内で重複 NG、Pack 間で同名 OK)
- World の Delete UI(旧 flat 構造の legacy world も削除可)
- Pack ごとのお気に入りサーバー一覧 (マイクラ式: サーバー側 Mod 要件への適合は Luanti のハンドシェイクが処理)
- ContentDB から Mod を検索して Pack に追加・削除(既存 Pack の編集も新規作成も可)
- Pack の Import(URL / ローカル zip)
- Pack の新規 Create
- Pack ごとのサムネ画像(`thumbnail.png` を Pack ディレクトリに置く、無ければデフォルト画像)

## 必要要件

- Luanti 5.16 以降(formspec v6 と `main_menu_script` を使うため)
- 動作確認は Linux + Luanti 5.16.1。Windows は `install/install.ps1` あり、Junction 経由の World 起動は未検証(#23)

## インストール(メインメニューの置き換え)

### Linux / macOS

```sh
./install/install.sh symlink   # 推奨: repo の mainmenu/ と textures/ を ~/.minetest 下に symlink
./install/install.sh copy      # symlink でなく実体コピー(repo を消しても動かしたい場合)
```

### Windows

```powershell
.\install\install.ps1 -Mode copy
# または Developer Mode / 管理者で
.\install\install.ps1 -Mode symlink
```

### 何が起きるか

| 配置先 | 内容 |
|---|---|
| `<user>/PackerMOD/mainmenu/` | repo の `mainmenu/` への symlink (or コピー) |
| `<user>/PackerMOD/textures/` | repo の `textures/` への symlink (or コピー)。Luanti mainmenu のテクスチャ解決制限を回避するため絶対パスで参照される |
| `<user>/PackerMOD/packs/` | 空ディレクトリ。Pack をここに置く |
| `<user>/PackerMOD/cache/` | 空ディレクトリ。ContentDB のダウンロードキャッシュ |
| `<user>/minetest.conf` | `main_menu_script = .../PackerMOD/mainmenu/init.lua` を追記。既存の `main_menu_script` 行があれば `# packermod-backup main_menu_script` にコメント化して保存 |

`<user>` は OS によって違う:
- Linux: `~/.minetest`
- macOS: `~/Library/Application Support/luanti`
- Windows: `%APPDATA%\Luanti`

インストール後に Luanti を起動すると、通常の組み込みメインメニューの代わりに PackerMOD の Pack グリッド画面が出る。

## 使い方

### 初回起動

1. Luanti を起動 → Pack グリッド画面が出る(初回はカードが 0 個)
2. 右下の `[+ Create]` で新規 Pack を作るか、`[+ Import]` で既存 Pack を取り込む
3. テスト用に `test_fixtures/sample_pack.yaml` を `<user>/PackerMOD/packs/sample_pack/manifest.yaml` にコピーすれば最小構成が確認できる

### Pack で遊ぶ

1. グリッドから Pack カードをクリック → Pack 詳細画面に遷移
2. **Worlds** タブで `[+ New World]` → World 名を入力 → `Create & Play`
   - World は `<user>/PackerMOD/packs/<pack_id>/worlds/<sanitized_name>/` に作られる
   - 同 Pack 内で同名は弾かれる、別 Pack なら同じ名前で OK
3. 既存 World を選択して `[Play]` でゲーム起動
4. `[Delete]` で確認 modal 経由で World を削除
5. 画面上部の `[Back]` で Pack グリッドに戻る

### Pack の追加(Import / Create)

- **Import**: 画面1 の `[+ Import]` → URL か zip / `manifest.yaml` のパスを入力
- **Create**: 画面1 の `[+ Create]` → 新規 Pack のメタ情報を入力 + 同 modal で ContentDB から Mod を検索して組み込む

### サムネ画像

Pack ディレクトリの直下に `thumbnail.png` を置くと画面1 グリッドのカードに表示される。`manifest.yaml` に `thumbnail: <相対パス>` を書けば別ファイル名でも可。未設定なら共通のデフォルト画像が表示される。

## アンインストール(元に戻す)

```sh
# Linux / macOS
./install/uninstall.sh
```

```powershell
# Windows
.\install\uninstall.ps1
```

### 何が消えるか / 何が残るか

| 対象 | uninstall の動作 |
|---|---|
| `<user>/PackerMOD/mainmenu/` | 削除 |
| `<user>/PackerMOD/textures/` | 削除 |
| `<user>/textures/packermod_*.png`(過去 install 由来) | 削除(掃除) |
| `<user>/minetest.conf` の `main_menu_script` | PackerMOD が書いた行を削除し、backup コメントを元に戻す |
| `<user>/PackerMOD/packs/` | **残す**(あなたの Pack データ) |
| `<user>/PackerMOD/cache/` | **残す**(ContentDB ダウンロードキャッシュ) |
| `<user>/PackerMOD/packs/<pack_id>/worlds/` | **残す**(あなたの World データ) |

「Pack も World も全部完全に消したい」場合は uninstall 後に `<user>/PackerMOD/` ディレクトリ自体を手動で削除する。

uninstall 後に Luanti を起動すると Luanti 組み込みの通常メインメニューに戻る。

## Pack の作り方

Pack は 1 ディレクトリ = 1 Pack。最小構成:

```
<user>/PackerMOD/packs/<pack_id>/
  manifest.yaml          # 必須
  thumbnail.png          # 任意。画面1 のサムネ
  bundled_mods/          # source: bundle 用(任意)
  servers.yaml           # マルチプレイ用(任意。UI が自動で書く)
  worlds/                # World 一覧(UI が自動で作る)
    <world_name>/
      world.mt
      worldmods/<mod>/
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
thumbnail: thumbnail.png    # 任意

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

`mods[].source` は `contentdb` / `bundle` / `url` の 3 種。`base_game` は対応する Game(`<user>/games/<base_id>_<base_version>/`)が必要。

## 画面の概要

```
[画面1: Pack Library グリッド]
┌──────────────────────────────────────┐
│ PackerMOD — Pack Library             │
│ ┌──────┐ ┌──────┐ ┌──────┐           │
│ │サムネ │ │サムネ │ │サムネ │           │
│ │      │ │      │ │      │           │
│ └──────┘ └──────┘ └──────┘           │
│  Pack A   Pack B   Pack C            │
│  base/0.91 base/0.91 base/0.91       │
│                                       │
│           [Import][Create][Settings] │
└──────────────────────────────────────┘
                ↓ Pack をクリック
[画面2: Pack Detail]
┌──────────────────────────────────────┐
│ [↩ Back]  Pack A   v1.0  base=… mods=3│
│ [Worlds][Multiplayer][Mods][Info]    │
│ ──────────────────────────────────── │
│ < 選択中サブタブの中身 >             │
└──────────────────────────────────────┘
```

| サブタブ | 内容 |
|---|---|
| Worlds | この Pack の World 一覧 / New World / Delete / Play (legacy flat world も `[legacy]` 表示で削除可) |
| Multiplayer | `<pack>/servers.yaml` のサーバー一覧 / Add / Remove / Connect |
| Mods | manifest.mods の表示 + ContentDB 検索→追加・削除 |
| Info | name / version / description の編集 → manifest.yaml 保存 |

## World の物理配置と起動の仕組み

World は次のディレクトリに作られる:

```
<user>/PackerMOD/packs/<pack_id>/worlds/<sanitized_world_name>/
```

Luanti 本体は `<user>/worlds/` のフラット構造しか認識しないため、起動時のみ `<user>/worlds/_pm_<random>` に symlink(Windows は Junction)を作って Luanti に世界を見せる。次回起動時に `cleanup_symlinks` が `_pm_*` を全部掃除する(symlink/Junction なのでリンク先の本物 World は無事)。

これにより:
- 同 Pack 内で同名 World は弾かれる(ディレクトリ衝突)
- Pack 間では同名 OK(別 Pack の別ディレクトリ)
- ユーザーが入れた表示名は `world.mt` の `world_name` に保存され、ディレクトリ名は安全な文字に sanitize される

## ディレクトリ構成

```
mainmenu/
  init.lua                  # Luanti が main_menu_script として読み込むエントリ
  library.lua               # 画面1 (grid) + 画面2 (detail) の state machine + handler
  pack_manager.lua          # Pack 列挙 / Pack ↔ World 紐付け / サムネ解決
  pack_launcher.lua         # symlink trick による World 起動 + cleanup
  pack_editor.lua           # 既存 Pack の Mod 追加・削除・メタ編集
  pack_builder.lua          # 新規 Pack の manifest 構築(Create modal が使用)
  pack_importer.lua         # URL / zip / manifest.yaml からの Pack 取込
  mod_installer.lua         # ContentDB / bundle / url から Mod を world に配置
  world_builder.lua         # subdir 構造の create_world / delete_world / sanitize
  server_list.lua           # <pack>/servers.yaml の CRUD
  contentdb.lua             # ContentDB HTTP API クライアント
  manifest.lua / yaml.lua   # manifest 検証 / 軽量 YAML パーサ
  dialogs/
    dlg_import.lua          # Import modal
    dlg_create.lua          # Create modal(新規 Pack の組立)
    dlg_settings.lua        # Settings modal
    dlg_world_create.lua    # New World 名前入力 modal
    dlg_world_delete.lua    # World 削除確認 modal
  ui/
    library.yml             # 画面2 (Pack 詳細) の DSL
    modal_*.yml             # 各 modal の DSL
  lib/
    layout.lua              # PMLayout: VBox/HBox flex/align/padding + LabeledIconButton
    ui_loader.lua           # YAML/DSL → PMLayout tree
    theme.lua               # 配色・spacing・font_size style_type 統合
    icons.lua               # アイコン名 → 絶対 texture path
textures/
  packermod_icon_*.png      # vendor/pixelarticons から生成したアイコン
  packermod_default_pack_thumbnail.png  # サムネ未設定 Pack 用デフォルト画像
install/
  install.sh / install.ps1
  uninstall.sh / uninstall.ps1
```

## 開発

```sh
make test           # busted spec/ (Lua 単体テスト)
make e2e            # Xvfb 上で Luanti を 4 秒起動、ERROR/Mod security を grep
make screenshot SUBTAB=library          # 画面1 (Pack グリッド) の screenshot
make screenshot SUBTAB=worlds|multi|mods|info   # 画面2 の各 subtab
make screenshot SUBTAB=modal_import|modal_create|modal_settings
make screenshot-all                     # 全ページ取得
make icons          # vendor/pixelarticons の SVG → textures/*.png 再生成
make vendor-icons   # vendor/pixelarticons の SVG を vendoring
```

spec は 190 件(+1 pending = #15)、回帰検出に `spec/library_spec.lua` の overlap+OOB 検査も使う。

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
- #22 実機で New World → Play の通し検証
- #23 Windows Junction の動作確認

進捗は `WORKLOG.md`(逆時系列)に push ごとに 1 セクション追記される。
