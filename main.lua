-- name: Character Select Nuzlocke
-- description: character select nuzlocke
-- pausable: true
-- category: cs gamemode
-- incompatible: gamemode

local NUZLOCKE_CHAR_LOCKED = 0
local NUZLOCKE_CHAR_UNLOCKED = 1
local NUZLOCKE_CHAR_DIED = 2

local SEED_MAX = 10000

local function save_file_prefix(str)
    return "saveFile"..tostring(get_current_save_file_num())..(save_file_get_using_backup_slot() and "B" or "")..str
end

local function update_save()
    if not network_is_server() then return end
    if save_file_get_flags() < mod_storage_load_number(save_file_prefix("progress"), 0) then
        -- Assume if progress is lost, that the save had been deleted
        log_to_console("Character Select Nuzlocke: Save Data Lost, Deleting Custom Save Flags!", CONSOLE_MESSAGE_WARNING)
        mod_storage_remove(save_file_prefix("seed"))
    end
    mod_storage_save_integer(save_file_prefix("progress"), save_file_get_flags())

    gGlobalSyncTable.nuzlockeSeed = mod_storage_load_integer(save_file_prefix("seed"), get_time()%SEED_MAX)
    mod_storage_save_integer(save_file_prefix("seed"), gGlobalSyncTable.nuzlockeSeed)
    log_to_console("Character Select Nuzlocke: Set Seed to '" .. gGlobalSyncTable.nuzlockeSeed .. "'")
end
update_save()

local charTable = {}
local charLevelRng = {}

local function block_menu_in_stages()
    return gNetworkPlayers[0].currCourseNum == 0
end

local function nuzlocke_set_character_state(charNum, charState)
    if not charTable then return end
    gGlobalSyncTable["charState"..charTable[charNum].saveName] = charState
end

local function nuzlocke_get_character_state(charNum)
    if not charTable then return end
    return gGlobalSyncTable["charState"..charTable[charNum].saveName]
end

local function nuzlocke_count_character_state(charState)
    local count = 0
    for charNum, _ in pairs(charTable) do
        if nuzlocke_get_character_state(charNum) == charState then
            count = count + 1
        end
    end
    return count
end

local function nuzlocke_seed_rng(offset)
    offset = offset or 0
    math.randomseed(gGlobalSyncTable.nuzlockeSeed + offset)
end

local prevUnlockState = {}
local function initial_setup()
    local charList = ""
	local starter = 0
	for i = 0, #charTable do
        nuzlocke_set_character_state(i, mod_storage_load_integer(save_file_prefix("charState"..charTable[i].saveName), i == starter and NUZLOCKE_CHAR_UNLOCKED or NUZLOCKE_CHAR_LOCKED))
        charList = charList .. " " .. charTable[i].saveName
        charSelect.character_set_locked(i, function()
            return nuzlocke_get_character_state(i) == NUZLOCKE_CHAR_UNLOCKED
        end, true)
	end
    mod_storage_save(save_file_prefix("charList"), charList)

    -- Map out each level to a character
    nuzlocke_seed_rng()
    
    local mappedCharCount = 0
    local subArea = 1
    repeat
        for i = 0, LEVEL_COUNT - 1 do
            local char = 0
            repeat
                local charRepeat = false
                char = math.random(1, #charTable)
                for _, area in pairs(charLevelRng) do
                    for _, areaChar in pairs(area) do
                        if not charRepeat and char == areaChar then
                            charRepeat = true
                        end
                    end
                end
            until not charRepeat
            if not charLevelRng[i] then
                charLevelRng[i] = {}
            end
            charLevelRng[i][subArea] = char
            log_to_console("Level " .. i .. " / Area " .. subArea .. " - " .. charTable[char][1].name)

            mappedCharCount = mappedCharCount + 1
            if #charTable == mappedCharCount then return end
        end
        subArea = subArea + 1
    until #charTable == mappedCharCount
end

local function unlock_random_character()
    if nuzlocke_count_character_state(NUZLOCKE_CHAR_LOCKED) == 0 then return end
    math.randomseed(gGlobalSyncTable.nuzlockeSeed)
	local unlocked = 0
    repeat
        unlocked = math.random(0, #charTable)
    until nuzlocke_get_character_state(unlocked) == NUZLOCKE_CHAR_LOCKED
	nuzlocke_set_character_state(unlocked, NUZLOCKE_CHAR_UNLOCKED)
end

local queueKill = -1
local isDying = false
local function queue_char_kill()
	queueKill = charSelect.character_get_current_number(0) or 0
    isDying = true
end

local function update()
    if startup_init_stall(1) then
		charTable = _G.charSelect.character_get_full_table()
        initial_setup()
    end
    --if not startup_init_stall() then return end

    if not isDying then
        if queueKill ~= -1 then
            nuzlocke_set_character_state(queueKill, NUZLOCKE_CHAR_DIED)
            queueKill = -1
        end
    else
        isDying = false
    end

    local m = gMarioStates[0]
    if m.controller.buttonPressed & D_JPAD ~= 0 then
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 300, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 1
            djui_chat_message_create("spawned")
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 150, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 2
            djui_chat_message_create("spawned")
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 0, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 3
            djui_chat_message_create("spawned")
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x - 150, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 4
            djui_chat_message_create("spawned")
        end)
        spawn_sync_object(id_bhvBreakableBoxSmall, E_MODEL_BREAKABLE_BOX_SMALL, m.pos.x - 300, m.pos.y, m.pos.z - 300, function(o)
        end)
    end

    if network_is_server() then
        for charNum, char in pairs(charTable) do
            local saveName = "charState"..char.saveName
            if not prevUnlockState[saveName] or prevUnlockState[saveName] ~= gGlobalSyncTable[saveName] then
                if gGlobalSyncTable[saveName] == NUZLOCKE_CHAR_DIED then
                    
                end
                prevUnlockState[saveName] = gGlobalSyncTable[saveName]
                if gGlobalSyncTable[saveName] == NUZLOCKE_CHAR_LOCKED then
                    mod_storage_remove(save_file_prefix(saveName))
                else
                    mod_storage_save_integer(save_file_prefix(saveName), gGlobalSyncTable[saveName])
                end
            end
        end
    end
end

---@param o Object
local function bhv_unlockable_char_init(o)
    if nuzlocke_get_character_state(o.oAnimState) ~= NUZLOCKE_CHAR_LOCKED then
        obj_mark_for_deletion(o)
        return
    end
    o.oFlags = OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO | OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW | OBJ_FLAG_0100
    o.globalPlayerIndex = MAX_PLAYERS
    o.hitboxRadius = 80
    o.hitboxHeight = 160
    tagColor = {
        r = charTable[o.oAnimState][1].color.r * 0.5 + 127,
        g = charTable[o.oAnimState][1].color.g * 0.5 + 127,
        b = charTable[o.oAnimState][1].color.b * 0.5 + 127,
    }
    oTagLib.obj_set_nametag(o, charTable[o.oAnimState].nickname, tagColor)
    local char = charTable[o.oAnimState]
    obj_set_char_select_animation(o, char, charSelect.CS_ANIM_MENU, MARIO_ANIM_FIRST_PERSON)
end

--[[
bhvPlayerNPC = hook_behavior(nil, OBJ_LIST_GENACTOR, true, function(o)
    playerNPC_pos = {x = o.oPosX, y = o.oPosY, z = o.oPosZ}
    o.oFlags = OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO | OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW
    o.header.gfx.animInfo.curAnim = get_mario_vanilla_animation(MARIO_ANIM_FIRST_PERSON)
    o.oInteractType = INTERACT_TEXT
    o.hitboxRadius = 100
    o.hitboxHeight = 100
    o.oGraphYOffset = o.oGraphYOffset + 40
    bhv_bobomb_buddy_init()
end, function(o)
    o.oIntangibleTimer = 0
    bhv_bobomb_buddy_loop()
end)
]]

---@param o Object
local function bhv_unlockable_char_loop(o)
    o.oIntangibleTimer = -1
    local nM = nearest_mario_state_to_object(o) ---@type MarioState

    -- Process Visuals
    local char = charTable[o.oAnimState]
    if o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.sharedChild ~= nil then
        o.header.gfx.sharedChild.hookProcess = 1
    end
    obj_set_model_extended(o, char[1].ogModel)

    if o.oAction == 0 then
        if nM and obj_check_hitbox_overlap(o, nM.marioObj) then
            o.oAction = 1
            nuzlocke_set_character_state(o.oAnimState, NUZLOCKE_CHAR_UNLOCKED)
        end
    elseif o.oAction == 1 then
        play_char_select_character_sound(nM, char, CHAR_SOUND_YAH_WAH_HOO)
        obj_set_char_select_animation(o, char, MARIO_ANIM_SINGLE_JUMP)
        o.oVelY = 30
        o.oAction = 2
    elseif o.oAction == 2 then
        o.oVelY = o.oVelY - 2
        if o.oVelY < -5 then
            o.oAction = 3 
        end
    elseif o.oAction == 3 then
        play_char_select_character_sound(nM, char, CHAR_SOUND_HERE_WE_GO)
        obj_set_char_select_animation(o, char, MARIO_ANIM_DOUBLE_JUMP_RISE)
        o.oAction = 4
        
    elseif o.oAction == 4 then
        o.oVelY = o.oVelY + 0.5
        o.oMoveAngleYaw = o.oMoveAngleYaw + math.clamp((o.oVelY + 5)*0x100, 0, 0x1800)
        if o.oVelY > 50 then
            obj_mark_for_deletion(o)
        end
    end
    o.oPosY = o.oPosY + o.oVelY
end

id_bhvUnlockableChar = hook_behavior(nil, OBJ_LIST_DEFAULT, false, bhv_unlockable_char_init, bhv_unlockable_char_loop)

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

local blinkAnim = { 1, 2, 1, 0, 1, 2, 1 }

local function unlockable_char_before_geo_process(node, _)
    if node == nil or node.hookProcess == 0 then return end
    local m = gMarioStates[0] ---@type MarioState
    local np = gNetworkPlayers[0]

    local o = geo_get_current_object()
    if o == nil or get_id_from_behavior(o.behavior) ~= id_bhvUnlockableChar then return end
    local nM = nearest_mario_state_to_object(o)
    local char = charTable[o.oAnimState]
    local charPalette = charSelect.character_get_current_palette(char[1].ogModel, 1)
    local anims = charSelect.character_get_animations(char[1].ogModel)
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
    local blinkFrame = ((1 * 32 + (get_area_update_counter() + o.oAnimState * 32)) >> 1) & 0x1F;
    if (blinkFrame < 7) then
        m.marioBodyState.eyeState = blinkAnim[blinkFrame + 1];
    else
        m.marioBodyState.eyeState = MARIO_EYES_OPEN;
    end
    m.marioBodyState.handState = o.oAction < 3 and MARIO_HAND_FISTS or MARIO_HAND_OPEN
    m.marioBodyState.punchState = 0
    if o.oAction > 2 and o.oVelY >= 30 then
        m.fadeWarpOpacity = math.round((1 - math.max(o.oVelY - 20, 0)/30)*255)
        m.marioBodyState.modelState = m.marioBodyState.modelState & ~0xFF;
        m.marioBodyState.modelState = m.marioBodyState.modelState | (0x100 | m.fadeWarpOpacity);
    end

    -- Find and apply any custom anims
    if anims and o.oAction < 1 then
        if anims.eyes and anims.eyes[charSelect.CS_ANIM_MENU] then
            m.marioBodyState.eyeState = run_func_or_get_var(anims.eyes[charSelect.CS_ANIM_MENU], m, o.header.gfx.animInfo.animFrame)
        end
        if anims.hands and anims.hands[charSelect.CS_ANIM_MENU] then
            m.marioBodyState.handState = run_func_or_get_var(anims.hands[charSelect.CS_ANIM_MENU], m, o.header.gfx.animInfo.animFrame) or m.marioBodyState.handState
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

local function unlockable_char_on_geo_process(node, _)
    if not modelRevert.revert then return end
    if node == nil or node.hookProcess == 0 then return end
    local m = gMarioStates[0] ---@type MarioState
    local np = gNetworkPlayers[0]

    local o = geo_get_current_object()
    if o == nil or get_id_from_behavior(o.behavior) ~= id_bhvUnlockableChar then return end
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

hook_event(HOOK_BEFORE_GEO_PROCESS, unlockable_char_before_geo_process)
hook_event(HOOK_ON_GEO_PROCESS, unlockable_char_on_geo_process)

local bhvList1ups = {
    id_bhv1Up,
    id_bhv1upJumpOnApproach,
    id_bhv1upRunningAway,
    id_bhv1upSliding,
    id_bhv1upWalking,

    id_bhvHidden1up,
    id_bhvHidden1upInPole,
    id_bhvHidden1upInPoleSpawner,

    id_bhvStar,
    id_bhvStarSpawnCoordinates,
    id_bhvHiddenStar,
    id_bhvRedCoinStarMarker
}

local function on_sync()
    local m = gMarioStates[0]
    local currLevel = gNetworkPlayers[0].currLevelNum
    local currArea = gNetworkPlayers[0].currAreaIndex
    if not charLevelRng[currLevel] or not charLevelRng[currLevel][currArea] then return end
    djui_chat_message_create("clear")
    local spawnPosList = {}
    for _, bhvId in pairs(bhvList1ups) do
        local o1up = obj_get_first_with_behavior_id(bhvId)
        while o1up ~= nil do
            local floorHeight, floor = find_floor(o1up.oPosX, o1up.oPosY, o1up.oPosZ)
            --local angle = math.random(0, 0x10000)
            table.insert(spawnPosList, {
                x = (floor.vertex1.x + floor.vertex2.x + floor.vertex3.x)/3,
                y = (floor.vertex1.y + floor.vertex2.y + floor.vertex3.y)/3,
                z = (floor.vertex1.z + floor.vertex2.z + floor.vertex3.z)/3
            })
            o1up = obj_get_next_with_same_behavior_id(o1up)
            djui_chat_message_create("1up")
        end
    end
    if #spawnPosList == 0 then return end
    nuzlocke_seed_rng()
    local spawnPos = spawnPosList[math.random(1, #spawnPosList)]

    spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, spawnPos.x, spawnPos.y, spawnPos.z, function(o)
        o.oAnimState = charLevelRng[currLevel][currArea]
        djui_chat_message_create("spawned")
    end)
end

local function hud_render_behind()
    local totalCharacters = nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED)
    gMarioStates[0].numLives = totalCharacters
    hud_set_value(HUD_DISPLAY_LIVES, totalCharacters)
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_DEATH, queue_char_kill)
hook_event(HOOK_ON_SYNC_VALID, on_sync)
hook_event(HOOK_ON_HUD_RENDER_BEHIND, hud_render_behind)
_G.charSelect.hook_allow_menu_open(block_menu_in_stages)

local function set_seed(msg)
    if not network_is_server() then return end
    local prevSeed = gGlobalSyncTable.nuzlockeSeed
    local seed = tonumber(msg) or math.random(0, SEED_MAX - 1)
    seed = math.round(seed)%SEED_MAX
    
    gGlobalSyncTable.nuzlockeSeed = seed
    mod_storage_save_integer(save_file_prefix("seed"), gGlobalSyncTable.nuzlockeSeed)
    djui_chat_message_create("Nuzlocke Seed changed: " .. prevSeed .. " -> " .. gGlobalSyncTable.nuzlockeSeed)
    return true
end

hook_chat_command("nuzlocke-seed", "Set the Character Select Nuzlocke Seed [0 - "..(SEED_MAX - 1).."]", set_seed)