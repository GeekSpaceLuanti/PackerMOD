package.path = "./?.lua;" .. package.path

describe("ui_loader.expand", function()
    local loader, theme
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        loader = dofile("mainmenu/lib/ui_loader.lua")
        theme = dofile("mainmenu/lib/theme.lua")
    end)

    it("expands a page into a VBox with theme bg", function()
        local tree = loader.expand({ page = { size = {w=10,h=5}, children = {} } }, {}, theme)
        assert.equal("VBox", tree._kind)
        assert.equal(theme.colors.bg, tree.bgcolor)
    end)

    it("expands a card with bg_panel", function()
        local tree = loader.expand({ card = { children = {} } }, {}, theme)
        assert.equal("VBox", tree._kind)
        assert.equal(theme.colors.bg_panel, tree.bgcolor)
    end)

    it("expands a section as header + children", function()
        local tree = loader.expand({
            section = {
                title = "Hi",
                children = { { label = { text = "x" } } },
            },
        }, {}, theme)
        assert.equal("VBox", tree._kind)
        assert.equal("Label", tree[1]._kind)
        assert.equal("Hi", tree[1].text)
        assert.equal("section", tree[1].style)
        assert.equal("Label", tree[2]._kind)
    end)

    it("expands actions with leading flex spacer", function()
        local tree = loader.expand({
            actions = {
                children = {
                    { button = { name = "a", label = "A" } },
                    { button = { name = "b", label = "B" } },
                },
            },
        }, {}, theme)
        assert.equal("HBox", tree._kind)
        assert.equal("Spacer", tree[1]._kind)
        assert.equal(1, tree[1].flex)
        assert.equal("Button", tree[2]._kind)
        assert.equal("a", tree[2].name)
        assert.equal("Button", tree[3]._kind)
    end)

    it("expands button with variant as style hint", function()
        local tree = loader.expand({
            button = { name = "play", label = "Play", variant = "primary" },
        }, {}, theme)
        assert.equal("Button", tree._kind)
        assert.equal("primary", tree.style)
    end)

    it("expands icon-button with texture resolved by ctx.icon_path", function()
        local tree = loader.expand({
            ["icon-button"] = { name = "play", icon = "play", label = "Play", variant = "primary" },
        }, {
            icon_path = function(name) return "packermod_icon_" .. name .. "_md.png" end,
        }, theme)
        assert.equal("IconButton", tree._kind)
        assert.equal("packermod_icon_play_md.png", tree.texture)
        assert.equal("Play", tree.label)
    end)

    it("expands list to a TextList (optionally inside a VBox)", function()
        local tree = loader.expand({
            list = { name = "x", items = { "a", "b" }, selected = 2, flex = 1 },
        }, {}, theme)
        local tl = (tree._kind == "TextList") and tree or tree[1]
        assert.equal("TextList", tl._kind)
        assert.equal("x", tl.name)
        assert.are.same({ "a", "b" }, tl.items)
        assert.equal(2, tl.selected)
    end)

    it("substitutes ${var} inline in strings", function()
        local tree = loader.expand({
            label = { text = "Hello, ${name}" },
        }, { name = "World" }, theme)
        assert.equal("Hello, World", tree.text)
    end)

    it("substitutes ${list | formatter}", function()
        local tree = loader.expand({
            list = { name = "x", items = "${packs | fmt}" },
        }, {
            packs = { "a", "b" },
            fmt = function(s) return s:upper() end,
        }, theme)
        local tl = (tree._kind == "TextList") and tree or tree[1]
        assert.are.same({ "A", "B" }, tl.items)
    end)

    it("skips a node when 'when' resolves to false", function()
        local tree = loader.expand({
            actions = {
                children = {
                    { button = { name = "a", label = "A" } },
                    { button = { name = "b", label = "B", when = "${has_b}" } },
                },
            },
        }, { has_b = false }, theme)
        assert.equal("HBox", tree._kind)
        assert.equal(2, #tree) -- spacer + 1 button
    end)

    it("expands status as a dim label", function()
        local tree = loader.expand({ status = "Loading..." }, {}, theme)
        assert.equal("Label", tree._kind)
        assert.equal("Loading...", tree.text)
        assert.equal("dim", tree.style)
    end)

    it("expands spacer with flex", function()
        local tree = loader.expand({ spacer = { flex = 1 } }, {}, theme)
        assert.equal("Spacer", tree._kind)
        assert.equal(1, tree.flex)
    end)

    it("expands row/col", function()
        local r = loader.expand({
            row = { children = { { button = { name = "a", label = "A" } } } },
        }, {}, theme)
        assert.equal("HBox", r._kind)
        local c = loader.expand({
            col = { children = { { button = { name = "a", label = "A" } } } },
        }, {}, theme)
        assert.equal("VBox", c._kind)
    end)

    it("expands field with default substitution", function()
        local tree = loader.expand({
            field = { name = "q", label = "Query", default = "${q_default}" },
        }, { q_default = "hello" }, theme)
        assert.equal("Field", tree._kind)
        assert.equal("hello", tree.default)
    end)
end)

describe("ui_loader.load", function()
    local loader, theme
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        loader = dofile("mainmenu/lib/ui_loader.lua")
        theme = dofile("mainmenu/lib/theme.lua")
    end)

    it("loads YAML content directly into a PMLayout tree", function()
        local content = "page:\n  size:\n    w: 10\n    h: 5\n  children:\n    - label:\n        text: hello\n"
        local tree = loader.load({ content = content, ctx = {}, theme = theme })
        assert.equal("VBox", tree._kind)
    end)
end)
