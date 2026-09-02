local TEX_LOGO = get_texture_info("char_select_logo")

local introAnimFrame = 0
local menuState = 0
local menuCurrOption = 1

local MENU_STATE_MAIN = 1
local MENU_STATE_NEW_RUN = 2

currRomhack = "Super Mario 64"

for i in pairs(gActiveMods) do
    local mod = gActiveMods[i]
    if mod.incompatible ~= nil then
        if mod.incompatible:find("romhack") then
            currRomhack = mod.name
            break
        end
    end
    if mod.category ~= nil then
        if mod.category:find("romhack") then
            currRomhack = mod.name
            break
        end
    end
end

local fileRomhack = mod_storage_load(save_file_prefix("romhack"), currRomhack)
log_to_console(currRomhack)
log_to_console(fileRomhack)

continueError = ""
if fileRomhack ~= currRomhack then
    continueError = continueError.."\nRomhack Mismatch: Expected "..fileRomhack
end

-- Settings
gGlobalSyncTable.nuzMixupMode = mod_storage_load_integer(save_file_prefix("nuzMixupMode"), 0)
gGlobalSyncTable.nuzCharsInLevel = mod_storage_load_integer(save_file_prefix("nuzMixupMode"), 0)
gGlobalSyncTable.nuzOptionsDone = 0

local function update_menu_toggle(toggle, toggleChange, min, max)
    gGlobalSyncTable[toggle] = num_wrap(gGlobalSyncTable[toggle] + (toggleChange or 0), min, max)
    mod_storage_save_integer(save_file_prefix(toggle), gGlobalSyncTable[toggle])
end

local menuOptions = {
    [MENU_STATE_MAIN] = {
        function (toggleChange)
            if continueError ~= "" then
                return "\\#888888\\Continue", "Cannot Continue Run!"..continueError
            else
                if toggleChange ~= 0 then
                    gGlobalSyncTable.nuzOptionsDone = 1
                end
                local stars = hud_get_value(HUD_DISPLAY_STARS)
                local chars = nuzlocke_count_character_state(NUZLOCKE_CHAR_UNLOCKED)
                return "Continue", "Continue your existing run with ".. stars .." Star"..(stars ~= 1 and "s" or "").." and "..chars.." Character"..(chars ~= 1 and "s" or "")
            end
        end,
        function (toggleChange)
            if toggleChange ~= 0 then
                menuState = MENU_STATE_NEW_RUN
            end
            return "New Game", "Start a new Run with a set of settings"
        end,
    },
    [MENU_STATE_NEW_RUN] = {
        function (toggleChange)
            -- Update toggle
            update_menu_toggle("nuzMixupMode", toggleChange, 0, 1)

            -- Get Toggle String
            return "Mix-up Mode: "..(gGlobalSyncTable.nuzMixupMode ~= 0 and "On" or "Off"), "Randomly Set Character on Star Collect and Stage Entrance"
        end,
        function (toggleChange)
            update_menu_toggle("nuzCharsInLevel", toggleChange, 0, 3)
            local toggle = gGlobalSyncTable.nuzCharsInLevel
            return "Characters Per Level: "..(toggle > 0 and tostring(toggle) or "Max"), 
            (toggle > 0 and "Each Level will have "..tostring(toggle).." Character"..(toggle > 1 and "s" or "") or "Every Character will be mapped to a level.")
        end,
        function (toggleChange)
            return "Toggle C", "Start a new Run with a set of settings"
        end,
        function (toggleChange)
            return "Toggle D", "Start a new Run with a set of settings"
        end,
        function (toggleChange)
            if toggleChange ~= 0 then
                reset_save()
                gGlobalSyncTable.nuzOptionsDone = 1
            end
            return "Start Run", "Start the Run"
        end,
    },
    
}

local logoXTarget = 0
local logoYTarget = 0
local logoScaleTarget = 0
local logoShakeTarget = 0
local logoX
local logoY
local logoScale
local logoShake

local function hud_render()
    if gGlobalSyncTable.nuzOptionsDone ~= 0 then return end
    local m = gMarioStates[0]
    djui_hud_set_resolution(RESOLUTION_N64)
    local sW = djui_hud_get_screen_width() + 1
    local sH = djui_hud_get_screen_height()

    if introAnimFrame < 10 then
        logoXTarget = sW*0.5
        logoYTarget = -sH
        logoScaleTarget = 0.2
    elseif introAnimFrame < 40 then
        logoXTarget = sW*0.5
        logoYTarget = sH*0.5
        logoScaleTarget = 0.4
    elseif introAnimFrame == 40 then
        logoShakeTarget = 20
    elseif introAnimFrame > 80 and introAnimFrame < 100 then
        logoXTarget = 85
        logoYTarget = 45
        logoScaleTarget = 0.3
        menuState = MENU_STATE_MAIN
    end
    logoShake = math.max(logoShake and math.lerp(logoShake, logoShakeTarget, 0.15) or logoShakeTarget, logoShakeTarget)
    if logoShakeTarget > 0 then
        logoShakeTarget = 0
    end
    logoX = (logoX and math.lerp(logoX, logoXTarget, 0.1) or logoXTarget)
    logoY = (logoY and math.lerp(logoY, logoYTarget, 0.1) or logoYTarget)
    logoScale = logoScale and math.lerp(logoScale, logoScaleTarget, 0.1) or logoScaleTarget

    djui_hud_set_color(0, 0, 0, 255)
    djui_hud_render_rect(0, 0, sW, sH)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_render_texture(TEX_LOGO, -TEX_LOGO.width*logoScale*0.5 + logoX + (math.random()*2 - 1)*logoShake, -TEX_LOGO.height*logoScale*0.5 + logoY + (math.random()*2 - 1)*logoShake, logoScale, logoScale)

    introAnimFrame = introAnimFrame + 1

    if menuOptions[menuState] and network_is_server() then
        if m.controller.buttonPressed & D_JPAD ~= 0 then
            menuCurrOption = menuCurrOption + 1
        end
        if m.controller.buttonPressed & U_JPAD ~= 0 then
            menuCurrOption = menuCurrOption - 1
        end
        if m.controller.buttonPressed & B_BUTTON ~= 0 then
            menuState = MENU_STATE_MAIN
        end
        local y = sH*0.5 - #menuOptions[menuState]*27*0.5
        menuCurrOption = num_wrap(menuCurrOption, 1, #menuOptions[menuState])
        for i = 1, #menuOptions[menuState] do
            local isHovered = i == menuCurrOption
            local change = 0
            if m.controller.buttonPressed & A_BUTTON ~= 0 or m.controller.buttonPressed & R_JPAD ~= 0 then
                change = 1
            end
            if m.controller.buttonPressed & L_JPAD ~= 0 then
                change = -1
            end

            local name, desc = menuOptions[menuState][i](isHovered and change or 0)
            if isHovered then
                djui_hud_set_color(255, 255, 127, 255)
            else
                djui_hud_set_color(255, 255, 255, 255)
            end
            local descW, descH = djui_hud_measure_text(desc)
            djui_hud_print_text(name, sW-150, y + (i-1)*27, 0.5, 0.5)
            djui_hud_print_text(desc, sW-148, y + 16 + (i-1)*27, 0.2, 0.2)
            y = y + math.max(descH*0.2 - 10, 0)
        end
    end
end

hook_event(HOOK_ON_HUD_RENDER, hud_render)