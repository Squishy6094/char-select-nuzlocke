-- name: Character Select Nuzlocke
-- description: character select nuzlocke
-- category: character gamemode
-- incompatible: gamemode

charTable = {}

gServerSettings.playerKnockbackStrength = 10
gServerSettings.bubbleDeath = false
gLevelValues.pauseExitAnywhere = false
if gServerSettings.playerInteractions == PLAYER_INTERACTIONS_PVP then
    gServerSettings.playerInteractions = PLAYER_INTERACTIONS_SOLID
end

NUZLOCKE_CHAR_LOCKED = 0
NUZLOCKE_CHAR_UNLOCKED = 1
NUZLOCKE_CHAR_DIED = 2

local SEED_MAX = 10000

local characterMods = {}
local function check_character_packs()
    if not charTable or not network_is_server() then return end 

    for i = 0, #charTable do
        characterMods[charTable[i].modData.name] = 0
    end

    local modStorage = mod_storage_load_all()

    if modStorage then
        for key, value in pairs(modStorage) do
            if string.find(key, save_file_prefix("enabledPack")) then
                if characterMods[value] == 0 then
                    characterMods[value] = 1
                else
                    characterMods[value] = 2
                end
            end
        end

        for name, status in pairs(characterMods) do
            if status == 0 then
                continueError = continueError .. "\n\\#fff\\Extra Pack: " .. name
            end
            if status == 2 then
                continueError = continueError .. "\n\\#fff\\Missing Pack: " .. name
            end
        end
    end
end

local function update_save(reset, seed)
    if not network_is_server() then return end

    if save_file_get_flags() < mod_storage_load_number(save_file_prefix("progress"), 0) or reset then
        -- Assume if progress is lost, that the save had been deleted
        log_to_console("Character Select Nuzlocke: Save Data Lost, Deleting Custom Save Flags!", CONSOLE_MESSAGE_WARNING)
        mod_storage_remove(save_file_prefix("seed"))
        -- Clear Collected Char Flags
        local modStorage = mod_storage_load_all()
        if modStorage then
            for key, value in pairs(modStorage) do
                if string.find(key, save_file_prefix("charState")) then
                    mod_storage_remove(key)
                end
            end
        end

        mod_storage_save_integer(save_file_prefix("progress"), 0)
    else
        mod_storage_save_integer(save_file_prefix("progress"), save_file_get_flags())
    end

    gGlobalSyncTable.nuzlockeSeed = seed or mod_storage_load_integer(save_file_prefix("seed"), get_time()%SEED_MAX)
    mod_storage_save_integer(save_file_prefix("seed"), gGlobalSyncTable.nuzlockeSeed)
    log_to_console("Character Select Nuzlocke: Set Seed to '" .. gGlobalSyncTable.nuzlockeSeed .. "'")
end
update_save()

local function block_menu_in_stages()
    return gNetworkPlayers[0].currCourseNum == 0
end

function nuzlocke_set_character_state(charNum, charState)
    if not charTable or not charNum or not charState then return end
    gGlobalSyncTable["charState"..charTable[charNum].saveName] = charState
end

function nuzlocke_get_character_state(charNum)
    if not charTable or not charNum then return end
    return gGlobalSyncTable["charState"..charTable[charNum].saveName]
end

function nuzlocke_count_character_state(charState)
    local count = 0
    for charNum, _ in pairs(charTable) do
        if nuzlocke_get_character_state(charNum) == charState then
            count = count + 1
        end
    end
    return count
end

local function nuzlocke_seed_rng(offset)
    if not gGlobalSyncTable.nuzlockeSeed then return false end
    offset = offset or 0
    mul_random_seed((gGlobalSyncTable.nuzlockeSeed + offset)%SEED_MAX)
    return true
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
    log_to_console("Character Select Nuzlocke: Mapping Characters...")
    
    local levelLoop = 0
    repeat
        for levelNum, levelTable in pairs(charLevelMap) do
            if mappedCharCount >= #charTable then break end
            -- Get Random Area
            local areaNum = 0
            repeat 
                areaNum = mul_random(1, 7)
            until levelTable[areaNum]

            -- Get Random Character (without repeats)
            local charNum = 0
            repeat 
                charNum = mul_random(1, #charTable)
            until not mappedChars[charNum]
            
            table.insert(levelTable[areaNum], charNum)
            mappedChars[charNum] = true
            mappedCharCount = mappedCharCount + 1
        end
        levelLoop = levelLoop + 1
    until mappedCharCount >= #charTable or (gGlobalSyncTable.nuzCharsInLevel > 0 and gGlobalSyncTable.nuzCharsInLevel <= levelLoop)

    for levelNum, levelTable in pairs(charLevelMap) do
        for areaNum, areaTable in pairs(levelTable) do
            if #areaTable > 0 then
                log_to_console("  "..get_level_name(get_level_course_num(levelNum), levelNum, areaNum) .. " [" .. levelNum .. "/" .. areaNum .. "]")
            end
            for _, charNum in pairs(areaTable) do
                log_to_console("    "..charTable[charNum][1].name)
            end
        end
    end
end

local prevUnlockState = {}
local function initial_setup()
	for i = 0, #charTable do
        if network_is_server() then
            nuzlocke_set_character_state(i, mod_storage_load_integer(save_file_prefix("charState"..charTable[i].saveName), i == 0 and NUZLOCKE_CHAR_UNLOCKED or NUZLOCKE_CHAR_LOCKED))
        else
            log_to_console("Synced char state "..charTable[i].saveName.." = "..nuzlocke_get_character_state(i))
        end
        charSelect.character_set_locked(i, function()
            return nuzlocke_get_character_state(i) == NUZLOCKE_CHAR_UNLOCKED
        end, false)
	end

    map_characters()
end

local function reset_characters()
	for i = 0, #charTable do
        nuzlocke_set_character_state(i, i == 0 and NUZLOCKE_CHAR_UNLOCKED or NUZLOCKE_CHAR_LOCKED)
	end

    map_characters()
end

local function randomize_character()
    if #charTable > 0 and gGlobalSyncTable.nuzMixupMode ~= 0 then
        local charNum = CT_MARIO
        if nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED) > 0 then
            repeat
                charNum = math.random(0, #charTable)
            until nuzlocke_get_character_state(charNum) == NUZLOCKE_CHAR_UNLOCKED
        end

        local charAlt = math.random(1, #charTable[charNum])
        charSelect.character_set_current_number(charNum, charAlt)
    end
end

local queueKill = -1
local isDying = false
local function queue_char_kill()
	queueKill = charSelect.character_get_current_number(0) or 0
    isDying = true
end

PACKET_TYPE_RESET = 1
function reset_save(seed, noSync)
    save_file_erase(saveFile)
    save_file_do_save(saveFile, 1)
    save_file_reload(0)
    warp_to_start_level()
    gMarioStates[0].health = 0x880
    local oChar = obj_get_first_with_behavior_id(id_bhvUnlockableChar)
    while oChar do
        obj_mark_for_deletion(oChar)
        oChar = obj_get_next_with_same_behavior_id(oChar)
    end
    update_save(true, seed)
    reset_characters()

    local packCount = 0
    for name, status in pairs(characterMods) do
        if status ~= 2 then
            mod_storage_save(save_file_prefix("enabledPack"..packCount), name)
            packCount = packCount + 1
        end
    end
    mod_storage_save(save_file_prefix("romhack"), currRomhack)

    gGlobalSyncTable.nuzOptionsDone = 1


    if not noSync then
        network_send(true, {
            type = PACKET_TYPE_RESET,
            index = network_global_index_from_local(0),
            seed = seed
        })
    end
end

local function on_packet_recieve(data)
    if data.type == PACKET_TYPE_RESET then
        reset_save(data.seed, true)
    end
end

local syncedClient = false
local function update()
    if not startup_init_stall() then return end
    if (network_is_server() or gGlobalSyncTable.nuzlockeSeed ~= nil) and not syncedClient then
		charTable = _G.charSelect.character_get_full_table()
        check_character_packs()
        initial_setup()
        if mod_storage_load_integer(save_file_prefix("progress"), 0) == 0 and nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED) <= 1 then
            continueError = "\nNo Save Data"
        end
        syncedClient = true
    end

    if not isDying and gMarioStates[0].action & ACT_GROUP_CUTSCENE == 0 then
        if queueKill ~= -1 then
            nuzlocke_set_character_state(queueKill, NUZLOCKE_CHAR_DIED)
            local charData = charTable[queueKill][1]
            djui_popup_create_global("Character Select Nuzlocke:\n"..color_to_string(charData.color.r*0.5 + 127, charData.color.g*0.5 + 127, charData.color.b*0.5 + 127)..charData.name.."\\#dcdcdc\\ was lost by "..network_get_player_text_color_string(0)..gNetworkPlayers[0].name, 2)
            queueKill = -1
            randomize_character()
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
            gGlobalSyncTable.nuzOptionsDone = 0
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
    network_init_object(o, false, {
        "oCharNum",
        "oCharAlt",
        "oCharPalette",
        "oAction",
        "oPosY",
        "oVelY",
    })
end

---@param o Object
local function bhv_unlockable_char_loop(o)
    charSelectObjs.character_obj_loop(o)
    o.oIntangibleTimer = -1
    local nM = nearest_mario_state_to_object(o) ---@type MarioState

    if o.oAction == 0 then
        charSelectObjs.character_obj_set_animation(o, charSelect.CS_ANIM_MENU)
        if nM and obj_check_hitbox_overlap(o, nM.marioObj) then
            nuzlocke_set_character_state(o.oCharNum, NUZLOCKE_CHAR_UNLOCKED)
            if sync_object_is_owned_locally(o.oSyncID) then
                local charData = charTable[o.oCharNum][1]
                djui_popup_create_global("Character Select Nuzlocke:\n"..color_to_string(charData.color.r*0.5 + 127, charData.color.g*0.5 + 127, charData.color.b*0.5 + 127)..charData.name.."\\#dcdcdc\\ was found by "..network_get_player_text_color_string(nM.playerIndex)..gNetworkPlayers[nM.playerIndex].name, 2)
            end
            o.oAction = o.oAction + 1
            network_send_object(o, true)
        end
    elseif o.oAction == 1 then
        if o.oTimer == 0 then
            charSelectObjs.character_obj_play_sound(o, CHAR_SOUND_YAH_WAH_HOO)
            o.oVelY = 30
        end
        charSelectObjs.character_obj_set_animation(o, MARIO_ANIM_SINGLE_JUMP)
        o.oVelY = o.oVelY - 2
        if o.oVelY < -5 then
            o.oAction = o.oAction + 1
            network_send_object(o, true)
        end
    elseif o.oAction == 2 then
        if o.oTimer == 0 then
            charSelectObjs.character_obj_play_sound(o, CHAR_SOUND_HERE_WE_GO)
        end
        charSelectObjs.character_obj_set_animation(o, MARIO_ANIM_DOUBLE_JUMP_RISE)
        o.oCharHandState = MARIO_HAND_OPEN
        o.oVelY = o.oVelY + 0.5
        o.oMoveAngleYaw = o.oMoveAngleYaw + math.clamp((o.oVelY + 5)*0x100, 0, 0x1800)
        if o.oVelY > 50 then
            obj_mark_for_deletion(o)
            network_send_object(o, true)
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
    network_init_object(o, false, {
        "oCharNum",
    })
end

local function bhv_char_graffiti_loop(o)
end

id_bhvCharGraffiti = hook_behavior(nil, OBJ_LIST_GENACTOR, false, bhv_char_graffiti_init, bhv_char_graffiti_loop)

local graffiti_mesh_layer = gfx_get_from_name("char_graffiti_char_graffiti_mesh_layer_5")
local graffiti_mat = gfx_get_from_name("mat_char_graffiti_graffiti")

local changed_objects = {}
function graffiti_geo_func(node, matStackIndex)
    local o = geo_get_current_object()

    local ptr = o._pointer
    local geo = cast_graph_node(node.next)
    ---@cast geo GraphNodeDisplayList

    local meshRoot = gfx_get_from_name("graffiti_dl_mesh_layer" .. o.oCharNum)
    if not meshRoot then
        meshRoot = gfx_create("graffiti_dl_mesh_layer" .. o.oCharNum, gfx_get_length(graffiti_mesh_layer))
        gfx_copy(meshRoot, graffiti_mesh_layer, gfx_get_length(graffiti_mesh_layer))
    end

    local matRoot = gfx_get_from_name("graffiti_dl_mat" .. o.oCharNum)
    if not matRoot then
        matRoot = gfx_create("graffiti_dl_mat" .. o.oCharNum, gfx_get_length(graffiti_mat))
        gfx_copy(matRoot, graffiti_mat, gfx_get_length(graffiti_mat))
    end
    
    if not changed_objects[o] then
        local cmdMat = gfx_get_command(matRoot, 9)
        local texture = charSelect.character_get_graffiti(o.oCharNum)
        gfx_set_command(cmdMat, "gsDPSetTextureImage(G_IM_FMT_RGBA, G_IM_SIZ_16b_LOAD_BLOCK, 1, %t)", texture.texture)

        local cmdMesh = gfx_get_command(meshRoot, 4)
        gfx_set_command(cmdMesh, "gsSPDisplayList(%g)", matRoot)
        changed_objects[o] = true
    end
    geo.displayList = meshRoot
end

local function obj_unload(o)
    if changed_objects[o] then
        changed_objects[o] = nil
    end
end

hook_event(HOOK_ON_OBJECT_UNLOAD, obj_unload)

local levelMinX = -0x4000
local levelMaxX = 0x4000
local levelMinZ = -0x4000
local levelMaxZ = 0x4000
local checkCount = 10
local function find_level_bounds()
    levelMinX = -0x4000
    levelMaxX = 0x4000
    levelMinZ = -0x4000
    levelMaxZ = 0x4000

    -- Min X Pos
    local dist = nil
    for distMult = 16, 0, -1 do
        if not dist then
            for i = -checkCount, checkCount do
                local ray = collision_find_surface_on_ray(levelMinX*(distMult/16), 0x4000, 0x4000*(i/checkCount), 0, -0x8000, 0, 1)
                if ray.surface ~= nil then
                    dist = ray.hitPos.x
                end
            end
        end
    end
    levelMinX = dist and math.round(dist) or levelMinX
    
    -- Max X Pos
    local dist = nil
    for distMult = 16, 0, -1 do
        if not dist then
            for i = -checkCount, checkCount do
                local ray = collision_find_surface_on_ray(levelMaxX*(distMult/16), 0x4000, 0x4000*(i/checkCount), 0, -0x8000, 0, 1)
                if ray.surface ~= nil then
                    dist = ray.hitPos.x
                end
            end
        end
    end
    levelMaxX = dist and math.round(dist) or levelMaxX


    -- Min Z Pos
    local dist = nil
    for distMult = 16, 0, -1 do
        if not dist then
            for i = -checkCount, checkCount do
                local ray = collision_find_surface_on_ray(0x4000*(i/checkCount), 0x4000, levelMinZ*(distMult/16), 0, -0x8000, 0, 1)
                if ray.surface ~= nil then
                    dist = ray.hitPos.z
                end
            end
        end
    end
    levelMinZ = dist and math.round(dist) or levelMinZ
    
    -- Max Z Pos
    local dist = nil
    for distMult = 16, 0, -1 do
        if not dist then
            for i = -checkCount, checkCount do
                local ray = collision_find_surface_on_ray(0x4000*(i/checkCount), 0x4000, levelMaxZ*(distMult/16), 0, -0x8000, 0, 1)
                if ray.surface ~= nil then
                    dist = ray.hitPos.z
                end
            end
        end
    end
    levelMaxZ = dist and math.round(dist) or levelMaxZ

    djui_chat_message_create(tostring("-----"))
    djui_chat_message_create(tostring(levelMinX))
    djui_chat_message_create(tostring(levelMaxX))
    djui_chat_message_create(tostring(levelMinZ))
    djui_chat_message_create(tostring(levelMaxZ))
    return math.sqrt(levelMinX^2 + levelMaxX^2 + levelMinZ^2 + levelMaxZ^2)
end

local function find_character_spawn()
    local spawnPos = nil
    local spawnStart = get_time()
    local spawnIteration = 0
    while spawnPos == nil do
        local spawnStep = 0
        spawnIteration = spawnIteration + 1
        local ray = collision_find_surface_on_ray(mul_random(levelMinX, levelMaxX), 0x4000, mul_random(levelMinZ, levelMaxZ), 0, -0x8000, 0)
        while ray.surface and ray.surface.normal.y < 0.5 do
            ray = collision_find_surface_on_ray(ray.hitPos.x, ray.hitPos.y - 100, ray.hitPos.z, 0, -0x8000, 0)
        end
        if ray.surface and not evilFloorTypes[ray.surface.type] and ray.surface.normal.y > 0.95 and (ray.hitPos.y > find_water_level(ray.hitPos.x, ray.hitPos.z) or spawnIteration > 1000) then
            spawnStep = spawnStep + 1
            local surfaceX = (ray.surface.vertex1.x + ray.surface.vertex2.x + ray.surface.vertex3.x)/3
            local surfaceY = (ray.surface.vertex1.y + ray.surface.vertex2.y + ray.surface.vertex3.y)/3
            local surfaceZ = (ray.surface.vertex1.z + ray.surface.vertex2.z + ray.surface.vertex3.z)/3

            local avoidChar = nearest_object_with_behavior_id_to_pos(surfaceX, surfaceY, surfaceZ, id_bhvUnlockableChar)
            local avoidWarp = nearest_object_with_behavior_id_to_pos(surfaceX, surfaceY, surfaceZ, id_bhvWarp)
            local avoidDoorWarp = nearest_object_with_behavior_id_to_pos(surfaceX, surfaceY, surfaceZ, id_bhvDoorWarp)
            local avoidWarpPipe = nearest_object_with_behavior_id_to_pos(surfaceX, surfaceY, surfaceZ, id_bhvWarpPipe)

            local smallestEdge = nil
            for i = 0, 2 do
                local currNum = (i%3) + 1
                local nextNum = ((i+1)%3) + 1
                local currPos = ray.surface["vertex"..tostring(currNum)]
                local nextPos = ray.surface["vertex"..tostring(nextNum)]
                local edgeDist = math.sqrt((currPos.x - nextPos.x)^2 + (currPos.z - nextPos.z)^2)
                if not smallestEdge or smallestEdge > edgeDist then
                    smallestEdge = edgeDist
                end
            end

            local avoidDist = math.min(avoidChar and dist_between_object_and_point(avoidChar, surfaceX, surfaceY, surfaceZ) or 0x8000,
                avoidWarp and dist_between_object_and_point(avoidWarp, surfaceX, surfaceY, surfaceZ) or 0x8000,
                avoidDoorWarp and dist_between_object_and_point(avoidDoorWarp, surfaceX, surfaceY, surfaceZ) or 0x8000,
                avoidWarpPipe and dist_between_object_and_point(avoidWarpPipe, surfaceX, surfaceY, surfaceZ) or 0x8000)

            if (avoidDist > 100 or spawnIteration > 5000) and (smallestEdge > 100 and smallestEdge < (500 + spawnIteration)) then --- math.floor(spawnIteration/100)*100 then
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

        if get_time() - spawnStart > 3 then
            log_to_console(tostring("Character Select Nuzlocke: Character took 3 Seconds after "..tostring(spawnIteration).." iterations, got stuck on Step "..tostring(spawnStep)..", giving up."), CONSOLE_MESSAGE_ERROR)
            return {x = 0, y = 0, z = 0, yaw = 0}
        end
    end

    log_to_console(tostring("Character Select Nuzlocke: Character Spawned at ("..math.round(spawnPos.x)..", "..math.round(spawnPos.y)..", "..math.round(spawnPos.z)..") in [Level "..gNetworkPlayers[0].currLevelNum.." / Area "..gNetworkPlayers[0].currAreaIndex.."] on iteration "..tostring(spawnIteration)..", Took "..tostring(get_time() - spawnStart).." Seconds."))
    return spawnPos
end

local function find_griffiti_spawn()
    local spawnPos = nil
    local spawnStart = get_time()
    local spawnIteration = 0
    while spawnPos == nil do
        local spawnStep = 0
        spawnIteration = spawnIteration + 1
        local ray = collision_find_surface_on_ray(mul_random(levelMinX, levelMaxX), 0x4000, mul_random(levelMinZ, levelMaxZ), 0, -0x8000, 0, 1)
        if ray.surface and not evilFloorTypes[ray.surface.type] and ray.surface.normal.y > 0.95 and (ray.hitPos.y > find_water_level(ray.hitPos.x, ray.hitPos.z) or spawnIteration > 1000) then
            spawnStep = spawnStep + 1
            local surfaceX = (ray.surface.vertex1.x + ray.surface.vertex2.x + ray.surface.vertex3.x)/3
            local surfaceY = (ray.surface.vertex1.y + ray.surface.vertex2.y + ray.surface.vertex3.y)/3
            local surfaceZ = (ray.surface.vertex1.z + ray.surface.vertex2.z + ray.surface.vertex3.z)/3

            local angleYaw = mul_random(0, 0x10000)
            local canSpawnFloor = mul_random() <= 0.02
            if not canSpawnFloor then
                ray = collision_find_surface_on_ray(surfaceX, surfaceY + 100, surfaceZ, sins(angleYaw)*5000, mul_random()*1000, coss(angleYaw)*5000)
            end
            if ray.surface ~= nil and not evilFloorTypes[ray.surface.type] and ((ray.surface.normal.y < 0.75 and ray.surface.normal.y > -0.75) or canSpawnFloor) then
                local smallestEdge = nil
                for i = 0, 6 do
                    local currNum = (i%3) + 1
                    local nextNum = ((i+1)%3) + 1
                    local currPos = ray.surface["vertex"..tostring(currNum)]
                    local nextPos = ray.surface["vertex"..tostring(nextNum)]
                    if i > 2 then
                        local nextNum2 = ((i+2)%3) + 1
                        nextPos = {
                            x = (ray.surface["vertex"..tostring(nextNum)].x + ray.surface["vertex"..tostring(nextNum2)].x)*0.5,
                            y = (ray.surface["vertex"..tostring(nextNum)].y + ray.surface["vertex"..tostring(nextNum2)].y)*0.5,
                            z = (ray.surface["vertex"..tostring(nextNum)].z + ray.surface["vertex"..tostring(nextNum2)].z)*0.5,
                        }
                    end
                    local edgeDist = math.sqrt((currPos.x - nextPos.x)^2 + (currPos.y - nextPos.y)^2 + (currPos.z - nextPos.z)^2)
                    if not smallestEdge or smallestEdge > edgeDist then
                        smallestEdge = edgeDist
                    end
                end

                local spawnX = math.lerp((ray.surface.vertex1.x + ray.surface.vertex2.x + ray.surface.vertex3.x)/3, ray.hitPos.x, 0)
                local spawnY = math.lerp((ray.surface.vertex1.y + ray.surface.vertex2.y + ray.surface.vertex3.y)/3, ray.hitPos.y, 0)
                local spawnZ = math.lerp((ray.surface.vertex1.z + ray.surface.vertex2.z + ray.surface.vertex3.z)/3, ray.hitPos.z, 0)
                local avoidGraffiti = nearest_object_with_behavior_id_to_pos(spawnX, spawnY, spawnZ, id_bhvCharGraffiti)
                if smallestEdge > 300 and ((not avoidGraffiti or dist_between_object_and_point(avoidGraffiti, spawnX, spawnY, spawnZ) > 100) or spawnIteration > 1000) then
                    spawnPos = {
                        x = spawnX,
                        y = spawnY,
                        z = spawnZ,
                        normal = {
                            x = ray.surface.normal.x,
                            y = ray.surface.normal.y,
                            z = ray.surface.normal.z,
                        },
                        edge = smallestEdge,
                    }
                end
            end
        end 

        if get_time() - spawnStart > 1 then
            log_to_console(tostring("Character Select Nuzlocke: Graffiti took 1 Second after "..tostring(spawnIteration).." iterations, got stuck on Step "..tostring(spawnStep)..", giving up."), CONSOLE_MESSAGE_ERROR)
            return
        end
    end

    log_to_console(tostring("Character Select Nuzlocke: Graffiti Spawned at ("..math.round(spawnPos.x)..", "..math.round(spawnPos.y)..", "..math.round(spawnPos.z)..") in [Level "..gNetworkPlayers[0].currLevelNum.." / Area "..gNetworkPlayers[0].currAreaIndex.."] on iteration "..tostring(spawnIteration)..", Took "..tostring(get_time() - spawnStart).." Seconds."))
    return spawnPos
end

local function on_sync()
    local m = gMarioStates[0]
    local currLevel = gNetworkPlayers[0].currLevelNum
    local currArea = gNetworkPlayers[0].currAreaIndex
    if not charLevelMap[currLevel] or not charLevelMap[currLevel][currArea] then return end
    -- Don't run in act select
    if obj_get_first_with_behavior_id(id_bhvActSelector) then return end
    -- Don't run if someone else ran it already
    if obj_get_first_with_behavior_id(id_bhvUnlockableChar) then return end
    if obj_get_first_with_behavior_id(id_bhvCharGraffiti) then return end
    local levelScale = find_level_bounds()
    djui_chat_message_create(tostring(levelScale))
    if nuzlocke_seed_rng(currLevel*currArea) then
        for i, charNum in pairs(charLevelMap[currLevel][currArea]) do
            local charSpawn = find_character_spawn()
            spawn_sync_object(id_bhvUnlockableChar, E_MODEL_NONE, charSpawn.x, charSpawn.y, charSpawn.z, function(o)
                o.oCharNum = charNum
                o.oFaceAnglePitch = 0
                o.oFaceAngleRoll = 0
            end)
        end
        for i, areaData in pairs(charLevelMap[currLevel]) do
            for i, charNum in pairs(areaData) do
                for i = 1, math.max(levelScale/4000) + mul_random(0, 2) do
                    local graffitiSpawn = find_griffiti_spawn()
                    if graffitiSpawn then
                        spawn_sync_object(id_bhvCharGraffiti, E_MODEL_GRAFFITI, graffitiSpawn.x, graffitiSpawn.y, graffitiSpawn.z, function(o)
                            local slopeAngle = atan2s(graffitiSpawn.normal.z, graffitiSpawn.normal.x)
                            local tilt = 0
                            local pitch = atan2s(math.sqrt(graffitiSpawn.normal.x * graffitiSpawn.normal.x + graffitiSpawn.normal.z * graffitiSpawn.normal.z), graffitiSpawn.normal.y)
                            o.oFaceAnglePitch = (0x4000-pitch)*coss(tilt)
                            o.oFaceAngleRoll = (0x4000-pitch)*sins(tilt)
                            o.oFaceAngleYaw = slopeAngle + tilt
                            
                            --o.oFaceAngleRoll = mul_random(-0x1000, 0x1000)
                            obj_scale(o, math.clamp(graffitiSpawn.edge/350, 0.5, 5))
                            o.oCharNum = charNum
                        end)
                    end
                end
            end
        end
    end
end

local function set_lives_counter()
    local totalCharacters = nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED) - 1
    gMarioStates[0].numLives = totalCharacters
    hud_set_value(HUD_DISPLAY_LIVES, totalCharacters)
end

local function on_interact(m, o, int)
    if m.playerIndex == 0 then
        if int == INTERACT_STAR_OR_KEY then
            randomize_character()
        end
    end
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_DEATH, queue_char_kill)
hook_event(HOOK_ON_SYNC_VALID, on_sync)
hook_event(HOOK_MARIO_UPDATE, set_lives_counter)
hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_recieve)
hook_event(HOOK_ON_LEVEL_INIT, randomize_character)
hook_event(HOOK_ON_INTERACT, on_interact)
_G.charSelect.hook_allow_menu_open(block_menu_in_stages)

local function set_seed(msg)
    if not network_is_server() then return end
    local seed = tonumber(msg) or mul_random(0, SEED_MAX - 1)
    seed = math.round(seed)%SEED_MAX
    local prevSeed = gGlobalSyncTable.nuzlockeSeed
    reset_save(seed)
    djui_chat_message_create("Nuzlocke Seed changed: " .. prevSeed .. " -> " .. gGlobalSyncTable.nuzlockeSeed)
    return true
end

--hook_chat_command("nuzlocke-seed", "Set the Character Select Nuzlocke Seed [0 - "..(SEED_MAX - 1).."]", set_seed)