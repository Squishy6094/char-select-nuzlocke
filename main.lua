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

local function update_save(reset, seed)
    save_file_set_using_backup_slot(true)
    if not network_is_server() then return end
    if save_file_get_flags() < mod_storage_load_number(save_file_prefix("progress"), 0) or reset then
        -- Assume if progress is lost, that the save had been deleted
        log_to_console("Character Select Nuzlocke: Save Data Lost, Deleting Custom Save Flags!", CONSOLE_MESSAGE_WARNING)
        mod_storage_remove(save_file_prefix("seed"))
        local charFieldList = string_split(mod_storage_load(save_file_prefix("charList"), ""))
        for _, charName in pairs(charFieldList) do
            mod_storage_remove(save_file_prefix("charState"..charName))
        end
    end
    mod_storage_save_integer(save_file_prefix("progress"), save_file_get_flags())

    gGlobalSyncTable.nuzlockeSeed = seed or mod_storage_load_integer(save_file_prefix("seed"), get_time()%SEED_MAX)
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
    if not charTable or not charNum or not charState then return end
    gGlobalSyncTable["charState"..charTable[charNum].saveName] = charState
end

local function nuzlocke_get_character_state(charNum)
    if not charTable or not charNum then return end
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

-- Map out each level to a character
local function map_characters()
    nuzlocke_seed_rng()
    
    charLevelRng = {}
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

local prevUnlockState = {}
local function initial_setup()
	local starter = 0
	for i = 0, #charTable do
        nuzlocke_set_character_state(i, mod_storage_load_integer(save_file_prefix("charState"..charTable[i].saveName), i == starter and NUZLOCKE_CHAR_UNLOCKED or NUZLOCKE_CHAR_LOCKED))
        charSelect.character_set_locked(i, function()
            return nuzlocke_get_character_state(i) == NUZLOCKE_CHAR_UNLOCKED
        end, i ~= 0)
	end

    map_characters()
end

local function reset_new_game()
	for i = 0, #charTable do
        nuzlocke_set_character_state(i, i == 0 and NUZLOCKE_CHAR_UNLOCKED or NUZLOCKE_CHAR_LOCKED)
	end

    map_characters()
end

local queueKill = -1
local isDying = false
local function queue_char_kill()
	queueKill = charSelect.character_get_current_number(0) or 0
    isDying = true
end

local function reset_save(seed)
    save_file_erase_current_backup_save()
    warp_to_start_level()
    update_save(true, seed)
    reset_new_game()
end

local function update()
    if startup_init_stall(1) then
		charTable = _G.charSelect.character_get_full_table()
        initial_setup()
    end
    if not startup_init_stall() then return end

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
            o.oAnimState = CT_CELENA
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 150, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 2
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 0, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 3
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x - 150, m.pos.y, m.pos.z - 300, function(o)
            o.oAnimState = 4
        end)
        spawn_sync_object(id_bhvBreakableBoxSmall, E_MODEL_BREAKABLE_BOX_SMALL, m.pos.x - 300, m.pos.y, m.pos.z - 300, function(o)
        end)
    end

    if network_is_server() then
        local charList = ""
        for charNum, char in pairs(charTable) do
            local saveName = "charState"..char.saveName
            if not prevUnlockState[saveName] or prevUnlockState[saveName] ~= gGlobalSyncTable[saveName] then
                prevUnlockState[saveName] = gGlobalSyncTable[saveName]
                if gGlobalSyncTable[saveName] == NUZLOCKE_CHAR_LOCKED then
                    mod_storage_remove(save_file_prefix(saveName))
                else
                    charList = charList .. " " .. char.saveName
                    mod_storage_save_integer(save_file_prefix(saveName), gGlobalSyncTable[saveName])
                end
            end
        end
        mod_storage_save(save_file_prefix("charList"), charList)

        if nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED) == 0 then
            reset_save()
        end
    end
end

---@param o Object
local function bhv_unlockable_char_init(o)
    o.oCharNum = o.oAnimState
    o.oCharAlt = 1
    o.oCharPalette = 1
    if nuzlocke_get_character_state(o.oCharNum) ~= NUZLOCKE_CHAR_LOCKED then
        obj_mark_for_deletion(o)
        return
    end
    o.oFlags = OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO | OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW | OBJ_FLAG_0100
    o.globalPlayerIndex = 0
    o.hitboxRadius = 80
    o.hitboxHeight = 160
    tagColor = {
        r = charTable[o.oAnimState][1].color.r * 0.5 + 127,
        g = charTable[o.oAnimState][1].color.g * 0.5 + 127,
        b = charTable[o.oAnimState][1].color.b * 0.5 + 127,
    }
    oTagLib.obj_set_nametag(o, charTable[o.oAnimState].nickname, tagColor)
end

---@param o Object
local function bhv_unlockable_char_loop(o)
    charSelectObjs.character_obj_loop(o)
    o.oIntangibleTimer = -1
    local nM = nearest_mario_state_to_object(o) ---@type MarioState

    if o.oAction == 0 then
        charSelectObjs.character_obj_set_animation(o, charSelect.CS_ANIM_MENU)
        o.oAction = o.oAction + 1
    elseif o.oAction == 1 then
        if nM and obj_check_hitbox_overlap(o, nM.marioObj) then
            nuzlocke_set_character_state(o.oAnimState, NUZLOCKE_CHAR_UNLOCKED)
            o.oAction = o.oAction + 1
        end
    elseif o.oAction == 2 then
        charSelectObjs.character_obj_play_sound(o, CHAR_SOUND_YAH_WAH_HOO)
        charSelectObjs.character_obj_set_animation(o, MARIO_ANIM_SINGLE_JUMP)
        o.oVelY = 30
        o.oAction = o.oAction + 1
    elseif o.oAction == 3 then
        o.oVelY = o.oVelY - 2
        if o.oVelY < -5 then
            o.oAction = o.oAction + 1
        end
    elseif o.oAction == 4 then
        charSelectObjs.character_obj_play_sound(o, CHAR_SOUND_HERE_WE_GO)
        charSelectObjs.character_obj_set_animation(o, MARIO_ANIM_DOUBLE_JUMP_RISE)
        o.oCharHandState = MARIO_HAND_OPEN
        o.oAction = o.oAction + 1
    elseif o.oAction == 5 then
        o.oVelY = o.oVelY + 0.5
        o.oMoveAngleYaw = o.oMoveAngleYaw + math.clamp((o.oVelY + 5)*0x100, 0, 0x1800)
        if o.oVelY > 50 then
            obj_mark_for_deletion(o)
        end
    end
    o.oPosY = o.oPosY + o.oVelY
end

id_bhvUnlockableChar = hook_behavior(nil, OBJ_LIST_DEFAULT, false, bhv_unlockable_char_init, bhv_unlockable_char_loop)

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
        end
    end
    if #spawnPosList == 0 then return end
    nuzlocke_seed_rng()
    local spawnPos = spawnPosList[math.random(1, #spawnPosList)]

    spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, spawnPos.x, spawnPos.y, spawnPos.z, function(o)
        o.oAnimState = charLevelRng[currLevel][currArea]
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
    local seed = tonumber(msg) or math.random(0, SEED_MAX - 1)
    seed = math.round(seed)%SEED_MAX
    local prevSeed = gGlobalSyncTable.nuzlockeSeed
    reset_save(seed)
    djui_chat_message_create("Nuzlocke Seed changed: " .. prevSeed .. " -> " .. gGlobalSyncTable.nuzlockeSeed)
    return true
end

hook_chat_command("nuzlocke-seed", "Set the Character Select Nuzlocke Seed [0 - "..(SEED_MAX - 1).."]", set_seed)