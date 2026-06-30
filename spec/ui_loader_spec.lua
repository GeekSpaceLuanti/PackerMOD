-- ui_loader は旧 DSL の expand パイプラインを撤去 (commit 8) し、
-- 現在は resolve_value / resolve_path のみを提供する薄いモジュール。
-- PMUI の parser_html がこれを再利用する。

package.path = "./?.lua;" .. package.path

describe("ui_loader.resolve_value", function()
    local loader
    setup(function()
        loader = dofile("mainmenu/lib/ui_loader.lua")
    end)

    it("returns non-string values as-is", function()
        assert.equal(42, loader.resolve_value(42, {}))
        assert.is_true(loader.resolve_value(true, {}))
        local t = { 1, 2 }; assert.equal(t, loader.resolve_value(t, {}))
    end)

    it("full match ${name} preserves the resolved value type", function()
        assert.equal(7,   loader.resolve_value("${n}",  { n = 7 }))
        assert.is_true(   loader.resolve_value("${b}",  { b = true }))
        local lst = { "a", "b" }
        assert.same(lst,  loader.resolve_value("${lst}", { lst = lst }))
    end)

    it("partial substitution interpolates as string", function()
        assert.equal("v=42 ok",
            loader.resolve_value("v=${x} ok", { x = 42 }))
    end)

    it("dotted paths drill into nested tables", function()
        assert.equal("World", loader.resolve_value("${a.b.c}", { a = { b = { c = "World" } } }))
    end)

    it("pipe form ${list | fmt} maps the list through fmt", function()
        local out = loader.resolve_value("${items | f}", {
            items = { { name = "x" }, { name = "y" } },
            f = function(m) return m.name end,
        })
        assert.same({ "x", "y" }, out)
    end)

    it("missing variables become empty string in partial substitution", function()
        assert.equal("[]", loader.resolve_value("[${missing}]", {}))
    end)
end)
