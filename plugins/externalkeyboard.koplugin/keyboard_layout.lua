-- US QWERTY physical-keyboard resolver.

local M = {}

M.SHIFT = 1
M.ALTGR = 2

M.layouts = setmetatable({}, {
    __index = function(layouts, layout_name)
        if type(layout_name) ~= "string" or not layout_name:match("^[%w_-]+$") then return nil end
        local loader = loadfile("plugins/externalkeyboard.koplugin/keyboard_layouts/" .. layout_name .. ".lua")
        if not loader then return nil end
        local layout = loader()
        rawset(layouts, layout_name, layout)
        return layout
    end,
})

function M.resolve(layout_name, key_name, modifiers)
    if type(key_name) ~= "string" then return nil end
    modifiers = modifiers or {}
    local level = 0
    for name, active in pairs(modifiers) do
        if active then
            if name == "Shift" then
                level = level + M.SHIFT
            elseif name == "AltGr" then
                level = level + M.ALTGR
            else
                return nil
            end
        end
    end

    local layout = M.layouts[layout_name]
    if not layout then return nil end
    local entry = layout[key_name]
    if entry then return entry[level + 1] end

    if key_name:match("^[A-Z]$") then
        return level == M.SHIFT and key_name or (level == 0 and key_name:lower() or nil)
    end
end

return M
