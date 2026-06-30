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
        assert.are.equal("pack_select_my_pack",   lib._internal.pack_button_name("my_pack"))
        assert.are.equal("pack_select_my_pack",   lib._internal.pack_button_name("my-pack"))
        assert.are.equal("pack_select_a_b_c",     lib._internal.pack_button_name("a.b.c"))
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

    it("renders pack cards and action bar with Synthwave background", function()
        local fs = lib._internal.build_grid_formspec({})
        assert.is_string(fs)
        assert.is_truthy(fs:find("pack_select_pack_a", 1, true))
        assert.is_truthy(fs:find("Pack A", 1, true))
        assert.is_truthy(fs:find("btn_import", 1, true))
        assert.is_truthy(fs:find("btn_create", 1, true))
        assert.is_truthy(fs:find("btn_settings", 1, true))
        -- Synthwave テーマの背景画像と PackerMOD タイトルが出ていること
        assert.is_truthy(fs:find("packermod_bg_synthwave.png", 1, true))
        assert.is_truthy(fs:find("PackerMOD", 1, true))
    end)

    it("has no overlap and fits in page size", function()
        local fs = lib._internal.build_grid_formspec({})
        local size, els = helpers.parse_formspec(fs)
        assert.equal(30.0, size.w)
        assert.equal(16.0, size.h)
        local overlaps = helpers.find_overlaps(els)
        if #overlaps > 0 then
            error(helpers.format_overlaps(overlaps))
        end
        local ok, bad = helpers.fits_in_size(els, size)
        assert.is_true(ok, "OOB: " .. (bad and helpers.describe_el(bad) or ""))
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

    for _, subtab in ipairs({ "worlds", "multi", "mods", "info" }) do
        it("pmui detail " .. subtab .. " renders without overlap/OOB", function()
            local fs = pmui_fs(subtab)
            assert.is_string(fs)
            assert.is_truthy(fs:find("Pack A", 1, true))         -- title
            assert.is_truthy(fs:find("btn_back", 1, true))        -- Back button
            assert.is_truthy(fs:find("subtab_worlds", 1, true))   -- subtab buttons
            assert.is_truthy(fs:find("packermod_bg_synthwave.png", 1, true))  -- bg

            local size, els = helpers.parse_formspec(fs)
            assert.equal(30.0, size.w)
            assert.equal(16.0, size.h)
            local overlaps = helpers.find_overlaps(els, { label_h = 0.45 })
            if #overlaps > 0 then
                error("overlap in " .. subtab .. ":\n" .. helpers.format_overlaps(overlaps))
            end
            local ok, bad = helpers.fits_in_size(els, size, { label_h = 0.45 })
            assert.is_true(ok, "OOB in " .. subtab .. ": " ..
                (bad and helpers.describe_el(bad) or ""))
        end)
    end
end)

-- 旧 library.yml / modal_*.yml は commit 8 で撤去済み。各画面の overlap/OOB
-- regression は spec/modals_spec.lua と本ファイル上部の PMUI describe で担保。
