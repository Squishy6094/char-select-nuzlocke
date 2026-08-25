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
    math.randomseed((gGlobalSyncTable.nuzlockeSeed + offset)%SEED_MAX)
end

-- Map out each level to a character
local function map_characters()
    -- Empty table
    local mappedChars = {}
    local mappedCharCount = 0
    for levelNum, levelTable in pairs(charLevelMap) do
        for areaNum, areaTable in pairs(levelTable) do
            charLevelMap[levelNum][areaNum] = {}
        end
    end
    nuzlocke_seed_rng()
    
    repeat
        for levelNum, levelTable in pairs(charLevelMap) do
            if mappedCharCount >= #charTable then break end
            -- Get Random Area
            local areaNum = 0
            repeat 
                areaNum = math.random(1, 7)
            until levelTable[areaNum]

            -- Get Random Character (without repeats)
            local charNum = 0
            repeat 
                charNum = math.random(1, #charTable)
            until not mappedChars[charNum]
            
            table.insert(levelTable[areaNum], charNum)
            log_to_console(charTable[charNum][1].name .. " placed in ["..levelNum.."/"..areaNum.."] " .. get_level_name(get_level_course_num(levelNum), levelNum, areaNum))
            mappedChars[charNum] = true
            mappedCharCount = mappedCharCount + 1
        end
    until mappedCharCount >= #charTable
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
    gMarioStates[0].health = 0x880
    local oChar = obj_get_first_with_behavior_id(id_bhvUnlockableChar)
    while oChar do
        obj_mark_for_deletion(oChar)
        oChar = obj_get_next_with_same_behavior_id(oChar)
    end
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

    --[[
    local m = gMarioStates[0]
    if m.controller.buttonPressed & D_JPAD ~= 0 then
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 300, m.pos.y, m.pos.z - 300, function(o)
            o.oCharNum = CT_CELENA
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 150, m.pos.y, m.pos.z - 300, function(o)
            o.oCharNum = 2
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x + 0, m.pos.y, m.pos.z - 300, function(o)
            o.oCharNum = 3
        end)
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, m.pos.x - 150, m.pos.y, m.pos.z - 300, function(o)
            o.oCharNum = 4
        end)
        spawn_sync_object(id_bhvBreakableBoxSmall, E_MODEL_BREAKABLE_BOX_SMALL, m.pos.x - 300, m.pos.y, m.pos.z - 300, function(o)
        end)
    end
    ]]

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
        r = charTable[o.oCharNum][1].color.r * 0.5 + 127,
        g = charTable[o.oCharNum][1].color.g * 0.5 + 127,
        b = charTable[o.oCharNum][1].color.b * 0.5 + 127,
    }
    oTagLib.obj_set_nametag(o, charTable[o.oCharNum].nickname, tagColor)
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
            nuzlocke_set_character_state(o.oCharNum, NUZLOCKE_CHAR_UNLOCKED)
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

local E_MODEL_GRAFFITI = smlua_model_util_get_id("char_graffiti_geo")

local function bhv_char_graffiti_init(o)
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    if nuzlocke_get_character_state(o.oCharNum) ~= NUZLOCKE_CHAR_LOCKED then
        obj_mark_for_deletion(o)
        return
    end
end

local function bhv_char_graffiti_loop(o)
    --o.oFaceAngleYaw = o.oVelY - (get_global_timer()%90)/90*0x1000
    --djui_chat_message_create(tostring(math.floor((get_global_timer()%90)/90*0x1000/0x100)))
end

id_bhvCharGraffiti = hook_behavior(nil, OBJ_LIST_GENACTOR, false, bhv_char_graffiti_init, bhv_char_graffiti_loop)

local fe_mat = gfx_get_from_name("mat_char_graffiti_graffiti")
local changed_objects = {}
---@param node GraphNode
function graffiti_geo_func(node, matStackIndex)
    local o = geo_get_current_object()

    local ptr = o._pointer
    local geo = cast_graph_node(node.next.next.next)

    local dlHead = gfx_get_from_name("graffiti_displaylist" .. ptr)
    if not dlHead then
        dlHead = gfx_create("graffiti_displaylist" .. ptr, 16)
        gfx_copy(dlHead, fe_mat, gfx_get_length(fe_mat))
    end
    
    if not changed_objects[o] then
        local cmdt = gfx_get_command(dlHead, 6)
        local texture = get_texture_info("char_select_graffiti_invert")--charSelect.character_get_graffiti(0) ---@type TextureInfo
        djui_chat_message_create("i'm RUNNINGG!!")
        gfx_set_command(cmdt, "gsDPSetTextureImage(%i, %i, 1, %t)", texture.format, texture.size, texture.texture)
        
        changed_objects[o] = true
    end

    --geo.displayList = dlHead
end

local function obj_unload(o)
    if changed_objects[o] then
        changed_objects[o] = nil
    end
end

hook_event(HOOK_ON_OBJECT_UNLOAD, obj_unload)

local function find_character_spawn()
    local spawnPos = nil
    local minX = -0x8000
    local maxX = 0x8000
    local minZ = -0x8000
    local maxZ = 0x8000
    local spawnStart = get_time()
    local spawnIteration = 0
    while spawnPos == nil do
        local spawnStep = 0
        spawnIteration = spawnIteration + 1
        local rayFloor = collision_find_surface_on_ray(math.random(minX, maxX), 0x4000, math.random(minZ, maxZ), 0, -0x8000, 0, 1)
        if rayFloor.surface and not evilFloorTypes[rayFloor.surface.type] and rayFloor.surface.normal.y > 0.95 and (rayFloor.hitPos.y > find_water_level(rayFloor.hitPos.x, rayFloor.hitPos.z) or spawnIteration > 1000) then
            spawnStep = spawnStep + 1
            local surfaceX = (rayFloor.surface.vertex1.x + rayFloor.surface.vertex2.x + rayFloor.surface.vertex3.x)/3
            local surfaceY = (rayFloor.surface.vertex1.y + rayFloor.surface.vertex2.y + rayFloor.surface.vertex3.y)/3
            local surfaceZ = (rayFloor.surface.vertex1.z + rayFloor.surface.vertex2.z + rayFloor.surface.vertex3.z)/3

            local avoidChar = nearest_object_with_behavior_id_to_pos(surfaceX, surfaceY, surfaceZ, id_bhvUnlockableChar)
            local avoidDoorWarp = nearest_object_with_behavior_id_to_pos(surfaceX, surfaceY, surfaceZ, id_bhvDoorWarp)

            local smallestEdge = nil
            for i = 0, 2 do
                local currNum = (i%3) + 1
                local nextNum = ((i+1)%3) + 1
                local currPos = rayFloor.surface["vertex"..tostring(currNum)]
                local nextPos = rayFloor.surface["vertex"..tostring(nextNum)]
                local edgeDist = math.sqrt((currPos.x - nextPos.x)^2 + (currPos.z - nextPos.z)^2)
                if not smallestEdge or smallestEdge > edgeDist then
                    smallestEdge = edgeDist
                end
            end

            local avoidDist = math.min(avoidChar and dist_between_object_and_point(avoidChar, surfaceX, surfaceY, surfaceZ) or 0x8000,
                avoidDoorWarp and dist_between_object_and_point(avoidDoorWarp, surfaceX, surfaceY, surfaceZ) or 0x8000)

            if (avoidDist > 500 or spawnIteration > 5000) and (smallestEdge < (100 + spawnIteration)) then --- math.floor(spawnIteration/100)*100 then
                local outofBounds = false
                for i = 0, 7 do
                    if not outofBounds then
                        local angle = i/8*0x10000
                        local ray = collision_find_surface_on_ray(surfaceX, surfaceY + 200, surfaceZ, sins(angle)*2000, 0, coss(angle)*2000)

                        if ray.surface then
                            local surfaceAngle = atan2s(ray.surface.normal.z, ray.surface.normal.x)
                            if math.abs(math.s16(surfaceAngle - angle)) < 0x1000 then
                                spawn_non_sync_object(id_bhvStaticObject, E_MODEL_SPARKLES, ray.hitPos.x, ray.hitPos.y, ray.hitPos.z, function(o)
                                    obj_set_billboard(o)
                                end)
                                outofBounds = true
                            end
                        end
                    end
                end
                if not outofBounds then
                    spawnStep = spawnStep + 1
                    spawnPos = {
                        x = surfaceX,
                        y = surfaceY,
                        z = surfaceZ,
                        yaw = 0,
                    }
                end
            end
        end 

        if get_time() - spawnStart > 10 then
            log_to_console(tostring("Character Select Nuzlocke: Character took 10 Seconds after "..tostring(spawnIteration).." iterations, got stuck on Step "..tostring(spawnStep)..", giving up."), CONSOLE_MESSAGE_ERROR)
            return {x = 0, y = 0, z = 0, yaw = 0}
        end
    end

    log_to_console(tostring("Character Select Nuzlocke: Character Spawned at ("..math.round(spawnPos.x)..", "..math.round(spawnPos.y)..", "..math.round(spawnPos.z)..") in [Level "..gNetworkPlayers[0].currLevelNum.." / Area "..gNetworkPlayers[0].currAreaIndex.."] on iteration "..tostring(spawnIteration)..", Took "..tostring(get_time() - spawnStart).." Seconds."))
    return spawnPos
end

local function find_griffiti_spawn(charObj)
    local m = gMarioStates[0] ---@type MarioState
    local spawnPos = nil
    local spawnIteration = 0
    local startPos = {
        x = m.spawnInfo.startPos.x,
        y = m.spawnInfo.startPos.y,
        z = m.spawnInfo.startPos.z
    }
    repeat
        spawnIteration = spawnIteration + 1
        if spawnIteration > 1000 and charObj then
            startPos.x = charObj.oPosX
            startPos.y = charObj.oPosY
            startPos.z = charObj.oPosZ
            spawnIteration = 0
        end
        local angleYaw = math.random(0, 0x10000)
        local floorHeight = find_floor(startPos.x, startPos.y, startPos.z)
        local ray = collision_find_surface_on_ray(startPos.x, floorHeight + 100, startPos.z, sins(angleYaw)*2000, math.random()*500 - spawnIteration, coss(angleYaw)*2000)
        if ray.surface ~= nil and not evilFloorTypes[ray.surface.type] then
            local spawnX = ((ray.surface.vertex1.x + ray.surface.vertex2.x + ray.surface.vertex3.x)/3 + ray.hitPos.x)*0.5
            local spawnY = ((ray.surface.vertex1.y + ray.surface.vertex2.y + ray.surface.vertex3.y)/3 + ray.hitPos.y)*0.5
            local spawnZ = ((ray.surface.vertex1.z + ray.surface.vertex2.z + ray.surface.vertex3.z)/3 + ray.hitPos.z)*0.5
            local avoidGraffiti = nearest_object_with_behavior_id_to_pos(spawnX, spawnY, spawnZ, id_bhvCharGraffiti)
            if not avoidGraffiti or dist_between_object_and_point(avoidGraffiti, spawnX, spawnY, spawnZ) > 200 then
                spawnPos = {
                    x = spawnX,
                    y = spawnY,
                    z = spawnZ,
                    normal = {
                        x = ray.surface.normal.x,
                        y = ray.surface.normal.y,
                        z = ray.surface.normal.z,
                    }
                }
            end
        end
    until spawnPos ~= nil

    return spawnPos
end

local function on_sync()
    local m = gMarioStates[0]
    local currLevel = gNetworkPlayers[0].currLevelNum
    local currArea = gNetworkPlayers[0].currAreaIndex
    if not charLevelMap[currLevel] or not charLevelMap[currLevel][currArea] then return end
    if obj_get_first_with_behavior_id(id_bhvActSelector) then return end
    --if obj_get_first_with_behavior_id(id_bhvUnlockableChar) then return end
    nuzlocke_seed_rng(currLevel*currArea)
    for i, charNum in pairs(charLevelMap[currLevel][currArea]) do
        local charSpawn = find_character_spawn()
        local charObj spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, charSpawn.x, charSpawn.y, charSpawn.z, function(o)
            o.oCharNum = charNum
        end)
        for i = 1, math.random(1, 3) do
            local graffitiSpawn = find_griffiti_spawn(charObj)
            spawn_sync_object(id_bhvCharGraffiti, E_MODEL_GRAFFITI, graffitiSpawn.x, graffitiSpawn.y, graffitiSpawn.z, function(o)
                local slopeAngle = atan2s(graffitiSpawn.normal.z, graffitiSpawn.normal.x)
                local tilt = 0
                local pitch = atan2s(math.sqrt(graffitiSpawn.normal.x * graffitiSpawn.normal.x + graffitiSpawn.normal.z * graffitiSpawn.normal.z), graffitiSpawn.normal.y)
                djui_chat_message_create(tostring(pitch))
                o.oFaceAnglePitch = (0x4000-pitch)*coss(tilt)
                o.oFaceAngleRoll = (0x4000-pitch)*sins(tilt)
                o.oFaceAngleYaw = slopeAngle + tilt
                
                --o.oFaceAngleRoll = math.random(-0x1000, 0x1000)
                obj_scale(o, 1 + math.random()*0.5)
                o.oCharNum = charNum
            end)
        end
    end

    --[[
    for i = 0, 10 do
        local spawnPos = find_character_spawn()
        spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, spawnPos.x, spawnPos.y, spawnPos.z, function(o)
            o.oCharNum = 1
        end)
    end
    ]]
end

local function set_lives_counter()
    local totalCharacters = nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED) - 1
    gMarioStates[0].numLives = totalCharacters
    hud_set_value(HUD_DISPLAY_LIVES, totalCharacters)
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_DEATH, queue_char_kill)
hook_event(HOOK_ON_SYNC_VALID, on_sync)
hook_event(HOOK_MARIO_UPDATE, set_lives_counter)
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