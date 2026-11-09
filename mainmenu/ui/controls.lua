-- Application-wide defaults by control type. No per-screen CSS is required.
-- Roles (primary/danger/quiet) keep their semantic colors.
return {
    button = { ["font-size"] = 16, ["min-height"] = 44 },
    field = { ["font-size"] = 16, ["min-height"] = 42 },
    textarea = { ["font-size"] = 16 },
    dropdown = { ["min-height"] = 42 },
    slider = { ["min-height"] = 32 },
}
