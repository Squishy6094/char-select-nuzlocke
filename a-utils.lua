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
    [SURFACE_WARP] = true,
    [SURFACE_WOBBLING_WARP] = true,
    [SURFACE_PAINTING_WARP_D3] = true,

    [SURFACE_PAINTING_WOBBLE_A6] = true,
    [SURFACE_PAINTING_WOBBLE_A7] = true,
    [SURFACE_PAINTING_WOBBLE_A8] = true,
    [SURFACE_PAINTING_WOBBLE_A9] = true,
    [SURFACE_PAINTING_WOBBLE_AA] = true,
    [SURFACE_PAINTING_WOBBLE_AB] = true,
    [SURFACE_PAINTING_WOBBLE_AC] = true,
    [SURFACE_PAINTING_WOBBLE_AD] = true,
    [SURFACE_PAINTING_WOBBLE_AE] = true,
    [SURFACE_PAINTING_WOBBLE_AF] = true,
    [SURFACE_PAINTING_WOBBLE_B0] = true,
    [SURFACE_PAINTING_WOBBLE_B1] = true,
    [SURFACE_PAINTING_WOBBLE_B2] = true,
    [SURFACE_PAINTING_WOBBLE_B3] = true,
    [SURFACE_PAINTING_WOBBLE_B4] = true,
    [SURFACE_PAINTING_WOBBLE_B5] = true,
    [SURFACE_PAINTING_WOBBLE_B6] = true,
    [SURFACE_PAINTING_WOBBLE_B7] = true,
    [SURFACE_PAINTING_WOBBLE_B8] = true,
    [SURFACE_PAINTING_WOBBLE_B9] = true,
    [SURFACE_PAINTING_WOBBLE_BA] = true,
    [SURFACE_PAINTING_WOBBLE_BB] = true,
    [SURFACE_PAINTING_WOBBLE_BC] = true,
    [SURFACE_PAINTING_WOBBLE_BD] = true,
    [SURFACE_PAINTING_WOBBLE_BE] = true,
    [SURFACE_PAINTING_WOBBLE_BF] = true,
    [SURFACE_PAINTING_WOBBLE_C0] = true,
    [SURFACE_PAINTING_WOBBLE_C1] = true,
    [SURFACE_PAINTING_WOBBLE_C2] = true,
    [SURFACE_PAINTING_WOBBLE_C3] = true,
    [SURFACE_PAINTING_WOBBLE_C4] = true,
    [SURFACE_PAINTING_WOBBLE_C5] = true,
    [SURFACE_PAINTING_WOBBLE_C6] = true,
    [SURFACE_PAINTING_WOBBLE_C7] = true,
    [SURFACE_PAINTING_WOBBLE_C8] = true,
    [SURFACE_PAINTING_WOBBLE_C9] = true,
    [SURFACE_PAINTING_WOBBLE_CA] = true,
    [SURFACE_PAINTING_WOBBLE_CB] = true,
    [SURFACE_PAINTING_WOBBLE_CC] = true,
    [SURFACE_PAINTING_WOBBLE_CD] = true,
    [SURFACE_PAINTING_WOBBLE_CE] = true,
    [SURFACE_PAINTING_WOBBLE_CF] = true,
    [SURFACE_PAINTING_WOBBLE_D0] = true,
    [SURFACE_PAINTING_WOBBLE_D1] = true,
    [SURFACE_PAINTING_WOBBLE_D2] = true,
    [SURFACE_PAINTING_WARP_D3] = true,
    [SURFACE_PAINTING_WARP_D4] = true,
    [SURFACE_PAINTING_WARP_D5] = true,
    [SURFACE_PAINTING_WARP_D6] = true,
    [SURFACE_PAINTING_WARP_D7] = true,
    [SURFACE_PAINTING_WARP_D8] = true,
    [SURFACE_PAINTING_WARP_D9] = true,
    [SURFACE_PAINTING_WARP_DA] = true,
    [SURFACE_PAINTING_WARP_DB] = true,
    [SURFACE_PAINTING_WARP_DC] = true,
    [SURFACE_PAINTING_WARP_DD] = true,
    [SURFACE_PAINTING_WARP_DE] = true,
    [SURFACE_PAINTING_WARP_DF] = true,
    [SURFACE_PAINTING_WARP_E0] = true,
    [SURFACE_PAINTING_WARP_E1] = true,
    [SURFACE_PAINTING_WARP_E2] = true,
    [SURFACE_PAINTING_WARP_E3] = true,
    [SURFACE_PAINTING_WARP_E4] = true,
    [SURFACE_PAINTING_WARP_E5] = true,
    [SURFACE_PAINTING_WARP_E6] = true,
    [SURFACE_PAINTING_WARP_E7] = true,
    [SURFACE_PAINTING_WARP_E8] = true,
    [SURFACE_PAINTING_WARP_E9] = true,
    [SURFACE_PAINTING_WARP_EA] = true,
    [SURFACE_PAINTING_WARP_EB] = true,
    [SURFACE_PAINTING_WARP_EC] = true,
    [SURFACE_PAINTING_WARP_ED] = true,
    [SURFACE_PAINTING_WARP_EE] = true,
    [SURFACE_PAINTING_WARP_EF] = true,
    [SURFACE_PAINTING_WARP_F0] = true,
    [SURFACE_PAINTING_WARP_F1] = true,
    [SURFACE_PAINTING_WARP_F2] = true,
    [SURFACE_PAINTING_WARP_F3] = true,
    [SURFACE_TTC_PAINTING_1] = true,
    [SURFACE_TTC_PAINTING_2] = true,
    [SURFACE_TTC_PAINTING_3] = true,
    [SURFACE_PAINTING_WARP_F7] = true,
    [SURFACE_PAINTING_WARP_F8] = true,
    [SURFACE_PAINTING_WARP_F9] = true,
    [SURFACE_PAINTING_WARP_FA] = true,
    [SURFACE_PAINTING_WARP_FB] = true,
    [SURFACE_PAINTING_WARP_FC] = true,
    [SURFACE_WOBBLING_WARP] = true,
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

-- passing a table like {255, 100, 20}

function color_to_string(r, g, b)
	local hexadecimal = ''

    local rgb = {math.floor(r)%256, math.floor(g)%256, math.floor(b)%256}
	for key, value in pairs(rgb) do
		local hex = ''

		while (value > 0) do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex			
		end

		if(string.len(hex) == 0)then
			hex = '00'

		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end

		hexadecimal = hexadecimal .. hex
	end

	return "\\#"..hexadecimal.."\\"
end

-- Custom mulberry32 based rng funcs for cross-device-compatibility

function imul(a, b)
    return math.u32(a * b)
end

function mulberry32(a)
    a = math.u32(a + 0x6D2B79F5)
    local t = a;
    t = imul(t ~ (t >> 15), t | 1);
    t = math.u32(t ~ (t + imul(t ~ (t >> 7), t | 61)))
    return math.u32(t ~ (t >> 14)) / 4294967296;
end

local mulberrySeed = 1
function mul_random_seed(seed)
    mulberrySeed = seed
end

function mul_random(a, b)
    local num = mulberry32(mulberrySeed)
    mulberrySeed = math.round(num*4294967296)
    if a then
        if b then
            return math.round(num*(b - a)) + a
        else
            return math.round(num*(a-1)) + 1
        end
    else
        return num
    end
end

for i = 0, 100 do
    print("DebugTest " .. i .. " - " ..mul_random())
end