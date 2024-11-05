-- Adjust image or video to screen_ca_v1_8
-- Versió: 1.8
-- Script dissenyat per a l'ús d'OBS en produccions en directe.
-- Funcionalitats: 
-- 1. Ajusta automàticament les fonts de vídeo i imatge a la pantalla només si no han estat ajustades prèviament cada vegada que fem una transicio.
-- Autor: [Pëpep]
-- Última actualització: [31/10/24]

obs = obslua

local VERBOSE = true
local adjusted_sources = {}
local original_print = print
-- Sobreescrivim la funció print global
function print(...)
    if VERBOSE then
        original_print(...)
    end
end

-- Definició de les propietats del script
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "verbose_logging", "Activar logging detallat")
    return props
end

-- Funció per actualitzar la configuració
function script_update(settings)
    VERBOSE = obs.obs_data_get_bool(settings, "verbose_logging")
end

-- Funció per aplicar "Fit to Screen" a un element d'escena
local function fit_item_to_screen(scene, item)
    local source = obs.obs_sceneitem_get_source(item)
    local source_name = obs.obs_source_get_name(source)
    local source_id = obs.obs_source_get_unversioned_id(source)

    -- Comprovem si la font ja ha estat ajustada prèviament
    if adjusted_sources[source_name] then
        print("La font ja ha estat ajustada prèviament: " .. source_name)
        return
    end

    -- Comprovem si la font és un vídeo o una imatge
    if source_id == "ffmpeg_source" or source_id == "image_source" then
        local source_width = obs.obs_source_get_width(source)
        local source_height = obs.obs_source_get_height(source)

        if source_width > 0 and source_height > 0 then
            -- Obtenim les dimensions del canvas
            local video_info = obs.obs_video_info()
            local success = obs.obs_get_video_info(video_info)
            if not success then
                print("Error: No s'ha pogut obtenir la informació del vídeo")
                return
            end
            local canvas_width = video_info.base_width
            local canvas_height = video_info.base_height

            -- Comprovem el tipus de límits
            local bounds_type = obs.obs_sceneitem_get_bounds_type(item)
            print(string.format("Font: %s, Tipus de límits: %d", source_name, bounds_type))

            if bounds_type == 2 then
                print("La font ja ha estat ajustada amb 'Fit to Screen': " .. source_name)
                return -- No fem res si ja està ajustada
            elseif bounds_type == 0 then
                -- Calculem l'escala
                local scale_x = canvas_width / source_width
                local scale_y = canvas_height / source_height
                local scale = math.min(scale_x, scale_y)

                -- Calculem les dimensions escalades
                local new_width = source_width * scale
                local new_height = source_height * scale

                -- Centrem la font a (0, 0)
                local pos = obs.vec2()
                pos.x = 0.0
                pos.y = 0.0

                print(string.format("Escala calculada: %.3f", scale))
                print(string.format("Dimensions escalades: %.0fx%.0f", new_width, new_height))
                print(string.format("Posició calculada: %.1f, %.1f", pos.x, pos.y))

                -- Aplica l'escala i la posició
                local scale_vec = obs.vec2()
                scale_vec.x = scale
                scale_vec.y = scale

                obs.obs_sceneitem_set_pos(item, pos)
                obs.obs_sceneitem_set_scale(item, scale_vec)

                -- Canviem el tipus de límits a 2 per marcar que s'ha aplicat 'Fit to Screen'
                obs.obs_sceneitem_set_bounds_type(item, 2)

                -- Establim els límits a les dimensions del canvas
                local bounds_vec = obs.vec2()
                bounds_vec.x = canvas_width
                bounds_vec.y = canvas_height
                local success = obs.obs_sceneitem_set_bounds(item, bounds_vec)
                if not success then
                    print("Error: No s'han pogut establir els límits de la font")
                    return
                end

                print("Font ajustada: " .. source_name .. " (Escala: " .. scale .. ")")
                
                -- Marquem la font com ajustada
                adjusted_sources[source_name] = true
            else
                print("Tipus de límits desconegut per a la font: " .. source_name)
            end
        else
            print("Error: Les dimensions de la font són zero o negatives: " .. source_name)
        end
    else
        print("Font no compatible, s'ignora: " .. source_name)
    end
end

-- Funció per ajustar tots els elements d'una escena
local function adjust_scene(scene)
    local items = obs.obs_scene_enum_items(scene)
    if not items then
        print("Error: No s'han pogut obtenir els elements de l'escena")
        return
    end
    for _, item in ipairs(items) do
        fit_item_to_screen(scene, item)
    end
    obs.sceneitem_list_release(items)
end

-- Funció per gestionar els esdeveniments
local function handle_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        print("Canvi d'escena detectat")
        local scene = obs.obs_frontend_get_current_scene()
        if scene then
            adjust_scene(obs.obs_scene_from_source(scene))
            obs.obs_source_release(scene)
        end
    end
end

-- Funció per descriure l'script
function script_description()
    return "Ajusta automàticament les fonts de vídeo i imatge a la pantalla només si no han estat ajustades prèviament cada vegada que fem una transicio."
end

-- Funció per carregar l'script
function script_load(settings)
    print("Script 'Ajust automàtic a pantalla' carregat")
    obs.obs_frontend_add_event_callback(handle_event)
end

-- Funció per descarregar l'script
function script_unload()
    obs.obs_frontend_remove_event_callback(handle_event)
    print("Script 'Ajust automàtic a pantalla' descarregat")
end
