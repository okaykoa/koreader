-- US QWERTY physical-keyboard resolver.

local M = {}

M.SHIFT = 1
M.ALTGR = 2

M.layouts = {
    us = {
        ["1"] = { [0] = "1", [M.SHIFT] = "!" },
        ["2"] = { [0] = "2", [M.SHIFT] = "@" },
        ["3"] = { [0] = "3", [M.SHIFT] = "#" },
        ["4"] = { [0] = "4", [M.SHIFT] = "$" },
        ["5"] = { [0] = "5", [M.SHIFT] = "%" },
        ["6"] = { [0] = "6", [M.SHIFT] = "^" },
        ["7"] = { [0] = "7", [M.SHIFT] = "&" },
        ["8"] = { [0] = "8", [M.SHIFT] = "*" },
        ["9"] = { [0] = "9", [M.SHIFT] = "(" },
        ["0"] = { [0] = "0", [M.SHIFT] = ")" },
        ["-"] = { [0] = "-", [M.SHIFT] = "_" },
        ["="] = { [0] = "=", [M.SHIFT] = "+" },
        ["["] = { [0] = "[", [M.SHIFT] = "{" },
        ["]"] = { [0] = "]", [M.SHIFT] = "}" },
        ["\\"] = { [0] = "\\", [M.SHIFT] = "|" },
        [";"] = { [0] = ";", [M.SHIFT] = ":" },
        ["'"] = { [0] = "'", [M.SHIFT] = '"' },
        ["`"] = { [0] = "`", [M.SHIFT] = "~" },
        [","] = { [0] = ",", [M.SHIFT] = "<" },
        ["."] = { [0] = ".", [M.SHIFT] = ">" },
        ["/"] = { [0] = "/", [M.SHIFT] = "?" },
        [" "] = { [0] = " ", [M.SHIFT] = " " },
    },
}

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

    if key_name:match("^[A-Z]$") then
        return level == M.SHIFT and key_name or (level == 0 and key_name:lower() or nil)
    end

    local layout = M.layouts[layout_name]
    if not layout then return nil end
    local entry = layout[key_name]
    if not entry then return nil end
    return entry[level]
end

return M
