-- Layout regression: parse the formspec string each tab emits, build AABB rectangles,
-- and assert no two rectangles overlap (with labels expanded to a realistic height).
-- Also verifies the buggy pre-refactor Create snapshot still flags overlaps -- that
-- guards the detector itself against regressions.

local helpers = dofile("spec/support/formspec_helpers.lua")
local escape_min = helpers.escape_min

local function setup_mocks()
    _G.core = _G.core or {}
    core.formspec_escape         = escape_min
    core.explode_textlist_event  = function() return { type = "INV", index = 0 } end
    core.get_version             = function() return { string = "5.16.1" } end
    core.get_builtin_path        = function() return "/tmp/_builtin/" end
    core.get_texturepath_share   = function() return "/tmp/_tex" end
    core.get_user_path           = function() return "/tmp/_user" end
    core.is_debug_build          = false
    core.settings                = { set = function() end, get = function() return nil end }
    core.sound_play              = function() end
    core.set_topleft_text        = function() end
    core.close                   = function() end
    _G.DIR_DELIM = _G.DIR_DELIM or "/"
    _G.PACKERMOD_VERSION = _G.PACKERMOD_VERSION or "0.1.0"
    _G.PACKERMOD_TAB_W = _G.PACKERMOD_TAB_W or 15.5
    _G.PACKERMOD_TAB_H = _G.PACKERMOD_TAB_H or 8.0
    _G.packermod = _G.packermod or {}
    packermod.user_path = "/tmp/_user"
    packermod.pack_manager = packermod.pack_manager or {
        list_packs = function() return {} end,
    }
    packermod.layout = packermod.layout or dofile("mainmenu/lib/layout.lua")
    packermod.theme  = packermod.theme  or dofile("mainmenu/lib/theme.lua")
    packermod.icons  = packermod.icons  or dofile("mainmenu/lib/icons.lua")
    packermod.ui_loader = packermod.ui_loader or dofile("mainmenu/lib/ui_loader.lua")
end

local parse_formspec  = helpers.parse_formspec
local find_overlaps   = helpers.find_overlaps
local fits_in_size    = helpers.fits_in_size
local describe_el     = helpers.describe_el
local format_overlaps = helpers.format_overlaps

describe("formspec layout", function()
    setup(setup_mocks)

    describe("flex distribution", function()
        local L
        setup(function() L = dofile("mainmenu/lib/layout.lua") end)

        it("HBox child with flex grows to fill leftover width", function()
            local root = L.HBox{ spacing = 0,
                L.Button{name="a", label="A", w=2, h=1},
                L.Spacer{flex = 1},
                L.Button{name="b", label="B", w=2, h=1},
            }
            local els = L.iter_elements(root, { w = 10, h = 1 })
            assert.equal(2, #els)
            assert.equal(0, els[1].x)
            assert.equal(8, els[2].x) -- 10 - 2 = 8
        end)

        it("splits leftover space by flex ratio", function()
            local root = L.HBox{ spacing = 0,
                L.Spacer{flex = 1},
                L.Button{name="m", label="M", w=2, h=1},
                L.Spacer{flex = 3},
            }
            local els = L.iter_elements(root, { w = 10, h = 1 })
            -- leftover = 10 - 2 = 8; ratio 1:3 → spacer1 = 2, spacer2 = 6
            -- button sits at x = 2
            assert.equal(1, #els)
            assert.is_true(math.abs(els[1].x - 2) < 1e-6)
        end)

        it("VBox flex stretches a child vertically", function()
            local root = L.VBox{ spacing = 0,
                L.Label{text = "top",    w = 5, h = 0.5},
                L.TextList{name = "mid", items = {}, w = 5, flex = 1},
                L.Label{text = "bot",    w = 5, h = 0.5},
            }
            local els = L.iter_elements(root, { w = 5, h = 10 })
            -- bot label sits at y = 10 - 0.5 = 9.5
            assert.equal(3, #els)
            assert.is_true(math.abs(els[3].y - 9.5) < 1e-6)
            -- textlist now spans the available 10 - 0.5 - 0.5 = 9
            assert.is_true(math.abs(els[2].h - 9) < 1e-6)
        end)

        it("leaves non-flex children at natural size when there's no leftover", function()
            local root = L.HBox{ spacing = 0,
                L.Button{name="a", label="A", w=4, h=1},
                L.Button{name="b", label="B", w=4, h=1},
            }
            local els = L.iter_elements(root, { w = 8, h = 1 })
            assert.equal(0, els[1].x)
            assert.equal(4, els[2].x)
        end)
    end)

    describe("Field reserves vertical space for its label", function()
        local L
        setup(function() L = dofile("mainmenu/lib/layout.lua") end)

        it("includes the on-top label band in the field's effective height", function()
            -- formspec v6 prints the field `label` ABOVE the box (Luanti
            -- lua_api.md 'top left above the field'). Reserving 0 px there
            -- lets the next row's label bleed into this row's box.
            local field = L.Field{name="x", label="X", w=3, h=0.7}
            L.iter_elements(L.VBox{ field })
            assert.is_true(field.h > 0.7, "label-bearing field should reserve > 0.7 units of height")
        end)

        it("packs two labeled fields without their labels colliding", function()
            local root = L.VBox{ spacing = 0.2,
                L.Field{name="a", label="A label", w=3, h=0.7},
                L.Field{name="b", label="B label", w=3, h=0.7},
            }
            local els = L.iter_elements(root, { w = 3, h = 5 })
            -- The second field's y must clear the first field's effective bottom.
            assert.is_true(els[2].y >= els[1].y + els[1].h,
                ("field b at y=%g vs field a bottom at y=%g"):format(els[2].y, els[1].y + els[1].h))
        end)

        it("emits the field box below the label band, not at the declared y", function()
            local root = L.VBox{ L.Field{name="a", label="A", w=3, h=0.7} }
            local fs = L.build_formspec(root, { w = 3, h = 2, version = 6 })
            -- After header `formspec_version[6]size[3,2]`, the field y should
            -- be > 0 (offset by the label band).
            local y = tonumber(fs:match("field%[%d+%.?%d*,([%d.]+);"))
            assert.is_true(y and y > 0, "field box y should be offset below 0 to leave room for the label")
        end)
    end)

    describe("TextArea (#13)", function()
        local L
        setup(function() L = dofile("mainmenu/lib/layout.lua") end)

        it("emits textarea[X,Y;W,H;name;label;default] with label band offset", function()
            local root = L.VBox{ L.TextArea{name="d", label="Desc", default="hello\nworld", w=5, h=2} }
            local fs = L.build_formspec(root, { w = 5, h = 4, version = 6 })
            local x, y, w, h, name, label, default =
                fs:match("textarea%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+);([^;]*);([^%]]*)%]")
            assert.equal("d", name)
            assert.equal("Desc", label)
            assert.is_truthy(default:find("hello", 1, true))
            assert.is_truthy(default:find("world", 1, true))
            assert.is_true(tonumber(y) > 0, "textarea y should be offset below label band")
            assert.is_true(math.abs(tonumber(w) - 5) < 1e-6)
            assert.is_true(math.abs(tonumber(h) - 2) < 1e-6)
        end)

        it("reserves vertical space for its label like Field does", function()
            local ta = L.TextArea{name="d", label="Desc", w=4, h=2}
            L.iter_elements(L.VBox{ ta })
            assert.is_true(ta.h > 2, "label-bearing textarea should reserve > 2 units of height")
        end)
    end)

    describe("AABB detector", function()
        it("flags overlapping rectangles", function()
            local hits = find_overlaps({
                { kind = "button", x = 0, y = 0, w = 1, h = 1 },
                { kind = "button", x = 0.5, y = 0.5, w = 1, h = 1 },
            })
            assert.equal(1, #hits)
        end)

        it("treats touching rectangles as non-overlap", function()
            local hits = find_overlaps({
                { kind = "button", x = 0, y = 0, w = 1, h = 1 },
                { kind = "button", x = 1, y = 0, w = 1, h = 1 },
            })
            assert.equal(0, #hits)
        end)

        it("counts label visual height against neighbouring fields", function()
            local hits = find_overlaps({
                { kind = "label",  x = 0, y = 2.2, text = "Section" },
                { kind = "field",  x = 0, y = 2.5, w = 3, h = 0.7,  name = "q" },
            }, { label_h = 0.5 })
            assert.equal(1, #hits)
        end)
    end)

    describe("regression detector self-check", function()
        -- Snapshot of the pre-refactor Create tab. Kept literal so the detector
        -- keeps fingerprinting the bug pattern even after the live tab is rewritten.
        local broken_snapshot = table.concat({
            "formspec_version[6]",
            "size[15.5,7.1]",
            "label[0.3,2.2;ContentDB search]",
            "field[0.3,2.5;5.5,0.7;search_query;Query;]",
            "field[5.9,2.5;1.5,0.7;search_release;Release id;]",
            "button[7.5,2.5;1.5,0.7;search;Search]",
            "button[9.1,2.5;1.5,0.7;add_search;Add]",
            "label[9.5,2.2;Current mods]",
            "textlist[9.5,2.5;5.7,2.9;mod_list;;0;false]",
            "button[9.5,5.5;2.0,0.7;remove_mod;Remove]",
            "button[12.0,5.5;3.2,0.7;export;Export manifest]",
            "label[0.3,5.5;long status overflowing into the buttons]",
        }, "")

        it("flags the original Create-tab overlap pattern", function()
            local _, elements = parse_formspec(broken_snapshot)
            local overlaps = find_overlaps(elements, { label_h = 0.5 })
            -- Known overlaps in the original layout:
            --   ContentDB search label vs Query field
            --   Current mods   label vs mod_list
            --   Add            button vs mod_list textlist (x ranges cross)
            --   status         label  vs Remove / Export buttons (same y, long text)
            assert.is_true(#overlaps >= 3,
                ("expected at least 3 overlaps in the broken snapshot, got %d"):format(#overlaps))
        end)
    end)

    -- Phase 12: 旧 tabs/tab_*.lua + ui/tab_*.yml は削除済み。
    -- 同等の overlap / out-of-bounds 検査は library_spec.lua / 各 modal の
    -- 描画テストでカバー(packermod global を組み立てた状態で ui_loader を
    -- 呼ぶ形)。

    describe("theme rendering", function()
        local L, theme
        setup(function()
            L = dofile("mainmenu/lib/layout.lua")
            theme = dofile("mainmenu/lib/theme.lua")
        end)

        it("emits the same formspec as before when theme is omitted", function()
            local root = L.VBox{ L.Button{name="a", label="A"} }
            local without = L.build_formspec(root, { w = 5, h = 2, version = 6 })
            assert.is_falsy(without:find("style_type[", 1, true))
            assert.is_falsy(without:find("bgcolor[",   1, true))
        end)

        it("prepends global style_type + bgcolor when theme is given", function()
            local root = L.VBox{ L.Button{name="a", label="A"} }
            local fs = L.build_formspec(root, { w = 5, h = 2, version = 6, theme = theme })
            assert.is_truthy(fs:find("style_type[button", 1, true))
            assert.is_truthy(fs:find("style_type[field",  1, true))
            assert.is_truthy(fs:find("bgcolor[",          1, true))
        end)

        it("emits per-widget style[] for buttons with a variant", function()
            local root = L.VBox{ L.Button{name="play", label="Play", style="primary"} }
            local fs = L.build_formspec(root, { w = 5, h = 2, version = 6, theme = theme })
            assert.is_truthy(fs:find("style[play;", 1, true),
                "expected style[play;...] for primary-variant button")
            assert.is_truthy(fs:find("bgcolor=#3FA63F", 1, true),
                "expected primary bgcolor in style[]")
        end)

        it("emits per-widget style[] for labels with a variant", function()
            local root = L.VBox{ L.Label{text="Heading", name="hd", style="section"} }
            local fs = L.build_formspec(root, { w = 5, h = 2, version = 6, theme = theme })
            assert.is_truthy(fs:find("style[hd;", 1, true))
            assert.is_truthy(fs:find("textcolor=#55FF55", 1, true))
        end)

        it("preserves user prepend after theme prelude", function()
            local root = L.VBox{ L.Button{name="a", label="A"} }
            local fs = L.build_formspec(root, {
                w = 5, h = 2, version = 6, theme = theme,
                prepend = { "real_coordinates[true]" },
            })
            local prelude_end = fs:find("bgcolor[", 1, true)
            local user_at    = fs:find("real_coordinates[true]", 1, true)
            assert.is_truthy(user_at)
            assert.is_truthy(prelude_end)
            assert.is_true(user_at > prelude_end,
                "user prepend must come after theme prelude")
        end)
    end)

    describe("Icon and IconButton widgets", function()
        local L
        setup(function() L = dofile("mainmenu/lib/layout.lua") end)

        it("Icon renders as image[]", function()
            local root = L.VBox{ L.Icon{texture="foo.png", w=1, h=1} }
            local fs = L.build_formspec(root, { w = 2, h = 2, version = 6 })
            assert.is_truthy(fs:find("image[", 1, true))
            assert.is_truthy(fs:find("foo.png", 1, true))
        end)

        it("IconButton renders as image_button[]", function()
            local root = L.VBox{ L.IconButton{name="go", texture="foo.png", label="Go", w=1, h=1} }
            local fs = L.build_formspec(root, { w = 2, h = 2, version = 6 })
            assert.is_truthy(fs:find("image_button[", 1, true))
            assert.is_truthy(fs:find("foo.png", 1, true))
            assert.is_truthy(fs:find(";go;", 1, true))
        end)

        it("Icon and IconButton have natural size (don't stretch)", function()
            -- Inside a stretch VBox, leaf icon widgets should keep their natural size.
            local root = L.VBox{ align = "stretch",
                L.Icon{texture="x.png", w=0.7, h=0.7},
                L.IconButton{name="b", texture="x.png", label="", w=0.7, h=0.7},
            }
            local els = L.iter_elements(root, { w = 5, h = 5 })
            assert.equal(0.7, els[1].w)
            assert.equal(0.7, els[2].w)
        end)
    end)
end)
