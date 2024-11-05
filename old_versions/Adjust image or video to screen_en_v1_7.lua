-- Adjust image or video to screen_v1_7_EN
-- Version: 1.7
-- Script designed for use with OBS in live productions.
-- Features: 
-- 1. Automatically adjusts video and image sources to the screen only if they haven't been adjusted previously each time we make a transition.
-- Author: [Pëpep]
-- Last update: [29/10/24]

obs = obslua

local VERBOSE = true
local adjusted_sources = {}
local original_print = print
-- Overwrite the global print function
function print(...)
    if VERBOSE then
        original_print(...)
    end
end

-- Script properties definition
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "verbose_logging", "Enable detailed logging")
    return props
end

-- Function to update settings
function script_update(settings)
    VERBOSE = obs.obs_data_get_bool(settings, "verbose_logging")
end

-- Function to apply "Fit to Screen" to a scene item
local function fit_item_to_screen(scene, item)
    local source = obs.obs_sceneitem_get_source(item)
    local source_name = obs.obs_source_get_name(source)
    local source_id = obs.obs_source_get_unversioned_id(source)

    -- Check if the source is a video or image
    if source_id == "ffmpeg_source" or source_id == "image_source" then
        local source_width = obs.obs_source_get_width(source)
        local source_height = obs.obs_source_get_height(source)

        if source_width > 0 and source_height > 0 then
            -- Get canvas dimensions
            local video_info = obs.obs_video_info()
            local success = obs.obs_get_video_info(video_info)
            local canvas_width = success and video_info.base_width or 1920
            local canvas_height = success and video_info.base_height or 1080

            -- Check bounds type
            local bounds_type = obs.obs_sceneitem_get_bounds_type(item)
            print(string.format("Source: %s, Bounds type: %d", source_name, bounds_type))

            if bounds_type == 2 then
                print("Source already adjusted with 'Fit to Screen': " .. source_name)
                return -- Do nothing if already adjusted
            elseif bounds_type == 0 then
                -- Calculate scale
                local scale_x = canvas_width / source_width
                local scale_y = canvas_height / source_height
                local scale = math.min(scale_x, scale_y)

                -- Calculate scaled dimensions
                local new_width = source_width * scale
                local new_height = source_height * scale

                -- Center the source at (0, 0)
                local pos = obs.vec2()
                pos.x = 0.0
                pos.y = 0.0

                print(string.format("Calculated scale: %.3f", scale))
                print(string.format("Scaled dimensions: %.0fx%.0f", new_width, new_height))
                print(string.format("Calculated position: %.1f, %.1f", pos.x, pos.y))

                -- Apply scale and position
                local scale_vec = obs.vec2()
                scale_vec.x = scale
                scale_vec.y = scale

                obs.obs_sceneitem_set_pos(item, pos)
                obs.obs_sceneitem_set_scale(item, scale_vec)

                -- Change bounds type to 2 to mark 'Fit to Screen' as applied
                obs.obs_sceneitem_set_bounds_type(item, 2)

                -- Set bounds to canvas dimensions
                local bounds_vec = obs.vec2()
                bounds_vec.x = canvas_width
                bounds_vec.y = canvas_height
                obs.obs_sceneitem_set_bounds(item, bounds_vec)

                print("Source adjusted: " .. source_name .. " (Scale: " .. scale .. ")")
                
                -- Mark the source as adjusted
                adjusted_sources[source_name] = true
            else
                print("Unknown bounds type for source: " .. source_name)
            end
        else
            print("Error: Source dimensions are zero or negative: " .. source_name)
        end
    else
        print("Incompatible source, ignored: " .. source_name)
    end
end

-- Function to adjust all items in a scene
local function adjust_scene(scene)
    local items = obs.obs_scene_enum_items(scene)
    for _, item in ipairs(items) do
        fit_item_to_screen(scene, item)
    end
    obs.sceneitem_list_release(items)
end

-- Function to handle events
local function handle_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        print("Scene change detected")
        local scene = obs.obs_frontend_get_current_scene()
        if scene then
            adjust_scene(obs.obs_scene_from_source(scene))
            obs.obs_source_release(scene)
        end
    end
end

-- Function to describe the script
function script_description()
    return "Automatically adjusts video and image sources to the screen only if they haven't been adjusted previously each time we make a transition."
end

-- Function to load the script
function script_load(settings)
    print("Script 'Automatic screen adjustment' loaded")
    obs.obs_frontend_add_event_callback(handle_event)
end

-- Function to unload the script
function script_unload()
    obs.obs_frontend_remove_event_callback(handle_event)
    print("Script 'Automatic screen adjustment' unloaded")
end
