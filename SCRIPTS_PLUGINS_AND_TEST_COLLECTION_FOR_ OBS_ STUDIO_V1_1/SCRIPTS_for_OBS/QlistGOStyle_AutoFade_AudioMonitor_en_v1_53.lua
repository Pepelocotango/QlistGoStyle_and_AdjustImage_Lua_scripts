-- QlistGOStyle_AutoFade_AudioMonitor_en
-- Version: 1.53
-- Script designed for use with OBS in live productions.
-- Features:
-- 1. Automatic Transition and Fade Out: Performs a transition and smooth fade-out of audio sources with automatic restoration of original volumes using hotkeys.
-- 2. Next/Previous Scene Change: Allows navigation between scenes using hotkeys.
-- 3. Automatic Monitoring: Automatically sets up audio monitoring for new sources.
-- Author: [Pëpep]
-- Last update: [29/10/24]
-----------------------------------------------
-- This script includes code from OBS-next-scene-hotkey by SimonGZ
-- https://github.com/SimonGZ/OBS-next-scene-hotkey
-- MIT License: https://github.com/SimonGZ/OBS-next-scene-hotkey/blob/master/LICENSE
------------------------------------------------------------
obs = obslua

-- Logging control
local VERBOSE = true
local original_print = print

function print(...)
    if VERBOSE then
        original_print(...)
    end
end

-- Global variables
local FADE_STEPS = 20
local original_volumes = {}
local sources_fading = {}
local fade_interval
local restore_timer = nil
local hotkey_id_fade = obs.OBS_INVALID_HOTKEY_ID
local hotkey_id_fade_prev = obs.OBS_INVALID_HOTKEY_ID
local next_scene_hotkey_id = obs.OBS_INVALID_HOTKEY_ID
local prev_scene_hotkey_id = obs.OBS_INVALID_HOTKEY_ID
local loop = true
local preview = true
local monitoring_type = obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT
local active_monitoring = true
local transition_duration = 300  -- Default initial value in milliseconds
local RESTORE_DELAY_MS
local cancel_fade_on_transition = true
local fade_enabled = true  -- New variable to enable/disable fade outs

-- Function to update fade_interval
local function update_fade_interval()
    fade_interval = transition_duration / FADE_STEPS
    print("New fade interval: " .. fade_interval .. " ms")
end

function update_restore_delay()
    local min_delay = 500 -- Minimum 500 milliseconds (half a second)
    RESTORE_DELAY_MS = math.max(min_delay, math.floor(transition_duration) + 200)
    print("Calculating RESTORE_DELAY_MS:")
    print("  Transition duration: " .. transition_duration .. " ms")
    print("  Final RESTORE_DELAY_MS: " .. RESTORE_DELAY_MS .. " ms")
end

-- Initialize fade_interval
update_fade_interval()

-- Function to safely get the default transition duration
function get_default_transition_duration()
    local transition = obs.obs_frontend_get_current_transition()
    local duration = 300  -- Default value in milliseconds (300ms)
    
    if transition then
        if obs.obs_transition_get_duration then
            duration = obs.obs_transition_get_duration(transition)
        else
            print("Warning: The function obs_transition_get_duration is not available.")
        end
        obs.obs_source_release(transition)
    else
        print("Warning: Could not get the current transition.")
    end
    
    print("Default transition duration: " .. duration .. " ms")
    return duration
end

-- Fade Out Functions

local function format_volume(volume)
    return string.format("%.5f", volume)
end

function get_source_volume(source)
    if source == nil then
        print("Error: Null source passed to get_source_volume")
        return 1.0  -- Return a default value
    end
    local volume = obs.obs_source_get_volume(source)
    if volume == nil or volume < 0 then
        print("Warning: obs_source_get_volume returned an invalid value")
        return 0.00001  -- Return a very small value instead of 0
    end
    return volume
end

function set_source_volume(source, volume)
    obs.obs_source_set_volume(source, volume)
end

function get_all_volumes()
    local sources = obs.obs_enum_sources()
    for _, source in ipairs(sources) do
        local name = obs.obs_source_get_name(source)
        original_volumes[name] = get_source_volume(source)
        print("Current volume of " .. name .. ": " .. format_volume(original_volumes[name]))
    end
    obs.source_list_release(sources)
end

function start_fade_out()
    if fade_enabled then
        print("Starting fade out")
        print("Fade out duration: " .. transition_duration .. " ms")
        local program_scene = obs.obs_frontend_get_current_scene()
        local scene = obs.obs_scene_from_source(program_scene)
        local scene_items = obs.obs_scene_enum_items(scene)
        
        update_restore_delay()

        for _, item in ipairs(scene_items) do
            local source = obs.obs_sceneitem_get_source(item)
            local name = obs.obs_source_get_name(source)
            if not sources_fading[name] then
                sources_fading[name] = {
                    source = source,
                    step = 0
                }
                print("Adding source to fade out: " .. name)
            end
        end
        obs.sceneitem_list_release(scene_items)
        obs.obs_source_release(program_scene)
        obs.timer_add(apply_fade_out, fade_interval)
    else
        print("Fade out disabled, only the transition will apply")
    end
    apply_transition()
end
-- fade_factor variables in fade function apply_fade_out():
        --local fade_factor = 1 - (progress * progress * progress)  -- More pronounced at the start
        --local fade_factor = 1 - math.sqrt(progress)  -- Smoother at the start
function apply_fade_out()
    if not fade_enabled then
        print("Fade out disabled, exiting apply_fade_out")
        obs.remove_current_callback()
        return
    end
    local all_faded = true
    for name, data in pairs(sources_fading) do
        if data.step == 0 then
            data.current_volume = get_source_volume(data.source)
            if data.current_volume == nil then
                print("Warning: Could not get volume for " .. name)
                data.current_volume = 1.0  -- Set a default value
            end
            print("Saving initial volume for " .. name .. ": " .. format_volume(data.current_volume))
        end
        data.step = data.step + 1
        local progress = data.step / FADE_STEPS
        local new_volume = data.current_volume * (1 - math.log(progress + 1) / math.log(2))
        
        -- Round to 5 decimals to avoid floating-point precision errors
        new_volume = math.floor(new_volume * 100000 + 0.5) / 100000
        
        -- Ensure new_volume is never negative or zero
        new_volume = math.max(new_volume, 0.00001)
        
        set_source_volume(data.source, new_volume)
        print("Source: " .. name .. ", Step: " .. data.step .. ", Volume: " .. format_volume(new_volume))
        
        if data.step < FADE_STEPS then
            all_faded = false
        end
    end
    if all_faded then
        print("Fade out completed")
        obs.remove_current_callback()
        restore_timer = obs.timer_add(restore_volumes, RESTORE_DELAY_MS)
    end
end

function cancel_fade_out()
    print("Canceling fade out")
    obs.remove_current_callback()
    if restore_timer then
        obs.timer_remove(restore_timer)
        restore_timer = nil
    end
    for name, data in pairs(sources_fading) do
        set_source_volume(data.source, data.current_volume)
        print("Volume restored for " .. name .. ": " .. format_volume(data.current_volume))
    end
    sources_fading = {}
    print("Fade out canceled and volumes restored")
end

function apply_transition()
    print("Applying default transition")
    obs.obs_frontend_preview_program_trigger_transition()
end

function restore_volumes()
    print("Restoring volumes")
    for name, data in pairs(sources_fading) do
        set_source_volume(data.source, data.current_volume)
        print("Volume restored for " .. name .. ": " .. format_volume(data.current_volume))
    end
    sources_fading = {}
    obs.timer_remove(restore_volumes)
    restore_timer = nil
    print("Restarting script")
    reset_script()
end

function reset_script()
    sources_fading = {}
    get_all_volumes()
    print("Script restarted and ready for a new fade out")
end

function on_hotkey_fade(pressed)
    if pressed then
        start_fade_out_and_next_scene()
    end
end

function on_hotkey_fade_prev(pressed)
    if pressed then
        start_fade_out_and_prev_scene()
    end
end

function start_fade_out_and_next_scene()
    print("Starting fade out, transition and move to the next scene")
    
    -- Start fade out
    start_fade_out()
 
    next_scene(true)
end

function start_fade_out_and_prev_scene()
    print("Starting fade out, transition and move to the previous scene")
    
    -- Start fade out
    start_fade_out()
    
    -- Change to the previous scene
    previous_scene(true)
end

-- Next/Previous Scene Functions

function next_scene(pressed)
    if not pressed then return end
    local previewMode = preview and obs.obs_frontend_preview_program_mode_active()
    local scenes = obs.obs_frontend_get_scenes()
    local current_scene = previewMode and obs.obs_frontend_get_current_preview_scene() or obs.obs_frontend_get_current_scene()
    local scene_function = previewMode and obs.obs_frontend_set_current_preview_scene or obs.obs_frontend_set_current_scene
    local current_scene_name = obs.obs_source_get_name(current_scene)
    if scenes ~= nil then
        for i, scn in ipairs(scenes) do
            if current_scene_name == obs.obs_source_get_name(scn) then
                if scenes[i + 1] ~= nil then
                    scene_function(scenes[i + 1])
                    break
                elseif loop then
                    scene_function(scenes[1])
                    break
                end
            end
        end
    end
    obs.obs_source_release(current_scene)
    obs.source_list_release(scenes)
end

function previous_scene(pressed)
    if not pressed then return end
    local previewMode = preview and obs.obs_frontend_preview_program_mode_active()
    local scenes = obs.obs_frontend_get_scenes()
    local current_scene = previewMode and obs.obs_frontend_get_current_preview_scene() or obs.obs_frontend_get_current_scene()
    local scene_function = previewMode and obs.obs_frontend_set_current_preview_scene or obs.obs_frontend_set_current_scene
    local current_scene_name = obs.obs_source_get_name(current_scene)
    if scenes ~= nil then
        for i, scn in ipairs(scenes) do
            if current_scene_name == obs.obs_source_get_name(scn) then
                if scenes[i - 1] ~= nil then
                    scene_function(scenes[i - 1])
                    break
                elseif loop then
                    scene_function(scenes[#scenes])
                    break
                end
            end
        end
    end
    obs.obs_source_release(current_scene)
    obs.source_list_release(scenes)
end

-- Functions (Automatic Monitoring)

function set_monitoring(source)
    if not active_monitoring then return end
    local source_id = obs.obs_source_get_id(source)
    local source_name = obs.obs_source_get_name(source)
    print("Processing source: " .. source_name .. " (ID: " .. source_id .. ")")
    local caps = obs.obs_source_get_output_flags(source)
    if bit.band(caps, obs.OBS_SOURCE_AUDIO) ~= 0 then
        obs.obs_source_set_monitoring_type(source, monitoring_type)
        print("Monitoring configured for: " .. source_name .. " - Type: " .. monitoring_type)
    else
        print("The source has no audio capabilities: " .. source_name)
    end
end

local function source_created(cd)
    local source = obs.calldata_source(cd, "source")
    if source ~= nil then
        print("New source created: " .. obs.obs_source_get_name(source))
        set_monitoring(source)
    end
end

-- Common functions and event management ---------------------------------------------------------------------

function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_TRANSITION_DURATION_CHANGED then
        transition_duration = obs.obs_frontend_get_transition_duration()
        update_fade_interval()
        update_restore_delay()
        print("Transition duration changed to: " .. transition_duration .. " ms")
        print("New fade interval: " .. fade_interval .. " ms")
    end
end

function script_description()
    return "This script combines three key functions for using OBS in live productions: 1. Automatic Fade Out, 2. Next/Previous Scene Change, 3. Automatic Monitoring."
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "loop", "Loop Scenes List")
    obs.obs_properties_add_bool(props, "preview", "Change Preview")
    obs.obs_properties_add_bool(props, "fade_enabled", "Enable Fade Outs")
    obs.obs_properties_add_int(props, "fade_steps", "Fade Steps", 5, 100, 1)
    local list = obs.obs_properties_add_list(props, "monitoring_type", "Monitoring Type", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    obs.obs_property_list_add_int(list, "Monitor and Output", obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT)
    obs.obs_property_list_add_int(list, "Monitor Only", obs.OBS_MONITORING_TYPE_MONITOR_ONLY)
    obs.obs_property_list_add_int(list, "Monitoring Disabled", obs.OBS_MONITORING_TYPE_NONE)
    obs.obs_properties_add_bool(props, "active_monitoring", "Enable automatic monitoring")
    obs.obs_properties_add_bool(props, "cancel_fade_on_transition", "Cancel fade out on consecutive transitions")
    obs.obs_properties_add_bool(props, "verbose_logging", "Enable detailed logging")
    return props
end

function script_update(settings)
    VERBOSE = obs.obs_data_get_bool(settings, "verbose_logging")
    loop = obs.obs_data_get_bool(settings, "loop")
    preview = obs.obs_data_get_bool(settings, "preview")
    fade_enabled = obs.obs_data_get_bool(settings, "fade_enabled")
    FADE_STEPS = obs.obs_data_get_int(settings, "fade_steps")
    monitoring_type = obs.obs_data_get_int(settings, "monitoring_type")
    active_monitoring = obs.obs_data_get_bool(settings, "active_monitoring")
    fade_interval = transition_duration / FADE_STEPS
    print("Fade Out enabled: " .. tostring(fade_enabled))
    print("Monitoring type updated to: " .. monitoring_type)
    print("Monitoring script active: " .. tostring(active_monitoring))
    print("Fade Outs enabled: " .. tostring(fade_enabled))
    print("Fade Steps: " .. FADE_STEPS)
    if active_monitoring then
        local sources = obs.obs_enum_sources()
        if sources ~= nil then
            for _, source in ipairs(sources) do
                set_monitoring(source)
            end
            obs.source_list_release(sources)
        end
    end
    cancel_fade_on_transition = obs.obs_data_get_bool(settings, "cancel_fade_on_transition")
    print("Cancel fade out on new transition: " .. tostring(cancel_fade_on_transition))
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "verbose_logging", false)
    obs.obs_data_set_default_bool(settings, "loop", true)
    obs.obs_data_set_default_bool(settings, "preview", true)
    obs.obs_data_set_default_bool(settings, "fade_enabled", true)
    obs.obs_data_set_default_int(settings, "fade_steps", 30)
    obs.obs_data_set_default_int(settings, "monitoring_type", obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT)
    obs.obs_data_set_default_bool(settings, "active_monitoring", true)
    obs.obs_data_set_default_bool(settings, "cancel_fade_on_transition", true)
end

function script_load(settings)
    print("Loading combined script")
    transition_duration = obs.obs_frontend_get_transition_duration()
    update_fade_interval()
    update_restore_delay()
    print("Initial transition duration: " .. transition_duration .. " ms")

    VERBOSE = obs.obs_data_get_bool(settings, "verbose_logging")
    hotkey_id_fade = obs.obs_hotkey_register_frontend("gofade_hotkey", "GOFade and next", on_hotkey_fade)
    hotkey_id_fade_prev = obs.obs_hotkey_register_frontend("gofade_prev_hotkey", "GOFade and Previous", on_hotkey_fade_prev)
    next_scene_hotkey_id = obs.obs_hotkey_register_frontend("next_scene.trigger", "Next Scene", next_scene)
    prev_scene_hotkey_id = obs.obs_hotkey_register_frontend("prev_scene.trigger", "Previous Scene", previous_scene)
    
    local hotkey_save_array_fade = obs.obs_data_get_array(settings, "gofade_hotkey")
    obs.obs_hotkey_load(hotkey_id_fade, hotkey_save_array_fade)
    obs.obs_data_array_release(hotkey_save_array_fade)
    
    local hotkey_save_array_fade_prev = obs.obs_data_get_array(settings, "gofade_prev_hotkey")
    obs.obs_hotkey_load(hotkey_id_fade_prev, hotkey_save_array_fade_prev)
    obs.obs_data_array_release(hotkey_save_array_fade_prev)
    
    local next_hotkey_save_array = obs.obs_data_get_array(settings, "next_scene.trigger")
    obs.obs_hotkey_load(next_scene_hotkey_id, next_hotkey_save_array)
    obs.obs_data_array_release(next_hotkey_save_array)
    
    local prev_hotkey_save_array = obs.obs_data_get_array(settings, "prev_scene.trigger")
    obs.obs_hotkey_load(prev_scene_hotkey_id, prev_hotkey_save_array)
    obs.obs_data_array_release(prev_hotkey_save_array)

    obs.obs_frontend_add_event_callback(on_event)
    
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_create", source_created)
end

function script_save(settings)
    local hotkey_save_array_fade = obs.obs_hotkey_save(hotkey_id_fade)
    obs.obs_data_set_array(settings, "gofade_hotkey", hotkey_save_array_fade)
    obs.obs_data_array_release(hotkey_save_array_fade)
    
    local hotkey_save_array_fade_prev = obs.obs_hotkey_save(hotkey_id_fade_prev)
    obs.obs_data_set_array(settings, "gofade_prev_hotkey", hotkey_save_array_fade_prev)
    obs.obs_data_array_release(hotkey_save_array_fade_prev)
    
    local next_hotkey_save_array = obs.obs_hotkey_save(next_scene_hotkey_id)
    obs.obs_data_set_array(settings, "next_scene.trigger", next_hotkey_save_array)
    obs.obs_data_array_release(next_hotkey_save_array)
    
    local prev_hotkey_save_array = obs.obs_hotkey_save(prev_scene_hotkey_id)
    obs.obs_data_set_array(settings, "prev_scene.trigger", prev_hotkey_save_array)
    obs.obs_data_array_release(prev_hotkey_save_array)
end

function script_unload()
    obs.obs_frontend_remove_event_callback(on_event)
end
