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

## 2026-07-16 14:05 (main)

**変更概要**:
#24 Phase 3: 全 label を hypertext[] 経路へ一括置換し、幅戦略 (flex ブロック +
text-align) で hypertext の「自然幅なし」を吸収。#1 (ラベル中心)・#4 (font-size 復活)・
#7 (空状態中央)・#8 の一部 (subtitle 右端一致) を green にした。

主な変更:
1. **Label render を hypertext[] emit に変更 (`lib/layout.lua`)**: `<global halign=
   valign= margin=0 color= size=>` に整列/色/サイズを集約。旧 ESC カラー hack
   (`\27(c@...)`) を廃止。text は adapter の `hypertext_escape` 経由、`]` も追加
   エスケープ。`attrs.markup` があれば整形済み markup をそのまま流す (2 色タイトル)。
2. **幅戦略 (hypertext は自然幅を持たないため必須)**:
   - title-bar を「左ブロック (title, flex:1) + 右ブロック (subtitle, flex:1
     text-align:right)」の 2 flex ブロックに再構造化。space-between + 自然幅推定への
     依存をやめ、右端をブロック右端 (= content 右端) に一致させた (#8 の subtitle 分)。
   - pack-card を align:stretch にし name/meta をカード全幅へ広げ halign=center。
     thumb は `.thumb-row` (justify center) で中央配置。折返し + スクロールバーを解消。
   - 残余の shrink-wrap 幅推定は `n*0.18` 固定から font_px 連動へ。
3. **ラベル帯を全幅 Label halign=center に (`LabeledIconButton`)**: 旧 Spacer サンド
   イッチを廃し、ボタン全幅ブロック + halign=center でラベル中心をボタン中心に一致
   (#1: offset 8~9.5px → 0.5px)。帯の色/font/transform は box (theme) から供給。
4. **css に text-align / text-transform 追加**: cascade→box_model→hypertext halign
   /string.upper。`font-size: *k` 倍率形式も units 換算で吸収 (未リベース画面対策)。
5. **空状態 #7**: pack 0 個のとき grid を出さず (`when: has_packs`)、no-packs-msg を
   flex:1 + text-align:center で content 全域中央に。汚染のない目視で縦横中央を確認。

検証: `busted spec/` 240 green、`make check-design SUBTAB=library` 5/5 PASS
(#1 offset 0.5px / #2 gap 5px / #3 margin 4px / #6 divider 2px×2)。three/empty
fixture の目視も正 (2 色タイトル 28px・右寄せ subtitle・カード中央寄せ・ラベル中央)。

**主な変更ファイル**:
- mainmenu/lib/layout.lua (Label→hypertext emit、LabeledIconButton 帯全幅化、ht_escape)
- mainmenu/lib/pmui/layout.lua (LABEL/status/icon-button 分岐で color/font_px/halign/transform 配線)
- mainmenu/lib/pmui/box_model.lua (text_transform 追加)
- mainmenu/lib/pmui/paint.lua (hypertext 経路調整)
- mainmenu/library.lua (title_markup 2 色化、has_packs/no_packs ctx)
- mainmenu/ui/library.html.yml (title-bar 2 ブロック化、thumb-row、has_packs で grid 出し分け)
- mainmenu/ui/themes/synthwave.css.yml (text-align、align:stretch、flex ブロック化)
- spec/{layout,pmui_layout,pmui_paint}_spec.lua (hypertext 期待値へ更新)

**次のTODO**: Phase 4 (composite button の box model 一致: full-frame image_button +
content_offset + image[] icon + box[] divider、帯意匠の theme 供給、#2/#5/#8 完結)

## 2026-07-16 13:20 (main)

**変更概要**:
#24 Phase 1: デザイン問題を数値で落とす再現テスト基盤を整備し、崩壊級 (#1/#2/#3)
+ divider (#6) を red 化した。再現テスト先行 (プロジェクトルール) の red 側。

1. **measure_ui.py に `--assert` モード追加**: 期待値 spec (JSON) の各 check を
   測定値と突き合わせ、1 つでも fail すれば exit 1。閾値は px (品質バー) か 'Nu'
   (unit_px 倍、解像度非依存) で書け、`only` で issue を絞れる。構造 (ラベル枠内/外)
   が変わっても「性質」の表明は不変にする設計。
2. **divider 検出を追加**: dim な cyan 罫線 (#6: 1px #059189, 輝度 57%) も拾えるよう
   広めの hue mask で検出し、thickness と brightness(g) を分けて測る。
3. **spec/design/library.json**: #24 の #1 (ラベル中心 ±2px)・#2 (gap ≥4px)・
   #3 (背景外周 ≤4px)・#6 (divider ≥2px & g≥210) を表明。現状 5/5 FAIL (red 確認)。
4. **screenshot_mainmenu.sh**: SCREEN_W/H・GUI_SCALING を conf 注入 (autosave 無効化
   込み。Phase 0 で判明したドリフト対策) し、解像度マトリクスを振れるように。
   FIXTURE=<name> で決定論的な pack 集合を差せる (Mod security 回避のため
   書き込み可能な ~/.minetest 下へステージング)。
5. **fixture 追加**: `empty` (0 packs, empty state 用) と `three` (3 packs, grid 用)。
6. **init.lua に fixture_root hook**: `packermod_fixture_root` で user_path を差し替え。
7. **make check-design SUBTAB=library**: 指定解像度で撮って spec を評価するターゲット。

検証: `make check-design SUBTAB=library` で 5/5 FAIL (exit 1)、three/empty fixture
とも撮影成功、既存 busted 241 tests は全 green を維持。

**主な変更ファイル**:
- scripts/measure_ui.py (--assert モード + divider 検出)
- scripts/screenshot_mainmenu.sh (解像度/gui_scaling/fixture 注入)
- spec/design/library.json (新規、アサーション spec)
- spec/design/fixtures/{empty,three}/ (新規、pack fixture)
- mainmenu/init.lua (packermod_fixture_root hook)
- Makefile (check-design ターゲット)

**次のTODO**: Phase 2 (host adapter + units + props + responsive size + auto-fit grid)

## 2026-07-16 14:30 (main)

**変更概要**:
#24 Phase 2: pmui にレスポンシブ基盤 (host adapter + px 単位系 + auto-fit grid) を
入れ、library を全画面レスポンシブ化。#3 (背景全面) と #6 (divider) を green にした。

新機構:
1. **host adapter (`pmui/host_mainmenu.lua`)**: engine API (get_window_info /
   set_background / hypertext_escape / log) を adapter 経由に。core 不在 (busted) は
   REF 値 (1024x600) を返す headless fallback。将来 in-game 版を別 adapter で差せる。
2. **単位系 (`pmui/units.lua`)**: theme の px = design px (mockup 1024x600 基準)。
   REF_UNIT_PX=53.328 (Phase 0 実測)。寸法 px→unit は px/REF (unit_px 非依存 = vh 的)、
   font は unit_px 依存。effective_unit_px は emit する size[] から engine 式で逆算。
3. **px 単位対応**: box_model の length resolver が "Npx" を unit へ換算 (数値はレガシー
   formspec unit のまま = 段階リベース共存)。calc()/media query も px 可に。
4. **responsive**: `pmui.responsive_page()` が window から page サイズ + unit_px を算出。
   library は max_formspec_size (min clamp 15.5x10) + `padding[0,0]` で全窓を覆う。
5. **auto-fit grid**: `grid-columns: auto` で列数 = 利用可能幅 ÷ (カード幅+gap)。
   placeholder は grid が最終行の空きセルへテンプレをクローン生成 (library.lua の
   grid_cols=3 二重管理 + ctx.placeholders を廃止)。
6. **device-pixel snapping**: border box を整数 px グリッドへスナップ (paint.lua)。

エンジン制約 (Phase 2 で判明、コメントに記録):
- `padding[0,0]` は size 直後に置く必要 (bgcolor が間に挟まると効かない)。
- box[] は色を ~57% 輝度でしか描けない (#00ffe5→(7,147,137))。9-slice PNG のみ full
  bright。box[] 罫線は AA で上下 1px 失うので、見かけ 2px の divider には 3px 指定。

library CSS を mockup px へリベース (`#pack-library` selector を新設し modal 共通の
`page` から分離)。detail/modal はまだ formspec unit のまま (Phase 6 でリベース)。

検証:
- `make check-design SUBTAB=library`: #3/#6/#2 green (残 #1 は Phase 3/4)。旧スクショで
  #6 thickness が red のまま = 再現維持。
- 1024x600 / 1600x900 / 2560x1440 で背景全面カバー・divider・auto-fit 列数を確認
  (2560 では 4 列 = 3 実カード + placeholder 1)。
- busted 241 tests green (library_spec を responsive size 前提に更新)。

**主な変更ファイル**:
- mainmenu/lib/pmui/host_mainmenu.lua, units.lua (新規)
- mainmenu/lib/pmui/{init,box_model,cascade,parser_css,layout,paint}.lua
- mainmenu/ui/themes/synthwave.css.yml (library 分を px リベース + #pack-library)
- mainmenu/ui/library.html.yml (placeholder を単一テンプレ化)
- mainmenu/library.lua (responsive_page 使用、grid_cols 撤去)
- spec/library_spec.lua, scripts/measure_ui.py, spec/design/library.json

**次のTODO**: props.lua + no-op 警告 (Phase 2 残)、Phase 3 (hypertext 化で #1/#4/#7)

## 2026-07-16 13:00 (main)

**変更概要**:
#24 (library 画面デザイン問題 9 件) を機構的に根治するための Phase 0 エンジン実測。
個別数値ハードコードでなく HTML/CSS 的な自動調整で直す方針が承認され (plan:
`.claude/plans/24-htlm-css-abstract-map.md`)、将来 pmui を汎用レスポンシブ UI
ライブラリ + in-game MOD へ昇華する構想も込みで、まず Luanti 5.16.1 の実挙動を
使い捨てハーネス (scratchpad/phase0/) で実測した。結果を以下に記録する
(以降の Phase 2〜5 の設計はこの数値に依存する)。

**実測結果 (Xvfb, gui_scaling=1, density=1)**:

1. **unit_px 実式が確定**: 1024x600 で `max_formspec_size = 19.2019 × 11.2511`、
   unit_px = 1024/19.2019 = **53.328px**。固定 size[10,5] でも responsive size でも
   1u 箱 = 53px で一定 → 短辺 floor (`0.5555×96 = 53.33`) が効く (600/15=40 < 53.33)。
   → REF_UNIT_PX = 53.33 の設計仮定は実測一致。
2. **responsive full-window カバー確認**: `size = max_formspec_size` + `padding[0,0]` で
   四隅の 1u 箱が window の (0,0)/(右上)/(右下) にピタリ (1024x600 全面)。
   → #3 (背景全面化) は size 可変化だけで大部分 green になる裏付け。
3. **hypertext の癖**:
   - `size=` は **px 単位** (12→cap 12px, 24→22px, 48→43px、ほぼ線形)。
   - デフォルト左マージン **3px**、`margin=0` で 0px に消える (label と同 x)。
   - `halign=center` はブロック中心一致 (±1.5px)、`halign=right` は右端 -5px、
     `valign=middle` は帯中央 (±3.5px)。→ エンジン整列が効くので幅推定を精度から外せる。
   - **幅不足時は折り返し + 高さ超過で縦スクロールバー出現** → 幅戦略必須の裏付け。
4. **クリック透過** (image_button 上に overlay を重ねてクリック到達を計測):
   - `image[]` / `label[]` / `box[]` overlay → **透過する** (下のボタンに届く)。
   - `hypertext[]` overlay → **透過しない** (クリックを食う)。
   - → composite button は「image_button(9-slice bgimg) を枠全域に敷き、icon=image[]・
     divider=box[] を重ね、**ラベルは image_button 自身の label** (content_offset で下帯へ)」
     で全域クリック可能。ラベルに hypertext は使えない。
5. **content_offset は px 単位** (0,48 でラベルが下帯へ、0,0.9 はほぼ不動)。
6. **resize 追従**: window リサイズで `WindowInfoChange` イベントが発火し、
   eventhandler で `ui.update()` すると get_formspec が新 window 情報で再実行される
   (2 回リサイズで n=2→3 と再構築を確認)。→ **responsive はライブ追従可能**。
   注意: Luanti は `autosave_screensize` により screen_w/h を conf に保存する。
   Phase 1 の解像度マトリクスでは conf に screen_w/h を明示注入 + autosave 無効化が要る。

**主な変更ファイル**:
- mainmenu/init.lua (`packermod_dev_screen` dev hook 追加。実験用画面を差し込む)

**次のTODO**: Phase 1 (再現テスト整備、#24 の 9 症状 + field 被りを red 化)

## 2026-07-16 10:35 (main)

**変更概要**:
デザインチェック手段を確立した。背景: 目視 (LLM 画像認識) のレビューはラベルの
+8px ズレ・gap=0 の密着を見逃した実績があり、幾何は測って判定する必要がある。

1. **`scripts/measure_ui.py`**: スクショのピクセル解析で幾何を数値化。bg 単色との
   差分から背景テクスチャのカバレッジ、accent 色の連結成分からアイコンボタン枠、
   枠下の白文字を単語クラスタリングしてラベルの中心 offset / gap を測る。
   `make measure SUBTAB=<画面>` でスクショ取得込みで実行できる。
2. **`.claude/agents/design-review.md`**: デザインレビュー用サブエージェント定義。
   スクショ取得 → measure_ui.py → 拡大クロップ目視 → mockup (docs/mockup/) 突き合わせ
   の手順で、崩壊 / ダサさ / mockup 差異をレポートする (修正はしない)。
3. **CLAUDE.md**: デザインチェック時は design-review のレポートを読んでから判断する
   運用ルールを追記。目視のみの合否判定を禁止。

検証: 定義と同内容の指示で library 画面をレビュー実行させ、崩壊 3 件 (ラベル中心
ズレ +8〜9.5px / gap=0 密着 / 背景が formspec 矩形にクリップされ全面を覆わない)、
中 2 件 (label 系 font-size が style[] no-op で全滅 → タイトル階層消失、ボタンラベル
の枠外・白・非 uppercase)、低 4 件を数値証拠つきで検出できることを確認した。

**主な変更ファイル**:
- scripts/measure_ui.py (新規)
- Makefile (`make measure` 追加)
- .claude/agents/design-review.md (新規)
- CLAUDE.md (デザインチェック節)
- .gitignore (.claude/settings.local.json を除外)

**コミット**: 83068be

**次のTODO**:
- レビュー検出済みの崩壊 3 件の修正: paint.lua の background 枠外ブリード /
  layout.lua の Label 幅推定 (0.18u/字 → 実測 0.24u/字) と LabeledIconButton 構造 /
  style_type[label] 経由の font-size 発行
- design-review エージェントは次セッションから subagent_type として起動可能

## 2026-07-15 22:20 (main)

**変更概要**:
Windows 実機 (Luanti 5.16.1) で PackerMOD を初回適用したところ 3 段の Windows 固有
バグに当たり、それぞれ修正して Pack Library 画面の起動まで確認した (#23 関連)。

1. **`install.ps1` / `uninstall.ps1` の `$userData` が `%APPDATA%\Luanti` を hardcode**。
   Luanti 5.16.1 は Windows で旧名の `%APPDATA%\Minetest` を user data として使い続けて
   いるため、そのままだと `Luanti user data directory not found` で即 error 終了する。
   → `%APPDATA%\Luanti` が存在すればそれ、なければ `%APPDATA%\Minetest` に fallback。
2. **pmui/*.lua (7 ファイル) の `SELF_DIR` 正規表現 `(.*/)` が Unix 区切りしか拾わない**。
   `debug.getinfo(1,"S").source` が Windows でバックスラッシュを返すため match 失敗
   → fallback の `./` になり `dofile("./dom.lua")` で
   `No such file or directory` を出して mainmenu 起動が丸ごと落ちる。
   → パターンを `(.*[/\\])` に拡張して `/` と `\` の両方を拾えるように。
3. **`mainmenu/init.lua:22` の `textures_dir` が `self_path .. ".." .. DIR_DELIM .. "textures"`**。
   Windows の Irrlicht image loader が `mainmenu\..\textures\` の `..` を正規化せず
   open 失敗し、synthwave 背景と neon ボタンの PNG が全て抜ける。
   → `self_path` から `mainmenu/` を落として `parent_dir .. "textures"` を直接構築。

**主な変更ファイル**:
- install/install.ps1, install/uninstall.ps1 — `$userData` の fallback ロジック
- mainmenu/lib/pmui/{init,box_model,cascade,layout,paint,parser_css,parser_html}.lua
  — `SELF_DIR` の regex を Windows 対応に (7 ファイル)
- mainmenu/init.lua — `textures_dir` を親ディレクトリ直接構築に

**検証**:
- `.\install\install.ps1 -Mode copy` が `%APPDATA%\Minetest\PackerMOD\` に mainmenu /
  textures / packs / cache を配置し、`minetest.conf` に `main_menu_script = ...` を
  追記することを確認 (`Using Luanti user data: ...\Minetest` が出るようになった)。
- Luanti 5.16.1 起動 → PackerMOD の Pack Library 画面 (`> PACKERMOD` タイトル +
  `No packs yet. Use Import or Create below` プレースホルダ) が表示されることを
  PowerShell 経由のウィンドウキャプチャで目視確認。
- `%APPDATA%\Minetest\worlds` / `games` は install 前後で LastWriteTime 変化なし
  (既存データ無傷)。

**残課題**:
- 背景 texture (`packermod_bg_synthwave.png`) と neon ボタン PNG は
  `%APPDATA%\Minetest\PackerMOD\textures\` に実在するのに Windows の
  Irrlicht image loader が Could not open で読めない。`..` を含まない
  絶対パスを渡してもダメなので Luanti 5.16.1 の Windows 実装側の別バグの
  可能性。メニューは背景抜けでも Pack Library として機能する。
  別 issue として追跡。
- #22 (実機 New World → Play 通し検証)、#23 (Windows Junction) は未着手のまま。
  今回は「メニューが起動する」までのスコープ。

## 2026-07-05 00:10 (main)

**変更概要**:
mockup 準拠改修 Step 5b: synthwave.css.yml と library.html.yml を neon.html 相当に
仕上げる。footer は上端罫線のみ + ボタンを 2.2x2.4 に縮小、pack-card は 9-slice
PNG 化、title-bar は下端罫線 + 2 色タイトル ("> " magenta + "PACKERMOD" cyan) + font
サイズを *3.5 → *2.0 に。

**主な変更**:
- `mainmenu/ui/themes/synthwave.css.yml`:
  - `.action-bar`: 4 辺 border + 半透明 bg 廃止、`border-top-width: 0.04` /
    `border-top-color: "#00ffe5"` の 1 本罫線のみ。gap 1.0 → 0.45、h 3.0 → 2.8。
  - `.action-btn`: w 4.0 → 2.2, h 2.7 → 2.4。
  - `.pack-card`: 4 辺 border を撤去して `bg-image: url(packermod_panel_neon.png)`
    + `bg-image-middle: 8` の 9-slice PNG に置換 (Step 5a で追加した container 9-slice
    発行を活用)。
  - `.title-bar`: `border-bottom-width: 0.04` + cyan の罫線を追加、h 1.8 → 1.4。
  - `#title`: color 撤去 (text 側で ESC 2 色化)、font-size *3.5 → *2.0。
  - `.subtitle`: font-size *1.6 → *1.2。
- `mainmenu/library.lua`: `ctx.title_text` に ESC (0x1B) 込みの
  "\27(c@#ff1b8d)> \27(c@#00ffe5)PACKERMOD" を組み立てて注入。
  YAML パーサは "\x1b" 系エスケープを実バイトに変換しないため、実 ESC バイトが
  必要なテキストは Lua 側で作る必要がある。
- `mainmenu/ui/library.html.yml`: `#title` の text を `${title_text}` に。

**検証**:
- `busted spec/`: 241 全緑 (回帰なし)
- `make screenshot-all`: library/worlds/multi/mods/info/modal_* 全 8 画面を目視。
  library は neon.html にほぼ準拠 (2 色タイトル、9-slice card、cyan 上罫線 footer、
  ボタン正方形 9-slice)。他画面も regression なし。

**主な変更ファイル**:
- mainmenu/ui/themes/synthwave.css.yml
- mainmenu/library.lua
- mainmenu/ui/library.html.yml

## 2026-07-05 00:00 (main)

**変更概要**:
mockup 準拠改修 Step 5a: PMUI の描画基盤を拡張する。footer 上 border のみのような
「特定の辺だけ罫線」を出せるように border-top/bottom/left/right プロパティを追加し、
container の背景を `background9[]` で 9-slice に塗れるようにする。

**主な変更**:
- `mainmenu/lib/pmui/box_model.lua`: border-top-width/color 等 4 辺個別の
  border プロパティを box に反映 (未指定なら 4 辺 border-color を継承)。
- `mainmenu/lib/pmui/paint.lua`: 個別 border 発行を追加、container の bg-image を
  `background9[X,Y;W,H;path;false;middle]` として発行。emit_borders /
  emit_container_bg9 を 1 つの `emit_container_decor` に統合。
  → iter_elements を 2 回呼ぶと flex 分配が不安定化し modal_create の field h が
     1.6 → 2.0 に膨らんで overlap 検出される回帰があったため、1 回に統一。

**検証**:
- `busted spec/`: 241 全緑 (回帰なし)

**主な変更ファイル**:
- mainmenu/lib/pmui/box_model.lua
- mainmenu/lib/pmui/paint.lua

**次のTODO**: Step 5b (synthwave.css.yml を mockup 準拠に、footer 上 border のみ /
card 9-slice / .action-btn 縮小 / タイトル 2 色化)

## 2026-07-04 23:55 (main)

**変更概要**:
mockup 準拠の見た目改修 Step 4。ボタン枠を単色 border から neon.html 相当の
9-slice PNG 枠 (通常 cyan / hover magenta) に置き換える基盤を用意する。

background9[] / style bgimg を絶対パスで実機動作させられるか未検証だったが、
PoC として `.action-btn` に `bg-image` + `bg-image-hover` + `bg-image-middle: 8`
を適用したところ、Import/Create/Settings のボタンに cyan の 9-slice 枠が
きれいに描画されることを確認 (make screenshot SUBTAB=library)。

**主な変更**:
- `scripts/bgimg_emit.lua`: `panel` kind (塗り + 外周単色枠 48x48 SVG) を追加。
  output マップは `conf.kind or key` で dispatch し既存 bg/grid とも共存。
- `mainmenu/ui/themes/synthwave.bgimg.yml`: `panel_neon` (パネル背景用) /
  `btn_neon` (ボタン通常) / `btn_neon_hover` (ボタン hover, magenta 枠) の
  3 枚の 48x48 9-slice PNG を追加。
- `mainmenu/lib/pmui/box_model.lua`: `bg-image-hover` / `bg-image-middle`
  プロパティを box に反映。
- `mainmenu/lib/pmui/paint.lua`: leaf button (button / icon-button) 要素に
  `style[name;bgimg=<絶対パス>;bgimg_middle=<n>;border=false]` を発行。
  `bg-image-hover` があれば `style[name:hovered;...]` も併発行。
  texture 絶対パス解決は既存 `emit_background` と同じロジックを共有。
- `mainmenu/ui/themes/synthwave.css.yml`: `.action-btn` に bg-image を適用
  (Import/Create/Settings のボタン枠が cyan に、hover で magenta に切り替わる)。
- `textures/packermod_btn_neon.png` / `packermod_btn_neon_hover.png` /
  `packermod_panel_neon.png` (新規生成、48x48)。

**検証**:
- `busted spec/`: 241 全緑
- `make screenshot SUBTAB=library`: cyan 9-slice 枠が 3 ボタンに適用されている
  ことを目視確認。style bgimg の実機動作 = 成功。

**主な変更ファイル**:
- scripts/bgimg_emit.lua
- mainmenu/ui/themes/synthwave.bgimg.yml
- mainmenu/lib/pmui/box_model.lua
- mainmenu/lib/pmui/paint.lua
- mainmenu/ui/themes/synthwave.css.yml
- textures/packermod_btn_neon.png (new)
- textures/packermod_btn_neon_hover.png (new)
- textures/packermod_panel_neon.png (new)

**次のTODO**: Step 5 (container の 9-slice 化, footer 上 border のみ, フォント比,
title 2 色化 で mockup 準拠へ最終化)

## 2026-07-04 23:45 (main)

**変更概要**:
Bug B (modal_create の flex リスト潰れ) を修正。
`.modal-card-wide` (w26.0 h12.5) に固定高コンテンツ (title/section-label 3 個/
2 modal-row/actions row/status label) を詰めすぎており、算術上 flex な
`search_results` textlist が h≈0.2u まで潰れていた (mod_list も h≈1.3u)。
overlap/OOB 判定は「潰れ」を検知しないため spec を素通りしていた。

**手順** (再現テスト先行):

1. `spec/modals_spec.lua`: modal_create テストに「search_results / mod_list の
   textlist h >= 2.0u」の assertion を追加。→ busted で失敗を確認 (`h=0.20`)。
2. `mainmenu/ui/themes/synthwave.css.yml` の modal サイズを是正:
   - `.modal-card-wide` w:26.0 → 28.4, h:12.5 → 14.4 (page 内寸フルに広げる)
   - `.modal-row` h:1.8 → 1.7
   - `.modal-section-label` h:0.8 → 0.6
   試算: 左 col の list h ≈ 2.8u / 右 col の mod_list h ≈ 3.8u。
3. `busted spec/` 241 全緑。

**検証**:
- `make screenshot SUBTAB=modal_create`: ContentDB search 結果リストと Current mods
  リストが実用サイズに広がり、Remove/Export/Close が下端に収まることを目視確認。

**主な変更ファイル**:
- spec/modals_spec.lua
- mainmenu/ui/themes/synthwave.css.yml

**次のTODO**: Step 4 (9-slice panel/btnframe + cyan アイコン生成)

## 2026-07-04 23:40 (main)

**変更概要**:
Bug A (Import/Create/Settings のアイコンとラベル/アクションバー枠との被り) を修正。
formspec v6 の label は「y = テキスト第 1 行の垂直中心」(lua_api.md L3334) だが、
`mainmenu/lib/layout.lua:277` は widget 上端 `_y` を label コマンドの y に渡していた。
結果、全 label が半文字分上に描画されて、LabeledIconButton (issue #21 対応) の
label band 内に文字が中心せず、上の image_button に食い込んでいた。

**手順** (再現テスト先行):

1. `spec/support/formspec_helpers.lua`: label rect を実機仕様 (中心アンカー) に
   合わせて `(x, y − h/2, w, h)` へ変更、default `label_h` を LabeledIconButton の
   band h と一致する 0.45 へ。
2. `busted spec/` → library grid の overlap テストが btn_import/create/settings と
   その下 label の重なりを検出して 3 件失敗することを確認 (再現)。
3. `mainmenu/lib/layout.lua:281` の Label render を `label[x, _y + h/2; text]` に
   修正。あわせて Image / IconButton の texture パスに `fs_escape` を追加
   (Windows DIR_DELIM=`\` 対策、menu_lua_api.md 推奨)。
4. `spec/layout_spec.lua`: detector self-check の 2 件が中心アンカー化に追従。
   - "counts label visual height against neighbouring fields" は label y を 2.6 に。
   - "flags the original Create-tab overlap pattern" (broken_snapshot) は Phase 12 で
     該当タブ削除済み + 座標が上端アンカー前提で意義が薄れているため撤去。
5. `busted spec/` 241 全緑。

**検証**:
- `make screenshot SUBTAB=library`: Import/Create/Settings ラベルがアイコンと重ならず
  アクションバー内に収まることを目視確認 (before/after 比較)

**主な変更ファイル**:
- mainmenu/lib/layout.lua
- spec/support/formspec_helpers.lua
- spec/layout_spec.lua

**次のTODO**: Step 3 (modal_create の flex リスト潰れ修正)

## 2026-07-04 23:30 (main)

**変更概要**:
mockup (`docs/mockup/neon.html`) と実機の乖離を段階的に埋める作業の Step 1。
cce5fe5 で `bg-image` を撤去した結果 spec が 5 件失敗 (library_spec.lua:148,216) しており、
`background[]` が formspec に出ずメニューが純色 `#0a0a18` のみになっていた。
neon.html の背景 (base 濃紺 + 下中央 magenta radial + 左上 cyan radial + 3px 周期スキャンライン)
を SVG→PNG で焼き直して `bg-image` を復活させる。

**主な変更**:
- `scripts/bgimg_emit.lua`: gradient 単一 stops のほかに `neon` セクション (base + radials
  + scanlines) を SVG で出せるようにした。radialGradient を objectBoundingBox 相対で並べ、
  scanline は 1x{period}px の pattern で敷く。
- `mainmenu/ui/themes/synthwave.bgimg.yml`: sunset gradient + grid の 2 出力から、
  neon 1 出力 (base `#0a0a18` / magenta radial 20% / cyan radial 15% / scanline 4%) に置換。
  未使用だった `packermod_grid_synthwave.png` は生成もやめ、`textures/` から削除。
- `mainmenu/ui/themes/synthwave.css.yml`: `page` と `.modal-page` に
  `bg-image: url(packermod_bg_synthwave.png)` を復活。
- `spec/library_spec.lua:149`: 実機の title 表記 (`> PACKERMOD`) に合わせて期待文字列を
  `PackerMOD` → `PACKERMOD` に是正 (cce5fe5 の追従漏れ)。
- `textures/packermod_bg_synthwave.png`: 1920x1024 で再生成。

**検証**:
- `busted spec/`: 242 全緑
- `make screenshot SUBTAB=library`: neon 背景 (magenta 下グラデ + cyan 左上 + scanline)
  が実機に反映されていることを目視確認

**主な変更ファイル**:
- scripts/bgimg_emit.lua
- mainmenu/ui/themes/synthwave.bgimg.yml
- mainmenu/ui/themes/synthwave.css.yml
- spec/library_spec.lua
- textures/packermod_bg_synthwave.png (regen)
- textures/packermod_grid_synthwave.png (delete)

**次のTODO**: Step 2 (label 垂直中心アンカー修正で Import/Create/Settings のラベル重なり解消)

## 2026-07-01 11:45 (main)

**変更概要**:
Luanti 実機で画面1 (Pack Library) の見た目が `docs/mockup/neon.html` と乖離しており、
派手な紫→ピンクの sunset パレット + Luanti タイトルバーに被る `PackerMOD 0.1.0` の
topleft テキスト + イエロー subtitle 等で統一感を欠いていた。モックアップの neon 2色
(cyan `#00ffe5` / magenta `#ff1b8d`) 準拠に寄せて視認性と統一感を上げる。

**主な変更**:
- `mainmenu/init.lua`: `core.set_topleft_text("PackerMOD ...")` を削除 (debug build 時に
  Luanti タイトルバーへ重なっていた。位置は Luanti が固定で調整不可)
- `mainmenu/ui/themes/synthwave.css.yml`: hex 60 箇所を neon パレットへ置換
  (旧 `#A06EFF/#FF52A4/#FFD400/#28114f/#1a0a3a/#f0e6ff/#b09ad8/#0a061f`
  → 新 `#00ffe5/#ff1b8d/#14143a/#0a0a18/#e0e0ff/#7a7aa8`)。
  title 系 (`#title` / `.detail-title` / `.modal-title`) だけ cyan、他タイトル系や
  danger/meta は magenta という 2 色ロールで分離。
  `bg-image: packermod_bg_synthwave.png` (page / .modal-page) を廃止して純色 bg のみに。
- `mainmenu/ui/library.html.yml`: タイトルを `PackerMOD` / `Pack Library` から
  `> PACKERMOD` / `// PACK_LIBRARY` に変更 (モックアップ準拠の terminal 風装飾)
- `textures/packermod_default_pack_thumbnail_synthwave.png`: 従来のピンク T字を
  Python stdlib で 256x256 黒地 + cyan T字 に再生成 (モックアップ準拠)

**諦めたこと** (Luanti formspec 非対応):
- glow / text-shadow, scanline overlay, blink カーソル `_`, hover 効果

**主な変更ファイル**:
- mainmenu/init.lua
- mainmenu/ui/themes/synthwave.css.yml
- mainmenu/ui/library.html.yml
- textures/packermod_default_pack_thumbnail_synthwave.png

**次のTODO**:
- 実機で目視確認 (背景純黒 / タイトル cyan / subtitle magenta / T字 cyan / タイトルバー被りなし)
- 旧 `textures/packermod_bg_synthwave.png` はまだ残置 (将来 neon 版 PNG を作る場合の再利用余地)

## 2026-06-30 23:10 (main)

**変更概要**:
**commit 8** で旧 path とフラグを完全撤去。PMUI + Synthwave 一本に集約。

**撤去対象**:
- 旧 DSL ファイル 6 つ: `mainmenu/ui/library.yml` + `modal_create.yml` + `modal_import.yml` + `modal_settings.yml` + `modal_world_create.yml` + `modal_world_delete.yml`
- 旧 `build_grid_formspec` / `build_detail_formspec` (PMLayout 直接構築) は削除し、PMUI 経由の `_pmui` 接尾辞付き関数をリネームしてその名前を引き継ぎ
- `PACKERMOD_LEGACY_GRID` / `PACKERMOD_LEGACY_DETAIL` / `PACKERMOD_LEGACY_MODALS` の os.getenv 分岐を全削除
- `ui_loader.lua` の `expand` / `load` / `build_tab_formspec` / `ui_yaml_path` / 19 個の handler 関数を削除。残るのは `resolve_value` / `resolve_path` のみ(PMUI の parser_html が依存)
- 旧 spec: `library_spec.lua` の `library.yml (detail view) expansion via ui_loader` と `formspec layout regression (#14, detail view)` describe ブロック削除。`ui_loader_spec.lua` も resolve_value 単体テストに置換

**結果**:
- 全 242 件緑 (前回 270 + 1 pending → -28 件 -1 pending)
- `#15` pending (layout shrink-to-fit) は旧 detail view 関連だったので一緒に解消
- ui_loader.lua: 200 行 → 50 行に簡素化
- 実機 screenshot で画面1/画面2/modal_import が問題なく動くことを確認

**主な変更ファイル**:
- `mainmenu/library.lua` (旧 build_*_formspec 削除 + リネーム + ディスパッチ簡素化)
- `mainmenu/dialogs/dlg_*.lua` x5 (LEGACY_MODALS 分岐削除)
- `mainmenu/lib/ui_loader.lua` (簡素化)
- `mainmenu/ui/library.yml`, `mainmenu/ui/modal_*.yml` x6 (削除)
- `spec/library_spec.lua` (旧 path テスト削除)
- `spec/ui_loader_spec.lua` (resolve_value 単体テストに置換)

**コミット**:
- a6b3be0: commit 8 - 旧 path とフラグを完全撤去

**次のTODO**:
- PMUI 自体の改善 (yaml.lua インラインマップ対応、他テーマ Neon/CRT/Matrix の実装、textlist 内側色の Synthwave 化)
- 細部 UX (画面2 で text サイズ調整、modal の textlist の見栄え)

## 2026-06-30 22:55 (main)

**変更概要**:
5 modal (Import / Create / Settings / WorldCreate / WorldDelete) を PMUI + Synthwave に移行。各 modal は size[30, 16] 全画面で外側を Synthwave 紫紺 + 中央に紫枠の `modal-card` を配置するパターンに統一。

**実装**:
- `synthwave.css.yml` に modal 共通スタイル一式を追加 (`.modal-page`, `.modal-card`(+ `-narrow`/`-mid`/`-wide`), `.modal-title`, `.modal-dim`, `.modal-info`, `.modal-status`, `.modal-field`, `.modal-actions`, `.modal-btn`(+ `-primary`/`-danger`), `.modal-icon-btn`, modal-create 用の grid/list/section-label など)
- `mainmenu/ui/modal_*.html.yml` を 5 ファイル新規作成
- `mainmenu/dialogs/dlg_*.lua` の get_formspec を `packermod.pmui.build_formspec` 呼び出しに書き換え。`PACKERMOD_LEGACY_MODALS=1` で旧 ui_loader path にフォールバック可能
- `spec/modals_spec.lua` 新規。5 modal すべて overlap=0 / fits_in_size を assert

**ハマったポイント**:
- `.modal-actions .modal-btn-primary` の子孫 selector だと modal-row 内の Import ボタンが対象外で primary 色が出なかった → `.modal-btn-primary` 単独 selector に変更
- modal-card のデフォルト h=8 では Import の Close が card 下端を超えていた → h=9 に拡張、modal-create-wide は h=14→12.5 に縮小 (画面 16 に対して上下余白を確保)

**主な変更ファイル**:
- `mainmenu/ui/themes/synthwave.css.yml` (modal 共通スタイル追加)
- `mainmenu/ui/modal_world_delete.html.yml`, `modal_world_create.html.yml`, `modal_import.html.yml`, `modal_settings.html.yml`, `modal_create.html.yml` (新規)
- `mainmenu/dialogs/dlg_import.lua`, `dlg_settings.lua`, `dlg_world_create.lua`, `dlg_world_delete.lua`, `dlg_create.lua` (PMUI 経路追加)
- `spec/modals_spec.lua` (新規、5 件)

**コミット**:
- e4fe9ce: 5 modal を PMUI + Synthwave に移行

**次のTODO**:
- modal の細部改善: TextList の内側色 (Synthwave 化が難しい)、icon-button ラベルの位置調整
- commit 8: `PACKERMOD_LEGACY_GRID` / `PACKERMOD_LEGACY_DETAIL` / `PACKERMOD_LEGACY_MODALS` フラグと旧 path 撤去
- (低優先) yaml.lua のインラインマップ対応、他テーマ実装

## 2026-06-30 22:30 (main)

**変更概要**:
画面2 (Pack Detail) を PMUI + Synthwave テーマで描画する移行を完了。前段で 6 ステップに分けて作業:

1. PMUI に `list` / `textarea` / `status` タグを追加 (TextList / TextArea / dim Label の wrapper)
2. `mainmenu/ui/pack_detail.html.yml` を新規作成 — ヘッダ + subtab buttons + 4 subtab pane (Worlds/Multi/Mods/Info) を when: で出し分け
3. `mainmenu/ui/themes/synthwave.css.yml` に画面2 用スタイルを追加 (subtab-btn の active/inactive、detail-list、form-row、mods-grid、subtab-actions など)
4. `mainmenu/library.lua` に `build_detail_formspec_pmui` を追加。`get_formspec` でディスパッチ (PACKERMOD_LEGACY_DETAIL=1 で旧 path にフォールバック)
5. `spec/library_spec.lua` に PMUI 経由 detail view smoke test を追加 (4 subtab すべて overlap=0 + fits_in_size 通過)
6. screenshot で 4 subtab を実機確認、`subtab-actions` の高さと `form-textarea` h 固定で OOB を解消

**ハマったポイント**:
- `ui_loader.lua` の `resolve_value` が module export されておらず、PMUI の parser_html がフォールバック実装を使っていた。フォールバックは pipe form (`${list | fmt}`) 非対応で、worlds リストなどが文字列のまま widget に渡されて `bad argument #1 to 'ipairs'` エラー → `M.resolve_value = resolve_value` を export して解決
- subtab active 状態は class 値の動的展開 (`class: "subtab-btn ${subtab_class_worlds}"`) で実現。parser_html が class 値も resolve するよう 1 行修正
- 画面1 用 `.action-btn` (4.0x2.7) が画面2 にも当たって `.subtab-actions` (h: 2.0) を超えて OOB → 子孫 selector `.subtab-actions .action-btn` で 3.5x1.6 に上書き
- TextArea は default h=2.0 + label_h 0.4 = 真の高さ 2.4 で flex:1 でも余りなしと判定されて固定。`.form-textarea` に明示的 h を指定して解決

**主な変更ファイル**:
- `mainmenu/lib/pmui/layout.lua` (list/textarea/status 追加)
- `mainmenu/lib/pmui/parser_html.lua` (class 値 resolve)
- `mainmenu/lib/ui_loader.lua` (resolve_value export)
- `mainmenu/library.lua` (build_detail_formspec_pmui 追加)
- `mainmenu/ui/pack_detail.html.yml` (新規)
- `mainmenu/ui/themes/synthwave.css.yml` (画面2 セクション追加)
- `spec/library_spec.lua`, `spec/pmui_layout_spec.lua` (テスト追加)

**コミット**:
- d1a0908: 画面2 (Pack Detail) を PMUI + Synthwave に移行

**次のTODO**:
- 画面2 の細部改善: textlist 内部の色 (現状 default の黒/緑) を Synthwave に合わせる方法を検討 — formspec の textlist style 制限あり
- 5 modal (Import/Create/Settings/WorldCreate/WorldDelete) の PMUI 移行
- commit 8: `PACKERMOD_LEGACY_GRID` / `PACKERMOD_LEGACY_DETAIL` フラグと旧 path 撤去
- (低優先) yaml.lua のインラインマップ対応、他テーマ実装

## 2026-06-30 13:45 (main)

**変更概要**:
画面1 細部の見栄え改善 3 件。

- A. subtitle "Pack Library" を dim purple → accent yellow (#FFD400) に、`.title-bar` に `justify: space-between` を適用してタイトル左 / subtitle 右の配置に。pmui/layout.lua に space-between 実装 (子要素間に Spacer{flex=1} を挿入)
- B. pack 数 % cols の空きスロットを薄いプレースホルダカード (`.pack-card-placeholder`、半透明 bg/border) で埋めて grid を均等に
- C. `.pack-card` に `align: center` を追加して thumb / Pack 名 / meta を水平中央配置 (HTML mockup と同じ `align-items: center` 相当)

**主な変更ファイル**:
- `mainmenu/lib/pmui/layout.lua` (justify: space-between 実装)
- `mainmenu/library.lua` (placeholder 計算)
- `mainmenu/ui/library.html.yml` (placeholders for ループ)
- `mainmenu/ui/themes/synthwave.css.yml` (subtitle 色 / placeholder スタイル / align: center)
- `spec/pmui_layout_spec.lua` (space-between テスト)

**コミット**:
- 8f163b5: subtitle 色 + space-between + placeholder + 中央寄せ

**次のTODO**:
- 画面2 / modal の PMUI 移行
- commit 8: `PACKERMOD_LEGACY_GRID` フラグと旧 `build_grid_formspec` を撤去
- (低優先) yaml.lua のインラインマップ対応
- (低優先) 他テーマ (Neon/CRT/Matrix) を `<name>.{bgimg,thumb,css}.yml` で実装

## 2026-06-30 13:30 (main)

**変更概要**:
ユーザー指摘「UI が中央に狭いのがダサい原因」を解消。formspec を window 全体に拡張した。

**真の原因**:
- Luanti が `minetest.conf` の `screen_w=1608, screen_h=853` で動いていた (≈ 16:9 弱)
- 旧 `size[13, 8.5]` は 4:3 ワイドアスペクト → Luanti が中央配置 + 周囲塗りで画面の 43%×57% しか formspec が映らなかった
- formspec の 1 unit ≈ 52 px (screenshot から逆算)

**修正**:
- `size[30, 16]` で 1 unit のピクセルサイズを維持しつつ window 全体を埋める。bgimg PNG も 1920x1024 で再生成
- 全 UI 要素を約 2x スケール: title font *1.8 → *3.5、pack-card w3.8/h4.0 → w8.5/h8.0、action-btn 1.9x1.4 → 4.0x2.7 など
- padding[-1,-1] / アスペクト調整など試行錯誤の末、結局 size を大きくして 1 unit の Luanti 物理サイズを維持するのが正攻法だった

**試行錯誤の経緯**:
1. `background[];auto_clip=true` → 効果なし (formspec 内側のみ)
2. `padding[-0.05,-0.05]` `padding[-1,-1]` → 効果なし (Luanti mainmenu では効かない)
3. size を window アスペクト (4:3 = 12.8x9.6) に → アスペクト合うが Luanti が依然中央配置
4. screen_w/screen_h を確認して **1608x853 = 16:9 弱**と判明
5. 1 unit ≈ 52 px と分かったので `size[30, 16]` で物理サイズが画面と一致 → 解決

**主な変更ファイル**:
- `mainmenu/library.lua` (page_w/h)
- `mainmenu/ui/themes/synthwave.bgimg.yml` (1920x1024)
- `mainmenu/ui/themes/synthwave.css.yml` (全 UI 値を 2x)
- `mainmenu/lib/pmui/paint.lua` (試行 prelude を削除)
- `textures/packermod_*_synthwave.png` (再生成)
- `spec/library_spec.lua` (size 期待値)

**コミット**:
- c3bb95b: formspec を window 全体に拡張 + UI 2x スケール

**次のTODO**:
- 画面2 / modal の PMUI 移行 (今は dark テーマのまま)
- commit 8: 数日運用後に `PACKERMOD_LEGACY_GRID` フラグと旧 `build_grid_formspec` を撤去
- Pack 数が grid-columns 未満のとき 3 列目の余白が目立つ → 空の placeholder カード or grid 中央配置で改善可能

## 2026-06-30 00:25 (main)

**変更概要**:
PMUI フェーズの仕上げ 2 件。実機 screenshot で確認したユーザーから「背景の雲がそのまま」「アイコンがドットのまま」「HTML mockup と全然違う」と指摘を受け、原因を調査して対処。

**雲消去 (f214a1b)**:
- 原因調査: A 案 `background[];auto_clip=true` 単独では効果なし。`auto_clip=true` は formspec 内側 (0,0)-(w,h) のテクスチャ clip を外すだけで、画面全体には拡大されない
- 解: Luanti formspec の `bgcolor[<bg>;<fullscreen>;<fbgcolor>]` で `fullscreen=both` を指定すると formspec 外側 (Luanti のメインメニュー雲・青空) を `fbgcolor` で塗り潰せる
- 副次的バグ: PMLayout の VBox bgcolor が `box[0,0;13,8.5;<bg>]` を出して背景画像を上から塗り潰す → page タグだけ VBox bgcolor を nil にして box[] 発行を抑止

**default thumbnail のテーマ別生成 (0b79421)**:
- 旧 `packermod_default_pack_thumbnail.png` はグレー単色で Synthwave テーマと合わなかった
- bgimg と同じ流儀で SVG → rsvg-convert パイプライン (`scripts/thumb_emit.lua` + `build_thumb.sh` + `make thumb`) を追加
- Synthwave 用は紫 (#28114f) + ピンク (#FF52A4) の T-icon (HTML mockup の defaultThumb と同等)
- `packermod.active_theme = "synthwave"` を init.lua で一箇所に集約、`library.lua` の `default_thumbnail_texture()` がテーマ別 PNG を返す

**主な変更ファイル**:
- `mainmenu/lib/pmui/paint.lua`, `mainmenu/lib/pmui/layout.lua`, `mainmenu/ui/themes/synthwave.css.yml`
- `scripts/thumb_emit.lua`, `scripts/build_thumb.sh` (新規)
- `mainmenu/ui/themes/synthwave.thumb.yml` (新規)
- `textures/packermod_default_pack_thumbnail_synthwave.png` (生成済み)
- `mainmenu/library.lua`, `mainmenu/init.lua`, `Makefile`

**コミット**:
- f214a1b: 雲消去 (bgcolor fullscreen=both + page VBox bgcolor 抑止)
- 0b79421: テーマ別 default thumbnail パイプライン

**次のTODO**:
- 画面1 で残る違和感: formspec 領域の境界が画面の中央付近に見える (Luanti formspec の固定 size 13.0x8.5 が window と違うアスペクト)。size を window アスペクトに合わせる改修が要れば別検討
- 画面2 / modal の PMUI 移行
- commit 8: 数日運用後に `PACKERMOD_LEGACY_GRID` フラグと旧 `build_grid_formspec` を撤去

## 2026-06-29 23:50 (main)

**変更概要**:
画面1 (Pack Library) の UI を **HTML/CSS 風 DSL ライブラリ PMUI** + Synthwave テーマで描く実装を入れた。前段で HTML mockup 4 案 (`docs/mockup/`) を作り、ユーザーが Synthwave を選択した結果のフォローアップ。8 段階のコミット計画 (`/home/bacon/.claude/plans/ui-html-ui-ui-drifting-sifakis.md`) のうち commit 1〜7 を完了。

**PMUI モジュール構成** (`mainmenu/lib/pmui/`):
- `dom.lua` / `stylesheet.lua` / `parser_html.lua` / `parser_css.lua` — HTML 風 DSL と CSSOM 相当のパーサ
- `cascade.lua` — selector (tag/.class/#id/子孫/直接子/疑似クラス) + specificity + `var()` + `calc()` + media query
- `box_model.lua` + `layout.lua` — 既存 `lib/layout.lua` (PMLayout) の VBox/HBox に組み立てる wrapper。`display: grid` の行分割もここで
- `paint.lua` — `background[]` / `bgcolor[]` / `style[name;...]` を prelude に積んで PMLayout の `build_formspec` に渡す
- `init.lua` — 公開 API `pmui.build_formspec(opts)`

**Synthwave PNG パイプライン**:
- `scripts/bgimg_emit.lua` で YAML → SVG、`scripts/build_bgimg.sh` で `rsvg-convert` で PNG 化 (既存 `build_icons.sh` と同じ流儀)
- `mainmenu/ui/themes/synthwave.bgimg.yml` で sunset グラデと outrun grid を生成
- `make bgimg` で `textures/packermod_bg_synthwave.png` + `..._grid_synthwave.png` を再生成可能

**画面1 配線**:
- `mainmenu/ui/library.html.yml` (HTML 風構造) と `mainmenu/ui/themes/synthwave.css.yml` (スタイル) を新規追加
- `mainmenu/library.lua` に `build_grid_formspec_pmui` 追加。`PACKERMOD_LEGACY_GRID=1` で旧 path に戻せる
- `mainmenu/init.lua` に `packermod.pmui` と `packermod.mainmenu_path` 登録

**画面2 (Pack Detail) と各 modal は旧 dark テーマのまま** (段階移行 A)。視覚的不整合は許容して、PMUI の安定後に順次移行する。

**テスト**: 新規 4 ファイル + 既存 library_spec に PMUI 経由テスト 2 件追加。256 件緑 (+1 pending #15)。

**コミット**:
- 295e09f: HTML mockup 4 案
- b390e5e: dom + stylesheet + parser_html/css
- c9a8525: cascade (selector + var/calc + media)
- 3fdb763: box_model + layout (PMLayout wrapper)
- 8915b14: paint + init で formspec e2e
- 865eecc: bgimg PNG パイプライン (SVG + rsvg-convert)
- 8e2d623: 画面1 DSL + Synthwave + 配線 (flag OFF)
- b372d40: フラグ反転で PMUI default
- e92fe82: label inline color + border + アクションバー bg (見た目フィニッシュ)

**次のTODO**:
- 残作業: paint.lua に **border (border-width + border-color) 描画**を追加してカード/ボタンに紫枠を出す
- label の textcolor を `style[name;textcolor=...]` でなく **`<style color=#...>text</style>` の inline 形式**で出して Luanti 5.16 で確実に効くようにする
- `.action-bar` に半透明黒 bg を入れて Import/Create/Settings のラベル読みやすさを改善
- 画面2 / modal の PMUI 移行 (将来コミット 8 の後)
- commit 8: 数日運用してバグなければ `PACKERMOD_LEGACY_GRID` フラグと旧 `build_grid_formspec` を撤去

## 2026-06-29 12:30 (main)

**変更概要**:
README に「インストール / 使い方 / アンインストール」のセクションを最新の構成で書き直した。PackerMOD は通常の MOD ではなく **メインメニュー自体の置き換え** であることを冒頭で明示。

`uninstall.sh` / `uninstall.ps1` に以下を追加:
- 新規追加した `<user>/PackerMOD/textures/` symlink を削除
- 過去 install スクリプトが残した `<user>/textures/packermod_*.png` も掃除
- 「packs/ と cache/ は残す」旨の説明出力を追加

**主な変更ファイル**:
- `README.md` (大幅書き直し)
- `install/uninstall.sh`, `install/uninstall.ps1`

**コミット**: 5e8e357

## 2026-06-29 12:15 (main) — d6becfa

**変更概要**:
#21 派生問題: icon-button のアイコンが横長ボタンで横に潰れて見えていたのを修正。

Luanti `image_button[X,Y;W,H;tex]` は画像を W×H 領域に縦横独立に拡大する(アスペクト比保持なし)仕様で、48×48 の正方形アイコンが横長ボタン (例 w=1.8, h=0.95 → ストレッチ比 1.9) で潰れていた。

修正: `layout.LabeledIconButton` のアイコン部を **正方形 (w = img_h)** にして、`HBox(Spacer + IconButton + Spacer)` で中央寄せ。ラベル側も同様に `HBox(Spacer + Label + Spacer)` で中央寄せして、アイコン中央とラベル中央が縦に揃うようにした。

検証(screenshot):
- 画面1: Import / Create / Settings のアイコンが正方形、ラベル中央 ✓
- 画面2 Worlds: New World / Delete / Play 同様 ✓
- Back ボタンも整列 ✓
- 全 190 spec 緑(1 pending は既存 #15)

**主な変更ファイル**:
- `mainmenu/lib/layout.lua` (LabeledIconButton をアイコン正方形 + 中央寄せに)
- `spec/ui_loader_spec.lua` (新構造に追従)

**コミット**: d6becfa

## 2026-06-29 12:00 (main)

**変更概要**:
#21 を実装。icon-button の label が画像中央に重なる Luanti formspec の仕様問題を解消した。

対応: `layout.LabeledIconButton` ヘルパーを新設し、label がある場合は `VBox(IconButton + Label)` で構成、label="" のサムネカード等はそのまま `IconButton` を返す。`ui_loader.icon-button` handler と `library.lua` の grid 画面 bottom action から呼び出して全 icon-button が同じ挙動になるよう統一。

副作用対応:
- ボタン高さ 0.9 → 1.4 に拡大(label 帯 0.45 + 画像 0.95)。Import / Create / Settings ボタンが視覚的に大きくなる
- spec/support/formspec_helpers の `overlaps_rect` に epsilon=1e-3 を入れて、image_button と直下 Label の浮動小数点誤差による誤検知を回避

検証(screenshot):
- 画面1: Import / Create / Settings にアイコン上 + ラベル下のレイアウトが効いた ✓
- 画面2 Worlds: Back / New World / Delete / Play 同様 ✓
- 全 190 spec 緑 (1 pending は既存 #15)

**主な変更ファイル**:
- `mainmenu/lib/layout.lua` (LabeledIconButton 新設)
- `mainmenu/lib/ui_loader.lua` (icon-button handler を LabeledIconButton にディスパッチ)
- `mainmenu/library.lua` (grid 画面 bottom action を LabeledIconButton 化)
- `mainmenu/lib/theme.lua` (一度入れた content_offset を撤去、ロジックは ui_loader 側で完結)
- spec: `library_spec.lua`, `ui_loader_spec.lua`, `support/formspec_helpers.lua` 更新

**コミット**: 77cb90b

**残課題**:
- #22 実機での New World → Play 通し検証
- #23 Windows Junction 動作確認
- 画面1 のサムネカードがアスペクト比固定でない (画像が横長に引き伸ばされる) のは Luanti image_button の仕様。気になるなら icon を 256×256 完全正方形のままで使い、ボタン w=h で固定する必要

## 2026-06-29 11:40 (main)

**変更概要**:
メインメニュー UI を「Pack グリッド画面 (3列) → Pack 詳細画面 (subtab)」のドリルダウン形式にし、世界の物理配置を `<user>/PackerMOD/packs/<pack_id>/worlds/<world_name>/` のサブディレクトリ階層に変更した。マイクラ風の体験を目指した変更。

主な変更点:
- **World ディレクトリ階層化**: 旧 `<user>/worlds/<pack_id>__<timestamp>/` を廃止、`<user>/PackerMOD/packs/<pack_id>/worlds/<sanitized_name>/` に変更。同 Pack 内で同名 NG、Pack 間では同名 OK。
- **起動方式**: Luanti は flat `<user>/worlds/` しか認識しないため、起動直前に `<user>/worlds/_pm_<random>` を symlink (Linux/macOS) / Junction (Windows `mklink /J`) で作成して core.start。次回起動時に `pack_launcher.cleanup_symlinks` が掃除。
  - POC は実機で `--worldlist both` と `--server --world <symlink>` で検証済み(POC 大成功)。
- **NewWorld バグ修正**: `os.time()` ベースの命名による衝突 (`world already exists: sample_pack__1782695620`) を解消。ユーザー入力名を `sanitize_world_name` で安全化してディレクトリ名に使う。display name は world.mt の `world_name` に保存。
- **UI**: 画面1 = Pack グリッド(3列、サムネ + 名前 + base game version、新規 / Import / Create / Settings)。画面2 = Pack 詳細(Back ボタン + 既存 subtab)。size を 15.5×8.5 → 13×8.5 に縮小し、`style_type[…;font_size=*1.2〜1.3]` を theme prelude に追加して widget を大型化。
- **サムネ機能**: manifest に `thumbnail: optional<string>` を追加。設定なしの Pack には `packermod_default_pack_thumbnail.png`(pixelarticons の package を rsvg-convert で 256×256 化)を表示。
- **Delete World UI**: subdir world / legacy flat world 両方に対応。確認 modal (`dlg_world_delete`) 経由。
- **Legacy 検出緩和**: 旧 `<pack_id>__` プレフィックス命名を `pack_id__` プレフィックスで認識し、world.mt に `packermod_pack_id` がない古いワールドも legacy として表示 + 削除可能に。
- **テクスチャ絶対パス解決**: Luanti mainmenu は `<share>/textures/base/pack/` 以外の name 解決をしないため、`<user>/PackerMOD/textures/` を sibling として配置し、Lua 側で絶対パスに変換するよう icons.lua / library.lua を修正。install.sh / install.ps1 も対応。

**再現テスト**:
- `world_builder_spec.lua`: 同 pack 同名衝突 / 別 pack 同名 OK / sanitize / delete を spec で先行確認。実装前に失敗 → 実装後に通過の流れを踏襲(CLAUDE.md ルール)。

**実機検証** (screenshot):
- 画面1 (Pack グリッド) サムネ表示・3列レイアウト ✓
- 画面2 各 subtab (Worlds / Multi / Mods / Info) ✓
- Legacy `[legacy] Sample Pack` が Worlds タブに出現 ✓
- Delete / Play / New World ボタン ✓
- 全 189 spec 緑 (1 pending は #15 既存)

**残課題 (別 issue 化推奨)**:
- icon-button の label が画像中央に overlap する (Luanti formspec の仕様)。アイコン+ラベルを分離した DSL 追加が必要
- 実機で New World → Play フローを通しで確認(GUI 操作なのでスクリプトでは不可)
- Windows での Junction 動作検証

**主な変更ファイル**:
- `mainmenu/world_builder.lua` (subdir 化 + sanitize + delete)
- `mainmenu/pack_manager.lua` (list_worlds 書き直し + list_legacy_worlds + get_thumbnail_path)
- `mainmenu/pack_launcher.lua` (symlink trick + cleanup_symlinks + delete_world routing)
- `mainmenu/library.lua` (state machine grid/detail + grid 直接構築)
- `mainmenu/manifest.lua` (thumbnail field)
- `mainmenu/lib/theme.lua` (font_size style_type prelude)
- `mainmenu/lib/icons.lua` (絶対パス化)
- `mainmenu/ui/library.yml` (画面2 リファクタ)
- `mainmenu/ui/modal_world_create.yml`, `mainmenu/ui/modal_world_delete.yml` (新規)
- `mainmenu/dialogs/dlg_world_create.lua`, `mainmenu/dialogs/dlg_world_delete.lua` (新規)
- `mainmenu/init.lua` (textures_dir export + cleanup_symlinks 呼び出し + 新 modal 登録)
- `textures/packermod_default_pack_thumbnail.png` (新規, 256×256)
- `install/install.sh`, `install/install.ps1` (textures sibling 配置に変更)
- spec: `world_builder_spec.lua`, `pack_manager_spec.lua`, `pack_launcher_spec.lua`, `library_spec.lua`, `manifest_spec.lua` を新 API 前提に更新

**コミット**: d78b06e

**次のTODO**:
- icon-button label overlap の改善(別 issue)
- 実機で New World → Play の通し検証
- Windows Junction の動作確認

## 2026-06-29 01:45 (main)

**変更概要**:
コード変更なし。残作業を全部 GitHub Issue 化した。以降の作業は Issue 駆動。
- #17 Settings dialog の Luanti core 設定実装(現状 placeholder)
- #18 Library に Pack の Delete UI を追加
- #19 Worlds サブタブに Configure ボタン
- #20 e2e/run.sh を Library 構造に追従

これで open Issue は計 7 件:
- (派生品質) #15 layout shrink-to-fit / #16 アイコン PNG 再生成
- (未実装機能) #17 Settings / #18 Pack Delete / #19 World Configure / #20 e2e
- (無関連) #8 PackerMOD-Base 別リポジトリ

**主な変更ファイル**: なし(本セクション = WORKLOG.md のみ)

**コミット**: 94ad2cd

**次のTODO**: GitHub Issue を見て個別に着手。優先度は #18 (Pack Delete UI) > #17 (Settings) > #19 (World Configure) > #20 (e2e) > #15/#16(品質)あたりが妥当。

## 2026-06-29 01:30 (main)

**変更概要**:
Phase 12 後の派生 Issue を 4 連続で対応。すべて Library + modal の品質改善で、メインメニュー再設計の本筋とは独立。
- **#11 Mods サブタブを左右分割** (commit 0917d86): mod_list と search_results を縦並びから左 col / 右 col の分割に変更。各 textlist が flex=1 で十分な高さを取れる。Remove / Add ボタンに w=2.5 明示(natural 0.9 では Remove が "Remov" で切れていた)
- **#13 Description を textarea で編集可能に** (commit 5aa8ca3): PMLayout に TextArea widget 追加(`textarea[X,Y;W,H;name;label;default]` を emit、label 上方バンド = Field と同じ)。ui_loader に textarea タグハンドラ。library.yml の info_description を field → textarea。spec も 2 case 追加(layout_spec.lua)
- **#14 library/modal の overlap regression テストを復活** (commit 989e32f): spec/support/formspec_helpers.lua にヘルパ抽出(layout_spec から)、library_spec.lua に library 7 シナリオ + 3 modal の overlap+OOB 検査を追加。過程で発覚した OOB を YAML 側で修正(modal_import/settings/create のサイズ、library の no_pack ステータス長文短縮、library page h 8.0→8.5)。library/info は #15 で別対応(layout shrink-to-fit 無しが原因)、pending
- **#10 アイコン視認性 (部分対応)** (commit 213928b): theme.button.default の bgcolor を #3A3A3A → #5A5A5A、hovered #4A4A4A → #7A7A7A、pressed #2A2A2A → #3A3A3A。emit_global_prelude に style_type[image_button;...] 追加(button の style_type は image_button に inherit しないため)。アイコン PNG 自体の単色問題は #16 で別途
- **新規 Issue 発見**: #15 layout が shrink-to-fit しない(子の natural h が parent を超えると OOB)/ #16 アイコン PNG を accent 色で再生成

**主な変更ファイル**:
- mainmenu/ui/library.yml (Mods 左右分割、Info textarea 化、page h 8.5、no_pack 文短縮)
- mainmenu/lib/layout.lua (M.TextArea + measure + render、KIND_TO_THEME_KIND に TextArea=field 追加)
- mainmenu/lib/ui_loader.lua (textarea タグ)
- mainmenu/lib/theme.lua (button bgcolor brighter + style_type[image_button])
- mainmenu/ui/modal_*.yml (各サイズ調整)
- spec/support/formspec_helpers.lua (新規, 共通ヘルパ)
- spec/layout_spec.lua (helpers 使用、TextArea spec 2 case)
- spec/library_spec.lua (overlap+OOB regression セクション、library 7 + modal 3 シナリオ)

**コミット**: 0917d86 (#11) / 5aa8ca3 (#13) / 989e32f (#14) / 213928b (#10)

**最終状態**: 163 spec 緑 + 1 pending(#15)。Issue: #9/#10/#11/#12/#13/#14 closed、#8/#15/#16 open。
- #8 Fork VoxeLibre 0.91 → PackerMOD-Base(別リポジトリの作業、無関連)
- #15 layout shrink-to-fit(library/info で顕在化、別途対応)
- #16 アイコン PNG 再生成(#10 のフォロー、SVG/PNG ビルドフローの作業)

メインメニュー再設計(Phase 7→12)+ 直接派生品質改善(#11/#13/#14/#10)を完了。

## 2026-06-29 00:55 (main)

**変更概要**:
Phase 12 (#9)。旧 tabview 時代の遺物を全削除して仕上げ。コードベースが Library + modal 構造に完全に切り替わった。
- 削除: `mainmenu/tabs/tab_*.lua` (4) / `mainmenu/ui/tab_*.yml` (4) / `ui_loader.tab_yaml_path()` / `init.lua` の `PACKERMOD_TAB_W` `PACKERMOD_TAB_H` `MAIN_TAB_W` `MAIN_TAB_H` `TABHEADER_H` `GAMEBAR_*` (旧 tabview 時代の global 定数) / `screenshot_mainmenu.sh` の `packermod_initial_tab` 互換コード
- `spec/layout_spec.lua` の "live tabs" セクション(4 件)を削除。これらは `mainmenu/tabs/tab_*.lua` を dofile していたため。同等の overlap / OOB 検査の復活は #14 で別途
- `library.lua` の旧コメント(「旧 4 タブは Phase 11 でモーダル化するまで残置」)を最新の状態に書き換え
- 全 151 spec 緑(155 → 151 は live tabs 4 件削除分のみ、他は無回帰)
- 実機(Xvfb)で Library が削除前と同じ見た目で動くことを確認

**Issue ナビゲーション修正**: Phase 11 の commit message では `Closes #9` と書いたが、実際の Phase 11 issue は #12(`gh issue create` の並列実行で issue 番号順序が逆になっていた)。GitHub 上で #12 を close、#9 を reopen して整合させた。**正しい対応関係**:
- #9 = Phase 12 (本コミットで close 予定)
- #10 = アイコン視認性 (open)
- #11 = Mods タブ高さ (open)
- #12 = Phase 11 (closed)
- #13 = Description textarea (open)
- #14 = Library/Modal overlap regression テスト復活 (open) ← Phase 12 から派生

**主な変更ファイル**:
- mainmenu/tabs/ (削除)
- mainmenu/ui/tab_*.yml (削除)
- mainmenu/lib/ui_loader.lua (tab_yaml_path 削除)
- mainmenu/init.lua (旧 global 定数削除)
- mainmenu/library.lua (コメント更新)
- scripts/screenshot_mainmenu.sh (packermod_initial_tab 互換削除)
- spec/layout_spec.lua (live tabs セクション削除)

**コミット**: b01b012

**次のTODO**: メインメニュー再設計の本筋(Phase 7→12)はこれで終わり。残課題は派生 Issue:
- #10 アイコン視認性(button 背景に同化、テーマ調整 + アイコン再生成)
- #11 Mods サブタブの textlist 高さ(左右分割への組換え)
- #13 Description を textarea に
- #14 Library/Modal overlap regression テスト復活

## 2026-06-29 00:20 (main)

**変更概要**:
Phase 11 (#9)。Library 左下の [Import][Create][Settings] を fstk dialog modal に変換。タブが完全に消えて CurseForge / Modrinth 流の「Library が主役、機能は modal 起動」フローに到達。
- Issue #9〜#13 を一括作成: 残りの Phase + 派生課題を全部 GitHub Issue 化(今回作業から「Issue ドリブン」運用に移行)
- `mainmenu/dialogs/dlg_import.lua` / `dlg_create.lua` / `dlg_settings.lua` 新設。`dialog_create` で fstk dialog を作って `set_parent(library_dlg)` + `parent:hide()` → `dlg:show()`。ESC または Close ボタンで `self:delete()` → fstk が parent を再 show
- `mainmenu/ui/modal_import.yml` / `modal_create.yml` / `modal_settings.yml` 新設(対応する旧 `tab_*.yml` から流用 + サイズ調整 + Close ボタン追加)
- `library.lua`: `M._dlg` で library dialog を保持して modal から参照可。`btn_import` / `btn_create` / `btn_settings` ハンドラを「dlg.show(M._dlg) を呼ぶ」に置換。dev hook の `packermod_initial_modal` を追加(library 起動と同時に modal を開く)
- `init.lua` で `packermod.dialogs.dlg_import/dlg_create/dlg_settings` を inject
- `screenshot_mainmenu.sh` と Makefile: `modal_import` / `modal_create` / `modal_settings` を引数として受けるよう拡張、initial_modal setting で modal を起動時 dispatch
- 実機(Xvfb)で 3 modal すべて表示確認(`make screenshot SUBTAB=modal_import|modal_create|modal_settings`)
- 旧 `tabs/tab_import.lua` / `tab_create.lua` / `tab_settings.lua` および `ui/tab_*.yml` は **Phase 12 (#10)** で削除予定。現在は孤立しているが残置(参照しているコードは無いので動作上は問題なし)
- 全 155 spec 緑(回帰なし)

**主な変更ファイル**:
- mainmenu/dialogs/dlg_import.lua / dlg_create.lua / dlg_settings.lua (新規)
- mainmenu/ui/modal_import.yml / modal_create.yml / modal_settings.yml (新規)
- mainmenu/library.lua (M._dlg / btn_* handler / packermod_initial_modal hook)
- mainmenu/init.lua (packermod.dialogs 配列に dialogs 3 つを inject)
- scripts/screenshot_mainmenu.sh (modal_* 引数対応)
- Makefile (screenshot-all に modal_* 追加)

**コミット**: dc339a2

**次のTODO**: Phase 12 (#10) = 旧 `tabs/tab_*.lua` + `ui/tab_*.yml` + `tab_yaml_path()` + `packermod_initial_tab` 互換コードを全削除して仕上げ。並行して派生 issue (#11 アイコン、#12 textarea、#13 Mods タブ高さ)も対応。

## 2026-06-29 00:00 (main)

**変更概要**:
Phase 10。Mods サブタブと Info サブタブを実装。Pack を選択した状態で:
- Mods タブで manifest.mods の表示・ContentDB 検索→追加・削除
- Info タブで name / version / description を編集して保存
ができる。`tab_create.lua` の ContentDB 検索 + manifest 編集ロジックは内部関数 + pack_builder の薄いラッパで、これを既存 Pack 編集向けに切り出して `mainmenu/pack_editor.lua` を新設。
- pack_editor: `add_mod / remove_mod / update_meta / contentdb_result_to_mod`。manifest.yaml への書き戻しまで完結。`packermod.manifest` グローバル + `opts.write_file` で test 差し替え可能
- library.lua: ctx に pack_mods / search_results / mod_status / info_status 等を追加。button_handler で mod_list / search_results / search_query / do_search / mod_add / mod_remove / info_save を処理
- library.yml: Mods section に list + search row + results list + Add/Remove actions、Info section に name/version/description field + Save Changes
- 実機(Xvfb)で Mods タブ(現 mod 一覧 / Search / Remove ボタン)と Info タブ(Name/Version/Description/Save)を確認。Description は formspec の単行 `field` で表示しているので長文だと読みづらい(textarea 未対応 — Phase 10 のスコープ外)
- 全 155 spec 緑(+9 件: pack_editor 7 + library Mods/Info レンダリング 2)

**主な変更ファイル**:
- mainmenu/pack_editor.lua (新規)
- mainmenu/library.lua (Mods + Info の ctx / handler / format_mod_entry / format_search_result)
- mainmenu/ui/library.yml (Mods / Info セクション)
- mainmenu/init.lua (pack_editor を packermod に inject)
- spec/pack_editor_spec.lua (新規, 7 case)
- spec/library_spec.lua (build_ctx 拡張 + Mods/Info レンダリングテスト 2)

**コミット**: f87c054

**次のTODO**: Phase 11 = Import / Create / Settings をモーダル化、ライブラリ左下の3小ボタンから dialog を開く。tab_*.yml は捨てずにモーダル用にリフォーム。Phase 12 で旧 `tab_*.yml` / `tabs/tab_*.lua` を削除して清書。アイコン視認性問題は Phase 12 で解決(白系アイコンを accent 色で塗り直す or テーマ button.bgcolor を明るくする)。

## 2026-06-28 23:40 (main)

**変更概要**:
Phase 9。Multiplayer サブタブを実装。`<pack_root>/servers.yaml` のサーバー一覧表示・追加・削除・接続が動く。Edit は省略(現状は Remove → 再 Add で代用)。
- マイクラ式: `servers.yaml` は単に「IP メモ」、サーバー側 Mod 要件への適合は Luanti のハンドシェイクが処理。プラン通り
- library.yml: Multi セクションに list + Name/Address/Port フィールド + Add / Remove / Connect ボタン。Remove と Connect は `${has_server}` 条件付き
- library.lua: get_formspec で `packermod.launcher.list_servers(pack)` 呼び出し、form 値を tabdata.form_server で保持(再描画でクリアされない)。button_handler で Add / Remove / Connect 分岐、Connect は `gamedata.singleplayer=false / address / port / playername / password` セット → `core.start()`
- `build_server_from_form(form)` で入力 validation(address 必須、port 数値チェック、空白 trim、port default 30000)
- `format_server_label` でリスト表示「Name (host:port)」、port=30000 のときは port 省略
- **Hot fix**: `server_list.lua` の `deps()` が `require("mainmenu.yaml")` を呼ぶと Luanti のメニュー sandbox(mod security)で死ぬ。`packermod.yaml` グローバル → `require` の順に fallback して回避(spec も無修正で通る)
- Xvfb で Multi サブタブ描画を確認(空サーバー時の状態)。Add → 接続のインタラクション部はテストで担保
- 全 146 spec 緑(+9 件)

**主な変更ファイル**:
- mainmenu/library.lua (Multi 関連 ctx・handler・launch_server・build_server_from_form 追加)
- mainmenu/ui/library.yml (Multi セクション)
- mainmenu/server_list.lua (require → packermod.yaml fallback)
- spec/library_spec.lua (format_server_label・build_server_from_form・Multi UI レンダリングテスト 9 件追加)

**コミット**: 58517ca

**次のTODO**: Phase 10 = Mods サブタブ。`tab_create.lua` の ContentDB 検索 + manifest 編集ロジックを `pack_editor.lua` に切り出し、Mods サブタブから呼ぶ。Info サブタブ(description 編集)も Phase 10 でセットで。アイコン PNG の視認性問題は Phase 10/11 のテーマ調整時に対応(白系 stroke を fill 黒色 + accent stroke 等に置換するアイコン再生成が必要)。

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
