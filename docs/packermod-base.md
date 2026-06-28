# PackerMOD-Base

PackerMOD の Pack manifest が指す既定のベース Game。Pack 作者は
`base_game.id = packerbase` を指定して特定バージョンの Base に依存する。

## リポジトリ

別管理: https://github.com/GeekSpaceLuanti/PackerMOD-Base

本リポジトリ(`PackerMOD`)は mainmenu / Pack 管理のみを扱い、ゲーム
コンテンツは PackerMOD-Base 側で完結させる。複数バージョンの併存と
release pin を可能にするため、Game ID にバージョンを含める。

## Game ID 命名規約

```
packerbase_<major>_<minor>
```

例:
- `packerbase_0_91` ← VoxeLibre 0.91 から fork した世代
- `packerbase_0_92` ← VoxeLibre 0.92 取り込み

Pack manifest 側の表現は `base_game.id = packerbase` + `base_game.version = "0.91"`
で、`world_builder.gameid_for` がドット → アンダーバー変換で `packerbase_0_91`
に解決する(`mainmenu/world_builder.lua:gameid_for`)。

## 起源と上流追従

- 初期コンテンツ: [VoxeLibre](https://content.luanti.org/packages/Wuzzy/mineclone5/) の特定 release から fork
- 上流追従: 手動マージ(自動同期はしない)。VoxeLibre の新リリースが出たら、
  新しい `packerbase_<X>_<Y>` を増やす方針

## ライセンス

VoxeLibre は GPL v3 → PackerMOD-Base も GPL v3 を継承する。

PackerMOD 本体(mainmenu Lua)は Luanti 本体 builtin と合わせて LGPL 系
の可能性があるが、Base game の取り込み境界はランタイム動的ロードであり、
別ライセンスでの配布も許される(Luanti の Game/Mod 配布慣行に従う)。

## インストール

エンドユーザー向けには PackerMOD-Base のリリース zip を:

```
<luanti-user-data>/games/packerbase_<X>_<Y>/
```

に展開する。`install/install.sh` には Base のセットアップは含まれない
(本リポは menu と Pack 管理のみ)。

## 開発手順(fork メンテナ向け)

1. `git clone https://github.com/GeekSpaceLuanti/PackerMOD-Base`
2. VoxeLibre の release archive を取得し、`games/packerbase_<X>_<Y>/` 配下に展開
3. `game.conf` の `name` / `title` を PackerMOD 流に書き換え
4. 動作確認: `~/.minetest/games/` に symlink → Luanti で world 作成 → 起動
5. リリース zip を作って GitHub Releases に置く
