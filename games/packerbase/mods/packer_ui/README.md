# PackerMOD Baseのゲーム内UI

インベントリの「クラフト」で本のボタンを押すと、左にレシピブックが開く。
右のクラフト欄と持ち物は開いたまま使える。検索・作り方・使い道は上流の
`mtg_craftguide` が管理し、表示はPMUIが担当する。
`packer_java_inventory = false` のワールドでは従来のクラフトとレシピタブを使う。

「設定」の配色はプレイヤーごとに保存する。自動回収や移動の数値はホスト
設定を表示する。映像・音・キー操作はLuantiの標準ポーズメニューで設定する。

このゲーム向けMODからPMUIを使うときは、`mod.conf` に
`depends = packer_ui` を追加し、`local pmui = packer_ui.pmui` で
ライブラリを参照する。`pmui.new():render` にプレイヤーのウィンドウ
情報とLuaツリーまたはHTMLを渡せる。アイテムボタンを置く場合は
`pmui.el("item-button", {name = "recipe_result", item = "default:torch 4"})`
に幅と高さをCSSで指定する。

PMUIの編集元はリポジトリの `mainmenu/lib/pmui/modern`。編集後に
`python3 scripts/sync_packer_ui.py` を実行してLuaとゲーム用画像を同期し、
`python3 scripts/sync_packer_ui.py --check` で同期を確認する。
ゲーム配布物には同期済みのランタイムを含む。
