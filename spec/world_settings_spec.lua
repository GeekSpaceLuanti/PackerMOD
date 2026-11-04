package.path = "./?.lua;" .. package.path
local worlds = require("mainmenu.world_settings")
local catalog = require("mainmenu.settings_catalog")
local editor = require("mainmenu.engine_settings")
describe("World settings isolation", function()
    local values, defaults, journal, records, session, settings, write_ok, restore_ok
    before_each(function()
        values, defaults, records, journal = { time_speed = "90", client = "keep" }, { gravity = "9.81" }, {}, nil
        write_ok, restore_ok = true, true
        settings = {
            get = function(_, k) return values[k] or defaults[k] end,
            has = function(_, k) return values[k] ~= nil or defaults[k] ~= nil end,
            to_table = function() local t={}; for k,v in pairs(values) do t[k]=v end; return t end,
            set = function(_, k,v) values[k]=v end,
            remove = function(_, k) values[k]=nil end,
            write = function() return restore_ok end,
        }
        session = worlds.session { settings = settings, journal_path = "/journal",
            write = function(_, text) if not write_ok then return false end; journal=text; return true end,
            read = function() return journal end,
            remove = function() journal=nil; return true end,
            encode = function(t) records[#records+1]=t; return tostring(#records) end,
            decode = function(s) return records[tonumber(s)] end,
        }
    end)
    local function world(speed, gravity)
        return { entries = {
            { name = "time_speed", category_parts = { "Gameplay" } },
            { name = "gravity", category_parts = { "Gameplay" } },
            { name = "mg_name", category_parts = { "Mapgen" } },
        }, read = function(e) return ({ time_speed=speed, gravity=gravity, mg_name="v7" })[e.name] end }
    end
    it("restores explicit settings and removes overrides of inherited defaults", function()
        assert.is_true(session.begin(world("120", "4.2")))
        assert.equal("120", values.time_speed)
        assert.equal("4.2", values.gravity)
        assert.is_nil(values.mg_name)
        assert.is_not_nil(journal)
        assert.is_true(session.recover())
        assert.equal("90", values.time_speed)
        assert.is_nil(values.gravity)
        assert.equal("keep", values.client)
        assert.is_nil(journal)
    end)
    it("restores world A before applying world B", function()
        session.begin(world("120", "4.2"))
        session.begin(world("72", "9.81"))
        assert.equal("72", values.time_speed)
        assert.equal("9.81", values.gravity)
        session.recover()
        assert.equal("90", values.time_speed)
        assert.is_nil(values.gravity)
    end)
    it("does not apply any override when recovery journaling fails", function()
        write_ok=false
        assert.is_false(session.begin(world("120", "4.2")))
        assert.equal("90", values.time_speed)
        assert.is_nil(values.gravity)
    end)
    it("retains the journal when restoring the config fails", function()
        session.begin(world("120", "4.2")); restore_ok=false
        assert.is_false(session.recover())
        assert.is_not_nil(journal)
        restore_ok=true
        assert.is_true(session.recover())
        assert.is_nil(journal)
    end)
    it("validates the complete recovery record before applying anything", function()
        session.begin(world("120", "4.2"))
        records[1].values["invalid\nname"] = { present=true, value="bad" }
        assert.is_false(session.recover())
        assert.equal("120", values.time_speed)
    end)
    it("keeps all keys in focused groups and separates world contexts from client search", function()
        for name, group in pairs({ keymap_jump="Movement", keymap_dig="Actions", keymap_slot32="Hotbar",
            keymap_cmd="Chat and commands", keymap_camera_mode="Camera and HUD", keymap_toggle_debug="Debug keys" }) do
            local tab, actual = catalog.section({ name=name, type="key", context="client" })
            assert.equal("keymap", tab); assert.equal(group, actual)
        end
        local backend=editor.new({
            { name="fov", type="int", context="client", default="72" },
            { name="time_speed", type="int", context="server", default="72" },
            { name="mg_name", type="enum", context="world_creation", default="v7", values={"v7"} },
        },settings)
        local client=catalog.scope(backend,false)
        assert.equal(1,#client.filter(""))
        assert.equal(0,#client.filter("time_speed"))
        assert.equal(2,#catalog.scope(backend,true).entries)
        assert.is_false(client.apply(backend.by_name.time_speed,"120"))
    end)
end)
