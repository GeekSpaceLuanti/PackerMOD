-- Prepare a complete MOD update before touching a playable world. Keep the old
-- worldmods/config in a per-update backup; map/player databases are never moved.
local M = {}

function M.new(opts)
    local fs, installer, manifest_mod = opts.fs, opts.installer, opts.manifest
    local self = {}

    function self.record(pack, world_path)
        local valid, snapshot = manifest_mod.dump(pack.manifest)
        if not valid then return false, snapshot end
        return fs.write_file(world_path .. "/packermod_manifest.yaml", snapshot)
    end

    function self.sync(pack, world)
        local ok, snapshot = manifest_mod.dump(pack.manifest)
        if not ok then return false, snapshot end
        local marker = world.path .. "/packermod_manifest.yaml"
        local old_snapshot = fs.read_file(marker)
        if old_snapshot == snapshot then return true end
        local config = fs.read_file(world.path .. "/world.mt")
        if not config then return false, "cannot read world.mt" end

        local managed = {}
        if old_snapshot then
            local valid, old = manifest_mod.parse(old_snapshot)
            if not valid then return false, "invalid saved Pack manifest: " .. tostring(old) end
            for _, mod in ipairs(old.mods or {}) do managed[mod.name] = true end
        else
            -- Migration for worlds created before snapshots were introduced.
            for name in config:gmatch("load_mod_([a-z0-9_]+)%s*=%s*true") do
                managed[name] = true
            end
        end
        for _, mod in ipairs(pack.manifest.mods or {}) do managed[mod.name] = true end

        local transaction = world.path .. ("/.packermod-backup-%d-%06x"):format(
            os.time(), math.random(0, 0xffffff))
        if fs.exists(transaction) then return false, "update directory already exists" end
        if not fs.mkdir(transaction) then return false, "cannot create update directory" end
        local staged = transaction .. "/worldmods"
        local live = world.path .. "/worldmods"
        local had_mods = fs.exists(live)
        if had_mods then
            if not fs.copy_dir(live, staged, true) then
                fs.delete_dir(transaction)
                return false, "cannot stage existing MODs"
            end
        elseif not fs.mkdir(staged) then
            fs.delete_dir(transaction)
            return false, "cannot create staged MODs"
        end
        for name in pairs(managed) do
            local path = staged .. "/" .. name
            if fs.exists(path) and not fs.delete_dir(path) then
                fs.delete_dir(transaction)
                return false, "cannot replace MOD: " .. name
            end
        end
        local installed, err = installer.install_all(pack.manifest, transaction, pack.path)
        if not installed then
            fs.delete_dir(transaction)
            return false, "MOD update failed: " .. tostring(err)
        end
        local lines = {}
        for line in (config .. "\n"):gmatch("([^\n]*)\n") do
            local name = line:match("^%s*load_mod_([a-z0-9_]+)%s*=")
            if not (name and managed[name]) then lines[#lines + 1] = line end
        end
        for _, mod in ipairs(pack.manifest.mods or {}) do
            lines[#lines + 1] = "load_mod_" .. mod.name .. " = true"
        end
        local written = fs.write_file(transaction .. "/world.mt", table.concat(lines, "\n") .. "\n")
        local saved = fs.write_file(transaction .. "/manifest.yaml", snapshot)
        if not written or not saved then
            fs.delete_dir(transaction)
            return false, "cannot stage updated configuration"
        end

        local moves = {}
        local function move(src, dst)
            local moved, why = fs.rename(src, dst)
            if moved then moves[#moves + 1] = { src, dst } end
            return moved, why
        end
        local function fail(why)
            local restored = true
            for i = #moves, 1, -1 do
                local m = moves[i]
                if not fs.rename(m[2], m[1]) then restored = false end
            end
            if restored then fs.delete_dir(transaction) end
            return false, tostring(why) .. (restored and "; original world restored"
                or "; recovery files retained at " .. transaction)
        end
        if had_mods then
            local moved, why = move(live, transaction .. "/previous_worldmods")
            if not moved then return fail(why) end
        end
        local moved, why = move(staged, live)
        if not moved then return fail(why) end
        moved, why = move(world.path .. "/world.mt", transaction .. "/previous_world.mt")
        if not moved then return fail(why) end
        moved, why = move(transaction .. "/world.mt", world.path .. "/world.mt")
        if not moved then return fail(why) end
        if old_snapshot then
            moved, why = move(marker, transaction .. "/previous_manifest.yaml")
            if not moved then return fail(why) end
        end
        moved, why = move(transaction .. "/manifest.yaml", marker)
        if not moved then return fail(why) end
        return true
    end

    return self
end

return M
