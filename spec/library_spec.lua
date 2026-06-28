package.path = "./?.lua;" .. package.path

-- library.lua の純粋ロジック部分(_internal)と、library.yml が ui_loader で
-- エラーなく展開できることのテスト。

local function load_library()
    -- library.lua は dofile されるので require ではなく dofile で読む
    return dofile("mainmenu/library.lua")
end

describe("library._internal helpers", function()
    local lib
    setup(function() lib = load_library() end)

    it("format_pack_label returns just the pack name (詳細は右パネルが担当)", function()
        local s = lib._internal.format_pack_label({
            id = "x",
            manifest = { name = "MyPack", version = "1.2.3",
                         base_game = { id = "packerbase", version = "0.91" },
                         mods = { { name = "a" } } },
        })
        assert.are.equal("MyPack", s)
    end)

    it("format_world_label uses display_name when given", function()
        assert.are.equal("My World",
            lib._internal.format_world_label({ name = "raw", display_name = "My World" }))
        assert.are.equal("raw",
            lib._internal.format_world_label({ name = "raw" }))
    end)

    it("subtab_variant returns 'primary' for active, 'secondary' otherwise", function()
        assert.are.equal("primary",  lib._internal.subtab_variant("worlds", "worlds"))
        assert.are.equal("secondary", lib._internal.subtab_variant("worlds", "multi"))
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

describe("library.yml expansion via ui_loader", function()
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
            packs = {},
            selected_pack = 1,
            has_pack = false,
            no_pack = true,
            pack_name = "",
            pack_version = "",
            pack_base = "",
            pack_mods_count = 0,
            pack_description = "",
            variant_worlds = "secondary",
            variant_multi = "secondary",
            variant_mods = "secondary",
            variant_info = "secondary",
            show_worlds = false,
            show_multi = false,
            show_mods = false,
            show_info = false,
            worlds = {},
            has_world = false,
            no_world = true,
            selected_world = 1,
            servers = {},
            has_server = false,
            no_server = true,
            selected_server = 1,
            form_server_name = "",
            form_server_address = "",
            form_server_port = "",
            format_pack_label = function(p) return p.manifest.name end,
            format_world_label = function(w) return w.display_name or w.name end,
            format_server_label = function(s) return tostring(s.name or s.address) end,
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        }
        for k, v in pairs(overrides or {}) do c[k] = v end
        return c
    end

    it("expands library.yml with empty packs (no_pack branch)", function()
        local tree = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx(),
            theme = theme,
        })
        assert.equal("VBox", tree._kind)
        assert.equal(15.5, tree.w)
        assert.equal(8.0,  tree.h)
    end)

    it("expands library.yml with a pack selected and Worlds subtab active", function()
        local ctx = build_ctx({
            packs = { { id = "p", manifest = { name = "P", version = "1", base_game = {} } } },
            has_pack = true, no_pack = false,
            pack_name = "P",
            variant_worlds = "primary",
            show_worlds = true,
            worlds = { { name = "w1", display_name = "World 1" } },
            has_world = true,
            no_world = false,
        })
        local tree = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = ctx,
            theme = theme,
        })
        assert.equal("VBox", tree._kind)
    end)

    it("subtab buttons are visible only when has_pack is true", function()
        local fs_no = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx(),
            theme = theme,
        })
        local fs_yes = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({ has_pack = true, no_pack = false, show_worlds = true }),
            theme = theme,
        })
        local build_formspec = packermod.layout.build_formspec
        local s_no  = build_formspec(fs_no,  { theme = theme })
        local s_yes = build_formspec(fs_yes, { theme = theme })
        assert.is_nil(s_no:find("subtab_worlds", 1, true),
            "subtab_worlds button should not render when no_pack")
        assert.is_truthy(s_yes:find("subtab_worlds", 1, true),
            "subtab_worlds button should render when has_pack")
    end)

    it("Multi subtab shows Add only when no servers, plus Remove/Connect when servers exist", function()
        local build = packermod.layout.build_formspec
        local fs_empty = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({
                has_pack = true, no_pack = false, show_multi = true,
            }),
            theme = theme,
        })
        local fs_with = loader.load({
            yaml_path = "mainmenu/ui/library.yml",
            ctx = build_ctx({
                has_pack = true, no_pack = false, show_multi = true,
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
end)
