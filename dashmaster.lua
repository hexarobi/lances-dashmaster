--$$\        $$$$$$\  $$\   $$\  $$$$$$\  $$$$$$$$\ 
--$$ |      $$  __$$\ $$$\  $$ |$$  __$$\ $$  _____|
--$$ |      $$ /  $$ |$$$$\ $$ |$$ /  \__|$$ |      
--$$ |      $$$$$$$$ |$$ $$\$$ |$$ |      $$$$$\    
--$$ |      $$  __$$ |$$ \$$$$ |$$ |      $$  __|   
--$$ |      $$ |  $$ |$$ |\$$$ |$$ |  $$\ $$ |      
--$$$$$$$$\ $$ |  $$ |$$ | \$$ |\$$$$$$  |$$$$$$$$\ 
--\________|\__|  \__|\__|  \__| \______/ \________|
-- coded by Lance/stonerchrist on Discord

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
            function(result, headers, status_code)
                local function parse_auto_update_result(result, headers, status_code)
                    local error_prefix = "Error downloading auto-updater: "
                    if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                    if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                    filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                    local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                    if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                    file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                end
                auto_update_complete = parse_auto_update_result(result, headers, status_code)
            end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

auto_updater.run_auto_update({
    project_url="https://github.com/hexarobi/lances-dashmaster"
})

local natives_version = "1681379138.g"
util.require_natives(natives_version)

local car_hdl = 0 

function say(text) 
    util.toast('[DASHMASTER] ' .. text)
end

util.create_tick_handler(function()
    car_hdl = entities.get_user_vehicle_as_handle(false)
end) 


resources_dir = filesystem.resources_dir() .. '\\dashmaster\\'
-- filesystem handling and logo 
if not filesystem.is_dir(resources_dir) then
    say("Resources dir is missing. The script will now exit.")
    util.stop_script()
end

local gauge_bg = directx.create_texture(resources_dir .. '/dial.png')
local needle = directx.create_texture(resources_dir .. '/needle.png')
local wrench = directx.create_texture(resources_dir .. '/wrench.png')

local gears = {}
for i=0, 7 do 
    gears[i] = directx.create_texture(resources_dir .. '/gear_' .. tostring(i) .. '.png')
end

local speed_nums = {}
for i=0, 9 do 
    speed_nums[i] = directx.create_texture(resources_dir .. '/mph_' .. tostring(i) .. '.png')
end

local hp_nums = {}
for i=0, 9 do 
    hp_nums[i] = directx.create_texture(resources_dir .. '/hp_' .. tostring(i) .. '.png')
end


local mph_label = directx.create_texture(resources_dir .. '/mph_label.png')
local kph_label = directx.create_texture(resources_dir .. '/kph_label.png')
local ms_label = directx.create_texture(resources_dir .. '/ms_label.png')

local speed_setting = 'MPH'
local speed_settings = {'MPH', 'KPH', 'M/S'}
menu.my_root():list_select("Speed unit", {'dashmasterunits'}, "", speed_settings, 2, function(unit)
    speed_setting = speed_settings[unit]
end)

local dm_x_off = 0.00 
local dm_y_off = 0.00
local gauge_scale = 0.08
local speed_scale = 0.06
local hp_scale = 0.008

local hud_list = menu.my_root():list('HUD', {}, '')
local cam_root = menu.my_root():list('Cameras', {}, '')

hud_list:slider_float('X offset', {'dmxoff'}, '', -2000, 2000, 0, 1, function(val)
    dm_x_off = val * 0.01 
end)

hud_list:slider_float('Y offset', {'dmyoff'}, '', -2000, 2000, 0, 1, function(val)
    dm_y_off = val * 0.01 
end)

hud_list:slider_float('Gauge scale', {'dmgaugescale'}, '', 0, 2000, 8, 1, function(val)
    gauge_scale = val * 0.01 
end)

hud_list:slider_float('Speed scale', {'dmspeedscale'}, '', 0, 2000, 6, 1, function(val)
    speed_scale = val * 0.01 
end)

hud_list:slider_float('HP scale', {'dmhpscale'}, '', 0, 2000, 8, 1, function(val)
    hp_scale = val * 0.001 
end)

local draw_tach = true 
hud_list:toggle('Draw tachometer', {'dmdrawtach'}, '', function(on)
    draw_tach = on
end, true)


local draw_speed = true 
hud_list:toggle('Draw speed', {'dmdrawspeed'}, '', function(on)
    draw_speed = on
end, true)

local draw_hp = true 
hud_list:toggle('Draw HP', {'dmdrawhp'}, '', function(on)
    draw_hp = on
end, true)



menu.my_root():toggle_loop('Hold shift to drift', {'shiftdrift'}, "", function()
    if IS_CONTROL_PRESSED(21, 21) then
        SET_VEHICLE_REDUCE_GRIP(car_hdl, true)
        SET_VEHICLE_REDUCE_GRIP_LEVEL(car_hdl, 0.0)
    else
        SET_VEHICLE_REDUCE_GRIP(car_hdl, false)
    end
end)


hud_list:toggle_loop("Draw control values", {""}, "", function()
    if car_hdl ~= 0 and IS_PED_IN_ANY_VEHICLE(players.user_ped(), true) then
        local center_x = 0.8
        local center_y = 0.8
        -- main underlay
        directx.draw_rect(center_x - 0.062, center_y - 0.125, 0.12, 0.13, {r = 0, g = 0, b = 0, a = 0.2})
        -- throttle
        directx.draw_rect(center_x, center_y, 0.005, -GET_CONTROL_NORMAL(87, 87)/10, {r = 0, g = 1, b = 0, a =1})
        -- brake 
        directx.draw_rect(center_x - 0.01, center_y, 0.005, -GET_CONTROL_NORMAL(72, 72)/10, {r = 1, g = 0, b = 0, a =1 })
        -- steering
        directx.draw_rect(center_x - 0.0025, center_y - 0.115, math.max(GET_CONTROL_NORMAL(146, 146)/20), 0.01, {r = 0, g = 0.5, b = 1, a =1 })
    end
end)

local af_downforce = 0.0

util.create_tick_handler(function()
    if car_hdl ~= 0 and af_downforce ~= 0.0 then  
        local vel = GET_ENTITY_VELOCITY(car_hdl)
        vel['z'] = -vel['z']
        APPLY_FORCE_TO_ENTITY(car_hdl, 2, 0, 0, -af_downforce -vel['z'], 0, 0, 0, 0, true, false, true, false, true)
    end
end)

menu.my_root():slider_float("Artificial downforce", {'afdownforce'}, '', 0, 10000, 0, 10  , function(v)
    af_downforce = v * 0.01
end)

local cur_engine_sound_override = 'off' --placeholder value, will be changed automatically
local last_car = 0
local last_esound_override = -1

function update_engine_sound(car, sound) 
    FORCE_USE_AUDIO_GAME_OBJECT(car, sound)
end

util.create_tick_handler(function()
    if car_hdl ~= 0 then 
        local ct = true 
        if (last_car ~= car_hdl and cur_engine_sound_override == 'Off') then 
            ct = false
        end

        if ct then 
            if (last_esound_override ~= cur_engine_sound_override) or (last_car ~= car_hdl)  then 
                update_engine_sound(car_hdl, cur_engine_sound_override)
                last_esound_override = cur_engine_sound_override
                last_car = car_hdl
            end
        end
    end
end)

local engine_sound_overrides = {'Off', 'Adder', 'Zentorno', 'Openwheel1', 'Openwheel2', 'Formula', 'Formula2', 'Tractor', 'Buffalo4', 'XA21', 'Drafter', 'Jugular', 'TurismoR', 'Voltic2', 'Neon'}
menu.my_root():list_select("Engine swap", {}, 'Make your car\'s engine sound like another engine.\nOnly you can hear this.', engine_sound_overrides, 1, function(index, val)
    if index == 1 then
        local model_name = util.reverse_joaat(GET_ENTITY_MODEL(car_hdl))
        update_engine_sound(car_hdl, model_name)
        return
    end
    cur_engine_sound_override = val
end)

local top_cam = 0
local top_cam_ht = 20
local top_down_mode = false
local top_were_we_in_a_car = false

util.create_thread(function()
    if top_down_mode then 
        SET_CAM_ROT(top_cam, GET_ENTITY_HEADING(players.user_ped()), 0.0, 0.0, 0)
        local v = GET_VEHICLE_PED_IS_IN(players.user_ped(), true)
        if v ~= 0 then 
            if not top_were_we_in_a_car then 
                DETACH_CAM(top_cam)
                top_were_we_in_a_car = true 
                ATTACH_CAM_TO_ENTITY(top_cam, v, 0.0, 0.0, top_cam_ht, true)
            end
        else
            if top_were_we_in_a_car then 
                DETACH_CAM(top_cam)
                ATTACH_CAM_TO_ENTITY(top_cam, players.user_ped(), 0.0, 0.0, top_cam_ht, true)
            end

        end
    end
end)


cam_root:toggle("Top-down camera", {''}, '', function(on)
    if on then
        local c = players.get_position(players.user())
        local camera = CREATE_CAM_WITH_PARAMS('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z + top_cam_ht, -90.0, 0.0, 0.0, 120, true, 0) 
        top_cam = camera
        RENDER_SCRIPT_CAMS(true, false, 0, true, true, 0)
        ATTACH_CAM_TO_ENTITY(camera, players.user_ped(), 0.0, 0.0, top_cam_ht, true)
        top_down_mode = true
        --HARD_ATTACH_CAM_TO_ENTITY(camera, players.user_ped(), -90.0, 0.0, 0.0, 0.0, 0.0, top_cam_ht, true)
    else
        RENDER_SCRIPT_CAMS(false, false, 0, true, true, 0)
        DESTROY_CAM(top_cam, false) 
        top_cam = 0
        top_down_mode = false
    end
end)

local cam2_root = cam_root:list('Camera 2.0', {}, '')
local cam_2_mode = false
local cam2 = 0 
local cam2_pitch = 0
local cam2_yaw = 0.01
local incr_mult = 2
local cam2_x_off = 0 
local cam2_y_off = -5
local cam2_z_off = 3
local cam2_tar_ang = 30
local cam2_rot_speed = 0.40
local have_cam2_vals_changed = true 

cam2_root:slider_float('X offset', {'cam2xoff'}, '', -2000, 2000, 0, 1, function(val)
    cam2_x_off = val * 0.01 
    have_cam2_vals_changed = true
end)

cam2_root:slider_float('Y offset', {'cam2yoff'}, '', -2000, 2000, -500, 1, function(val)
    cam2_y_off = val * 0.01 
    have_cam2_vals_changed = true
end)

cam2_root:slider_float('Z offset', {'cam2zoff'}, '', -2000, 2000, 300, 1, function(val)
    cam2_z_off = val * 0.01 
    have_cam2_vals_changed = true
end)

cam2_root:slider('Target angle', {'cam2tar'}, '', -360, 360, 30, 1, function(val)
    cam2_tar_ang = val
end)


cam2_root:slider_float('Rotation speed', {'cam2rotspeed'}, '', 10, 1000, 40, 1, function(val)
    cam2_rot_speed = val * 0.01
end)


util.create_tick_handler(function()
    if cam_2_mode then 
        local v = GET_VEHICLE_PED_IS_IN(players.user_ped(), true)
        if v == -1 then 
            v = players.user_ped()
        end

        if have_cam2_vals_changed then 
            ATTACH_CAM_TO_ENTITY(cam2, v, cam2_x_off, cam2_y_off, cam2_z_off, true)
            have_cam2_vals_changed = false 
        end

        local pitch_mul = GET_CONTROL_NORMAL(2, 2)
        local yaw_mul = GET_CONTROL_NORMAL(1, 1)
        if pitch_mul ~= 0 then 
            cam2_pitch = cam2_pitch + (pitch_mul * incr_mult)
        end

        if yaw_mul ~= 0 then 
            cam2_yaw = cam2_yaw + (yaw_mul * incr_mult)
        end

        if cam2_yaw >= 360 then 
            cam2_yaw = 0 
        end

        if cam2_yaw <= -360 then 
            cam2_yaw = 0 
        end

        if cam2_pitch >= 360 then 
            cam2_pitch = 0 
        end

        if cam2_pitch <= -360 then 
            cam2_pitch = 0 
        end
        
        local diff = GET_ENTITY_ROTATION(v, 0)['z'] - GET_CAM_ROT(cam2, 0)['z']
        if diff > cam2_tar_ang then 
            diff = diff - 1
            if diff < 200 then 
                cam2_yaw = cam2_yaw - cam2_rot_speed
            else
                cam2_yaw = cam2_yaw + cam2_rot_speed
            end
        end

        if diff < -cam2_tar_ang then 
            diff = diff + 1
            if diff < -200 then 
                cam2_yaw = cam2_yaw - cam2_rot_speed
            else
                cam2_yaw = cam2_yaw + cam2_rot_speed
            end
        end


        SET_CAM_ROT(cam2, -cam2_pitch, 0.0, -cam2_yaw, 0)
        local c = GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(v, cam2_x_off, cam2_y_off, cam2_z_off)
        SET_CAM_COORD(cam2, c.x, c.y, c.z)
    end
end)

cam2_root:toggle("Camera 2.0", {''}, '', function(on)
    if on then
        local c = players.get_position(players.user())

        local camera = CREATE_CAM_WITH_PARAMS('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, 0.0, 100, true, 0) 
        cam2 = camera
        RENDER_SCRIPT_CAMS(true, false, 0, true, true, 0)
        cam_2_mode = true

        local v = GET_VEHICLE_PED_IS_IN(players.user_ped(), false) 
        if v == -1 then 
            v = players.user_ped()
        end
        ATTACH_CAM_TO_ENTITY(cam2, v, cam2_x_off, cam2_y_off, cam2_z_off, true)

    else
        RENDER_SCRIPT_CAMS(false, false, 0, true, true, 0)
        DESTROY_CAM(cam2, false) 
        cam2 = 0
        cam_2_mode = false
    end
end)

cam2_root:action("Debug: Destroy current rendering cam", {}, "", function()
    DESTROY_CAM(GET_RENDERING_CAM())
end)



-- draw tachometer tick handler
util.create_tick_handler(function()
    local rpm = 0
    local car_ptr = entities.get_user_vehicle_as_pointer(false)
    if car_ptr ~= 0 then 
        rpm = entities.get_rpm(car_ptr)
        local car = entities.pointer_to_handle(car_ptr) 
        local texture_width = 0.08
        local texture_height = 0.08
        local posX = 0.8
        local posY = 0.7

        local max_rotation = math.rad(0.501 * 180) -- Maximum rotation angle the needle can reach in radians

        -- Calculate the needle rotation based on the car's speed and maximum speed
        local needle_rotation = (rpm / 1)/1.485  - 0.170
        local gear_pos_x = posX - 0.0001
        local gear_pos_y = posY - 0.005
        local gear = entities.get_current_gear(car_ptr)
        if draw_tach then 
            directx.draw_texture(gauge_bg, gauge_scale , gauge_scale , 0.5, 0.5, posX + dm_x_off, (posY - 0.004) + dm_y_off, 0, 1.0, 1.0, 1.0, 1.0)
            directx.draw_texture(needle, gauge_scale , gauge_scale, 0.5, 0.5, posX + dm_x_off, posY + dm_y_off, needle_rotation, 1.0, 1.0, 1.0, 0.5)
            directx.draw_texture(gears[gear], gauge_scale , gauge_scale , 0.5, 0.5, gear_pos_x + dm_x_off, gear_pos_y + dm_y_off, 0, 1.0, 1.0, 1.0, 1)
        end

        local car_hp = math.ceil((GET_ENTITY_HEALTH(car) / GET_ENTITY_MAX_HEALTH(car)) * 100.0)
        local car_hp_str = tostring(car_hp)
        local car_hp_r = 0.0 
        local car_hp_g = 1.0 
        local car_hp_b = 0.6

        if car_hp < 70 then 
            car_hp_r = 1.0 
            car_hp_g = 0.5 
            car_hp_b = 0.2
        end

        if car_hp < 30 then 
            car_hp_r = 1.0 
            car_hp_g = 0.0
            car_hp_b = 0.0
        end

        if draw_hp then 
            directx.draw_texture(wrench, hp_scale - 0.003, hp_scale - 0.003, 0.5, 0.5, (gear_pos_x + 0.05) + dm_x_off, (gear_pos_y + 0.04) + dm_y_off, 0, car_hp_r, car_hp_g, car_hp_b, 1)
            local cur_hp_num_off = hp_scale - 0.005
            for i=1, #car_hp_str do
                directx.draw_texture(hp_nums[tonumber(car_hp_str:sub(i,i))], hp_scale, hp_scale , 0.5, 0.5, (gear_pos_x + 0.06 + cur_hp_num_off) + dm_x_off, (gear_pos_y + 0.04) + dm_y_off, 0, car_hp_r, car_hp_g, car_hp_b, 1)
                cur_hp_num_off += hp_scale / 1.5
            end
        end

        local speed = math.ceil(GET_ENTITY_SPEED(car_hdl))
        local unit_text = ms_label
        pluto_switch speed_setting do 
            case "MPH":
                unit_text = mph_label
                speed = math.ceil(speed * 2.236936)
                break 
            case "KPH":
                speed = math.ceil(speed * 3.6)
                unit_text = kph_label 
                break
            case 'M/S': 
                speed = math.ceil(speed) 
                unit_text = ms_label
                break
        end

        local cur_speed_num_offset = 0
        local speed_str = tostring(speed)
        if draw_speed then 
            for i=1, #speed_str do
                directx.draw_texture(speed_nums[tonumber(speed_str:sub(i,i))], speed_scale , speed_scale , 0.5, 0.5, ((posX) + cur_speed_num_offset) + dm_x_off, (posY + 0.1) + dm_y_off, 0, 1.0, 1.0, 1.0, 1)
                cur_speed_num_offset += speed_scale / 2
            end

            cur_speed_num_offset += speed_scale / 5
            directx.draw_texture(unit_text, speed_scale , speed_scale , 0.5, 0.5, ((posX) + cur_speed_num_offset) + dm_x_off, ((posY + (speed_scale)) + dm_y_off) * 1.10, 0, 1.0, 1.0, 1.0, 1)
        end

    end
end)

menu.my_root():hyperlink('Join Discord', 'https://discord.gg/zZ2eEjj88v', '')
-- cleanup for you :)
function on_stop()
    DESTROY_CAM(top_cam, true)
    DESTROY_CAM(cam2, true)
end
