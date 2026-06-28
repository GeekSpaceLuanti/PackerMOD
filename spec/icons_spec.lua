package.path = "./?.lua;" .. package.path

local icons = dofile("mainmenu/lib/icons.lua")

describe("icons.path", function()
    it("returns packermod_icon_<name>_<size>.png for known names", function()
        assert.equal("packermod_icon_play_md.png",     icons.path("play", "md"))
        assert.equal("packermod_icon_search_sm.png",   icons.path("search", "sm"))
        assert.equal("packermod_icon_download_lg.png", icons.path("download", "lg"))
    end)

    it("defaults size to 'md' when omitted", function()
        assert.equal("packermod_icon_save_md.png", icons.path("save"))
    end)

    it("resolves aliases", function()
        assert.equal("packermod_icon_settings-2_md.png", icons.path("sliders", "md"))
        assert.equal("packermod_icon_box_md.png",        icons.path("cube",    "md"))
    end)

    it("returns blank texture path for nil / empty name", function()
        assert.equal("blank.png", icons.path(nil))
        assert.equal("blank.png", icons.path(""))
    end)
end)

describe("icons.names", function()
    it("lists vendored icon names plus aliases", function()
        local names = icons.names()
        assert.is_table(names)
        local seen = {}
        for _, n in ipairs(names) do seen[n] = true end
        assert.is_true(seen.play, "play missing")
        assert.is_true(seen.reload, "reload missing")
        assert.is_true(seen.sliders, "sliders alias missing")
        assert.is_true(seen.cube, "cube alias missing")
    end)
end)
