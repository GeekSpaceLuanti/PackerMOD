local L = dofile("mainmenu/lib/layout.lua")
describe("automatic flow layout", function()
    it("wraps horizontal actions without shrinking click targets", function()
        local row = L.HBox { spacing = 0.3,
            L.Button { name = "first", w = 5, h = 1 },
            L.Button { name = "second", w = 5, h = 1 },
            L.Button { name = "third", w = 5, h = 1 } }
        local elements = L.iter_elements(row, { w = 11, h = 5, auto_flow = true })
        assert.equal(elements[1].y, elements[2].y)
        assert.is_true(elements[3].y > elements[1].y)
        for _, el in ipairs(elements) do assert.equal(5, el.w) end
    end)
    it("makes overflowing content scrollable and preserves its controls", function()
        local root = L.VBox { L.Field { name = "name", w = 9 },
            L.TextArea { name = "description", w = 9, h = 6 },
            L.Button { name = "save", w = 5 } }
        local options = { w = 8, h = 4, auto_flow = true, scroll_value = 12 }
        local fs = L.build_formspec(root, options)
        assert.is_truthy(fs:find("scroll_container[", 1, true))
        assert.is_truthy(fs:find("pm_flow_scroll;12]", 1, true))
        assert.is_truthy(fs:find(";save;", 1, true))
        assert.equal(fs, L.build_formspec(root, options))
        assert.is_nil(L.build_formspec(root, { w = 12, h = 20, auto_flow = true }):find("scroll_container[", 1, true))
    end)
    it("wraps long text and constrains its width", function()
        local elements = L.iter_elements(L.VBox { L.Label { text = string.rep("text ", 30) } },
            { w = 7, h = 20, auto_flow = true })
        assert.equal("Paragraph", elements[1].kind)
        assert.is_true(elements[1].w <= 7)
        assert.is_true(elements[1].h > 0.5)
    end)
    it("caps the viewport using the engine DPI-aware bounds", function()
        local before = _G.core
        _G.core = { get_window_info = function() return {
            size = { x = 3000, y = 1800 }, max_formspec_size = { x = 18, y = 10 } } end }
        local ok, err = pcall(function()
            local prefs = dofile("mainmenu/ui_preferences.lua")
            local w, h = prefs.viewport(30, 16)
            assert.is_true(w <= 17.5)
            assert.is_true(h <= 9.5)
            local fw, fh = prefs.viewport(30, 16, true)
            assert.equal(30, fw)
            assert.equal(16, fh)
        end)
        _G.core = before
        assert.is_true(ok, err)
    end)
    it("reserves usable height for populated fluid lists", function()
        local els = L.iter_elements(L.VBox { L.TextList { name = "mods", flex = 1, items = { "a", "b" } } },
            { w = 10, h = 5, auto_flow = true })
        assert.is_true(els[1].h >= 1.6)
    end)
end)
