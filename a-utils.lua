oTagLib = require("libs/oTagLib")
charSelectObjs = require("libs/charSelectObjs")

local stallFrame = 0
local stallComplete = 3
function startup_init_stall(framesBefore)
    framesBefore = framesBefore or 0
    return stallFrame == (stallComplete - framesBefore)
end

hook_event(HOOK_UPDATE, function()
    if stallFrame < stallComplete then
        stallFrame = stallFrame + 1
    end
end)


function run_func_or_get_var(x, ...)
    if type(x) == "function" then
        return x(...)
    else
        return x
    end
end

---@param string string
--- Splits a string into a table by spaces
function string_split(string, splitAt)
    if splitAt == nil then
        splitAt = " "
    end
    local result = {}
    for match in string:gmatch(string.format("[^%s]+", splitAt)) do
        table.insert(result, match)
    end
    return result
end