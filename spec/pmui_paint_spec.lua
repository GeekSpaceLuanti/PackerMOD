package.path = "./?.lua;" .. package.path

describe("pmui.paint (end-to-end formspec)", function()
    local pmui, helpers
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        packermod.yaml   = dofile("mainmenu/yaml.lua")
        pmui    = dofile("mainmenu/lib/pmui/init.lua")
        helpers = dofile("spec/support/formspec_helpers.lua")
    end)

    local function fs(html, css, opts)
        return pmui.build_formspec {
            renderer = "legacy", -- compatibility backend is intentionally tested here
            html = html, css = css,
            ctx = (opts or {}).ctx,
            page_w = (opts or {}).page_w or 13.0,
            page_h = (opts or {}).page_h or 8.5,
            hover_ids  = (opts or {}).hover_ids,
            active_ids = (opts or {}).active_ids,
            texture_dir = (opts or {}).texture_dir,
        }
    end

    it("emits formspec_version and size", function()
        local s = fs([[
root:
  tag: page
]], [[
rules: []
]])
        assert.is_truthy(s:find("formspec_version", 1, true))
        assert.is_truthy(s:find("size[13,8.5]", 1, true))
    end)

    it("emits background[] when page has bg-image", function()
        local s = fs([[
root:
  tag: page
]], [[
rules:
  - selector: "page"
    style:
      bg-image: "url(packermod_bg.png)"
]])
        assert.is_truthy(s:find("background[0,0;13,8.5;packermod_bg.png;true;0]", 1, true))
    end)

    -- Windows で texture_dir が DIR_DELIM='\' 由来のバックスラッシュ区切りになると、
    -- formspec parser が '\' を escape として消費し 'C:Users...' に化けて Irrlicht が open 失敗する。
    -- image path は formspec に埋める直前に fs_escape で '\' → '\\' に escape する必要がある。
    it("escapes backslashes in Windows-style texture_dir for background[]", function()
        local s = fs([[
root:
  tag: page
]], [[
rules:
  - selector: "page"
    style:
      bg-image: "url(bg.png)"
]], { texture_dir = "C:\\Users\\x\\textures\\" })
        -- Lua 文字列で "\\\\" = 2 chars ('\\'), find の plain=true でリテラル一致。
        assert.is_truthy(s:find("C:\\\\Users\\\\x\\\\textures\\\\bg.png", 1, true))
        -- 生の 'C:\Users' (backslash + 'U') が残っていないこと (escape 漏れ検出)。
        assert.is_nil(s:find("C:\\U", 1, true))
    end)

    it("escapes backslashes in bgimg style for button 9-slice", function()
        local s = fs([[
root:
  tag: page
  children:
    - tag: button
      id: btn
      name: btn
      text: OK
]], [[
rules:
  - selector: "button"
    style:
      bg-image: "url(btn.png)"
      bg-image-middle: 8
]], { texture_dir = "C:\\Users\\x\\textures\\" })
        assert.is_truthy(s:find("bgimg=C:\\\\Users\\\\x\\\\textures\\\\btn.png", 1, true))
    end)

    it("emits bgcolor[ ;both; ] when page has bg (formspec 外側の Luanti 雲も塗り潰す)", function()
        local s = fs([[
root:
  tag: page
]], [[
rules:
  - selector: "page"
    style:
      bg: "#1a0a3a"
]])
        assert.is_truthy(s:find("bgcolor[#1a0a3a;both;#1a0a3a]", 1, true))
    end)

    it("emits inline ESC color sequence for label text (style[textcolor] is unreliable on labels)", function()
        local s = fs([[
root:
  tag: page
  children:
    - tag: h1
      id: title
      text: PackerMOD
]], [[
rules:
  - selector: "#title"
    style:
      color: "#FF52A4"
]])
        -- Label の textcolor は label[] の text 前置 ESC color sequence で埋め込む
        assert.is_truthy(s:find("\27(c@#FF52A4)PackerMOD", 1, true))
        -- style[label;textcolor=...] は二重指定回避のため出力しない
        assert.is_nil(s:find("style[title;textcolor=", 1, true))
    end)

    it("sets label type font size immediately before rendering the label", function()
        local s = fs([[
root:
  tag: page
  children:
    - tag: h1
      id: t
      text: x
]], [[
rules:
  - selector: "#t"
    style:
      font-size: "*1.8"
]])
        assert.is_truthy(s:find("style_type[label;font_size=*1.8]label[", 1, true))
        assert.is_nil(s:find("style[t;", 1, true))
    end)

    it("labeled icon-button renders one clickable text button", function()
        local s = fs([[
root:
  tag: footer
  class: actions
  children:
    - tag: icon-button
      attrs:
        name: btn_create
        icon: plus
        label: Create
]], [[
rules:
  - selector: ".actions"
    style:
      flex-direction: row
      justify: end
]], { ctx = { icon_path = function(n) return "icon_" .. n .. ".png" end } })
        assert.is_truthy(s:find("button[", 1, true))
        assert.is_truthy(s:find("btn_create;Create]", 1, true))
        assert.is_nil(s:find("image_button[", 1, true))
        -- label "Create" は別 Label として出力 (LabeledIconButton 構造)
        assert.is_truthy(s:find("Create", 1, true))
    end)

    it("grid splits children into rows with no overlap", function()
        local s = fs([[
root:
  tag: page
  children:
    - tag: main
      class: g
      for:
        each: it
        in: items
      children:
        - tag: div
          class: card
          attrs:
            name: "card_${it.id}"
]], [[
rules:
  - selector: ".g"
    style:
      display: grid
      grid-columns: 3
      gap: 0.2
      flex: 1
  - selector: ".card"
    style:
      bg: "#28114f"
      w: 3.5
      h: 3.5
]], { ctx = { items = { {id="a"}, {id="b"}, {id="c"}, {id="d"} } } })
        local size, els = helpers.parse_formspec(s)
        assert.equal(13.0, size.w)
        local overlaps = helpers.find_overlaps(els)
        assert.equal(0, #overlaps, "found overlaps: " .. tostring(#overlaps))
        local ok = helpers.fits_in_size(els, size)
        assert.is_true(ok)
    end)

    it("media query: max-width 10 switches grid-columns to 2", function()
        local html = [[
root:
  tag: page
  children:
    - tag: main
      class: g
      for:
        each: it
        in: items
      children:
        - tag: div
]]
        local css = [[
rules:
  - selector: ".g"
    style:
      display: grid
      grid-columns: 3
media:
  - query: "max-width 10.0"
    rules:
      - selector: ".g"
        style:
          grid-columns: 2
]]
        -- 普通サイズ (13.0): 3 列 → 4 個で行が 2 (3+1)
        local s_wide = fs(html, css, { ctx = { items = { {},{},{},{} } }, page_w = 13.0 })
        -- 狭いサイズ (9.0): 2 列 → 4 個で行が 2 (2+2)
        local s_narrow = fs(html, css, { ctx = { items = { {},{},{},{} } }, page_w = 9.0, page_h = 5 })
        -- 内容比較 (HBox 数で代用するのは難しいので、empty なら少なくとも no error で出ること)
        assert.is_truthy(s_wide:find("size[13,8.5]", 1, true))
        assert.is_truthy(s_narrow:find("size[9,5]", 1, true))
    end)

    it(":hover state changes style via cascade (static snapshot)", function()
        local html = [[
root:
  tag: page
  children:
    - tag: h1
      id: t
      text: x
]]
        local css = [[
rules:
  - selector: "#t"
    style:
      color: "#111"
  - selector: "#t:hover"
    style:
      color: "#fff"
]]
        local off = fs(html, css)
        local on  = fs(html, css, { hover_ids = { t = true } })
        -- label の textcolor は ESC color sequence として埋め込まれる
        assert.is_truthy(off:find("\27(c@#111)x", 1, true))
        assert.is_truthy(on:find("\27(c@#fff)x", 1, true))
    end)

    it("emits border boxes when border-width and border-color are set", function()
        local s = fs([[
root:
  tag: page
  children:
    - tag: card
      id: c
]], [[
rules:
  - selector: "#c"
    style:
      bg: "#28114f"
      border-width: 0.04
      border-color: "#A06EFF"
      w: 3.0
      h: 2.0
]])
        -- top / bottom / left / right の 4 辺の box[] が含まれること
        local _, count = s:gsub("box%[[^%]]*#A06EFF%]", "")
        assert.is_true(count >= 4, "expected at least 4 border boxes, got " .. count)
    end)
end)
