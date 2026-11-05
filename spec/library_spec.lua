package.path = "./?.lua;" .. package.path

-- library.lua の純粋ロジック部分(_internal)と、library.yml(画面2 = detail)が
-- ui_loader でエラーなく展開できることのテスト。
-- 画面1(grid)は動的なアイテム数を持つので library.lua 内で直接構築される。

local function load_library()
    return dofile("mainmenu/library.lua")
end

describe("library._internal helpers", function()
    local lib
    setup(function() lib = load_library() end)

    it("format_world_label uses display_name when given", function()
        assert.are.equal("My World",
            lib._internal.format_world_label({ name = "raw", display_name = "My World" }))
        assert.are.equal("raw",
            lib._internal.format_world_label({ name = "raw" }))
    end)

    it("format_world_label prefixes [legacy] for legacy flat worlds", function()
        assert.are.equal("[legacy] Old Save",
            lib._internal.format_world_label({ name = "x", display_name = "Old Save", legacy = true }))
    end)

    it("subtab_variant returns 'primary' for active, 'secondary' otherwise", function()
        assert.are.equal("primary",  lib._internal.subtab_variant("worlds", "worlds"))
        assert.are.equal("secondary", lib._internal.subtab_variant("worlds", "multi"))
    end)

    it("pack_button_name produces alphanumeric formspec name", function()
        assert.are.equal("pack_select_my_5fpack", lib._internal.pack_button_name("my_pack"))
        assert.are.equal("pack_select_my_2dpack", lib._internal.pack_button_name("my-pack"))
        assert.are.equal("pack_select_a_2eb_2ec", lib._internal.pack_button_name("a.b.c"))
    end)

    it("resolve_thumbnail returns default when manifest has no thumbnail", function()
        local p = { id = "p", path = "/u/p", manifest = { name = "P" } }
        local t = lib._internal.resolve_thumbnail(p)
        assert.is_truthy(t:find("default_pack_thumbnail", 1, true))
    end)

    it("resolve_thumbnail returns pack-relative path when manifest.thumbnail is set", function()
        local p = { id = "p", path = "/u/p", manifest = { name = "P", thumbnail = "thumb.png" } }
        assert.are.equal("/u/p/thumb.png", lib._internal.resolve_thumbnail(p))
    end)

    describe("clamp_selection", function()
        local clamp
        setup(function() clamp = lib._internal.clamp_selection end)
        it("returns 1 on empty list", function() assert.are.equal(1, clamp(5, 0)) end)
        it("clamps to max", function() assert.are.equal(3, clamp(99, 3)) end)
        it("clamps to 1 on negative or nil", function()
            assert.are.equal(1, clamp(-3, 5))
            assert.are.equal(1, clamp(nil, 5))
        end)
        it("passes through in-range value", function() assert.are.equal(2, clamp(2, 5)) end)
    end)

    describe("format_server_label", function()
        local f
        setup(function() f = lib._internal.format_server_label end)
        it("includes name and address when name given", function()
            local s = f({ name = "Home", address = "1.2.3.4", port = 30000 })
            assert.is_truthy(s:find("Home", 1, true))
            assert.is_truthy(s:find("1.2.3.4", 1, true))
        end)
        it("appends port when non-default", function()
            local s = f({ name = "Home", address = "1.2.3.4", port = 30001 })
            assert.is_truthy(s:find(":30001", 1, true))
        end)
        it("omits port when default 30000", function()
            local s = f({ name = "Home", address = "1.2.3.4", port = 30000 })
            assert.is_nil(s:find(":30000", 1, true))
        end)
        it("returns only address when name is empty", function()
            local s = f({ name = "", address = "host" })
            assert.are.equal("host", s)
        end)
    end)

    describe("build_server_from_form", function()
        it("rejects zero, negative, fractional and out-of-range ports", function()
            for _, port in ipairs({ "0", "-1", "1.5", "65536", "inf" }) do
                assert.is_nil(lib._internal.build_server_from_form({ address = "localhost", port = port }))
            end
            for _, port in ipairs({ "1", "65535" }) do
                assert.equal(tonumber(port), lib._internal.build_server_from_form({ address = "localhost", port = port }).port)
            end
        end)
        local f
        setup(function() f = lib._internal.build_server_from_form end)
        it("rejects empty address", function()
            local r, err = f({ address = "" })
            assert.is_nil(r)
            assert.is_truthy(err:find("Address"))
        end)
        it("rejects non-numeric port", function()
            local r, err = f({ address = "a.b", port = "abc" })
            assert.is_nil(r)
            assert.is_truthy(err:find("Port"))
        end)
        it("defaults port to 30000 when blank", function()
            local r = f({ address = "a.b" })
            assert.are.equal(30000, r.port)
        end)
        it("trims whitespace on name and address", function()
            local r = f({ name = "  X  ", address = "  a.b  ", port = "30005" })
            assert.are.equal("X", r.name)
            assert.are.equal("a.b", r.address)
            assert.are.equal(30005, r.port)
        end)
    end)
end)

-- ---- 画面1 (grid view) は library.lua 内で PMUI を呼んで構築する。
describe("library grid view (画面1)", function()
    local lib, theme, helpers
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        packermod.yaml = dofile("mainmenu/yaml.lua")
        packermod.theme = dofile("mainmenu/lib/theme.lua")
        packermod.icons = dofile("mainmenu/lib/icons.lua")
        packermod.pmui = dofile("mainmenu/lib/pmui/init.lua")
        packermod.mainmenu_path = "mainmenu/"
        packermod.pack_manager = {
            list_packs = function()
                return {
                    { id = "pack_a", path = "/u/pack_a",
                      manifest = { name = "Pack A", version = "1.0",
                                   base_game = { id = "packerbase", version = "0.91" } } },
                    { id = "pack_b", path = "/u/pack_b",
                      manifest = { name = "Pack B", version = "2.0",
                                   base_game = { id = "packerbase", version = "0.91" } } },
                }
            end,
        }
        packermod.user_path = "/u"
        packermod.manifest = {}
        theme = packermod.theme
        helpers = dofile("spec/support/formspec_helpers.lua")
        lib = dofile("mainmenu/library.lua")
    end)

    it("renders pack cards and action bar with clean dark theme", function()
        local fs = lib._internal.build_grid_formspec({})
        assert.is_string(fs)
        assert.is_truthy(fs:find("pack_select_pack_5fa", 1, true))
        assert.is_truthy(fs:find("Pack A", 1, true))
        assert.is_truthy(fs:find("btn_import", 1, true))
        assert.is_truthy(fs:find("btn_create", 1, true))
        assert.is_truthy(fs:find("btn_settings", 1, true))
        -- Synthwave テーマの背景画像と PackerMOD タイトルが出ていること
        assert.is_truthy(fs:find("#101418", 1, true))
        assert.is_truthy(fs:find("PackerMOD", 1, true))
    end)

    it("has no overlap and fits in page size", function()
        local fs, meta = lib._internal.build_grid_formspec({})
        local size, els = helpers.parse_formspec(fs)
        assert.is_true(size.w>0 and size.h>0)
        assert.same({},packermod.pmui.modern.layout.validate(meta.tree))
        local controls={};for _,el in ipairs(els)do if el.kind=="button" or el.kind=="field" then controls[#controls+1]=el end end
        local ok, bad = helpers.fits_in_size(controls, size)
        assert.is_true(ok, "OOB: " .. (bad and helpers.describe_el(bad) or ""))
    end)

    for _, count in ipairs({ 0, 1, 3, 4, 6, 7, 13 }) do
        it("keeps " .. count .. " packs within the page", function()
            local original = packermod.pack_manager.list_packs
            packermod.pack_manager.list_packs = function()
                local packs = {}
                for i = 1, count do
                    packs[i] = { id = "p" .. i, path = "/p" .. i,
                        manifest = { name = "Pack " .. i,
                            base_game = { id = "base", version = "1" } } }
                end
                return packs
            end
            local data = {}
            local fs, meta = lib._internal.build_grid_formspec(data)
            local size, els = helpers.parse_formspec(fs)
            local controls={};for _,el in ipairs(els)do if el.kind=="button" or el.kind=="field" then controls[#controls+1]=el end end
            local fits, bad = helpers.fits_in_size(controls, size)
            packermod.pack_manager.list_packs = original
            assert.is_true(fits, bad and helpers.describe_el(bad))
            assert.same({},packermod.pmui.modern.layout.validate(meta.tree))
            assert.equal(math.max(1, math.ceil(count / 6)), data.page_count)
            if count > 6 then
                assert.is_nil(fs:find(";pack_select_p7;", 1, true))
            end
        end)
    end

    it("uses distinct buttons for hyphen and underscore Pack IDs", function()
        local name = lib._internal.pack_button_name
        assert.are_not.equal(name("my-pack"), name("my_pack"))
        assert.are_not.equal(name("my-pack"), name("my_2dpack"))
        local first, selected = { id = "my_2dpack" }, { id = "my-pack" }
        assert.equal(selected, lib._internal.find_pack_by_button(
            { [name(selected.id)] = true }, { first, selected }))
    end)
end)

-- ---- PMUI 経由の画面2 (Pack Detail) smoke test ----
describe("library detail view PMUI (画面2)", function()
    local lib, helpers
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        packermod.yaml   = dofile("mainmenu/yaml.lua")
        packermod.theme  = dofile("mainmenu/lib/theme.lua")
        packermod.icons  = dofile("mainmenu/lib/icons.lua")
        packermod.ui_loader = dofile("mainmenu/lib/ui_loader.lua")
        packermod.pmui  = dofile("mainmenu/lib/pmui/init.lua")
        packermod.mainmenu_path = "mainmenu/"
        packermod.user_path = "/u"
        packermod.manifest = {}

        local pack = {
            id = "pack_a", path = "/u/pack_a",
            manifest = {
                name = "Pack A", version = "1.0",
                base_game = { id = "packerbase", version = "0.91" },
                mods = {},
            },
        }
        packermod.pack_manager = {
            list_packs = function() return { pack } end,
        }
        packermod.launcher = {
            list_worlds = function() return {} end,
            list_legacy_worlds = function() return {} end,
            list_servers = function() return {} end,
        }
        helpers = dofile("spec/support/formspec_helpers.lua")
        lib = dofile("mainmenu/library.lua")
    end)

    local function pmui_fs(subtab)
        local tabdata = {
            selected_pack_id = "pack_a",
            subtab = subtab,
        }
        return lib._internal.build_detail_formspec(tabdata)
    end

    it("empty worlds shows creation without an empty list or pack deletion", function()
        local fs = pmui_fs("worlds")
        assert.is_truthy(fs:find("new_world", 1, true))
        assert.is_nil(fs:find("textlist[", 1, true))
        assert.is_nil(fs:find("delete_pack", 1, true))
        assert.is_truthy(pmui_fs("info"):find("delete_pack", 1, true))
    end)

    it("keeps every detail tab within DPI-limited windows and scrolls overflow", function()
        local saved_core = _G.core
        local ok, err = pcall(function()
            for _, bounds in ipairs({ { 16, 10 }, { 24, 9 }, { 12, 18 } }) do
                _G.core = { get_window_info = function() return {
                    size = { x = 3000, y = 1800 },
                    max_formspec_size = { x = bounds[1], y = bounds[2] } } end }
                for _, tab in ipairs({ "worlds", "multi", "mods", "info" }) do
                    local fs, meta = pmui_fs(tab)
                    local size, elements = helpers.parse_formspec(fs)
                    assert.is_true(size.w < bounds[1] and size.h < bounds[2])
                    assert.same({}, dofile("mainmenu/lib/pmui/modern/layout.lua").validate(meta.tree))
                    local controls = {}
                    for _, el in ipairs(elements) do if el.kind == "button" or el.kind == "field" or el.kind == "textarea" then controls[#controls+1] = el end end
                    local fits, bad = helpers.fits_in_size(controls, size)
                    assert.is_true(fits, tab .. ": " .. (bad and helpers.describe_el(bad) or ""))
                    assert.is_truthy(fs:find("new_world", 1, true) or tab ~= "worlds")
                    if tab == "info" then
                        assert.is_truthy(fs:find("info_save", 1, true))
                        assert.is_truthy(fs:find("delete_pack", 1, true))
                    end
                end
            end
        end)
        _G.core = saved_core
        assert.is_true(ok, err)
    end)

    for _, subtab in ipairs({ "worlds", "multi", "mods", "info" }) do
        it("pmui detail " .. subtab .. " renders without overlap/OOB", function()
            local fs, meta = pmui_fs(subtab)
            assert.is_string(fs)
            assert.is_truthy(fs:find("Pack A", 1, true))         -- title
            assert.is_truthy(fs:find("btn_back", 1, true))        -- Back button
            assert.is_truthy(fs:find("subtab_worlds", 1, true))   -- subtab buttons
            assert.is_truthy(fs:find("#101418", 1, true))  -- bg

            local size, els = helpers.parse_formspec(fs)
            assert.is_true(size.w > 0 and size.w < 19.2)
            assert.is_true(size.h > 0 and size.h < 14.4)
            assert.same({}, dofile("mainmenu/lib/pmui/modern/layout.lua").validate(meta.tree))
            local controls = {}
            for _, el in ipairs(els) do if el.kind == "button" or el.kind == "field" or el.kind == "textarea" then controls[#controls+1] = el end end
            local ok, bad = helpers.fits_in_size(controls, size)
            assert.is_true(ok, "OOB in " .. subtab .. ": " ..
                (bad and helpers.describe_el(bad) or ""))
        end)
    end
end)

-- 旧 library.yml / modal_*.yml は commit 8 で撤去済み。各画面の overlap/OOB
-- regression は spec/modals_spec.lua と本ファイル上部の PMUI describe で担保。
