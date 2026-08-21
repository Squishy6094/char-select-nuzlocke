oTagLib = require("libs/oTagLib")

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

function obj_set_char_select_animation(o, charData, animID, animIDFallback)
    if not o or not animID then return end
    local anims = charSelect.character_get_animations(charData[1].ogModel)
    if anims and anims.anims then
        if anims.anims[animID] then
            smlua_anim_util_set_animation(o, anims.anims[animID])
        elseif anims.anims[animIDFallback] then
            smlua_anim_util_set_animation(o, anims.anims[animIDFallback])
        else
            o.header.gfx.animInfo.curAnim = animIDFallback and get_mario_vanilla_animation(animIDFallback) or get_mario_vanilla_animation(animID)
        end
    else
        o.header.gfx.animInfo.curAnim = animIDFallback and get_mario_vanilla_animation(animIDFallback) or get_mario_vanilla_animation(animID)
    end
    if o.header.gfx.animInfo.curAnim ~= nil then
        o.header.gfx.animInfo.animYTrans = o.header.gfx.animInfo.curAnim.animYTransDivisor 
    end
    o.header.gfx.animInfo.animFrame = 0
    o.header.gfx.animInfo.animTimer = 0
end

local varToChar = {
    [CHAR_SOUND_YAH_WAH_HOO] = "soundYahWahHoo",
    [CHAR_SOUND_HOOHOO] = "soundHoohoo",
    [CHAR_SOUND_YAHOO] = "soundYahoo",
    [CHAR_SOUND_UH] = "soundUh",
    [CHAR_SOUND_HRMM] = "soundHrmm",
    [CHAR_SOUND_WAH2] = "soundWah2",
    [CHAR_SOUND_WHOA] = "soundWhoa",
    [CHAR_SOUND_EEUH] = "soundEeuh",
    [CHAR_SOUND_ATTACKED] = "soundAttacked",
    [CHAR_SOUND_OOOF] = "soundOoof",
    [CHAR_SOUND_OOOF2] = "soundOoof2",
    [CHAR_SOUND_HERE_WE_GO] = "soundHereWeGo",
    [CHAR_SOUND_YAWNING] = "soundYawning",
    [CHAR_SOUND_SNORING1] = "soundSnoring1",
    [CHAR_SOUND_SNORING2] = "soundSnoring2",
    [CHAR_SOUND_WAAAOOOW] = "soundWaaaooow",
    [CHAR_SOUND_HAHA] = "soundHaha",
    [CHAR_SOUND_HAHA_2] = "soundHaha_2",
    [CHAR_SOUND_UH2] = "soundUh2",
    [CHAR_SOUND_UH2_2] = "soundUh2_2",
    [CHAR_SOUND_ON_FIRE] = "soundOnFire",
    [CHAR_SOUND_DYING] = "soundDying",
    [CHAR_SOUND_PANTING_COLD] = "soundPantingCold",
    [CHAR_SOUND_PANTING] = "soundPanting",
    [CHAR_SOUND_COUGHING1] = "soundCoughing1",
    [CHAR_SOUND_COUGHING2] = "soundCoughing2",
    [CHAR_SOUND_COUGHING3] = "soundCoughing3",
    [CHAR_SOUND_PUNCH_YAH] = "soundPunchYah",
    [CHAR_SOUND_PUNCH_HOO] = "soundPunchHoo",
    [CHAR_SOUND_MAMA_MIA] = "soundMamaMia",
    [CHAR_SOUND_GROUND_POUND_WAH] = "soundGroundPoundWah",
    [CHAR_SOUND_DROWNING] = "soundDrowning",
    [CHAR_SOUND_PUNCH_WAH] = "soundPunchWah",
    [CHAR_SOUND_YAHOO_WAHA_YIPPEE] = "soundYahooWahaYippee",
    [CHAR_SOUND_DOH] = "soundDoh",
    [CHAR_SOUND_GAME_OVER] = "soundGameOver",
    [CHAR_SOUND_HELLO] = "soundHello",
    [CHAR_SOUND_PRESS_START_TO_PLAY] = "soundPressStartToPlay",
    [CHAR_SOUND_TWIRL_BOUNCE] = "soundTwirlBounce",
    [CHAR_SOUND_SNORING3] = "soundSnoring3",
    [CHAR_SOUND_SO_LONGA_BOWSER] = "soundSoLongaBowser",
    [CHAR_SOUND_IMA_TIRED] = "soundImaTired",
    [CHAR_SOUND_LETS_A_GO] = "soundLetsAGo",
    [CHAR_SOUND_OKEY_DOKEY] = "soundOkeyDokey",
}

function play_char_select_character_sound(m, charData, charSound)
    if character_get_voice(charData[1].ogModel) then
        local prevModel = charSelect.gCSPlayers[m.playerIndex].modelId
        charSelect.gCSPlayers[m.playerIndex].modelId = charData[1].ogModel
        play_character_sound(m, charSound)
        charSelect.gCSPlayers[m.playerIndex].modelId = prevModel
    else
        play_sound(gCharacters[charData[1].baseChar][varToChar[charSound]], m.marioObj.header.gfx.cameraToObject)
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