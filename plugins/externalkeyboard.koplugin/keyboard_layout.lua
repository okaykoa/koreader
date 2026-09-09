-- US QWERTY physical-keyboard resolver (base and Shift levels).

local M = {}

M.layouts = {
    us = {
        ["1"] = { base = "1", shift = "!" },
        ["2"] = { base = "2", shift = "@" },
        ["3"] = { base = "3", shift = "#" },
        ["4"] = { base = "4", shift = "$" },
        ["5"] = { base = "5", shift = "%" },
        ["6"] = { base = "6", shift = "^" },
        ["7"] = { base = "7", shift = "&" },
        ["8"] = { base = "8", shift = "*" },
        ["9"] = { base = "9", shift = "(" },
        ["0"] = { base = "0", shift = ")" },
        ["-"] = { base = "-", shift = "_" },
        ["="] = { base = "=", shift = "+" },
        ["["] = { base = "[", shift = "{" },
        ["]"] = { base = "]", shift = "}" },
        ["\\"] = { base = "\\", shift = "|" },
        [";"] = { base = ";", shift = ":" },
        ["'"] = { base = "'", shift = '"' },
        ["`"] = { base = "`", shift = "~" },
        [","] = { base = ",", shift = "<" },
        ["."] = { base = ".", shift = ">" },
        ["/"] = { base = "/", shift = "?" },
        [" "] = { base = " ", shift = " " },
    },
}

function M.resolve(layout_name, key_name, modifiers)
    if type(key_name) ~= "string" then return nil end
    modifiers = modifiers or {}
    -- Non-Shift modifiers are shortcuts, not text.
    for name, active in pairs(modifiers) do
        if active and name ~= "Shift" then return nil end
    end
    local shift = modifiers.Shift or false

    if key_name:match("^[A-Z]$") then
        return shift and key_name or key_name:lower()
    end

    local layout = M.layouts[layout_name]
    if not layout then return nil end
    local entry = layout[key_name]
    if not entry then return nil end
    return shift and entry.shift or entry.base
end

return M
