-- QlistGOStyle_AutoFade_AudioMonitor_ca
-- Versió: 1.53
-- Script dissenyat per a l'ús d'OBS en produccions en directe.
-- Funcionalitats: 
-- 1. Transició i Fade Out Automàtic: Realitza una transició i un fade out suau de les fonts d'àudio amb restauració automàtica dels volums originals utilitzant tecles d'accés ràpid.
-- 2. Canvi d'Escena Següent/Anterior: Permet navegar entre escenes utilitzant tecles d'accés ràpid.
-- 3. Monitorització Automàtica: Configura automàticament la monitorització d'àudio per a noves fonts.
-- Autor: [Pëpep]
-- Última actualització: [29/10/24]
-----------------------------------------------
-- This script includes code from OBS-next-scene-hotkey by SimonGZ
-- https://github.com/SimonGZ/OBS-next-scene-hotkey
-- MIT License: https://github.com/SimonGZ/OBS-next-scene-hotkey/blob/master/LICENSE
------------------------------------------------------------
obs = obslua

-- Control de logging
local VERBOSE = true
local original_print = print

function print(...)
    if VERBOSE then
        original_print(...)
    end
end

-- Variables globals
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
local transition_duration = 300  -- Valor inicial per defecte en mil·lisegons
local RESTORE_DELAY_MS
local cancel_fade_on_transition = true
local fade_enabled = true  -- Nova variable per activar/desactivar els fade outs

-- Funció per actualitzar fade_interval
local function update_fade_interval()
    fade_interval = transition_duration / FADE_STEPS
    print("Nou interval de fade: " .. fade_interval .. " ms")
end

function update_restore_delay()
    local min_delay = 500 -- Mínim de 500 mil·lisegons (mig segon)
    RESTORE_DELAY_MS = math.max(min_delay, math.floor(transition_duration) + 200)
    print("Càlcul de RESTORE_DELAY_MS:")
    print("  Durada de la transició: " .. transition_duration .. " ms")
    print("  RESTORE_DELAY_MS final: " .. RESTORE_DELAY_MS .. " ms")
end

-- Inicialitzem fade_interval
update_fade_interval()

--funció per obtenir la durada de la transició per defecte de manera segura
function get_default_transition_duration()
    local transition = obs.obs_frontend_get_current_transition()
    local duration = 300  -- Valor per defecte en mil·lisegons (300ms)
    
    if transition then
        if obs.obs_transition_get_duration then
            duration = obs.obs_transition_get_duration(transition)
        else
            print("Advertència: La funció obs_transition_get_duration no està disponible.")
        end
        obs.obs_source_release(transition)
    else
        print("Advertència: No s'ha pogut obtenir la transició actual.")
    end
    
    print("Durada de la transició per defecte: " .. duration .. " ms")
    return duration
end

-- Funcions del (Fade Out)

local function format_volume(volume)
    return string.format("%.5f", volume)
end

function get_source_volume(source)
    if source == nil then
        print("Error: Font nul·la passada a get_source_volume")
        return 1.0  -- Retornem un valor per defecte
    end
    local volume = obs.obs_source_get_volume(source)
    if volume == nil or volume < 0 then
        print("Advertència: obs_source_get_volume va retornar un valor invàlid")
        return 0.00001  -- Retornem un valor molt petit en lloc de 0
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
        print("Volum actual de " .. name .. ": " .. format_volume(original_volumes[name]))
    end
    obs.source_list_release(sources)
end

function start_fade_out()
    if fade_enabled then
        print("Iniciant fade out")
        print("Durada del fade out: " .. transition_duration .. " ms")
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
                print("Afegint font al fade out: " .. name)
            end
        end
        obs.sceneitem_list_release(scene_items)
        obs.obs_source_release(program_scene)
        obs.timer_add(apply_fade_out, fade_interval)
    else
        print("Fade out desactivat, només s'aplicarà la transició")
    end
    apply_transition()
end
---- variables possibles de fade function apply_fade_out():
        --local fade_factor = 1 - (progress * progress * progress)  -- Més pronunciat al principi
        --local fade_factor = 1 - math.sqrt(progress)  -- Més suau al principi
function apply_fade_out()
    if not fade_enabled then
        print("Fade out desactivat, sortint de apply_fade_out")
        obs.remove_current_callback()
        return
    end
    local all_faded = true
    for name, data in pairs(sources_fading) do
        if data.step == 0 then
            data.current_volume = get_source_volume(data.source)
            if data.current_volume == nil then
                print("Advertència: No s'ha pogut obtenir el volum per a " .. name)
                data.current_volume = 1.0  -- Establim un valor per defecte
            end
            print("Guardant volum inicial per a " .. name .. ": " .. format_volume(data.current_volume))
        end
        data.step = data.step + 1
        local progress = data.step / FADE_STEPS
        local new_volume = data.current_volume * (1 - math.log(progress + 1) / math.log(2))
        
        -- Arrodonir a 5 decimals per evitar errors de precisió en punt flotant
        new_volume = math.floor(new_volume * 100000 + 0.5) / 100000
        
        -- Assegurar-nos que new_volume no sigui mai negatiu o zero
        new_volume = math.max(new_volume, 0.00001)
        
        set_source_volume(data.source, new_volume)
        print("Font: " .. name .. ", Pas: " .. data.step .. ", Volum: " .. format_volume(new_volume))
        
        if data.step < FADE_STEPS then
            all_faded = false
        end
    end
    if all_faded then
        print("Fade out completat")
        obs.remove_current_callback()
        restore_timer = obs.timer_add(restore_volumes, RESTORE_DELAY_MS)
    end
end

function cancel_fade_out()
    print("Cancel·lant fade out")
    obs.remove_current_callback()
    if restore_timer then
        obs.timer_remove(restore_timer)
        restore_timer = nil
    end
    for name, data in pairs(sources_fading) do
        set_source_volume(data.source, data.current_volume)
        print("Volum restaurat per a " .. name .. ": " .. format_volume(data.current_volume))
    end
    sources_fading = {}
    print("Fade out cancel·lat i volums restaurats")
end

function apply_transition()
    print("Aplicant transició per defecte")
    obs.obs_frontend_preview_program_trigger_transition()
end

function restore_volumes()
    print("Restaurant volums")
    for name, data in pairs(sources_fading) do
        set_source_volume(data.source, data.current_volume)
        print("Volum restaurat per a " .. name .. ": " .. format_volume(data.current_volume))
    end
    sources_fading = {}
    obs.timer_remove(restore_volumes)
    restore_timer = nil
    print("Reiniciant l'script")
    reset_script()
end

function reset_script()
    sources_fading = {}
    get_all_volumes()
    print("Script reiniciat i llest per a un nou fade out")
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
    print("Iniciant fade out, transició i canvi a la següent escena")
    
    -- Iniciem el fade out
    start_fade_out()
 
    next_scene(true)
end

function start_fade_out_and_prev_scene()
    print("Iniciant fade out, transició i canvi a l'escena anterior")
    
    -- Iniciem el fade out
    start_fade_out()
    
    -- Canviem a l'escena anterior
    previous_scene(true)
end

-- Funcions (Next/Previous Scene)

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

-- Funcions (Monitorització automàtica)

function set_monitoring(source)
    if not active_monitoring then return end
    local source_id = obs.obs_source_get_id(source)
    local source_name = obs.obs_source_get_name(source)
    print("Processant font: " .. source_name .. " (ID: " .. source_id .. ")")
    local caps = obs.obs_source_get_output_flags(source)
    if bit.band(caps, obs.OBS_SOURCE_AUDIO) ~= 0 then
        obs.obs_source_set_monitoring_type(source, monitoring_type)
        print("Monitorització configurada per a: " .. source_name .. " - Tipus: " .. monitoring_type)
    else
        print("La font no té capacitats d'àudio: " .. source_name)
    end
end

local function source_created(cd)
    local source = obs.calldata_source(cd, "source")
    if source ~= nil then
        print("Nova font creada: " .. obs.obs_source_get_name(source))
        set_monitoring(source)
    end
end

-- Funcions comunes i de gestió d'esdeveniments ---------------------------------------------------------------------

function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_TRANSITION_DURATION_CHANGED then
        transition_duration = obs.obs_frontend_get_transition_duration()
        update_fade_interval()
        update_restore_delay()
        print("Durada de la transició canviada a: " .. transition_duration .. " ms")
        print("Nou interval de fade: " .. fade_interval .. " ms")
    end
end

function script_description()
    return "Aquest script combina tres funcions clau per a l'ús d'OBS en produccions en directe: 1. Fade Out Automàtic, 2. Canvi d'Escena Següent/Anterior, 3. Monitorització Automàtica."
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "loop", "Loop Scenes List")
    obs.obs_properties_add_bool(props, "preview", "Change Preview")
    obs.obs_properties_add_bool(props, "fade_enabled", "Activar Fade Outs")
    obs.obs_properties_add_int(props, "fade_steps", "Passos de Fade", 5, 100, 1)
    local list = obs.obs_properties_add_list(props, "monitoring_type", "Tipus de Monitorització", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    obs.obs_property_list_add_int(list, "Monitorització i Sortida", obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT)
    obs.obs_property_list_add_int(list, "Només Monitorització", obs.OBS_MONITORING_TYPE_MONITOR_ONLY)
    obs.obs_property_list_add_int(list, "Monitorització Desactivada", obs.OBS_MONITORING_TYPE_NONE)
    obs.obs_properties_add_bool(props, "active_monitoring", "Activar monitorització automàtica")
    obs.obs_properties_add_bool(props, "cancel_fade_on_transition", "Cancel·lar fade out en transicions consecutives")
    obs.obs_properties_add_bool(props, "verbose_logging", "Activar logging detallat")
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
        print("Fade Out activat: " .. tostring(fade_enabled))
    print("Tipus de monitorització actualitzat a: " .. monitoring_type)
    print("Script de monitorització actiu: " .. tostring(active_monitoring))
    print("Fade Outs activats: " .. tostring(fade_enabled))
    print("Passos de Fade: " .. FADE_STEPS)
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
    print("Cancel·lar fade out en nova transició: " .. tostring(cancel_fade_on_transition))
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
    print("Carregant script combinat")
    transition_duration = obs.obs_frontend_get_transition_duration()
    update_fade_interval()
    update_restore_delay()
    print("Durada de la transició inicial: " .. transition_duration .. " ms")

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
