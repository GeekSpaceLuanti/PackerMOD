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

describe("library.yml (detail view) expansion via ui_loader", function()
    local loader, theme
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        packermod.yaml = dofile("mainmenu/yaml.lua")
        loader = dofile("mainmenu/lib/ui_loader.lua")
        theme = dofile("mainmenu/lib/theme.lua")
    end)

    local function build_ctx(overrides)
        local c = {
            pack_name = "TestPack", pack_version = "1.0",
            pack_base = "packerbase/0.91",
            pack_mods_count = 0, pack_description = "",
            variant_worlds = "primary", variant_multi = "secondary",
            variant_mods = "secondary", variant_info = "secondary",
            show_worlds = true, show_multi = false, show_mods = false, show_info = false,
            worlds = {}, has_world = false, no_world = true, selected_world = 1,
            servers = {}, has_server = false, no_server = true, selected_server = 1,
            form_server_name = "", form_server_address = "", form_server_port = "",
            pack_mods = {}, has_mod = false, selected_mod = 1,
            search_query = "", search_release = "",
            search_results = {}, selected_search = 1, has_search_result = false,
            mod_status = "", info_status = "",
            format_world_label  = function(w) return w.display_name or w.name end,
            format_server_label = function(s) return tostring(s.name or s.address) end,
            format_mod_entry    = function(m) return tostring(m.name) end,
            format_search_result = function(r) return tostring(r.name) end,
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        }
        for k, v in pairs(overrides or {}) do c[k] = v end
        return c
    end

    it("expands library.yml at the new compact size (13×8.5)", function()
        local tree = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx(),
            theme = theme,
        })
        assert.equal("VBox", tree._kind)
        assert.equal(13.0, tree.w)
        assert.equal(8.5,  tree.h)
    end)

    it("renders the back button and Pack name header", function()
        local build_formspec = packermod.layout.build_formspec
        local tree = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({ pack_name = "Hello Pack" }),
            theme = theme,
        })
        local s = build_formspec(tree, { theme = theme })
        assert.is_truthy(s:find("btn_back", 1, true))
        assert.is_truthy(s:find("Hello Pack", 1, true))
    end)

    it("Worlds subtab: shows new_world button; Delete/Play only when has_world", function()
        local build = packermod.layout.build_formspec
        local fs_empty = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx(),
            theme = theme,
        })
        local fs_with = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({
                worlds = { { name = "w1", display_name = "World 1" } },
                has_world = true, no_world = false,
            }),
            theme = theme,
        })
        local s_empty = build(fs_empty, { theme = theme })
        local s_with  = build(fs_with,  { theme = theme })
        assert.is_truthy(s_empty:find("new_world", 1, true))
        assert.is_nil(s_empty:find("delete_world", 1, true))
        assert.is_nil(s_empty:find("play_world", 1, true))
        assert.is_truthy(s_with:find("delete_world", 1, true))
        assert.is_truthy(s_with:find("play_world", 1, true))
    end)

    it("Multi subtab shows Add only when no servers, plus Remove/Connect when servers exist", function()
        local build = packermod.layout.build_formspec
        local fs_empty = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({ show_worlds = false, show_multi = true, variant_multi = "primary" }),
            theme = theme,
        })
        local fs_with = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({
                show_worlds = false, show_multi = true, variant_multi = "primary",
                servers = { { name = "H", address = "1.1.1.1", port = 30000 } },
                has_server = true, no_server = false,
            }),
            theme = theme,
        })
        local s_empty = build(fs_empty, { theme = theme })
        local s_with  = build(fs_with,  { theme = theme })
        assert.is_truthy(s_empty:find("server_add", 1, true))
        assert.is_nil(s_empty:find("server_remove", 1, true))
        assert.is_nil(s_empty:find("server_connect", 1, true))
        assert.is_truthy(s_with:find("server_add", 1, true))
        assert.is_truthy(s_with:find("server_remove", 1, true))
        assert.is_truthy(s_with:find("server_connect", 1, true))
    end)

    it("Mods subtab shows mod_list, search controls, and Remove/Add gated by selection", function()
        local build = packermod.layout.build_formspec
        local fs_empty = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({ show_worlds = false, show_mods = true, variant_mods = "primary" }),
            theme = theme,
        })
        local fs_with_results = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({
                show_worlds = false, show_mods = true, variant_mods = "primary",
                pack_mods = { { name = "m1", source = "contentdb", package = "a/m1", release = 1 } },
                has_mod = true,
                search_results = { { name = "mesecons", author = "rubenwardy" } },
                has_search_result = true,
                selected_mod = 1,
                selected_search = 1,
            }),
            theme = theme,
        })
        local s_empty = build(fs_empty, { theme = theme })
        local s_with  = build(fs_with_results, { theme = theme })
        assert.is_truthy(s_empty:find("do_search", 1, true))
        assert.is_nil(s_empty:find("mod_remove", 1, true))
        assert.is_nil(s_empty:find("mod_add", 1, true))
        assert.is_truthy(s_with:find("mod_remove", 1, true))
        assert.is_truthy(s_with:find("mod_add", 1, true))
    end)

    it("Info subtab shows name/version/description fields and Save button", function()
        local build = packermod.layout.build_formspec
        local fs = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({
                show_worlds = false, show_info = true, variant_info = "primary",
                pack_name = "MyPack", pack_version = "1.0",
                pack_description = "desc", pack_base = "base/1",
            }),
            theme = theme,
        })
        local s = build(fs, { theme = theme })
        assert.is_truthy(s:find("info_name", 1, true))
        assert.is_truthy(s:find("info_version", 1, true))
        assert.is_truthy(s:find("info_description", 1, true))
        assert.is_truthy(s:find("info_save", 1, true))
    end)
end)

-- ---- grid view (画面1) は library.lua 内で直接構築するので、build_grid_formspec
-- が形式正しい formspec を吐くことだけを確認する ----
describe("library grid view (画面1)", function()
    local lib, theme
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        packermod.yaml = dofile("mainmenu/yaml.lua")
        packermod.theme = dofile("mainmenu/lib/theme.lua")
        packermod.icons = dofile("mainmenu/lib/icons.lua")
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
        lib = dofile("mainmenu/library.lua")
    end)

    it("build_grid_formspec returns a string containing pack_select_* buttons", function()
        local tabdata = {}
        local fs = lib._internal.build_grid_formspec(tabdata)
        assert.is_string(fs)
        assert.is_truthy(fs:find("pack_select_pack_a", 1, true))
        assert.is_truthy(fs:find("pack_select_pack_b", 1, true))
        assert.is_truthy(fs:find("Pack A", 1, true))
        assert.is_truthy(fs:find("Pack B", 1, true))
        assert.is_truthy(fs:find("btn_import", 1, true))
        assert.is_truthy(fs:find("btn_create", 1, true))
        assert.is_truthy(fs:find("btn_settings", 1, true))
    end)

    it("renders an empty-state message when no packs exist", function()
        packermod.pack_manager.list_packs = function() return {} end
        local fs = lib._internal.build_grid_formspec({})
        assert.is_truthy(fs:find("No packs yet", 1, true))
    end)
end)

-- ---- overlap / OOB regression: detail view (library.yml) の各 subtab を全部
-- 一度ずつ描画して 0 overlap・OOB なしを assert。grid view は動的構築なので別途。
describe("formspec layout regression (#14, detail view)", function()
    local loader, theme, helpers, build_formspec
    setup(function()
        _G.packermod = _G.packermod or {}
        packermod.layout = dofile("mainmenu/lib/layout.lua")
        packermod.yaml = dofile("mainmenu/yaml.lua")
        loader = dofile("mainmenu/lib/ui_loader.lua")
        theme = dofile("mainmenu/lib/theme.lua")
        helpers = dofile("spec/support/formspec_helpers.lua")
        build_formspec = packermod.layout.build_formspec

        _G.core = _G.core or {}
        _G.core.formspec_escape = helpers.escape_min
    end)

    local function library_ctx(overrides)
        local c = {
            pack_name = "P", pack_version = "1", pack_base = "base/1",
            pack_mods_count = 0, pack_description = "",
            variant_worlds = "primary", variant_multi = "secondary",
            variant_mods = "secondary", variant_info = "secondary",
            show_worlds = true, show_multi = false, show_mods = false, show_info = false,
            worlds = {}, has_world = false, no_world = true, selected_world = 1,
            servers = {}, has_server = false, no_server = true, selected_server = 1,
            form_server_name = "", form_server_address = "", form_server_port = "",
            pack_mods = {}, has_mod = false, selected_mod = 1,
            search_query = "", search_release = "",
            search_results = {}, selected_search = 1, has_search_result = false,
            mod_status = "", info_status = "",
            format_world_label  = function(w) return w.display_name or w.name end,
            format_server_label = function(s) return tostring(s.name or s.address) end,
            format_mod_entry    = function(m) return tostring(m.name) end,
            format_search_result = function(r) return tostring(r.name) end,
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        }
        for k, v in pairs(overrides or {}) do c[k] = v end
        return c
    end

    local function assert_no_overlap_oob(label, yaml_path, ctx)
        local tree = loader.load({ yaml_path = yaml_path, ctx = ctx, theme = theme })
        local fs = build_formspec(tree, { theme = theme })
        local size, els = helpers.parse_formspec(fs)
        local overlaps = helpers.find_overlaps(els, { label_h = 0.5 })
        assert.equal(0, #overlaps,
            label .. ": " .. (overlaps[1] and helpers.format_overlaps(overlaps) or ""))
        local ok, el = helpers.fits_in_size(els, size, { label_h = 0.5 })
        assert.is_true(ok, ok and "" or
            (label .. " OOB: " .. helpers.describe_el(el)))
    end

    local scenarios = {
        { name = "library/worlds-empty",  overrides = {} },
        { name = "library/worlds-filled", overrides = {
            worlds = { { name = "w1", display_name = "World 1" } },
            has_world = true, no_world = false } },
        { name = "library/multi-empty",   overrides = {
            show_worlds = false, show_multi = true, variant_multi = "primary" } },
        { name = "library/multi-filled",  overrides = {
            show_worlds = false, show_multi = true, variant_multi = "primary",
            servers = { { name = "H", address = "1.1.1.1", port = 30000 } },
            has_server = true, no_server = false } },
        { name = "library/mods-empty",    overrides = {
            show_worlds = false, show_mods = true, variant_mods = "primary" } },
        { name = "library/mods-filled",   overrides = {
            show_worlds = false, show_mods = true, variant_mods = "primary",
            pack_mods = { { name = "m1", source = "contentdb", package = "a/m1" } },
            has_mod = true, selected_mod = 1,
            search_results = { { name = "mesecons", author = "rubenwardy" } },
            has_search_result = true, selected_search = 1 } },
    }
    for _, sc in ipairs(scenarios) do
        it("library: " .. sc.name .. " has no overlap or OOB", function()
            assert_no_overlap_oob(sc.name, "mainmenu/ui/library.yml", library_ctx(sc.overrides))
        end)
    end

    pending("library/info has no overlap or OOB (#15: layout shrink-to-fit)", function() end)

    it("modal_import has no overlap or OOB", function()
        assert_no_overlap_oob("modal_import", "mainmenu/ui/modal_import.yml", {
            source = "", status = "",
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
    end)

    it("modal_settings has no overlap or OOB", function()
        assert_no_overlap_oob("modal_settings", "mainmenu/ui/modal_settings.yml", {
            user_path = "/u", version = "0.1.0", luanti_version = "5.16.1",
            status = "",
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
    end)

    it("modal_create has no overlap or OOB", function()
        assert_no_overlap_oob("modal_create", "mainmenu/ui/modal_create.yml", {
            pack_id = "", pack_name = "", pack_version = "0.1.0",
            pack_author = "", pack_description = "",
            base_id = "packerbase", base_version = "0.91",
            search_query = "", search_release = "",
            search_results = {}, search_selected = 0,
            mods = {}, mod_selected = 0, status = "",
            format_search_result = function(r) return tostring(r.name) end,
            format_mod_entry = function(m) return tostring(m.name) end,
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
    end)
end)
