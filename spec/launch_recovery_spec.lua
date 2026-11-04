package.path = "./?.lua;" .. package.path
local launcher = require("mainmenu.pack_launcher")
local lfs = require("lfs")
describe("Sandbox world launch recovery", function()
    local root, source, old_core, execute, record, fail_write, launch
    local function write(path, text) local f=assert(io.open(path,"w")); f:write(text); f:close(); return true end
    local function read(path) local f=io.open(path,"r"); if not f then return end; local t=f:read("*a"); f:close(); return t end
    local function clean(path)
        for name in lfs.dir(path) do
            if name ~= "." and name ~= ".." then
                local child=path .. "/" .. name
                if lfs.attributes(child,"mode")=="directory" then clean(child); lfs.rmdir(child) else os.remove(child) end
            end
        end
    end
    before_each(function()
        old_core, execute = core, os.execute
        root=os.tmpname(); os.remove(root); assert(lfs.mkdir(root))
        local path=root
        for _,part in ipairs({"PackerMOD","packs","p","worlds","a"}) do path=path .. "/" .. part; assert(lfs.mkdir(path)) end
        source=path
        write(source .. "/world.mt","gameid = test\n")
        write(source .. "/map.sqlite","test map bytes")
        fail_write=false
        _G.core={
            create_dir=function(p) return lfs.attributes(p,"mode")=="directory" or lfs.mkdir(p) end,
            get_dir_list=function(p) local t={}; for n in lfs.dir(p) do if n~="." and n~=".." then t[#t+1]=n end end; return t end,
            safe_file_write=function(p,t) if fail_write then return false end; return write(p,t) end,
            write_json=function(t) record=t; return "journal" end,
            parse_json=function() return record end,
        }
        os.execute=nil
        launch=launcher.new({user_path=root,world_builder={},mod_installer={}})
    end)
    after_each(function()
        _G.core, os.execute=old_core,execute
        assert(root and root~="/" and #root>8)
        clean(root); lfs.rmdir(root)
    end)
    it("returns a world to the pack after a game or crash without changing data", function()
        local world={path=source}
        assert.is_truthy(launch.prepare_launch(world))
        assert.is_nil(read(source .. "/world.mt"))
        assert.equal("test map bytes",read(world.path .. "/map.sqlite"))
        assert.is_true(launcher.recover_launch(root))
        assert.equal("test map bytes",read(source .. "/map.sqlite"))
        assert.is_nil(read(root .. "/PackerMOD/launch-world.json"))
    end)
    it("does not move data if the journal cannot be written", function()
        fail_write=true
        assert.is_false(launch.prepare_launch({path=source}))
        assert.equal("test map bytes",read(source .. "/map.sqlite"))
    end)
    it("preserves both worlds on a recovery conflict", function()
        local world={path=source}; launch.prepare_launch(world)
        assert(lfs.mkdir(source)); write(source .. "/world.mt","other world")
        assert.is_false(launcher.recover_launch(root))
        assert.equal("other world",read(source .. "/world.mt"))
        assert.equal("test map bytes",read(world.path .. "/map.sqlite"))
        assert.is_not_nil(read(root .. "/PackerMOD/launch-world.json"))
    end)
    it("rejects journal paths outside the pack world roots", function()
        record={source=root .. "/PackerMOD",target=root .. "/worlds/_pm_bad"}
        write(root .. "/PackerMOD/launch-world.json","journal")
        assert.is_false(launcher.recover_launch(root))
        assert.equal("test map bytes",read(source .. "/map.sqlite"))
    end)
    it("never deletes an orphaned launch directory containing world data", function()
        local world={path=source}; launch.prepare_launch(world)
        os.remove(root .. "/PackerMOD/launch-world.json")
        launcher.cleanup_symlinks(root)
        assert.equal("test map bytes",read(world.path .. "/map.sqlite"))
    end)
end)
