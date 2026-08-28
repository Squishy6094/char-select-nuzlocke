local TEX_LOGO = get_texture_info("char_select_logo")

local introAnimFrame = 0
local menuState = 0

local logoXTarget = 0
local logoYTarget = 0
local logoScaleTarget = 0
local logoShakeTarget = 0
local logoX
local logoY
local logoScale
local logoShake
local function hud_render()
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
end

--hook_event(HOOK_ON_HUD_RENDER, hud_render)