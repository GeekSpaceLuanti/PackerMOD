package.path = "./?.lua;" .. package.path
local editor = require("mainmenu.engine_settings")

describe("Engine settings editor", function()
    local backend, settings, values, groups, writes
    before_each(function()
        values, groups, writes = { unrelated = "keep", size = "18" }, {}, 0
        settings = {
            get = function(_, key) return values[key] end,
            has = function(_, key) return values[key] ~= nil or groups[key] ~= nil end,
            set = function(_, key, value) values[key] = value end,
            remove = function(_, key) values[key], groups[key] = nil, nil end,
            get_np_group = function(_, key) return groups[key] end,
            set_np_group = function(_, key, value) groups[key] = value end,
            write = function() writes = writes + 1; return true end,
        }
        backend = editor.new({
            { type = "category", name = "Graphics", level = 0 },
            { type = "int", name = "size", readable_name = "Font size", default = "16", min = 5, max = 72 },
            { type = "float", name = "volume", default = "0.8", min = 0, max = 1 },
            { type = "bool", name = "sound", default = "true" },
            { type = "enum", name = "driver", default = "", values = { "", "opengl" } },
            { type = "category", name = "World", level = 0 },
            { type = "flags", name = "flags", default = "caves", possible = { "caves", "trees" } },
            { type = "v3f", name = "vector", default = "(1, 2, 3)" },
            { type = "key", name = "key", default = "KEY_KEY_W" },
            { type = "noise_params_2d", name = "noise", noise_params = true,
                default_table = { offset = 0, scale = 1, spread = { x = 100, y = 100, z = 100 },
                    seed = 12, octaves = 3, persistence = 0.5, lacunarity = 2, flags = "eased" } },
        }, settings)
    end)
    it("uses installed defaults and filters by translated labels and categories", function()
        assert.equal("18", backend.read(backend.by_name.size))
        assert.equal("0.8", backend.read(backend.by_name.volume))
        local function translate(text) return text == "Graphics" and "描画" or text end
        assert.equal(4, #backend.filter("描画", nil, translate))
        assert.equal(4, #backend.filter("", "World"))
        assert.equal(1, #backend.filter("font size"))
    end)
    it("writes one setting, persists and resets its override", function()
        assert.is_true(backend.apply(backend.by_name.size, "24"))
        assert.equal("24", values.size)
        assert.equal("keep", values.unrelated)
        assert.equal(1, writes)
        assert.is_true(backend.reset(backend.by_name.size))
        assert.is_nil(values.size)
        assert.equal("16", backend.read(backend.by_name.size))
        assert.equal(2, writes)
    end)
    it("rejects invalid numbers, bounds and choices without writing", function()
        for _, item in ipairs({ { "size", "3" }, { "size", "100" }, { "size", "1.5" },
            { "volume", "nan" }, { "volume", "1e999" }, { "sound", "yes" }, { "driver", "invalid" } }) do
            assert.is_false(backend.apply(backend.by_name[item[1]], item[2]))
        end
        assert.equal(0, writes)
        assert.equal("18", values.size)
        assert.is_true(backend.apply(backend.by_name.driver, ""))
        assert.is_true(backend.apply(backend.by_name.sound, "false"))
    end)
    it("rolls back an override or new value if persistence fails", function()
        settings.write = function() return false end
        assert.is_false(backend.apply(backend.by_name.size, "24"))
        assert.equal("18", values.size)
        assert.is_false(backend.apply(backend.by_name.sound, "false"))
        assert.is_nil(values.sound)
        assert.is_false(backend.reset(backend.by_name.size))
        assert.equal("18", values.size)
    end)
    it("normalizes vectors and flags while rejecting unknown input", function()
        assert.is_true(backend.apply(backend.by_name.vector, "1, 2.5, -3"))
        assert.equal("(1, 2.5, -3)", values.vector)
        assert.is_false(backend.apply(backend.by_name.vector, "1, 2"))
        assert.is_true(backend.apply(backend.by_name.flags, "trees, nocaves,trees"))
        assert.equal("trees,nocaves", values.flags)
        assert.is_false(backend.apply(backend.by_name.flags, "unknown"))
        assert.is_true(backend.apply(backend.by_name.key, "KEY_KEY_W|KEY_UP"))
        assert.is_false(backend.apply(backend.by_name.key, "KEY_KEY_W\nother = value"))
    end)
    it("copies noise defaults and validates every component before saving", function()
        local entry = backend.by_name.noise
        local input = backend.read(entry)
        input.spread.x = "250"
        assert.equal(100, entry.default_table.spread.x)
        assert.is_true(backend.apply(entry, input))
        assert.equal(250, groups.noise.spread.x)
        local read = backend.read(entry)
        read.spread.x = 0
        assert.is_false(backend.apply(entry, read))
        assert.equal(250, groups.noise.spread.x)
        read.spread.x, read.octaves = 250, 1.5
        assert.is_false(backend.apply(entry, read))
        assert.is_true(backend.reset(entry))
        assert.equal(100, backend.read(entry).spread.x)
    end)
end)
