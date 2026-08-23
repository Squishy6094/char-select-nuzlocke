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

local sLevelTable = {
    [LEVEL_BBH] = true,
    [LEVEL_CCM] = true,
    [LEVEL_CASTLE] = true,
    [LEVEL_HMC] = true,
    [LEVEL_SSL] = true,
    [LEVEL_BOB] = true,
    [LEVEL_SL] = true,
    [LEVEL_WDW] = true,
    [LEVEL_JRB] = true,
    [LEVEL_THI] = true,
    [LEVEL_TTC] = true,
    [LEVEL_RR] = true,
    [LEVEL_CASTLE_GROUNDS] = true,
    [LEVEL_BITDW] = true,
    [LEVEL_VCUTM] = true,
    [LEVEL_BITFS] = true,
    [LEVEL_SA] = true,
    [LEVEL_BITS] = true,
    [LEVEL_LLL] = true,
    [LEVEL_DDD] = true,
    [LEVEL_WF] = true,
    [LEVEL_ENDING] = true,
    [LEVEL_CASTLE_COURTYARD] = true,
    [LEVEL_PSS] = true,
    [LEVEL_COTMC] = true,
    [LEVEL_TOTWC] = true,
    [LEVEL_BOWSER_1] = true,
    [LEVEL_WMOTR] = true,
    [LEVEL_BOWSER_2] = true,
    [LEVEL_BOWSER_3] = true,
    [LEVEL_TTM] = true
}

charLevelMap = {}
local function find_valid_areas()
    local isRomhack = false
    for i = 0, LEVEL_COUNT - 1 do
        if sLevelTable[i] and not level_is_vanilla_level(i) then
            isRomhack = true
            log_to_console("mwahh")
        end
    end
    
    for i = 0, LEVEL_COUNT - 1 do
        if sLevelTable[i] and not (isRomhack and level_is_vanilla_level(i)) then
            level_script_parse(i, function (areaIndex, bhvData, macroBhvIds, macroBhvArgs)
                if areaIndex then
                    if not charLevelMap[i] then
                        charLevelMap[i] = {}
                    end
                    charLevelMap[i][areaIndex] = {}
                end
            end)
            local debugValid = ""
            if charLevelMap[i] then
                for area, _ in pairs(charLevelMap[i]) do
                    debugValid = debugValid..area..", "
                end
                log_to_console("   "..i.. " - " .. get_level_name(get_level_course_num(i), i, 1) .. " has valid areas: "..string.sub(debugValid, 1, -3))
            end
        end
    end
end

hook_event(HOOK_ON_MODS_LOADED, find_valid_areas)

evilFloorTypes = {
    [SURFACE_BURNING] = true,
    [SURFACE_DEEP_MOVING_QUICKSAND] = true,
    [SURFACE_DEEP_QUICKSAND] = true,
    [SURFACE_INSTANT_MOVING_QUICKSAND] = true,
    [SURFACE_INSTANT_QUICKSAND] = true,
    [SURFACE_DEATH_PLANE] = true,
    [SURFACE_VERY_SLIPPERY] = true,
    [SURFACE_VERTICAL_WIND] = true,
    [SURFACE_HORIZONTAL_WIND] = true,
}

function nearest_object_with_behavior_id_to_pos(x, y, z, bhvId)
    if not x or not y or not z or not bhvId then return end
    local nearest = nil;
    local nearestDist = 0;
    local o = obj_get_first_with_behavior_id(bhvId)
    while o do
        local dist = math.sqrt((o.oPosX - x)^2 + (o.oPosY - y)^2 + (o.oPosZ - z)^2);
        if (nearest == nil or dist < nearestDist) then
            nearest = o;
            nearestDist = dist;
        end
        o = obj_get_next_with_same_behavior_id(o)
    end

    return nearest, nearestDist
end