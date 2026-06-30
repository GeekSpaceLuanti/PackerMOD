-- 5 modal の PMUI 経由 smoke test。各 modal の formspec が overlap=0 / fits_in_size
-- を満たすことを確認する。

package.path = "./?.lua;" .. package.path

describe("modals PMUI smoke", function()
    local pmui, helpers, theme
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
        pmui = packermod.pmui
        helpers = dofile("spec/support/formspec_helpers.lua")
    end)

    local function build(html_filename, ctx)
        return pmui.build_formspec {
            html_path = "mainmenu/ui/" .. html_filename,
            css_path  = "mainmenu/ui/themes/synthwave.css.yml",
            ctx       = ctx,
            page_w = 30.0, page_h = 16.0,
        }
    end

    local function assert_overlap_oob(label, fs)
        local size, els = helpers.parse_formspec(fs)
        assert.equal(30.0, size.w)
        assert.equal(16.0, size.h)
        local overlaps = helpers.find_overlaps(els, { label_h = 0.45 })
        if #overlaps > 0 then
            error(label .. ":\n" .. helpers.format_overlaps(overlaps))
        end
        local ok, bad = helpers.fits_in_size(els, size, { label_h = 0.45 })
        assert.is_true(ok, label .. " OOB: " .. (bad and helpers.describe_el(bad) or ""))
    end

    it("modal_world_delete renders without overlap/OOB", function()
        local fs = build("modal_world_delete.html.yml", {
            pack_name = "Pack A", world_display = "World 1", status = "",
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
        assert.is_truthy(fs:find("Delete World", 1, true))
        assert_overlap_oob("modal_world_delete", fs)
    end)

    it("modal_world_create renders without overlap/OOB", function()
        local fs = build("modal_world_create.html.yml", {
            pack_name = "Pack A", world_name = "", status = "",
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
        assert.is_truthy(fs:find("New World", 1, true))
        assert_overlap_oob("modal_world_create", fs)
    end)

    it("modal_import renders without overlap/OOB", function()
        local fs = build("modal_import.html.yml", {
            source = "", status = "",
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
        assert.is_truthy(fs:find("Import a Pack", 1, true))
        assert_overlap_oob("modal_import", fs)
    end)

    it("modal_settings renders without overlap/OOB", function()
        local fs = build("modal_settings.html.yml", {
            user_path = "/u",
            version = "0.1.0",
            luanti_version = "5.16",
            status = "",
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
        assert.is_truthy(fs:find("PackerMOD Settings", 1, true))
        assert_overlap_oob("modal_settings", fs)
    end)

    it("modal_create renders without overlap/OOB", function()
        local fs = build("modal_create.html.yml", {
            pack_id = "", pack_name = "", pack_version = "0.1.0", pack_author = "",
            pack_description = "", base_id = "packerbase", base_version = "0.91",
            search_query = "", search_release = "",
            search_results = {}, search_selected = 0,
            mods = {}, mod_selected = 0,
            status = "",
            format_search_result = function(r) return tostring(r.name) end,
            format_mod_entry     = function(m) return tostring(m.name) end,
            icon_path = function(n) return "icon_" .. n .. ".png" end,
        })
        assert.is_truthy(fs:find("Create Pack", 1, true))
        assert_overlap_oob("modal_create", fs)
    end)
end)
