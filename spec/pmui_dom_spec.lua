package.path = "./?.lua;" .. package.path

describe("pmui.dom", function()
    local dom
    setup(function()
        dom = dofile("mainmenu/lib/pmui/dom.lua")
    end)

    it("creates an element with defaults", function()
        local el = dom.element { tag = "div" }
        assert.equal("div", el.tag)
        assert.same({}, el.classes)
        assert.same({}, el.attrs)
        assert.same({}, el.children)
    end)

    it("walks in pre-order", function()
        local root = dom.element {
            tag = "page",
            children = {
                dom.element { tag = "h1" },
                dom.element {
                    tag = "section",
                    children = { dom.element { tag = "span" } },
                },
            },
        }
        local order = {}
        dom.walk(root, function(el) order[#order + 1] = el.tag end)
        assert.same({ "page", "h1", "section", "span" }, order)
    end)

    it("finds element by id", function()
        local target = dom.element { tag = "div", id = "target" }
        local root = dom.element {
            tag = "page",
            children = { dom.element { tag = "header" }, target },
        }
        assert.equal(target, dom.find_by_id(root, "target"))
        assert.is_nil(dom.find_by_id(root, "missing"))
    end)

    it("ancestors returns parents nearest first", function()
        local leaf = dom.element { tag = "span" }
        local mid  = dom.element { tag = "section", children = { leaf } }
        local root = dom.element { tag = "page", children = { mid } }
        dom.walk(root, function() end)
        local a = dom.ancestors(leaf)
        assert.equal("section", a[1].tag)
        assert.equal("page",    a[2].tag)
    end)
end)

describe("pmui.stylesheet selector", function()
    local stylesheet
    setup(function()
        stylesheet = dofile("mainmenu/lib/pmui/stylesheet.lua")
    end)

    it("parses tag selector", function()
        local s = stylesheet.parse_selector("page")
        assert.equal(1, #s.simples)
        assert.equal("page", s.simples[1].tag)
    end)

    it("parses class selector", function()
        local s = stylesheet.parse_selector(".pack-card")
        assert.equal("pack-card", s.simples[1].classes[1])
    end)

    it("parses id selector", function()
        local s = stylesheet.parse_selector("#pack-grid")
        assert.equal("pack-grid", s.simples[1].id)
    end)

    it("parses tag.class with pseudo", function()
        local s = stylesheet.parse_selector("button.action-btn:hover")
        local sim = s.simples[1]
        assert.equal("button", sim.tag)
        assert.equal("action-btn", sim.classes[1])
        assert.equal("hover", sim.pseudo)
    end)

    it("parses descendant combinator", function()
        local s = stylesheet.parse_selector(".pack-card .name")
        assert.equal(2, #s.simples)
        assert.same({ " " }, s.combinators)
        assert.equal("pack-card", s.simples[1].classes[1])
        assert.equal("name", s.simples[2].classes[1])
    end)

    it("parses child combinator", function()
        local s = stylesheet.parse_selector(".card > .name")
        assert.equal(2, #s.simples)
        assert.equal(">", s.combinators[1])
    end)

    it("computes specificity", function()
        local s = stylesheet.parse_selector("#pack-grid .card:hover")
        local spec = stylesheet.specificity(s)
        assert.equal(1, spec.a)  -- 1 id
        assert.equal(2, spec.b)  -- 1 class + 1 pseudo
        assert.equal(0, spec.c)  -- no tag
    end)

    it("orders specificity by a > b > c", function()
        local low  = stylesheet.specificity(stylesheet.parse_selector("div"))
        local high = stylesheet.specificity(stylesheet.parse_selector(".x"))
        assert.is_true(stylesheet.compare_specificity(low, high))
    end)
end)

describe("pmui.stylesheet value parser", function()
    local stylesheet
    setup(function() stylesheet = dofile("mainmenu/lib/pmui/stylesheet.lua") end)

    it("parses literal color", function()
        local v = stylesheet.parse_value("#A06EFF")
        assert.equal("literal", v.type)
        assert.equal("#A06EFF", v.value)
    end)

    it("parses var()", function()
        local v = stylesheet.parse_value("var(--accent-pink)")
        assert.equal("var", v.type)
        assert.equal("--accent-pink", v.name)
    end)

    it("parses url() and strips quotes", function()
        local v = stylesheet.parse_value("url(packermod_bg.png)")
        assert.equal("url", v.type)
        assert.equal("packermod_bg.png", v.value)

        local q = stylesheet.parse_value("url(\"foo.png\")")
        assert.equal("foo.png", q.value)
    end)

    it("parses calc() as raw expression for later evaluation", function()
        local v = stylesheet.parse_value("calc(var(--space-md) + 0.5)")
        assert.equal("calc", v.type)
        assert.equal("var(--space-md) + 0.5", v.expr)
    end)

    it("parses number as literal", function()
        local v = stylesheet.parse_value(0.4)
        assert.equal("literal", v.type)
        assert.equal(0.4, v.value)
    end)
end)

describe("pmui.parser_html", function()
    local parser_html
    setup(function()
        _G.packermod = _G.packermod or {}
        parser_html = dofile("mainmenu/lib/pmui/parser_html.lua")
    end)

    it("parses a minimal root element", function()
        local yaml = [[
root:
  tag: page
  id: pack-library
  children:
    - tag: h1
      class: app-title
      text: "PackerMOD"
]]
        local el = parser_html.parse(yaml, {})
        assert.equal("page", el.tag)
        assert.equal("pack-library", el.id)
        assert.equal("h1", el.children[1].tag)
        assert.equal("PackerMOD", el.children[1].text)
        assert.equal("app-title", el.children[1].classes[1])
    end)

    it("resolves ${var} in text and attrs", function()
        local yaml = [[
root:
  tag: card
  attrs:
    name: "pack_${pack.id_slug}"
  children:
    - tag: span
      text: "${pack.name}"
]]
        local el = parser_html.parse(yaml, { pack = { id_slug = "abc", name = "Hello" } })
        assert.equal("pack_abc", el.attrs.name)
        assert.equal("Hello", el.children[1].text)
    end)

    it("expands for: { each, in: }", function()
        local yaml = [[
root:
  tag: grid
  children:
    - tag: card
      for:
        each: pack
        in: packs
      attrs:
        name: "card_${pack.id}"
      children:
        - tag: span
          text: "${pack.name}"
]]
        local ctx = { packs = { { id = "a", name = "AAA" }, { id = "b", name = "BBB" } } }
        local el = parser_html.parse(yaml, ctx)
        assert.equal("grid", el.tag)
        assert.equal(2, #el.children)
        assert.equal("card_a", el.children[1].attrs.name)
        assert.equal("AAA", el.children[1].children[1].text)
        assert.equal("card_b", el.children[2].attrs.name)
    end)

    it("skips children with when: falsy", function()
        local yaml = [[
root:
  tag: page
  children:
    - tag: span
      when: "${show}"
      text: visible
    - tag: span
      when: "${hide}"
      text: hidden
]]
        local el = parser_html.parse(yaml, { show = true, hide = false })
        assert.equal(1, #el.children)
        assert.equal("visible", el.children[1].text)
    end)

    it("splits space-separated class string", function()
        local yaml = [[
root:
  tag: div
  class: "alpha beta gamma"
]]
        local el = parser_html.parse(yaml, {})
        assert.same({ "alpha", "beta", "gamma" }, el.classes)
    end)
end)

describe("pmui.parser_css", function()
    local parser_css
    setup(function() parser_css = dofile("mainmenu/lib/pmui/parser_css.lua") end)

    it("parses variables block", function()
        local sheet = parser_css.parse([[
variables:
  --fg: "#fff"
  --space-md: 0.4
]])
        assert.equal("literal", sheet.vars["--fg"].type)
        assert.equal("#fff", sheet.vars["--fg"].value)
        assert.equal(0.4, sheet.vars["--space-md"].value)
    end)

    it("parses rules with selector + style", function()
        local sheet = parser_css.parse([[
rules:
  - selector: ".pack-card"
    style:
      bg: "var(--card-bg)"
      border-width: 1
  - selector: ".pack-card:hover"
    style:
      border-color: "var(--accent-pink)"
]])
        assert.equal(2, #sheet.rules)
        local r1 = sheet.rules[1]
        assert.equal("pack-card", r1.selectors[1].simples[1].classes[1])
        assert.equal("var",     r1.declarations["bg"].type)
        assert.equal("--card-bg", r1.declarations["bg"].name)
        assert.equal(1, r1.declarations["border-width"].value)
        local r2 = sheet.rules[2]
        assert.equal("hover", r2.selectors[1].simples[1].pseudo)
    end)

    it("parses media query block", function()
        local sheet = parser_css.parse([[
media:
  - query: "min-width 13.0"
    rules:
      - selector: ".card-grid"
        style:
          grid-columns: 3
]])
        assert.equal(1, #sheet.media)
        assert.equal("min-width", sheet.media[1].query.type)
        assert.equal(13.0, sheet.media[1].query.value)
        assert.equal(3, sheet.media[1].rules[1].declarations["grid-columns"].value)
    end)
end)
