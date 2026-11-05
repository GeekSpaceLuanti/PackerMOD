-- SPDX-License-Identifier: LGPL-2.1-or-later
assert(packer_core.api_version == 1, "This example requires PackerMOD Base API 1")
local state = packer_core.open_data("packerbase_example", 1, {
    [1] = function(data)
        data.starts = 0
        return data
    end,
})
packer_core.on("ready", function()
    packer_core.measure("packerbase_example.ready", function()
        local data = state.read()
        data.starts = data.starts + 1
        state.write(data)
        core.log("action", "PackerMOD Base example: world start " .. data.starts)
    end)
end)
