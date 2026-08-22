if not charSelectExists then return end

---@class Object
---@field oIsChar integer
---@field oCharNum integer
---@field oCharAlt integer
---@field oCharPalette integer
---@field oCharAnim integer
---@field oCharHandState integer
define_custom_obj_fields({
    oIsChar = "f32",
    oCharNum = "f32",
    oCharAlt = "f32",
    oCharPalette = "f32",
    oCharAnim = "f32",

    oCharHandState = "f32",
})

local characterTable = charSelect.character_get_full_table()
local m = gMarioStates[0] ---@type MarioState
local np = gNetworkPlayers[0] ---@type NetworkPlayer
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

local function character_obj_set_animation(o, animID)
    if not o or o.oIsChar == 0 then return end
    local char = characterTable[o.oCharNum][o.oCharAlt]
    local anims = charSelect.character_get_animations(char.model)
    local animIDFallback = nil
    o.oCharAnim = animID
    if animID == charSelect.CS_ANIM_MENU then
        animIDFallback = CHAR_ANIM_FIRST_PERSON
    end 

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

local function character_obj_play_sound(o, charSound)
    if not o or o.oIsChar == 0 then return end
    local char = characterTable[o.oCharNum][o.oCharAlt]
    if charSelect.character_get_voice(char.model) then
        local prevModel = charSelect.gCSPlayers[m.playerIndex].modelId
        local prevPos = {x = m.pos.x, y = m.pos.y, z = m.pos.z}

        charSelect.gCSPlayers[m.playerIndex].modelId = char.model
        m.pos.x = o.oPosX
        m.pos.y = o.oPosY
        m.pos.z = o.oPosZ

        play_character_sound(m, charSound)

        charSelect.gCSPlayers[m.playerIndex].modelId = prevModel
        m.pos.x = prevPos.x
        m.pos.y = prevPos.y
        m.pos.z = prevPos.z
    else
        play_sound(gCharacters[char.baseChar][varToChar[charSound]], o.header.gfx.cameraToObject)
    end
end

local function character_obj_loop(o)
    o.oIsChar = 1
    obj_set_model_extended(o, characterTable[o.oCharNum][o.oCharAlt].model)
    if o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.sharedChild ~= nil then
        o.header.gfx.sharedChild.hookProcess = 1
    end
end

-- Handle Object Visuals
local modelRevert = {
    revert = true,
    eyeState = MARIO_EYES_OPEN,
    handState = MARIO_HAND_FISTS,
    punchState = 0,
    fadeWarpOpacity = 255,
    torsoAngleX = 0,
    torsoAngleZ = 0,
    headAngleX = 0,
    headAngleY = 0,
    headAngleZ = 0,
    headPosX = 0,
    headPosY = 0,
    headPosZ = 0,
    headRotationX = 0,
    headRotationY = 0,
    headRotationZ = 0,
    holpX = 0,
    holpY = 0,
    holpZ = 0,
    heldObj = nil,
    [PANTS]  = { r = 0, g = 0, b = 0 },
    [SHIRT]  = { r = 0, g = 0, b = 0 },
    [GLOVES] = { r = 0, g = 0, b = 0 },
    [SHOES]  = { r = 0, g = 0, b = 0 },
    [HAIR]   = { r = 0, g = 0, b = 0 },
    [SKIN]   = { r = 0, g = 0, b = 0 },
    [CAP]    = { r = 0, g = 0, b = 0 },
    [EMBLEM] = { r = 0, g = 0, b = 0 },
}

local blinkAnim = {
    MARIO_EYES_HALF_CLOSED,
    MARIO_EYES_CLOSED,
    MARIO_EYES_HALF_CLOSED,
    MARIO_EYES_OPEN,
    MARIO_EYES_HALF_CLOSED,
    MARIO_EYES_CLOSED,
    MARIO_EYES_HALF_CLOSED
}

local function character_obj_before_geo_process(node, _)
    if node == nil or node.hookProcess == 0 then return end
    local o = geo_get_current_object()
    if o == nil or o.oIsChar == 0 then return end
    local char = characterTable[o.oCharNum][o.oCharAlt]
    local model = char.model
    local charPalette = charSelect.character_get_current_palette(model, 1)
    local anims = charSelect.character_get_animations(model)
    if not charPalette then
        modelRevert.revert = false
    else
        modelRevert.revert = true
        for i = PANTS, EMBLEM do
            local playerColor = network_player_get_override_palette_color(np, i)
            modelRevert[i] = {
                r = playerColor.r,
                g = playerColor.g,
                b = playerColor.b,
            }
            network_player_set_override_palette_color(np, i, charPalette[i])
        end
    end

    modelRevert.eyeState = m.marioBodyState.eyeState
    modelRevert.handState = m.marioBodyState.handState
    modelRevert.eyeState = m.marioBodyState.punchState
    modelRevert.modelState = m.marioBodyState.modelState
    modelRevert.fadeWarpOpacity = m.fadeWarpOpacity
    modelRevert.holpX = m.marioBodyState.heldObjLastPosition.x
    modelRevert.holpY = m.marioBodyState.heldObjLastPosition.y
    modelRevert.holpZ = m.marioBodyState.heldObjLastPosition.z
    modelRevert.heldObj = m.heldObj
    m.heldObj = nil
    modelRevert.headAngleX = m.marioBodyState.headAngle.x
    modelRevert.headAngleY = m.marioBodyState.headAngle.y
    modelRevert.headAngleZ = m.marioBodyState.headAngle.z
    modelRevert.headPosX = m.marioBodyState.headPos.x
    modelRevert.headPosY = m.marioBodyState.headPos.y
    modelRevert.headPosZ = m.marioBodyState.headPos.z
    modelRevert.headRotationX = m.statusForCamera.headRotation.x
    modelRevert.headRotationY = m.statusForCamera.headRotation.y
    modelRevert.headRotationZ = m.statusForCamera.headRotation.z

    -- Set Defaults for Chars
    local blinkFrame = ((32 + (get_area_update_counter() + o.oCharNum * 32)) >> 1) & 0x1F;
    if (blinkFrame < 7) then
        m.marioBodyState.eyeState = blinkAnim[blinkFrame + 1];
    else
        m.marioBodyState.eyeState = MARIO_EYES_OPEN;
    end
    m.marioBodyState.handState = o.oCharHandState
    m.marioBodyState.punchState = 0
    if o.oAction > 2 and o.oVelY >= 30 then
        m.fadeWarpOpacity = math.round((1 - math.max(o.oVelY - 20, 0)/30)*255)
        m.marioBodyState.modelState = m.marioBodyState.modelState & ~0xFF;
        m.marioBodyState.modelState = m.marioBodyState.modelState | (0x100 | m.fadeWarpOpacity);
    end

    -- Find and apply any custom anims
    if anims then
        if anims.eyes and anims.eyes[o.oCharAnim] then
            m.marioBodyState.eyeState = run_func_or_get_var(anims.eyes[o.oCharAnim], m, o.header.gfx.animInfo.animFrame)
        end
        if o.oCharHandState == 0 and anims.hands and anims.hands[o.oCharAnim] then
            m.marioBodyState.handState = run_func_or_get_var(anims.hands[o.oCharAnim], m, o.header.gfx.animInfo.animFrame) or m.marioBodyState.handState
        end
    end

    modelRevert.torsoAngleX = m.marioBodyState.torsoAngle.x
    modelRevert.torsoAngleZ = m.marioBodyState.torsoAngle.z
    m.marioBodyState.torsoAngle.x = 0
    m.marioBodyState.torsoAngle.z = 0

    -- can use nM to make them look at you :3
    m.marioBodyState.headAngle.x = 0
    m.marioBodyState.headAngle.y = 0
    m.marioBodyState.headAngle.z = 0
    m.marioBodyState.headPos.x = 0
    m.marioBodyState.headPos.y = 0
    m.marioBodyState.headPos.z = 0
    m.statusForCamera.headRotation.x = 0
    m.statusForCamera.headRotation.y = 0
    m.statusForCamera.headRotation.z = 0
end

local function character_obj_on_geo_process(node, _)
    if not modelRevert.revert then return end
    if node == nil or node.hookProcess == 0 then return end
    local o = geo_get_current_object()
    if o == nil or o.oIsChar == 0 then return end

    if modelRevert.revert then
        for i = PANTS, EMBLEM do
            network_player_set_override_palette_color(np, i, modelRevert[i])
        end
    end
    
    m.marioBodyState.eyeState = modelRevert.eyeState
    m.marioBodyState.handState = modelRevert.handState
    m.marioBodyState.punchState = modelRevert.punchState
    m.marioBodyState.modelState = modelRevert.modelState
    m.fadeWarpOpacity = modelRevert.fadeWarpOpacity
    m.marioBodyState.torsoAngle.x = modelRevert.torsoAngleX
    m.marioBodyState.torsoAngle.z = modelRevert.torsoAngleZ
    m.marioBodyState.heldObjLastPosition.x = modelRevert.holpX
    m.marioBodyState.heldObjLastPosition.y = modelRevert.holpY
    m.marioBodyState.heldObjLastPosition.z = modelRevert.holpZ
    m.heldObj = modelRevert.heldObj
    m.marioBodyState.headAngle.x = modelRevert.headAngleX
    m.marioBodyState.headAngle.y = modelRevert.headAngleY
    m.marioBodyState.headAngle.z = modelRevert.headAngleZ
    m.marioBodyState.headPos.x = modelRevert.headPosX
    m.marioBodyState.headPos.y = modelRevert.headPosY
    m.marioBodyState.headPos.z = modelRevert.headPosZ
    m.statusForCamera.headRotation.x = modelRevert.headRotationX
    m.statusForCamera.headRotation.y = modelRevert.headRotationY
    m.statusForCamera.headRotation.z = modelRevert.headRotationZ
end

hook_event(HOOK_BEFORE_GEO_PROCESS, character_obj_before_geo_process)
hook_event(HOOK_ON_GEO_PROCESS, character_obj_on_geo_process)

return {
    character_obj_set_animation = character_obj_set_animation,
    character_obj_play_sound = character_obj_play_sound,
    character_obj_loop = character_obj_loop,
}