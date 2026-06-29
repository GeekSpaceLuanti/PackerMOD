package.path = "./?.lua;" .. package.path

describe("pmui.cascade selector match", function()
    local dom, stylesheet, cascade
    setup(function()
        dom        = dofile("mainmenu/lib/pmui/dom.lua")
        stylesheet = dofile("mainmenu/lib/pmui/stylesheet.lua")
        cascade    = dofile("mainmenu/lib/pmui/cascade.lua")
    end)

    local function root_with(children)
        local r = dom.element { tag = "page", children = children }
        dom.walk(r, function() end)
        return r
    end

    it("matches tag", function()
        local el = dom.element { tag = "div" }
        assert.is_true(cascade.match(el, stylesheet.parse_selector("div")))
        assert.is_false(cascade.match(el, stylesheet.parse_selector("span")))
    end)

    it("matches class", function()
        local el = dom.element { tag = "div", classes = { "card", "big" } }
        assert.is_true(cascade.match(el, stylesheet.parse_selector(".card")))
        assert.is_true(cascade.match(el, stylesheet.parse_selector(".big")))
        assert.is_false(cascade.match(el, stylesheet.parse_selector(".other")))
    end)

    it("matches id", function()
        local el = dom.element { tag = "div", id = "main" }
        assert.is_true(cascade.match(el, stylesheet.parse_selector("#main")))
        assert.is_false(cascade.match(el, stylesheet.parse_selector("#other")))
    end)

    it("matches universal *", function()
        local el = dom.element { tag = "span" }
        assert.is_true(cascade.match(el, stylesheet.parse_selector("*")))
    end)

    it("matches descendant chain", function()
        local leaf = dom.element { tag = "span", classes = { "name" } }
        local mid  = dom.element { tag = "div", classes = { "card" }, children = { leaf } }
        local root = root_with { mid }
        assert.is_true(cascade.match(leaf, stylesheet.parse_selector(".card .name")))
        assert.is_true(cascade.match(leaf, stylesheet.parse_selector("page .name")))
    end)

    it("rejects descendant when parent doesn't match", function()
        local leaf = dom.element { tag = "span", classes = { "name" } }
        local root = root_with { leaf }
        assert.is_false(cascade.match(leaf, stylesheet.parse_selector(".card .name")))
    end)

    it("matches direct child", function()
        local leaf = dom.element { tag = "span", classes = { "name" } }
        local mid  = dom.element { tag = "div", classes = { "card" }, children = { leaf } }
        local root = root_with { mid }
        assert.is_true(cascade.match(leaf, stylesheet.parse_selector(".card > .name")))
    end)

    it("rejects direct child when there's an intermediate", function()
        local leaf  = dom.element { tag = "span", classes = { "name" } }
        local inner = dom.element { tag = "p", children = { leaf } }
        local mid   = dom.element { tag = "div", classes = { "card" }, children = { inner } }
        local root  = root_with { mid }
        assert.is_false(cascade.match(leaf, stylesheet.parse_selector(".card > .name")))
    end)

    it("matches :hover when state opts in", function()
        local el = dom.element { tag = "button", id = "btn" }
        local sel = stylesheet.parse_selector("#btn:hover")
        assert.is_false(cascade.match(el, sel, { hover_ids = {} }))
        assert.is_true(cascade.match(el, sel, { hover_ids = { btn = true } }))
    end)

    it("matches :disabled by attribute", function()
        local el = dom.element { tag = "button", attrs = { disabled = true } }
        local sel = stylesheet.parse_selector("button:disabled")
        assert.is_true(cascade.match(el, sel))
    end)
end)

describe("pmui.cascade compute (selector + var)", function()
    local dom, parser_html, parser_css, cascade
    setup(function()
        dom         = dofile("mainmenu/lib/pmui/dom.lua")
        parser_html = dofile("mainmenu/lib/pmui/parser_html.lua")
        parser_css  = dofile("mainmenu/lib/pmui/parser_css.lua")
        cascade     = dofile("mainmenu/lib/pmui/cascade.lua")
    end)

    local function compute(html, css, ctx, opts)
        local root  = parser_html.parse(html, ctx or {})
        local sheet = parser_css.parse(css)
        cascade.compute(root, sheet, opts or {})
        return root, sheet
    end

    it("applies a simple class rule", function()
        local root = compute([[
root:
  tag: page
  children:
    - tag: div
      class: card
]], [[
rules:
  - selector: ".card"
    style:
      bg: "#abc"
]])
        assert.equal("#abc", root.children[1].computed.bg)
    end)

    it("resolves var() through cascade", function()
        local root = compute([[
root:
  tag: page
  children:
    - tag: div
      class: card
]], [[
variables:
  --accent: "#FF52A4"
rules:
  - selector: ".card"
    style:
      border-color: "var(--accent)"
]])
        assert.equal("#FF52A4", root.children[1].computed["border-color"])
    end)

    it("evaluates calc() with var() and arithmetic", function()
        local root = compute([[
root:
  tag: page
  children:
    - tag: div
      class: card
]], [[
variables:
  --space-md: 0.4
rules:
  - selector: ".card"
    style:
      padding: "calc(var(--space-md) * 2 + 0.1)"
]])
        local got = root.children[1].computed.padding
        assert.is_true(math.abs(got - 0.9) < 1e-9)
    end)

    it("specificity: id > class > tag", function()
        local root = compute([[
root:
  tag: page
  children:
    - tag: div
      id: target
      class: card
]], [[
rules:
  - selector: "div"
    style:
      color: "tag"
  - selector: ".card"
    style:
      color: "class"
  - selector: "#target"
    style:
      color: "id"
]])
        assert.equal("id", root.children[1].computed.color)
    end)

    it("media query applies when matching page_w", function()
        local css = [[
rules:
  - selector: ".grid"
    style:
      grid-columns: 3
media:
  - query: "max-width 10.0"
    rules:
      - selector: ".grid"
        style:
          grid-columns: 2
]]
        local html = [[
root:
  tag: page
  children:
    - tag: div
      class: grid
]]
        local r1 = compute(html, css, {}, { page_w = 13.0 })
        assert.equal(3, r1.children[1].computed["grid-columns"])
        local r2 = compute(html, css, {}, { page_w = 9.0 })
        assert.equal(2, r2.children[1].computed["grid-columns"])
    end)

    it(":hover overrides base on matching id", function()
        local html = [[
root:
  tag: page
  children:
    - tag: button
      id: btn
]]
        local css = [[
rules:
  - selector: "#btn"
    style:
      bg: "#111"
  - selector: "#btn:hover"
    style:
      bg: "#fff"
]]
        local off = compute(html, css, {}, {})
        assert.equal("#111", off.children[1].computed.bg)
        local on = compute(html, css, {}, { hover_ids = { btn = true } })
        assert.equal("#fff", on.children[1].computed.bg)
    end)

    it("descendant rule applies", function()
        local root = compute([[
root:
  tag: page
  children:
    - tag: div
      class: card
      children:
        - tag: span
          class: name
]], [[
rules:
  - selector: ".card .name"
    style:
      color: "#fff"
]])
        local span = root.children[1].children[1]
        assert.equal("#fff", span.computed.color)
    end)
end)
