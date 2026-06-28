package.path = "./?.lua;" .. package.path

local server_list = require("mainmenu.server_list")
local yaml = require("mainmenu.yaml")

local function fake_fs(initial)
    local files = {}
    for k, v in pairs(initial or {}) do files[k] = v end
    return {
        files = files,
        read = function(path) return files[path] end,
        write = function(path, text) files[path] = text; return true end,
    }
end

local function opts_for(fs)
    return {
        yaml = yaml,
        read_file = fs.read,
        write_file = fs.write,
    }
end

describe("server_list.load", function()
    it("returns empty list when servers.yaml is missing", function()
        local fs = fake_fs({})
        local list = server_list.load("/pack", opts_for(fs))
        assert.are.equal(0, #list)
    end)

    it("parses { servers: [...] } shape", function()
        local fs = fake_fs({
            ["/pack/servers.yaml"] =
                "servers:\n" ..
                "  - name: \"Home\"\n" ..
                "    address: \"192.168.0.10\"\n" ..
                "    port: 30005\n" ..
                "    description: \"my LAN\"\n",
        })
        local list = server_list.load("/pack", opts_for(fs))
        assert.are.equal(1, #list)
        assert.are.equal("Home", list[1].name)
        assert.are.equal("192.168.0.10", list[1].address)
        assert.are.equal(30005, list[1].port)
        assert.are.equal("my LAN", list[1].description)
    end)

    it("defaults port to 30000 when missing", function()
        local fs = fake_fs({
            ["/pack/servers.yaml"] =
                "servers:\n" ..
                "  - name: \"X\"\n" ..
                "    address: \"a.b\"\n",
        })
        local list = server_list.load("/pack", opts_for(fs))
        assert.are.equal(30000, list[1].port)
    end)
end)

describe("server_list.add / remove / update", function()
    it("appends then persists to servers.yaml", function()
        local fs = fake_fs({})
        local ok, idx = server_list.add("/pack",
            { name = "A", address = "1.1.1.1", port = 30001 },
            opts_for(fs))
        assert.is_true(ok)
        assert.are.equal(1, idx)
        local list = server_list.load("/pack", opts_for(fs))
        assert.are.equal(1, #list)
        assert.are.equal("A", list[1].name)
    end)

    it("removes by index", function()
        local fs = fake_fs({})
        server_list.add("/pack", { name = "A", address = "1" }, opts_for(fs))
        server_list.add("/pack", { name = "B", address = "2" }, opts_for(fs))
        local ok = server_list.remove("/pack", 1, opts_for(fs))
        assert.is_true(ok)
        local list = server_list.load("/pack", opts_for(fs))
        assert.are.equal(1, #list)
        assert.are.equal("B", list[1].name)
    end)

    it("rejects remove with out-of-range index", function()
        local fs = fake_fs({})
        local ok, err = server_list.remove("/pack", 99, opts_for(fs))
        assert.is_false(ok)
        assert.is_truthy(err:find("out of range"))
    end)

    it("updates by index", function()
        local fs = fake_fs({})
        server_list.add("/pack", { name = "A", address = "1" }, opts_for(fs))
        local ok = server_list.update("/pack", 1,
            { name = "AA", address = "9.9.9.9", port = 30002 },
            opts_for(fs))
        assert.is_true(ok)
        local list = server_list.load("/pack", opts_for(fs))
        assert.are.equal("AA", list[1].name)
        assert.are.equal("9.9.9.9", list[1].address)
        assert.are.equal(30002, list[1].port)
    end)
end)
