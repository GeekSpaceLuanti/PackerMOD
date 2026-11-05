# ライセンス確認記録

確認日: 2026-11-05。対象はこのチェックアウトと、下記の公式一次資料。

## 採用する扱い

| 対象 | ライセンス・根拠 | 配布で保持するもの |
|---|---|---|
| PackerMOD独自コード・スクリプト・文書 | LGPL-2.1-or-later。今回 `LICENSE.txt` で明示 | `LICENSE.txt`, `COPYING.LESSER`, `COPYING` と著作権表示 |
| 独自生成の背景・サムネイル・PMUI素材 | 生成元と同じLGPL-2.1-or-later | 生成スクリプト、元定義、ライセンス本文 |
| Pixelarticons SVGとそのPNG変換 | MIT。`vendor/pixelarticons/LICENSE` | Gerrit Halfmannの著作権表示とMIT全文。`THIRD_PARTY_NOTICES.md`にも収録 |
| Minetest Game由来ゲームコード | 原則LGPL-2.1-or-later。個別ファイルの条件を優先 | ゲーム全体・各MOD内の既存通知と変更記録 |
| Minetest Gameの画像・モデル・音声 | 主にCC BY-SA 3.0。CC BY/CC0等も混在 | 各MODの作者・素材別出所・適用条件をそのまま保持 |
| Luanti本体 | コードLGPL-2.1-or-later。素材・ライブラリには別条件 | バイナリ同梱時はその版の通知と対応ソース・ビルド手順 |

独自コードへのライセンス明示は、第三者コードの権利を上書きするものではない。
既存の著作権者は各ファイル・Git履歴で保持し、推測した個人名や権利譲渡は記載しない。

## 今回確認した範囲

- 変更前のREADMEは本体ライセンスが「未定」、ルートの本文ファイルは未配置だった。
- `vendor/` に同梱された第三者ライセンスはPixelarticons MIT。
- `textures/packermod_icon_*.png` は `scripts/build_icons.sh` によりSVGから生成。
- その他の背景・サムネイル・PMUI素材には、リポジトリ内の生成スクリプトと元定義がある。
- `mainmenu/init.lua` はインストール済みLuantiのbuiltinを実行時に読み込む。
- 旧 `docs/packermod-base.md` はVoxeLibre案だった。調査時点でVoxeLibre本体の
  ゲームディレクトリはこのリポジトリに存在せず、コード取り込みは確認されなかった。
  モック画面のサンプル名はゲームコード取り込みの証拠ではない。
- 新しいゲームの上流コミット・個別MOD通知は `games/packerbase` 内の記録を正とする。

これは全Git履歴に含まれる全ファイルの権利処理を証明するものではない。
将来追加する素材・MODは追加時に出所、版、作者、ライセンスを記録する。

## リリース時の確認

- [ ] 配布版に対応するソースのコミットを固定し、同じ版のソースアーカイブを提供する。
- [ ] LGPLの対象を利用者が改変・差し替えできる配布構成にする。
- [ ] 改変した上流ファイルに変更内容・日付を記録する。
- [ ] 各MODの素材別通知を含め、ライセンスファイルを配布物から除外しない。
- [ ] エンジン同梱版では、そのバイナリの全依存ライブラリと素材も確認する。
- [ ] 自作でない素材・MODの許諾を、ルートLICENSEだけで済ませない。

## 一次資料

- [Luanti LICENSE.txt](https://github.com/luanti-org/luanti/blob/master/LICENSE.txt)
- [Luanti LGPL本文](https://github.com/luanti-org/luanti/blob/master/COPYING.LESSER)
- [Minetest Game LICENSE.txt](https://github.com/luanti-org/minetest_game/blob/master/LICENSE.txt)
- [default MODのコード・素材別条件](https://github.com/luanti-org/minetest_game/blob/master/mods/default/license.txt)
- [Pixelarticons MIT](https://github.com/halfmage/pixelarticons/blob/master/LICENSE)
- [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)
- [GPL v2本文](https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt)
