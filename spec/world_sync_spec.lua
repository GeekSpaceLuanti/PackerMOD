package.path = "./?.lua;" .. package.path
local lfs = require("lfs")
local sync_mod = require("mainmenu.world_sync")
local manifest = require("mainmenu.manifest")

-- Use real temporary files to exercise directory swaps and rollback behavior.
describe("world_sync", function()
    local root, fs, pack, world, downloads, fail_install
    local function read(path)
        local f = io.open(path, "rb")
        if not f then return nil end
        local text = f:read("*a"); f:close(); return text
    end
    local function write(path, text)
        local f = assert(io.open(path, "wb")); f:write(text); f:close(); return true
    end
    local function remove(path)
        if lfs.attributes(path, "mode") == "directory" then
            for name in lfs.dir(path) do
                if name ~= "." and name ~= ".." then assert(remove(path .. "/" .. name)) end
            end
            return lfs.rmdir(path)
        end
        return os.remove(path)
    end
    local function copy(src, dst)
        if lfs.attributes(src, "mode") == "directory" then
            assert(lfs.mkdir(dst))
            for name in lfs.dir(src) do
                if name ~= "." and name ~= ".." then copy(src .. "/" .. name, dst .. "/" .. name) end
            end
        else write(dst, assert(read(src))) end
        return true
    end
    local function mkdir(path)
        if lfs.attributes(path) then return true end
        return lfs.mkdir(path)
    end
    local function new_sync()
        return sync_mod.new({ fs = fs, manifest = manifest, installer = {
            install_all = function(m, path)
                downloads = downloads + 1
                if fail_install then return false, "network unavailable" end
                mkdir(path .. "/worldmods")
                for _, mod in ipairs(m.mods or {}) do
                    mkdir(path .. "/worldmods/" .. mod.name)
                    write(path .. "/worldmods/" .. mod.name .. "/init.lua", "new version")
                end
                return true
            end,
        } })
    end
    before_each(function()
        root = os.tmpname(); os.remove(root); assert(lfs.mkdir(root))
        fs = { exists = function(p) return lfs.attributes(p) ~= nil end,
            mkdir = mkdir, read_file = read, write_file = write,
            copy_dir = copy, delete_dir = remove, rename = os.rename }
        world = { path = root }
        pack = { path = "/packs/p", manifest = { schema_version = 1, id = "p",
            name = "Pack", version = "1", base_game = { id = "base", version = "1" },
            mods = { { name = "newmod", source = "bundle", path = "newmod" } } } }
        mkdir(root .. "/worldmods"); mkdir(root .. "/worldmods/oldmod")
        mkdir(root .. "/worldmods/manual")
        write(root .. "/worldmods/oldmod/init.lua", "old version")
        write(root .. "/worldmods/manual/init.lua", "user addition")
        write(root .. "/world.mt", "world_name = Original\nload_mod_oldmod = true\nbackend = sqlite3\n")
        write(root .. "/map.sqlite", "map data")
        downloads, fail_install = 0, false
    end)
    after_each(function() assert(remove(root)) end)

    it("adds/removes managed MODs and preserves unrelated MODs and map data", function()
        assert.is_true(new_sync().sync(pack, world))
        assert.equal("new version", read(root .. "/worldmods/newmod/init.lua"))
        assert.is_nil(lfs.attributes(root .. "/worldmods/oldmod"))
        assert.equal("user addition", read(root .. "/worldmods/manual/init.lua"))
        assert.equal("map data", read(root .. "/map.sqlite"))
        local mt = read(root .. "/world.mt")
        assert.is_truthy(mt:find("world_name = Original", 1, true))
        assert.is_truthy(mt:find("load_mod_newmod = true", 1, true))
        assert.is_nil(mt:find("load_mod_oldmod", 1, true))
        local backup
        for name in lfs.dir(root) do if name:match("^%.packermod%-backup") then backup = name end end
        assert.equal("old version", read(root .. "/" .. backup .. "/previous_worldmods/oldmod/init.lua"))
    end)

    it("does not reinstall an unchanged Pack, even after re-parsing the manifest", function()
        local sync = new_sync()
        assert.is_true(sync.sync(pack, world))
        local valid, parsed = manifest.parse(read(root .. "/packermod_manifest.yaml"))
        assert.is_true(valid); pack.manifest = parsed
        assert.is_true(sync.sync(pack, world))
        assert.equal(1, downloads)
    end)

    it("leaves the playable world untouched when installation fails", function()
        fail_install = true
        local original = read(root .. "/world.mt")
        local ok, err = new_sync().sync(pack, world)
        assert.is_false(ok)
        assert.is_truthy(err:find("network unavailable", 1, true))
        assert.equal(original, read(root .. "/world.mt"))
        assert.equal("old version", read(root .. "/worldmods/oldmod/init.lua"))
        assert.is_nil(read(root .. "/packermod_manifest.yaml"))
    end)

    it("rolls back directory/config swaps if publishing the snapshot fails", function()
        local original = read(root .. "/world.mt")
        fs.rename = function(src, dst)
            if dst == root .. "/packermod_manifest.yaml" then return false, "disk error" end
            return os.rename(src, dst)
        end
        local ok = new_sync().sync(pack, world)
        assert.is_false(ok)
        assert.equal(original, read(root .. "/world.mt"))
        assert.equal("old version", read(root .. "/worldmods/oldmod/init.lua"))
        assert.equal("user addition", read(root .. "/worldmods/manual/init.lua"))
        assert.is_nil(lfs.attributes(root .. "/worldmods/newmod"))
        assert.equal("map data", read(root .. "/map.sqlite"))
    end)
end)
