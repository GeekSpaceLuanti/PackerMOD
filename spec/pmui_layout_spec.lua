package.path = "./?.lua;" .. package.path

describe("pmui.box_model", function()
    local dom, box_model
    setup(function()
        dom       = dofile("mainmenu/lib/pmui/dom.lua")
        box_model = dofile("mainmenu/lib/pmui/box_model.lua")
    end)

    it("copies layout properties from computed", function()
        local el = dom.element { tag = "div" }
        el.computed = {
            padding = 0.4, gap = 0.2, ["flex-direction"] = "row",
            justify = "end", flex = 1, w = 5, h = 3,
        }
        box_model.compute(el)
        assert.equal(0.4, el.box.padding)
        assert.equal(0.2, el.box.gap)
        assert.equal("row", el.box.flex_direction)
        assert.equal("end", el.box.justify)
        assert.equal(1, el.box.flex)
        assert.equal(5, el.box.w)
        assert.equal(3, el.box.h)
    end)

    it("defaults flex_direction to column and align to stretch", function()
        local el = dom.element { tag = "div" }
        el.computed = {}
        box_model.compute(el)
        assert.equal("column", el.box.flex_direction)
        assert.equal("stretch", el.box.align)
    end)

    it("extracts bg-image url", function()
        local el = dom.element { tag = "page" }
        el.computed = { ["bg-image"] = { _url = "foo.png" } }
        box_model.compute(el)
        assert.equal("foo.png", el.box.bg_image)
    end)

    it("copies paint properties (bg / color / border-color / font-size)", function()
        local el = dom.element { tag = "div" }
        el.computed = {
            bg = "#abc",
            color = "#fff",
            ["border-color"] = "#A06EFF",
            ["font-size"] = "*1.2",
        }
        box_model.compute(el)
        assert.equal("#abc",    el.box.bg)
        assert.equal("#fff",    el.box.color)
        assert.equal("#A06EFF", el.box.border_color)
        assert.equal("*1.2",    el.box.font_size)
    end)

    it("compute_all walks the whole tree", function()
        local root = dom.element {
            tag = "page",
            children = { dom.element { tag = "div" } },
        }
        dom.walk(root, function(el) el.computed = el.computed or {} end)
        box_model.compute_all(root)
        assert.is_not_nil(root.box)
        assert.is_not_nil(root.children[1].box)
    end)
end)

describe("pmui.layout (DOM → PMLayout)", function()
    local dom, parser_html, parser_css, cascade, box_model, layout
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        dom         = dofile("mainmenu/lib/pmui/dom.lua")
        parser_html = dofile("mainmenu/lib/pmui/parser_html.lua")
        parser_css  = dofile("mainmenu/lib/pmui/parser_css.lua")
        cascade     = dofile("mainmenu/lib/pmui/cascade.lua")
        box_model   = dofile("mainmenu/lib/pmui/box_model.lua")
        layout      = dofile("mainmenu/lib/pmui/layout.lua")
    end)

    local function compile(html, css, ctx, opts)
        local root  = parser_html.parse(html, ctx or {})
        local sheet = parser_css.parse(css)
        cascade.compute(root, sheet, opts or {})
        box_model.compute_all(root)
        return layout.flow(root, ctx or {})
    end

    it("page → VBox by default", function()
        local node = compile([[
root:
  tag: page
]], [[
rules: []
]])
        assert.equal("VBox", node._kind)
    end)

    it("flex-direction: row → HBox", function()
        local node = compile([[
root:
  tag: div
  class: title-bar
]], [[
rules:
  - selector: ".title-bar"
    style:
      flex-direction: row
]])
        assert.equal("HBox", node._kind)
    end)

    it("h1/span → Label", function()
        local node = compile([[
root:
  tag: page
  children:
    - tag: h1
      text: "Title"
    - tag: span
      text: "Sub"
]], [[
rules: []
]])
        assert.equal("Label", node[1]._kind)
        assert.equal("Title", node[1].text)
        assert.equal("Label", node[2]._kind)
        assert.equal("Sub",   node[2].text)
    end)

    it("icon-button → LabeledIconButton structure", function()
        local node = compile([[
root:
  tag: page
  children:
    - tag: icon-button
      attrs:
        name: btn_x
        icon: plus
        label: Create
]], [[
rules: []
]], { icon_path = function(n) return "icon_" .. n .. ".png" end })
        -- LabeledIconButton は VBox を返す
        local lib = node[1]
        assert.equal("VBox", lib._kind)
        -- 中の image_button 探索
        local row1 = lib[1]
        assert.equal("HBox", row1._kind)
        local found_ibtn
        for _, c in ipairs(row1) do
            if c._kind == "IconButton" then found_ibtn = c end
        end
        assert.is_not_nil(found_ibtn)
        assert.equal("btn_x", found_ibtn.name)
        assert.equal("icon_plus.png", found_ibtn.texture)
    end)

    it("justify: end inserts leading Spacer{flex=1}", function()
        local node = compile([[
root:
  tag: footer
  class: actions
  children:
    - tag: button
      attrs:
        name: a
        label: A
]], [[
rules:
  - selector: ".actions"
    style:
      flex-direction: row
      justify: end
]])
        assert.equal("HBox", node._kind)
        assert.equal("Spacer", node[1]._kind)
        assert.equal(1, node[1].flex)
        assert.equal("Button", node[2]._kind)
    end)

    it("display: grid splits children into HBox rows of N", function()
        local node = compile([[
root:
  tag: main
  class: g
  children:
    - tag: div
    - tag: div
    - tag: div
    - tag: div
    - tag: div
]], [[
rules:
  - selector: ".g"
    style:
      display: grid
      grid-columns: 3
      gap: 0.2
]])
        -- g 自体は VBox。2 行 (3 + 2)
        assert.equal("VBox", node._kind)
        assert.equal(2, #node)
        assert.equal("HBox", node[1]._kind)
        assert.equal(3, #node[1])
        assert.equal("HBox", node[2]._kind)
        assert.equal(2, #node[2])
    end)

    it("propagates gap and padding to spacing/padding on PMLayout", function()
        local node = compile([[
root:
  tag: page
  children:
    - tag: span
      text: x
]], [[
rules:
  - selector: "page"
    style:
      padding: 0.4
      gap: 0.6
]])
        assert.equal(0.4, node.padding)
        assert.equal(0.6, node.spacing)
    end)

    it("end-to-end produces buildable formspec via PMLayout", function()
        local node = compile([[
root:
  tag: page
  children:
    - tag: h1
      text: Hello
    - tag: footer
      class: actions
      children:
        - tag: button
          attrs:
            name: ok
            label: OK
]], [[
variables:
  --pad: 0.3
rules:
  - selector: "page"
    style:
      padding: "var(--pad)"
  - selector: ".actions"
    style:
      flex-direction: row
      justify: end
]])
        local fs = packermod.layout.build_formspec(node, { w = 10, h = 5 })
        assert.is_truthy(fs:find("formspec_version", 1, true))
        assert.is_truthy(fs:find("Hello", 1, true))
        assert.is_truthy(fs:find("button[", 1, true))
    end)
end)
