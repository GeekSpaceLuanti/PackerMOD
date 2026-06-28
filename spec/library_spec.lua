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
            format_pack_label = function(p) return p.manifest.name end,
            format_world_label = function(w) return w.display_name or w.name end,
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
end)
