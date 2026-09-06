--[[
Physical-keyboard layout resolver for the External keyboard plugin.

Maps a (key name, modifier state) to the composed UTF-8 character, or nil for
keys this layout does not produce a character for (the caller then emits no
TextInput event and the key falls through to normal KeyPress handling).

Letters are case-folded; only non-letter keys live in the per-layout tables.
Scope: US QWERTY, base + Shift. Structured so more layouts and an AltGr level
are drop-in additions later.
--]]

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

-- key_name: the KOReader key name. Letters arrive upper-case (e.g. "A"); symbols
-- and space arrive as their base char (e.g. ";", " ") from the event map.
-- modifiers: the Input.modifiers table (only .Shift is consulted at this scope).
function M.resolve(layout_name, key_name, modifiers)
    if type(key_name) ~= "string" then return nil end
    modifiers = modifiers or {}
    -- No composed character while a non-Shift modifier is held (Ctrl/Alt/Meta/
    -- Sym/...): those are shortcuts, not text. SDL likewise emits no TextInput
    -- for control combinations, so this path must not either.
    for name, active in pairs(modifiers) do
        if active and name ~= "Shift" then return nil end
    end
    local shift = modifiers.Shift or false

    -- Single A-Z letter: case-fold.
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
