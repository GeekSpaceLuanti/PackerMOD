# PMUI 2

HTML風マークアップまたはLuaツリーと、CSSの小さなサブセットからLuanti formspecを作る独立ライブラリです。
PackerMODのグローバル、設定、フォルダー配置、YAMLパーサーには依存しません。描画だけを担当し、ゲームデータの保存や起動は呼び出し側が担当します。

## 他のMODで使う

この`modern`フォルダー全体を`mods/pmui`として配置し、利用するMODの`mod.conf`に`depends = pmui`を記載します。
`textures`も必要です。`init.lua`が公開する`pmui`から以下のように呼び出せます。
通常MODにせず、自分のMODへ同梱して`local ui = dofile(modpath .. "/lib/pmui/init.lua")`と読み込むこともできます。

```lua
local window = core.get_player_window_information(player_name)
if not window then return end -- クライアント情報の到着後に再試行
local formspec, result = pmui.new():render {
    window = window,
    html = [[
      <section class="panel">
        <h2>${title}</h2>
        <field name="nickname" label="名前" value="${nickname}"/>
        <button name="save" icon="save">保存</button>
      </section>
    ]],
    context = { title = "設定", nickname = "Player" },
    css = [[
      .panel { padding: 24px; gap: 16px; background: #1D2429;
               border-radius: 16px; color: #EDF4F0; }
      h2 { font-size: 24px; font-weight: bold; }
      button { padding: 10px 16px; min-height: 44px;
               border-radius: 8px; background: #A0DFBB; color: #102A1D; }
    ]],
    max_width = 800,
    scroll = 0,
}
core.show_formspec(player_name, "my_mod:settings", formspec)
```

操作は通常の`core.register_on_player_receive_fields`で受け取ります。`fields.save`で保存を処理してください。
`pm_flow_scroll`の`CHG:N`を数値として保持し、次回の`scroll`に渡すと位置が維持されます。ドラッグ中はformspecを再送しません。
フィールド値も呼び出し側の状態へ保持し、再描画時の`context`に戻します。

実行できるサンプルMODはリポジトリの`examples/pmui_demo`です。両方を有効にして`/pmui_demo`を実行します。
`scripts/test_modern_gui.sh`は実際に両MODを使い捨てゲームへ配置し、PackerMODなしでゲーム内表示を検証します。

## API

- `ui.el(tag, attributes, children)`：Luaツリーを作成。`text`, `name`, `icon`, `class`, `id`, `inline`等を指定できます。
- `ui.components.text/button/panel/row/tabs/empty`：標準コンポーネント。PackerMODのパック詳細も同じ部品を使用します。
- `ui.components.field/dropdown/slider/key_button/toggle`：種類だけで標準の寸法・描画が適用される入力部品。
- `ui.el("item-button", {name = "recipe_result", item = "default:torch 4", tooltip = "Torch"})`：ゲーム内のアイテムボタン。Luaツリーで指定し、CSSで幅と高さを設定します。
- `ui.default_css`：同梱テーマ。描画時に自動適用し、利用側CSSで上書きできます。完全に置き換えるときは`theme = false`。
- `ui.parse_html(source, context)`：静的マークアップをツリーへ変換。`${key}`は解析後に文字列として埋め込みます。
- `ui.new(host):render(options)`：`formspec, result`を返します。入力ツリーを書き換えないため、再描画・リサイズで再利用できます。
- `result.tree`：CSS計算後のツリーとCSS px単位の`box = {x,y,w,h}`。
- `result.width`, `height`, `content_height`, `scroll`, `unit_per_px`：レイアウト検証用の情報。
- `ui.layout.validate(result.tree)`：親領域からのはみ出し、兄弟要素間の重なりを配列で返します。

`host`は任意の依存注入です。

- `get_window_info()`：`size`, `max_formspec_size`, `real_gui_scaling`を返す。`options.window`を優先。
- `texture(name, color)`：画像参照を返す。ゲーム内の既定値は`pmui_<name>.png^[multiply:<color>`。
- `measure_text(text, font_size)`：任意の文字幅測定。未指定時は日本語等を全角、ASCIIを比例近似した計測を使います。
- `defaults`：部品の種類をキーとする共通設定。画面ごとのCSSとは別に一括適用できます。

```lua
local renderer = pmui.new():configure("button", {
    ["font-size"] = 16, ["min-height"] = 44, ["border-radius"] = 12,
})
local button = pmui.el("button", { name = "save", text = "保存", variant = "primary" })
local dropdown = pmui.components.dropdown("mode", { "Survival", "Creative" }, 1)
local slider = pmui.components.slider("volume", 700) -- 0..1000
```

ボタンにはCSSクラスを指定しなくても標準スタイルが付きます。種類別の共通設定は全画面へ適用され、キー入力・切替ボタンも通常ボタンの設定を継承します。
`variant`を指定したボタンは、共通の文字・寸法設定を使いながら、主要操作・削除などの色を保持します。
選択欄とスライダーはエンジンのネイティブ部品を使うため、ポップアップやつまみ等の外観はエンジンの対応範囲に従います。

描画単位はCSS px相当です。寸法とフォントを同じDPI・GUI倍率で変換し、画面の最大formspecサイズを超えないようにします。
行は内容幅で配置し、入りきらなければ折り返します。`flex-grow`の要素には残り幅を配分します。
縦方向に足りなければルートをスクロール化します。画面情報が変わった場合は最新情報で再描画してください。
メインメニューでは`WindowInfoChange`、ゲーム内ではプレイヤーの最新ウィンドウ情報を使用します。

## 対応範囲

マークアップは`div/main/header/footer/nav/section/p/h1/h2/h3/button/icon/field/textarea/list/dropdown/slider/key-button/toggle/scroll/image/status`。
属性はダブルクォートで囲む`id/class/name/icon/label/value/variant/src`。`list`や`dropdown`の配列等はLuaツリーから渡します。
スクリプト、DOMイベント、外部リソースの取得は実装していません。未知のタグ・属性はエラーです。

CSSはタグ・クラス・ID・子孫セレクター、`:root`、変数`var(--name)`、`@media (max-width: Npx)`に対応します。
詳細度と記述順で適用し、文字色・フォントサイズ・行高を継承します。寸法は数値または`px`、`em`、`%`を使用できます。

主なプロパティ：

- 配置：`display`、`flex-direction`、`flex-wrap`、`flex-grow`、`gap`、`row-gap`、`align-items`、`justify-content`
- 寸法：`width`、`height`、`min-width`、`max-width`、`min-height`、`padding`と各辺指定
- 描画：`background`、`color`、`border-width/color/radius`、`border-bottom-width/color`、`icon-size`
- 文字：`font-size`、`font-weight`、`line-height`（倍率）、`text-align`

角丸は8/12/16/24pxの同梱9スライス画像を使用します。任意の半径は次の対応値へ丸めます。
完全なブラウザのCSSエンジンではなく、Grid、絶対配置、影、アニメーション、Webフォント等は未対応です。未対応の宣言は黙って無視せずエラーにします。
文字幅はホストからの測定関数がない場合に近似になるため、フォントによる数pxの差は残ります。
Luanti 5.16.1のメインメニューとゲーム内で確認しています。formspec version 6対応クライアントが必要です。

## メインメニューで使う

メインメニューの画像参照はゲーム内と異なり、テクスチャ修飾子を解釈しません。
`texture(name,color)`で色付きPNGの絶対パスを返してください。PackerMODのアダプターは`library.lua`にあります。
色付き画像と線画アイコンは`python scripts/build_modern_gui.py`で再生成できます。
PackerMODの配色は`mainmenu/ui/pack_detail.css`、ライブラリの既定配色は`modern/init.lua`と`modern/theme.lua`から収集します。
新しい配色を追加したら再生成してください。生成物は同梱するため、利用側にPythonは不要です。

従来のYAML画面とレイアウトツリーも、互換アダプターを通して種類別の標準部品へ変換します。
`build_formspec`の既定描画はPMUI 2です。旧描画を検証するときだけ`renderer = "legacy"`を指定します。
メインメニューのコールバックからはformspec文字列だけを返し、検証用の第2戻り値をUI側へ返さないでください。
独立した新APIは`pmui.modern`または`pmui.new`から利用できます。
