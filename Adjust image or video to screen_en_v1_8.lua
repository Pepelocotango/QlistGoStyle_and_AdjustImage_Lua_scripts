-- Adjust image or video to screen_en_v1_8
-- Version: 1.8
-- Script designed for use with OBS in live productions.
-- Features: 
-- 1. Automatically adjusts video and image sources to the screen only if they have not been previously adjusted each time we make a transition.
-- Author: [Pëpep]
-- Last update: [31/10/24]

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

-- Definition of script properties
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "verbose_logging", "Enable detailed logging")
    return props
end

-- Function to set default values
function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "verbose_logging", false)  -- Set to false to disable logging by default
end

-- Function to update the configuration
function script_update(settings)
    VERBOSE = obs.obs_data_get_bool(settings, "verbose_logging")
end

-- Function to apply "Fit to Screen" to a scene item
local function fit_item_to_screen(scene, item)
    local source = obs.obs_sceneitem_get_source(item)
    local source_name = obs.obs_source_get_name(source)
    local source_id = obs.obs_source_get_unversioned_id(source)

    -- Check if the source has already been adjusted
    if adjusted_sources[source_name] then
        print("The source has already been adjusted: " .. source_name)
        return
    end

    -- Check if the source is a video or an image
    if source_id == "ffmpeg_source" or source_id == "image_source" then
        local source_width = obs.obs_source_get_width(source)
        local source_height = obs.obs_source_get_height(source)

        if source_width > 0 and source_height > 0 then
            -- Get the canvas dimensions
            local video_info = obs.obs_video_info()
            local success = obs.obs_get_video_info(video_info)
            if not success then
                print("Error: Could not get video information")
                return
            end
            local canvas_width = video_info.base_width
            local canvas_height = video_info.base_height

            -- Check the bounds type
            local bounds_type = obs.obs_sceneitem_get_bounds_type(item)
            print(string.format("Source: %s, Bounds type: %d", source_name, bounds_type))

            if bounds_type == 2 then
                print("The source has already been adjusted with 'Fit to Screen': " .. source_name)
                return -- Do nothing if already adjusted
            elseif bounds_type == 0 then
                -- Calculate the scale
                local scale_x = canvas_width / source_width
                local scale_y = canvas_height / source_height
                local scale = math.min(scale_x, scale_y)

                -- Calculate the scaled dimensions
                local new_width = source_width * scale
                local new_height = source_height * scale

                -- Center the source at (0, 0)
                local pos = obs.vec2()
                pos.x = 0.0
                pos.y = 0.0

                print(string.format("Calculated scale: %.3f", scale))
                print(string.format("Scaled dimensions: %.0fx%.0f", new_width, new_height))
                print(string.format("Calculated position: %.1f, %.1f", pos.x, pos.y))

                -- Apply the scale and position
                local scale_vec = obs.vec2()
                scale_vec.x = scale
                scale_vec.y = scale

                obs.obs_sceneitem_set_pos(item, pos)
                obs.obs_sceneitem_set_scale(item, scale_vec)

                -- Change the bounds type to 2 to mark that 'Fit to Screen' has been applied
                obs.obs_sceneitem_set_bounds_type(item, 2)

                -- Set the bounds to the canvas dimensions
                local bounds_vec = obs.vec2()
                bounds_vec.x = canvas_width
                bounds_vec.y = canvas_height
                local success = obs.obs_sceneitem_set_bounds(item, bounds_vec)
                if not success then
                    print("Error: Could not set the source bounds")
                    return
                end

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
        print("Unsupported source, ignored: " .. source_name)
    end
end

-- Function to adjust all items in a scene
local function adjust_scene(scene)
    local items = obs.obs_scene_enum_items(scene)
    if not items then
        print("Error: Could not get scene items")
        return
    end
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
    return "Automatically adjusts video and image sources to the screen only if they have not been previously adjusted each time we make a transition."
end

-- Function to load the script
function script_load(settings)
    print("Script 'Automatic Fit to Screen' loaded")
    obs.obs_frontend_add_event_callback(handle_event)
end

-- Function to unload the script
function script_unload()
    obs.obs_frontend_remove_event_callback(handle_event)
    print("Script 'Automatic Fit to Screen' unloaded")
end
