if SERVER then return end


-- Ensure the XPGUI library is included (It's Workshop Library Addon)
hook.Add("Initialize", "LoadXPGUI", function()
    if not XPGUI then
        include("xpgui/xpgui.lua")
    end
end)

local function sendCommandToServer(command, parameter)
    command = string.gsub(command, "%*$", "")
    net.Start("KeyBindManager_RunCommand")
    net.WriteString(command)
    net.WriteString(parameter or "")
    net.SendToServer()
end

local keyBinds = {}
local keyPressStates = {}
local frame

TypingInTextEntry = false

hook.Add("OnTextEntryGetFocus", "IsTyping", function()
    TypingInTextEntry = true
end)

hook.Add("OnTextEntryLoseFocus", "IsNotTyping", function()
    TypingInTextEntry = false
end)


net.Receive("KeyBindManager_Config", function()
    keyBinds = net.ReadTable()
    if IsValid(frame) then
        RefreshKeyBindList()
    end
end)

local function isValidCommand(cmd)
    return string.match(cmd, "^[%w%+%-_%*/!%s]+$") ~= nil and string.match(cmd, "%S")
end

function RefreshKeyBindList()
    if not IsValid(frame) then return end
    if IsValid(frame.keyBindList) then
        frame.keyBindList:Remove()
    end
    frame.keyBindList = vgui.Create("XPListView", frame)
    frame.keyBindList:SetPos(10, 200)
    frame.keyBindList:SetSize(frame:GetWide(), frame:GetTall() - 190)
    frame.keyBindList:AddColumn("Command")
    frame.keyBindList:AddColumn("Parameter")
    frame.keyBindList:AddColumn("Key")
    for command, data in pairs(keyBinds) do
        local key = data.key
        local parameter = data.parameter
        local line = frame.keyBindList:AddLine(command, parameter, input.GetKeyName(key))
        line.key = key
        line.command = command
        line.parameter = parameter
    end
    frame.keyBindList.OnRowRightClick = function(_, _, line)
        local menu = vgui.Create("XPMenu")
        menu:AddOption("Delete", function()
            keyBinds[line.command] = nil
            net.Start("KeyBindManager_Update")
            net.WriteString(line.command)
            net.WriteInt(0, 32)
            net.SendToServer()
            RefreshKeyBindList()
        end):SetIcon("icon16/delete.png")
        menu:Open()
    end
end

local function showOverwriteConfirmation(command, key, existingCommand)
    local confirmFrame = vgui.Create("XPFrame")
    confirmFrame:SetTitle("Overwrite Key Bind")
    confirmFrame:SetSize(300, 150)
    confirmFrame:Center()
    confirmFrame:MakePopup()

    local confirmLabel = vgui.Create("DLabel", confirmFrame)
    confirmLabel:SetText("The key is already bound to another command. Overwrite?")
    confirmLabel:SetWrap(true)
    confirmLabel:SetContentAlignment(5)
    confirmLabel:SetPos(10, 30)
    confirmLabel:SetSize(280, 40)

    local confirmButton = vgui.Create("XPButton", confirmFrame)
    confirmButton:SetText("Yes")
    confirmButton:SetPos(50, 80)
    confirmButton:SetSize(80, 30)

    local cancelButton = vgui.Create("XPButton", confirmFrame)
    cancelButton:SetText("No")
    cancelButton:SetPos(170, 80)
    cancelButton:SetSize(80, 30)

    confirmButton.DoClick = function()
        keyBinds[existingCommand] = nil
        keyBinds[command] = key
        net.Start("KeyBindManager_Update")
        net.WriteString(existingCommand)
        net.WriteInt(0, 32)
        net.SendToServer()
        net.Start("KeyBindManager_Update")
        net.WriteString(command)
        net.WriteInt(key, 32)
        net.SendToServer()
        confirmFrame:Close()
        RefreshKeyBindList()
    end

    cancelButton.DoClick = function()
        confirmFrame:Close()
    end
end

-- Yeah, I took all the commands from the wiki, I didn't know a better way to do this I suck at code ya know :p
local function GetCommandSuggestions(command)
    local allCommands = {
        "+alt1", "+alt2", "+attack", "+attack2", "+attack3", "+back", "+break", "+camdistance", "+camin", "+cammousemove",
        "+camout", "+campitchdown", "+campitchup", "+camyawleft", "+camyawright", "+commandermousemove", "+demoui2",
        "+duck", "+forward", "+graph", "+grenade1", "+grenade2", "+jlook", "+jump", "+klook", "+left", "+lookdown",
        "+lookup", "+mat_texture_list", "+menu", "+menu_context", "+movedown", "+moveleft", "+moveright", "+moveup",
        "+posedebug", "+reload", "+right", "+score", "+showbudget", "+showbudget_texture", "+showbudget_texture_global",
        "+showscores", "+showvprof", "+speed", "+strafe", "+use", "+vgui_drawtree", "+voicerecord", "+walk", "+zoom", "-",
        "-alt1", "-alt2", "-attack", "-attack2", "-attack3", "-back", "-break", "-camdistance", "-camin", "-cammousemove",
        "-camout", "-campitchdown", "-campitchup", "-camyawleft", "-camyawright", "-commandermousemove", "-demoui2",
        "-duck", "-forward", "-graph", "-grenade1", "-grenade2", "-jlook", "-jump", "-klook", "-left", "-lookdown",
        "-lookup", "-mat_texture_list", "-menu", "-menu_context", "-movedown", "-moveleft", "-moveright", "-moveup",
        "-posedebug", "-reload", "-right", "-score", "-showbudget", "-showbudget_texture", "-showbudget_texture_global",
        "-showscores", "-showvprof", "-speed", "-strafe", "-use", "-vgui_drawtree", "-voicerecord", "-walk", "-zoom",
        "_autosave", "_autosavedangerous", "_bugreporter_restart", "_fov", "_resetgamestats", "_restart",
        "achievement_debug", "act", "addip", "adsp_alley_min", "adsp_courtyard_min", "adsp_debug", "adsp_door_height",
        "adsp_duct_min", "adsp_hall_min", "adsp_low_ceiling", "adsp_opencourtyard_min", "adsp_openspace_min",
        "adsp_openstreet_min", "adsp_openwall_min", "adsp_room_min", "adsp_street_min", "adsp_tunnel_min",
        "adsp_wall_height", "advisor_use_impact_table", "ai_actbusy_search_time", "ai_ally_manager_debug",
        "ai_auto_contact_solver", "ai_block_damage", "ai_citizen_debug_commander", "ai_clear_bad_links",
        "ai_debug_actbusy", "ai_debug_assault", "ai_debug_avoidancebounds", "ai_debug_directnavprobe", "ai_debug_doors",
        "ai_debug_dyninteractions", "ai_debug_efficiency", "ai_debug_enemies", "ai_debug_enemyfinders",
        "ai_debug_eventresponses", "ai_debug_expressions", "ai_debug_follow", "ai_debug_loners", "ai_debug_looktargets",
        "ai_debug_los", "ai_debug_nav", "ai_debug_node_connect", "ai_debug_ragdoll_magnets", "ai_debug_readiness",
        "ai_debug_shoot_positions", "ai_debug_speech", "ai_debug_squads", "ai_debug_think_ticks",
        "ai_debugscriptconditions", "ai_default_efficient", "ai_disable", "ai_disabled", "ai_drawbattlelines",
        "ai_drop_hint", "ai_dump_hints", "ai_ef_hate_npc_duration", "ai_ef_hate_npc_frequency", "ai_efficiency_override",
        "ai_enable_fear_behavior", "ai_expression_frametime", "ai_expression_optimization", "ai_fear_player_dist",
        "ai_find_lateral_cover", "ai_find_lateral_los", "ai_follow_move_commands", "ai_follow_use_points",
        "ai_follow_use_points_when_moving", "ai_force_serverside_ragdoll", "ai_frametime_limit", "ai_hull",
        "ai_ignoreplayers", "ai_inhibit_spawners", "ai_lead_time", "ai_LOS_mode", "ai_moveprobe_debug",
        "ai_moveprobe_jump_debug", "ai_moveprobe_usetracelist", "ai_navigator_generate_spikes",
        "ai_navigator_generate_spikes_strength", "ai_new_aiming", "ai_newgroundturret", "ai_next_hull",
        "ai_no_local_paths", "ai_no_node_cache", "ai_no_select_box", "ai_no_steer", "ai_no_talk_delay", "ai_nodes",
        "ai_norebuildgraph", "ai_path_adjust_speed_on_immediate_turns", "ai_path_insert_pause_at_est_end",
        "ai_path_insert_pause_at_obstruction", "ai_post_frame_navigation", "ai_radial_max_link_dist",
        "ai_reaction_delay_alert", "ai_reaction_delay_idle", "ai_readiness_decay", "ai_rebalance_thinks",
        "ai_report_task_timings_on_limit", "ai_resume", "ai_sequence_debug", "ai_serverragdolls",
        "ai_set_move_height_epsilon", "ai_setupbones_debug", "ai_shot_bias", "ai_shot_bias_max", "ai_shot_bias_min",
        "ai_shot_stats", "ai_shot_stats_term", "ai_show_connect", "ai_show_connect_fly", "ai_show_connect_jump",
        "ai_show_graph_connect", "ai_show_grid", "ai_show_hints", "ai_show_hull", "ai_show_hull_attacks", "ai_show_node",
        "ai_show_think_tolerance", "ai_show_visibility", "ai_simulate_task_overtime", "ai_spread_cone_focus_time",
        "ai_spread_defocused_cone_multiplier", "ai_spread_pattern_focus_time", "ai_step", "ai_strong_optimizations",
        "ai_strong_optimizations_no_checkstand", "ai_task_pre_script", "ai_test_los", "ai_test_moveprobe_ignoresmall",
        "ai_think_limit_label", "ai_use_clipped_paths", "ai_use_efficiency", "ai_use_frame_think_limits",
        "ai_use_readiness", "ai_use_think_optimizations", "ai_use_visibility_cache", "ai_vehicle_avoidance",
        "ainet_generate_report", "ainet_generate_report_only", "air_density", "airboat_fatal_stress",
        "airboat_joy_response_move", "alias", "anim_3wayblend", "anim_showmainactivity", "antlion_easycrush",
        "askconnect_accept", "async_allow_held_files", "async_mode", "async_resume", "async_serialize",
        "async_simulate_delay", "async_suspend", "audit_save_in_memory", "autoaim_max_deflect", "autoaim_max_dist",
        "autoaim_unlock_target", "autosave", "autosavedangerous", "autosavedangerousissafe", "axis_forcelimit",
        "axis_hingefriction", "axis_nocollide", "axis_torquelimit", "balloon_b", "balloon_force", "balloon_g",
        "balloon_model", "balloon_r", "balloon_ropelength", "ballsocket_forcelimit", "ballsocket_nocollide", "banid",
        "banid2", "banip", "bench_end", "bench_showstatsdialog", "bench_start", "bench_upload", "benchframe", "bind",
        "bind_mac", "BindToggle", "birds_debug", "blink_duration", "bloodspray", "bot", "bot_attack", "bot_changeclass",
        "bot_crouch", "bot_defend", "bot_flipout", "bot_forceattack2", "bot_forceattackon", "bot_forcefireweapon",
        "bot_mimic", "bot_mimic_yaw_offset", "bot_sendcmd", "bot_zombie", "box", "breakable_disable_gib_limit",
        "breakable_multiplayer", "buddha", "budget_averages_window", "budget_background_alpha",
        "budget_bargraph_background_alpha", "budget_bargraph_range_ms", "budget_history_numsamplesvisible",
        "budget_history_range_ms", "budget_panel_bottom_of_history_fraction", "budget_panel_height", "budget_panel_width",
        "budget_panel_x", "budget_panel_y", "budget_peaks_window", "budget_show_averages", "budget_show_history",
        "budget_show_peaks", "budget_toggle_group", "bug", "bug_swap", "bugbait_distract_time", "bugbait_grenade_radius",
        "bugbait_hear_radius", "bugbait_radius", "bugreporter_includebsp", "bugreporter_uploadasync", "buildcubemaps",
        "building_cubemaps", "bulletspeed", "button_description", "button_keygroup", "button_model", "button_toggle",
        "c_maxdistance", "c_maxpitch", "c_maxyaw", "c_mindistance", "c_minpitch", "c_minyaw", "c_orthoheight",
        "c_orthowidth", "cache_print", "cache_print_lru", "cache_print_summary", "callvote", "cam_collision",
        "cam_command", "cam_idealdelta", "cam_idealdist", "cam_idealdistright", "cam_idealdistup", "cam_ideallag",
        "cam_idealpitch", "cam_idealyaw", "cam_showangles", "cam_snapto", "camera_key", "camera_locked", "camera_toggle",
        "camortho", "cancelselect", "cast_hull", "cast_ray", "catapult_physics_drag_boost", "cc_captiontrace", "cc_emit",
        "cc_findsound", "cc_flush", "cc_lang", "cc_linger_time", "cc_minvisibleitems", "cc_predisplay_time", "cc_random",
        "cc_sentencecaptionnorepeat", "cc_showblocks", "cc_smallfontlength", "cc_subtitles",
        "ccs_create_convars_from_hwconfig", "centerview", "ch_createairboat", "ch_createjalopy", "ch_createjeep",
        "changelevel", "changelevel2", "changeteam", "cl_allowdownload", "cl_allowupload", "cl_anglespeedkey",
        "cl_animationinfo", "cl_autowepswitch", "cl_backspeed", "cl_burninggibs", "cl_chatfilters", "cl_class",
        "cl_clearhinthistory", "cl_clock_correction", "cl_clock_correction_adjustment_max_amount",
        "cl_clock_correction_adjustment_max_offset", "cl_clock_correction_adjustment_min_offset",
        "cl_clock_correction_force_server_tick", "cl_clock_showdebuginfo", "cl_clockdrift_max_ms",
        "cl_clockdrift_max_ms_threadmode", "cl_cmdrate", "cl_crosshair_drawoutline", "cl_crosshair_outlinethickness",
        "cl_crosshair_t", "cl_crosshairalpha", "cl_crosshaircolor_b", "cl_crosshaircolor_g", "cl_crosshaircolor_r",
        "cl_crosshairdot", "cl_crosshairgap", "cl_crosshairsize", "cl_crosshairstyle", "cl_crosshairthickness",
        "cl_crosshairusealpha", "cl_customsounds", "cl_debug_player_perf", "cl_debugrumble", "cl_defaultweapon",
        "cl_demoviewoverride", "cl_detail_allow_vertex_lighting", "cl_detail_avoid_force", "cl_detail_avoid_radius",
        "cl_detail_avoid_recover_speed", "cl_detail_max_sway", "cl_detail_multiplier", "cl_detaildist", "cl_detailfade",
        "cl_downloadfilter", "cl_draw_airboat_wake", "cl_drawcameras", "cl_draweffectrings", "cl_drawhud", "cl_drawleaf",
        "cl_drawmaterial", "cl_drawmonitors", "cl_drawownshadow", "cl_drawshadowtexture", "cl_drawspawneffect",
        "cl_drawthrusterseffects", "cl_drawworldtooltips", "cl_dump_particle_stats", "cl_ejectbrass",
        "cl_enable_loadingurl", "cl_ent_absbox", "cl_ent_bbox", "cl_ent_rbox", "cl_entityreport",
        "cl_entityreport_sorted", "cl_extrapolate", "cl_extrapolate_amount", "cl_fastdetailsprites",
        "cl_fasttempentcollision", "cl_find_ent", "cl_find_ent_index", "cl_first_person_uses_world_model",
        "cl_flushentitypacket", "cl_forcepreload", "cl_forwardspeed", "cl_fullupdate", "cl_idealpitchscale",
        "cl_ignorepackets", "cl_interp", "cl_interp_all", "cl_interp_npcs", "cl_interp_ratio", "cl_jiggle_bone_debug",
        "cl_jiggle_bone_debug_pitch_constraints", "cl_jiggle_bone_debug_yaw_constraints", "cl_jiggle_bone_invert",
        "cl_jiggle_bone_sanity", "cl_lagcompensation", "cl_language", "cl_leveloverview", "cl_leveloverviewmarker",
        "cl_localnetworkbackdoor", "cl_logofile", "cl_maxrenderable_dist", "cl_mouseenable", "cl_mouselook",
        "cl_new_impact_effects", "cl_npc_speedmod_intime", "cl_npc_speedmod_outtime", "cl_observercrosshair",
        "cl_overdraw_test", "cl_panelanimation", "cl_particle_batch_mode", "cl_particle_retire_cost",
        "cl_particle_show_bbox", "cl_particle_show_bbox_cost", "cl_particle_stats_start", "cl_particle_stats_stop",
        "cl_particle_stats_trigger_count", "cl_particleeffect_aabb_buffer", "cl_pclass", "cl_pdump",
        "cl_phys_props_enable", "cl_phys_props_max", "cl_phys_props_respawndist", "cl_phys_props_respawnrate",
        "cl_phys_timescale", "cl_pitchdown", "cl_pitchspeed", "cl_pitchup", "cl_playback_screenshots",
        "cl_playerbodygroups", "cl_playercolor", "cl_playermodel", "cl_playerskin", "cl_playerspraydisable",
        "cl_precacheinfo", "cl_pred_optimize", "cl_pred_track", "cl_predict", "cl_predictionlist", "cl_predictweapons",
        "cl_ragdoll_collide", "cl_removedecals", "cl_report_soundpatch", "cl_resend", "cl_rumblescale",
        "cl_screenshotname", "cl_SetupAllBones", "cl_shadowtextureoverlaysize", "cl_show_connectionless_packet_warnings",
        "cl_show_num_particle_systems", "cl_show_splashes", "cl_showbattery", "cl_ShowBoneSetupEnts",
        "cl_showdemooverlay", "cl_showents", "cl_showerror", "cl_showevents", "cl_showfps", "cl_showhelp", "cl_showhints",
        "cl_showhitboxes", "cl_showpausedimage", "cl_showpluginmessages", "cl_showpos", "cl_ShowSunVectors",
        "cl_showtextmsg", "cl_sidespeed", "cl_smooth", "cl_smoothtime", "cl_software_cursor", "cl_soundemitter_flush",
        "cl_soundfile", "cl_soundscape_flush", "cl_soundscape_printdebuginfo", "cl_spewscriptintro",
        "cl_sporeclipdistance", "cl_starfield_diameter", "cl_starfield_distance", "cl_steamoverlay_pos",
        "cl_sun_decay_rate", "cl_team", "cl_threaded_bone_setup", "cl_timeout", "cl_tree_sway_dir", "cl_updaterate",
        "cl_upspeed", "cl_view", "cl_voice_filter", "cl_weaponcolor", "cl_winddir", "cl_windspeed", "cl_wpn_sway_interp",
        "cl_wpn_sway_scale", "cl_yawspeed", "clear", "clear_debug_overlays", "clientport", "closecaption", "cmd",
        "collision_shake_amp", "collision_shake_freq", "collision_shake_time", "collision_test", "colorcorrectionui",
        "colour_a", "colour_b", "colour_fx", "colour_g", "colour_mode", "colour_r", "combine_guard_spawn_health",
        "combine_spawn_health", "commentary", "commentary_available", "commentary_cvarsnotchanging",
        "commentary_finishnode", "commentary_firstrun", "commentary_showmodelviewer", "commentary_testfirstrun",
        "con_drawnotify", "con_enable", "con_filter_dupe", "con_filter_enable", "con_filter_text", "con_filter_text_out",
        "con_notifytime", "con_nprint_bgalpha", "con_nprint_bgborder", "con_timestamp", "con_trace", "connect",
        "contimes", "coop", "create_flashlight", "CreateHairball", "creator_arg", "creator_name", "creator_type",
        "creditsdone", "crosshair", "crosshair_setup", "curve_bias", "cvarlist", "darkness_ignore_LOS_to_sources",
        "datacachesize", "datapack_list", "datapack_paths", "datapack_stats", "dbghist_addline", "dbghist_dump",
        "deathmatch", "debug_dump", "debug_materialmodifycontrol", "debug_materialmodifycontrol_client",
        "debug_physimpact", "debug_touchlinks", "debugsystemui", "decalfrequency", "default_fov", "demo_avellimit",
        "demo_debug", "demo_fastforwardfinalspeed", "demo_fastforwardramptime", "demo_fastforwardstartspeed",
        "demo_fov_override", "demo_gototick", "demo_interplimit", "demo_interpolateview", "demo_legacy_rollback",
        "demo_pause", "demo_pauseatservertick", "demo_quitafterplayback", "demo_recordcommands", "demo_resume",
        "demo_setendtick", "demo_timescale", "demo_togglepause", "demolist", "demos", "demoui", "demoui2",
        "derma_controls", "derma_controls_menu", "derma_icon_browser", "developer", "devshots_nextmap", "differences",
        "disconnect", "disp_dynamic", "dispcoll_drawplane", "displaysoundlist", "dlight_debug", "dog_debug",
        "dog_max_wait_time", "download_debug", "drawcross", "drawline", "dsp_automatic", "dsp_db_min", "dsp_db_mixdrop",
        "dsp_dist_max", "dsp_dist_min", "dsp_enhance_stereo", "dsp_facingaway", "dsp_mix_max", "dsp_mix_min", "dsp_off",
        "dsp_player", "dsp_reload", "dsp_room", "dsp_slow_cpu", "dsp_spatial", "dsp_speaker", "dsp_vol_2ch",
        "dsp_vol_4ch", "dsp_vol_5ch", "dsp_volume", "dsp_water", "dt_ShowPartialChangeEnts", "dt_UsePartialChangeEnts",
        "dti_flush", "dtwarning", "dtwatchclass", "dtwatchent", "dtwatchvar", "dump_entity_sizes", "dump_globals",
        "dump_panels", "dump_x360_cfg", "dump_x360_saves", "dumpentityfactories", "dumpeventqueue", "dumpgamestringtable",
        "dumplongticks", "dumpsavedir", "dumpstringtables", "dumpstringtables_new", "dupe_arm", "dupe_publish",
        "dupe_save", "dupe_show", "dynamite_damage", "dynamite_delay", "dynamite_group", "dynamite_model",
        "dynamite_remove", "echo", "editdemo", "editor_toggle", "effects_freeze", "effects_list", "effects_reload",
        "effects_unfreeze", "elastic_color_b", "elastic_color_g", "elastic_color_r", "elastic_constant",
        "elastic_damping", "elastic_material", "elastic_rdamping", "elastic_stretch_only", "elastic_width",
        "emitter_delay", "emitter_effect", "emitter_key", "emitter_scale", "emitter_starton", "emitter_toggle",
        "enable_debug_overlays", "endmovie", "engine_no_focus_sleep", "english", "ent_absbox", "ent_attachments",
        "ent_autoaim", "ent_bbox", "ent_cancelpendingentfires", "ent_create", "ent_debugkeys", "ent_dump", "ent_fire",
        "ent_info", "ent_keyvalue", "ent_messages", "ent_messages_draw", "ent_name", "ent_orient", "ent_pause",
        "ent_pivot", "ent_rbox", "ent_remove", "ent_remove_all", "ent_rotate", "ent_setname",
        "ent_show_response_criteria", "ent_step", "ent_teleport", "ent_text", "ent_viewoffset", "envmap", "escape",
        "exec", "exit", "explode", "explodevector", "explosion_dlight", "eyeposer_strabismus", "eyeposer_x", "eyeposer_y",
        "faceposer_flex0", "faceposer_flex1", "faceposer_flex10", "faceposer_flex11", "faceposer_flex12",
        "faceposer_flex13", "faceposer_flex14", "faceposer_flex15", "faceposer_flex16", "faceposer_flex17",
        "faceposer_flex18", "faceposer_flex19", "faceposer_flex2", "faceposer_flex20", "faceposer_flex21",
        "faceposer_flex22", "faceposer_flex23", "faceposer_flex24", "faceposer_flex25", "faceposer_flex26",
        "faceposer_flex27", "faceposer_flex28", "faceposer_flex29", "faceposer_flex3", "faceposer_flex30",
        "faceposer_flex31", "faceposer_flex32", "faceposer_flex33", "faceposer_flex34", "faceposer_flex35",
        "faceposer_flex36", "faceposer_flex37", "faceposer_flex38", "faceposer_flex39", "faceposer_flex4",
        "faceposer_flex40", "faceposer_flex41", "faceposer_flex42", "faceposer_flex43", "faceposer_flex44",
        "faceposer_flex45", "faceposer_flex46", "faceposer_flex47", "faceposer_flex48", "faceposer_flex49",
        "faceposer_flex5", "faceposer_flex50", "faceposer_flex51", "faceposer_flex52", "faceposer_flex53",
        "faceposer_flex54", "faceposer_flex55", "faceposer_flex56", "faceposer_flex57", "faceposer_flex58",
        "faceposer_flex59", "faceposer_flex6", "faceposer_flex60", "faceposer_flex61", "faceposer_flex62",
        "faceposer_flex63", "faceposer_flex64", "faceposer_flex65", "faceposer_flex66", "faceposer_flex67",
        "faceposer_flex68", "faceposer_flex69", "faceposer_flex7", "faceposer_flex70", "faceposer_flex71",
        "faceposer_flex72", "faceposer_flex73", "faceposer_flex74", "faceposer_flex75", "faceposer_flex76",
        "faceposer_flex77", "faceposer_flex78", "faceposer_flex79", "faceposer_flex8", "faceposer_flex80",
        "faceposer_flex81", "faceposer_flex82", "faceposer_flex83", "faceposer_flex84", "faceposer_flex85",
        "faceposer_flex86", "faceposer_flex87", "faceposer_flex88", "faceposer_flex89", "faceposer_flex9",
        "faceposer_flex90", "faceposer_flex91", "faceposer_flex92", "faceposer_flex93", "faceposer_flex94",
        "faceposer_flex95", "faceposer_flex96", "faceposer_randomize", "faceposer_scale", "fadein", "fadeout",
        "fast_fogvolume", "filesystem_buffer_size", "filesystem_max_stdio_read", "filesystem_native",
        "filesystem_report_buffered_io", "filesystem_unbuffered_io", "filesystem_use_overlapped_io", "find", "find_ent",
        "find_ent_index", "findflags", "finger_0", "finger_1", "finger_10", "finger_11", "finger_12", "finger_13",
        "finger_14", "finger_15", "finger_2", "finger_3", "finger_4", "finger_5", "finger_6", "finger_7", "finger_8",
        "finger_9", "finger_restrict", "fire_absorbrate", "fire_dmgbase", "fire_dmginterval", "fire_dmgscale",
        "fire_extabsorb", "fire_extscale", "fire_growthrate", "fire_heatscale", "fire_incomingheatscale",
        "fire_maxabsorb", "firetarget", "firstperson", "fish_debug", "fish_dormant", "flex_expression", "flex_looktime",
        "flex_maxawaytime", "flex_maxplayertime", "flex_minawaytime", "flex_minplayertime", "flex_rules", "flex_smooth",
        "flex_talk", "flush", "flush_locked", "fog_color", "fog_colorskybox", "fog_enable", "fog_enable_water_fog",
        "fog_enableskybox", "fog_end", "fog_endskybox", "fog_maxdensity", "fog_maxdensityskybox", "fog_override",
        "fog_start", "fog_startskybox", "fogui", "force_centerview", "fov", "fov_desired", "fps_max",
        "free_pass_peek_debug", "fs_monitor_read_from_pack", "fs_printopenfiles", "fs_report_sync_opens",
        "fs_tellmeyoursecrets", "fs_warning_level", "fs_warning_mode", "func_break_max_pieces",
        "func_break_reduction_factor", "func_breakdmg_bullet", "func_breakdmg_club", "func_breakdmg_explosive",
        "g15_dumpplayer", "g15_reload", "g15_update_msec", "g_ai_citizen_show_enemy", "g_antlion_cascade_push",
        "g_antlion_maxgibs", "g_antlionguard_hemorrhage", "g_debug_angularsensor", "g_debug_antlion",
        "g_debug_antlion_worker", "g_debug_antlionguard", "g_debug_antlionmaker", "g_debug_basehelicopter",
        "g_debug_basescanner", "g_debug_combine_camera", "g_debug_constraint_sounds", "g_debug_cscanner",
        "g_debug_darkness", "g_debug_doors", "g_debug_dropship", "g_debug_dynamicresupplies", "g_debug_gunship",
        "g_debug_headcrab", "g_debug_hunter_charge", "g_debug_injured_follow", "g_debug_npc_vehicle_roles",
        "g_debug_physcannon", "g_debug_ragdoll_removal", "g_debug_ragdoll_visualize", "g_debug_trackpather",
        "g_debug_transitions", "g_debug_turret", "g_debug_turret_ceiling", "g_debug_vehiclebase", "g_debug_vehicledriver",
        "g_debug_vehicleexit", "g_debug_vehiclesound", "g_debug_vortigaunt_aim", "g_helicopter_bomb_danger_radius",
        "g_helicopter_bullrush_bomb_enemy_distance", "g_helicopter_bullrush_bomb_speed",
        "g_helicopter_bullrush_bomb_time", "g_helicopter_bullrush_distance", "g_helicopter_bullrush_mega_bomb_health",
        "g_helicopter_bullrush_shoot_height", "g_helicopter_chargetime", "g_helicopter_idletime",
        "g_helicopter_maxfiringdist", "g_jeepexitspeed", "g_Language", "g_ragdoll_fadespeed",
        "g_ragdoll_important_maxcount", "g_ragdoll_lvfadespeed", "g_ragdoll_maxcount", "g_test_new_antlion_jump",
        "gamemenucommand", "gamemode", "gameui_activate", "gameui_allowescape", "gameui_allowescapetoshow", "gameui_hide",
        "gameui_hide_dialog", "gameui_preventescape", "gameui_preventescapetoshow", "gameui_show_dialog", "gameui_xbox",
        "getpos", "give", "givecurrentammo", "gl_amd_occlusion_workaround", "gl_clear", "gl_clear_randomcolor",
        "global_set", "gm_demo", "gm_demo_icon", "gm_demo_to_video", "gm_giveswep", "gm_load", "gm_save", "gm_showhelp",
        "gm_showspare1", "gm_showspare2", "gm_showteam", "gm_snapangles", "gm_snapgrid", "gm_spawn", "gm_spawnsent",
        "gm_spawnswep", "gm_spawnvehicle", "gm_video", "gmod_admin_cleanup", "gmod_camera", "gmod_cleanup",
        "gmod_delete_temp_files", "gmod_drawhelp", "gmod_drawtooleffects", "gmod_language", "gmod_maxammo",
        "gmod_mcore_test", "gmod_modding", "gmod_npcweapon", "gmod_physiterations", "gmod_privacy", "gmod_servers",
        "gmod_spawnnpc", "gmod_suit", "gmod_tool", "gmod_toolmode", "gmod_tos", "gmod_undo", "gmod_undonum",
        "gmod_unload_test", "god", "groundlist", "hammer_update_entity", "hammer_update_safe_entities",
        "hap_airboat_gun_mag", "hap_damagescale_game", "hap_HasDevice", "hap_jeep_cannon_mag", "hap_melee_scale",
        "hap_noclip_avatar_scale", "hap_turret_mag", "hap_ui_vehicles", "help", "hideconsole", "hidehud", "hidepanel",
        "hl1_debug_sentence_volume", "hl1_fixup_sentence_sndlevel", "hl2_darkness_flashlight_factor", "hl2_episodic",
        "host_flush_threshold", "host_framerate", "host_limitlocal", "host_map", "host_profile", "host_runofftime",
        "host_showcachemiss", "host_ShowIPCCallCount", "host_sleep", "host_speeds", "host_timer_report", "host_timescale",
        "host_workshop_collection", "host_writeconfig", "hostip", "hostname", "hostport", "hoverball_keydn",
        "hoverball_keyon", "hoverball_keyup", "hoverball_model", "hoverball_resistance", "hoverball_speed",
        "hoverball_strength", "hud_airboathint_numentries", "hud_autoaim_method", "hud_autoaim_scale_icon",
        "hud_autoreloadscript", "hud_centerid", "hud_deathnotice_time", "hud_draw_active_reticle",
        "hud_draw_fixed_reticle", "hud_drawhistory_time", "hud_fastswitch", "hud_freezecamhide",
        "hud_jeephint_numentries", "hud_magnetism", "hud_quickinfo", "hud_reloadscheme", "hud_reticle_alpha_speed",
        "hud_reticle_maxalpha", "hud_reticle_minalpha", "hud_reticle_scale", "hud_saytext_time", "hud_showtargetid",
        "hud_takesshots", "hunter_allow_dissolve", "hunter_allow_nav_jump", "hunter_charge", "hunter_charge_min_delay",
        "hunter_charge_pct", "hunter_charge_test", "hunter_cheap_explosions", "hunter_clamp_shots",
        "hunter_disable_patrol", "hunter_dodge_debug", "hunter_dodge_warning", "hunter_dodge_warning_cone",
        "hunter_dodge_warning_width", "hunter_first_flechette_delay", "hunter_flechette_delay",
        "hunter_flechette_explode_delay", "hunter_flechette_max_concurrent_volleys", "hunter_flechette_max_range",
        "hunter_flechette_min_range", "hunter_flechette_speed", "hunter_flechette_test",
        "hunter_flechette_volley_end_max_delay", "hunter_flechette_volley_end_min_delay", "hunter_flechette_volley_size",
        "hunter_flechette_volley_start_max_delay", "hunter_flechette_volley_start_min_delay", "hunter_free_knowledge",
        "hunter_hate_attached_striderbusters", "hunter_hate_held_striderbusters", "hunter_hate_held_striderbusters_delay",
        "hunter_hate_held_striderbusters_tolerance", "hunter_hate_thrown_striderbusters",
        "hunter_hate_thrown_striderbusters_tolerance", "hunter_jostle_car_max_speed", "hunter_jostle_car_min_speed",
        "hunter_melee_delay", "hunter_plant_adjust_z", "hunter_random_expressions", "hunter_retreat_striderbusters",
        "hunter_seek_thrown_striderbusters_tolerance", "hunter_shoot_flechette", "hunter_show_weapon_los_condition",
        "hunter_show_weapon_los_z", "hunter_siege_frequency", "hunter_stand_still", "hurtme", "hydraulic_addlength",
        "hydraulic_color_b", "hydraulic_color_g", "hydraulic_color_r", "hydraulic_fixed", "hydraulic_group",
        "hydraulic_material", "hydraulic_speed", "hydraulic_toggle", "hydraulic_width", "impulse",
        "in_usekeyboardsampletime", "incrementvar", "injured_help_plee_range", "invnext", "invprev", "ip",
        "jalopy_blocked_exit_max_speed", "jalopy_cargo_anim_time", "jalopy_radar_test_ent", "joy_accel_filter",
        "joy_accelmax", "joy_accelscale", "joy_advanced", "joy_advaxisr", "joy_advaxisu", "joy_advaxisv", "joy_advaxisx",
        "joy_advaxisy", "joy_advaxisz", "joy_autoaimdampen", "joy_autoaimdampenrange", "joy_autosprint",
        "joy_axisbutton_threshold", "joy_deadzone_mode", "joy_diagonalpov", "joy_display_input", "joy_forwardsensitivity",
        "joy_forwardthreshold", "joy_inverty", "joy_inverty_default", "joy_lowend", "joy_lowmap", "joy_movement_stick",
        "joy_movement_stick_default", "joy_name", "joy_pegged", "joy_pitchsensitivity", "joy_pitchsensitivity_default",
        "joy_pitchthreshold", "joy_response_look", "joy_response_move", "joy_response_move_vehicle",
        "joy_sidesensitivity", "joy_sidethreshold", "joy_vehicle_turn_lowend", "joy_vehicle_turn_lowmap",
        "joy_virtual_peg", "joy_wingmanwarrior_centerhack", "joy_wingmanwarrior_turnhack", "joy_xcontroller_cfg_loaded",
        "joy_xcontroller_found", "joy_yawsensitivity", "joy_yawsensitivity_default", "joy_yawthreshold",
        "joyadvancedupdate", "joystick", "joystick_force_disabled", "jpeg", "jpeg_quality", "kdtree_test",
        "key_findbinding", "key_listboundkeys", "key_updatelayout", "kick", "kickall", "kickid", "kickid2", "kill",
        "killserver", "killvector", "lamp_b", "lamp_brightness", "lamp_distance", "lamp_fov", "lamp_g", "lamp_key",
        "lamp_model", "lamp_r", "lamp_texture", "lamp_toggle", "language_reload", "lastinv", "light_b",
        "light_brightness", "light_crosshair", "light_g", "light_key", "light_r", "light_ropelength",
        "light_ropematerial", "light_size", "light_toggle", "lightcache_maxmiss", "lightprobe", "linefile", "listdemo",
        "listid", "listip", "listissues", "listmodels", "listRecentNPCSpeech", "load", "loadcommentary",
        "loader_dump_table", "loader_spew_info", "loader_spew_info_ex", "lod_TransitionDist", "log", "log_verbose_enable",
        "log_verbose_interval", "logaddress_add", "logaddress_del", "logaddress_delall", "logaddress_list", "lookspring",
        "lookstrafe", "lservercfgfile", "lua_cookieclear", "lua_dumpfonts", "lua_dumpfonts_menu", "lua_dumptimers_cl",
        "lua_dumptimers_menu", "lua_dumptimers_sv", "lua_error_url", "lua_filestats", "lua_find", "lua_find_cl",
        "lua_findhooks", "lua_findhooks_cl", "lua_log_cl", "lua_log_sv", "lua_matproxy", "lua_networkvar_bytespertick",
        "lua_openscript", "lua_openscript_cl", "lua_refresh_file", "lua_reloadents", "lua_run", "lua_run_cl",
        "LuaParticle_SettleSpeed", "m_customaccel", "m_customaccel_exponent", "m_customaccel_max", "m_customaccel_scale",
        "m_filter", "m_forward", "m_mouseaccel1", "m_mouseaccel2", "m_mousespeed", "m_pitch", "m_rawinput", "m_side",
        "m_yaw", "map", "map_background", "map_commentary", "map_edit", "map_noareas", "mapcyclefile", "maps",
        "mat_aaquality", "mat_accelerate_adjust_exposure_down", "mat_alphacoverage", "mat_antialias",
        "mat_autoexposure_max", "mat_autoexposure_min", "mat_bloom_scalefactor_scalar", "mat_bloomamount_rate",
        "mat_bloomscale", "mat_bufferprimitives", "mat_bumpbasis", "mat_bumpmap", "mat_camerarendertargetoverlaysize",
        "mat_clipz", "mat_colcorrection_disableentities", "mat_color_projection", "mat_colorcorrection",
        "mat_compressedtextures", "mat_configcurrent", "mat_crosshair", "mat_crosshair_edit", "mat_crosshair_explorer",
        "mat_crosshair_printmaterial", "mat_crosshair_reloadmaterial", "mat_debug_autoexposure", "mat_debug_bloom",
        "mat_debug_postprocessing_effects", "mat_debug_process_halfscreen", "mat_debugalttab", "mat_debugdepth",
        "mat_debugdepthmode", "mat_debugdepthval", "mat_debugdepthvalmax", "mat_depthbias_decal", "mat_depthbias_normal",
        "mat_depthbias_shadowmap", "mat_diffuse", "mat_disable_bloom", "mat_disable_d3d9ex", "mat_disable_fancy_blending",
        "mat_disable_lightwarp", "mat_disable_ps_patch", "mat_disablehwmorph", "mat_drawflat", "mat_drawTexture",
        "mat_drawTextureScale", "mat_drawTitleSafe", "mat_drawwater", "mat_dump_rts", "mat_dumpmaterials",
        "mat_dumptextures", "mat_dxlevel", "mat_dynamic_tonemapping", "mat_edit", "mat_envmapsize", "mat_envmaptgasize",
        "mat_excludetextures", "mat_exposure_center_region_x", "mat_exposure_center_region_x_flashlight",
        "mat_exposure_center_region_y", "mat_exposure_center_region_y_flashlight", "mat_fastclip", "mat_fastnobump",
        "mat_fastspecular", "mat_fillrate", "mat_filterlightmaps", "mat_filtertextures", "mat_force_bloom",
        "mat_force_ps_patch", "mat_force_tonemap_scale", "mat_forceaniso", "mat_forcedynamic", "mat_forcehardwaresync",
        "mat_forcemanagedtextureintohardware", "mat_frame_sync_enable", "mat_frame_sync_force_texture",
        "mat_framebuffercopyoverlaysize", "mat_fullbright", "mat_hdr_enabled", "mat_hdr_level",
        "mat_hdr_manual_tonemap_rate", "mat_hdr_tonemapscale", "mat_hdr_uncapexposure", "mat_hsv", "mat_info",
        "mat_leafvis", "mat_levelflush", "mat_lightmap_pfms", "mat_loadtextures", "mat_luxels", "mat_managedtextures",
        "mat_max_worldmesh_vertices", "mat_maxframelatency", "mat_measurefillrate", "mat_mipmaptextures",
        "mat_monitorgamma", "mat_monitorgamma_tv_enabled", "mat_monitorgamma_tv_exp", "mat_monitorgamma_tv_range_max",
        "mat_monitorgamma_tv_range_min", "mat_morphstats", "mat_motion_blur_enabled", "mat_motion_blur_falling_intensity",
        "mat_motion_blur_falling_max", "mat_motion_blur_falling_min", "mat_motion_blur_forward_enabled",
        "mat_motion_blur_percent_of_screen_max", "mat_motion_blur_rotation_intensity", "mat_motion_blur_strength",
        "mat_non_hdr_bloom_scalefactor", "mat_norendering", "mat_normalmaps", "mat_normals", "mat_parallaxmap",
        "mat_picmip", "mat_postprocess_x", "mat_postprocess_y", "mat_postprocessing_combine", "mat_powersavingsmode",
        "mat_proxy", "mat_queue_mode", "mat_queue_report", "mat_reducefillrate", "mat_reduceparticles",
        "mat_reloadallmaterials", "mat_reloadmaterial", "mat_reloadtexture", "mat_reloadtextures",
        "mat_remoteshadercompile", "mat_report_queue_status", "mat_reporthwmorphmemory", "mat_reversedepth",
        "mat_savechanges", "mat_setvideomode", "mat_shadercount", "mat_shadowstate", "mat_show_ab_hdr",
        "mat_show_ab_hdr_hudelement", "mat_show_histogram", "mat_show_texture_memory_usage", "mat_showcamerarendertarget",
        "mat_showenvmapmask", "mat_showframebuffertexture", "mat_showlightmappage", "mat_showlowresimage",
        "mat_showmaterials", "mat_showmaterialsverbose", "mat_showmiplevels", "mat_showtextures", "mat_showwatertextures",
        "mat_slopescaledepthbias_decal", "mat_slopescaledepthbias_normal", "mat_slopescaledepthbias_shadowmap",
        "mat_software_aa_blur_one_pixel_lines", "mat_software_aa_debug", "mat_software_aa_edge_threshold",
        "mat_software_aa_quality", "mat_software_aa_strength", "mat_software_aa_strength_vgui",
        "mat_software_aa_tap_offset", "mat_softwarelighting", "mat_softwareskin", "mat_specular",
        "mat_spewvertexandpixelshaders", "mat_stub", "mat_supportflashlight", "mat_surfaceid", "mat_surfacemat",
        "mat_texture_list", "mat_texture_list_all", "mat_texture_list_content_path", "mat_texture_list_txlod",
        "mat_texture_list_txlod_sync", "mat_texture_list_view", "mat_texture_outline_fonts", "mat_texture_save_fonts",
        "mat_tonemap_algorithm", "mat_tonemap_min_avglum", "mat_tonemap_percent_bright_pixels",
        "mat_tonemap_percent_target", "mat_tonemapping_occlusion_use_stencil", "mat_trilinear",
        "mat_use_compressed_hdr_textures", "mat_viewportscale", "mat_viewportupscale", "mat_visualize_dof", "mat_vsync",
        "mat_wateroverlaysize", "mat_wireframe", "mat_yuv", "matchmakingport", "material_override", "maxplayers",
        "mem_compact", "mem_dump", "mem_dumpstats", "mem_dumpvballocs", "mem_eat", "mem_force_flush",
        "mem_incremental_compact", "mem_max_heapsize", "mem_max_heapsize_dedicated", "mem_min_heapsize",
        "mem_periodicdumps", "mem_test", "mem_test_each_frame", "mem_test_every_n_seconds", "mem_vcollide", "mem_verify",
        "memory", "menu_cleanupgmas", "metropolice_charge", "metropolice_chase_use_follow", "metropolice_move_and_melee",
        "minisave", "mission_list", "mission_show", "mod_forcedata", "mod_forcetouchdata", "mod_load_anims_async",
        "mod_load_fakestall", "mod_load_mesh_async", "mod_load_showstall", "mod_load_vcollide_async",
        "mod_lock_mdls_on_load", "mod_test_mesh_not_available", "mod_test_not_available", "mod_test_verts_not_available",
        "mod_touchalldata", "mod_trace_load", "model_list", "monk_headshot_freq", "mortar_visualize", "motdfile",
        "motdfile_text", "motor_bwd", "motor_forcelimit", "motor_forcetime", "motor_friction", "motor_fwd",
        "motor_nocollide", "motor_toggle", "motor_torque", "movie_fixwave", "mp_allowNPCs", "mp_allowspectators",
        "mp_autocrosshair", "mp_chattime", "mp_clan_ready_signal", "mp_clan_readyrestart", "mp_decals", "mp_defaultteam",
        "mp_disable_autokick", "mp_fadetoblack", "mp_falldamage", "mp_flashlight", "mp_footsteps", "mp_forcecamera",
        "mp_forcerespawn", "mp_fraglimit", "mp_friendlyfire", "mp_mapcycle_empty_timeout_seconds", "mp_ready_signal",
        "mp_readyrestart", "mp_restartgame", "mp_restartgame_immediate", "mp_show_voice_icons", "mp_teamlist",
        "mp_teamoverride", "mp_teamplay", "mp_timelimit", "mp_usehwmmodels", "mp_usehwmvcds",
        "mp_waitingforplayers_cancel", "mp_waitingforplayers_restart", "mp_waitingforplayers_time", "mp_weaponstay",
        "multvar", "muscle_addlength", "muscle_color_b", "muscle_color_g", "muscle_color_r", "muscle_fixed",
        "muscle_group", "muscle_material", "muscle_period", "muscle_starton", "muscle_width", "muzzleflash_light", "name",
        "nav_add_to_selected_set", "nav_add_to_selected_set_by_id", "nav_analyze", "nav_area_bgcolor",
        "nav_area_max_size", "nav_avoid", "nav_begin_area", "nav_begin_deselecting", "nav_begin_drag_deselecting",
        "nav_begin_drag_selecting", "nav_begin_selecting", "nav_begin_shift_xy", "nav_build_ladder",
        "nav_check_file_consistency", "nav_check_floor", "nav_check_stairs", "nav_chop_selected", "nav_clear_attribute",
        "nav_clear_selected_set", "nav_clear_walkable_marks", "nav_compress_id", "nav_connect",
        "nav_coplanar_slope_limit", "nav_coplanar_slope_limit_displacement", "nav_corner_adjust_adjacent",
        "nav_corner_lower", "nav_corner_place_on_ground", "nav_corner_raise", "nav_corner_select",
        "nav_create_area_at_feet", "nav_create_place_on_ground", "nav_crouch", "nav_debug_blocked", "nav_delete",
        "nav_delete_marked", "nav_disconnect", "nav_disconnect_outgoing_oneways", "nav_displacement_test",
        "nav_dont_hide", "nav_drag_selection_volume_zmax_offset", "nav_drag_selection_volume_zmin_offset",
        "nav_draw_limit", "nav_dump_selected_set_positions", "nav_edit", "nav_end_area", "nav_end_deselecting",
        "nav_end_drag_deselecting", "nav_end_drag_selecting", "nav_end_selecting", "nav_end_shift_xy", "nav_flood_select",
        "nav_gen_cliffs_approx", "nav_generate", "nav_generate_fencetops", "nav_generate_fixup_jump_areas",
        "nav_generate_incremental", "nav_generate_incremental_range", "nav_generate_incremental_tolerance", "nav_jump",
        "nav_ladder_flip", "nav_load", "nav_lower_drag_volume_max", "nav_lower_drag_volume_min", "nav_make_sniper_spots",
        "nav_mark", "nav_mark_attribute", "nav_mark_unnamed", "nav_mark_walkable", "nav_max_view_distance",
        "nav_max_vis_delta_list_length", "nav_merge", "nav_merge_mesh", "nav_no_hostages", "nav_no_jump",
        "nav_place_floodfill", "nav_place_list", "nav_place_pick", "nav_place_replace", "nav_place_set",
        "nav_potentially_visible_dot_tolerance", "nav_precise", "nav_quicksave", "nav_raise_drag_volume_max",
        "nav_raise_drag_volume_min", "nav_recall_selected_set", "nav_remove_from_selected_set", "nav_remove_jump_areas",
        "nav_run", "nav_save", "nav_save_selected", "nav_select_blocked_areas", "nav_select_damaging_areas",
        "nav_select_half_space", "nav_select_invalid_areas", "nav_select_larger_than", "nav_select_obstructed_areas",
        "nav_select_orphans", "nav_select_overlapping", "nav_select_radius", "nav_select_stairs",
        "nav_selected_set_border_color", "nav_selected_set_color", "nav_set_place_mode", "nav_shift",
        "nav_show_approach_points", "nav_show_area_info", "nav_show_compass", "nav_show_continguous", "nav_show_danger",
        "nav_show_dumped_positions", "nav_show_func_nav_avoid", "nav_show_func_nav_prefer", "nav_show_light_intensity",
        "nav_show_node_grid", "nav_show_node_id", "nav_show_nodes", "nav_show_player_counts",
        "nav_show_potentially_visible", "nav_simplify_selected", "nav_slope_limit", "nav_slope_tolerance",
        "nav_snap_to_grid", "nav_solid_props", "nav_splice", "nav_split", "nav_split_place_on_ground", "nav_stand",
        "nav_stop", "nav_store_selected_set", "nav_strip", "nav_subdivide", "nav_test_node", "nav_test_node_crouch",
        "nav_test_node_crouch_dir", "nav_test_stairs", "nav_toggle_deselecting", "nav_toggle_in_selected_set",
        "nav_toggle_place_mode", "nav_toggle_place_painting", "nav_toggle_selected_set", "nav_toggle_selecting",
        "nav_transient", "nav_unmark", "nav_update_blocked", "nav_update_lighting", "nav_update_visibility_on_edit",
        "nav_use_place", "nav_walk", "nav_warp_to_mark", "nav_world_center", "nb_allow_avoiding", "nb_allow_climbing",
        "nb_allow_gap_jumping", "nb_blind", "nb_command", "nb_debug", "nb_debug_climbing", "nb_debug_filter",
        "nb_debug_history", "nb_debug_known_entities", "nb_delete_all", "nb_force_look_at", "nb_goal_look_ahead_range",
        "nb_head_aim_resettle_angle", "nb_head_aim_resettle_time", "nb_head_aim_settle_duration",
        "nb_head_aim_steady_max_rate", "nb_ladder_align_range", "nb_last_area_update_tolerance", "nb_move_to_cursor",
        "nb_path_draw_inc", "nb_path_draw_segment_count", "nb_path_segment_influence_radius", "nb_player_crouch",
        "nb_player_move", "nb_player_move_direct", "nb_player_stop", "nb_player_walk", "nb_saccade_speed",
        "nb_saccade_time", "nb_select", "nb_shadow_dist", "nb_speed_look_ahead_range", "nb_stop", "nb_update_debug",
        "nb_update_framelimit", "nb_update_frequency", "nb_update_maxslide", "nb_warp_selected_here", "net_blockmsg",
        "net_channels", "net_chokeloop", "net_compresspackets", "net_compresspackets_minsize", "net_compressvoice",
        "net_drawslider", "net_droppackets", "net_fakejitter", "net_fakelag", "net_fakeloss", "net_graph",
        "net_graphheight", "net_graphmsecs", "net_graphpos", "net_graphproportionalfont", "net_graphshowinterp",
        "net_graphshowlatency", "net_graphsolid", "net_graphtext", "net_maxcleartime", "net_maxfilesize",
        "net_maxfragments", "net_maxpacketdrop", "net_maxroutable", "net_queue_trace", "net_queued_packet_thread",
        "net_scale", "net_showdrop", "net_showevents", "net_showfragments", "net_showmsg", "net_showpeaks",
        "net_showsplits", "net_showtcp", "net_showudp", "net_showudp_wire", "net_splitpacket_maxrate", "net_splitrate",
        "net_start", "net_status", "net_udp_rcvbuf", "net_usesocketsforloopback", "next", "nextdemo", "nextlevel",
        "noclip", "notarget", "npc_ally_deathmessage", "npc_alyx_crouch", "npc_alyx_force_stop_moving",
        "npc_alyx_readiness", "npc_alyx_readiness_transitions", "npc_ammo_deplete", "npc_barnacle_swallow", "npc_bipass",
        "npc_citizen_auto_player_squad", "npc_citizen_auto_player_squad_allow_use", "npc_citizen_dont_precache_all",
        "npc_citizen_explosive_resist", "npc_citizen_heal_chuck_medkit", "npc_citizen_insignia",
        "npc_citizen_medic_emit_sound", "npc_citizen_medic_throw_speed", "npc_citizen_medic_throw_style",
        "npc_citizen_squad_marker", "npc_combat", "npc_conditions", "npc_create", "npc_create_aimed",
        "npc_create_equipment", "npc_destroy", "npc_destroy_unselected", "npc_enemies", "npc_focus", "npc_freeze",
        "npc_freeze_unselected", "npc_go", "npc_go_do_run", "npc_go_random", "npc_heal", "npc_height_adjust", "npc_kill",
        "npc_nearest", "npc_relationships", "npc_reset", "npc_route", "npc_select", "npc_sentences", "npc_squads",
        "npc_steering", "npc_steering_all", "npc_strider_height_adj", "npc_strider_shake_ropes_magnitude",
        "npc_strider_shake_ropes_radius", "npc_task_text", "npc_tasks", "npc_teleport", "npc_thinknow", "npc_viewcone",
        "npc_vphysics", "old_radiusdamage", "opt_EnumerateLeavesFastAlgorithm", "option_duck_method",
        "option_duck_method_default", "overview_alpha", "overview_health", "overview_locked", "overview_names",
        "overview_tracks", "p2p_enabled", "p2p_friendsonly", "paint_decal", "panel_test_title_safe",
        "particle_sim_alt_cores", "particle_simulateoverflow", "particle_test_attach_attachment",
        "particle_test_attach_mode", "particle_test_file", "particle_test_start", "particle_test_stop",
        "passenger_collision_response_threshold", "passenger_debug_entry", "passenger_debug_transition",
        "passenger_impact_response_threshold", "passenger_use_leaning", "password", "path", "pause", "perfui",
        "perfvisualbenchmark", "perfvisualbenchmark_abort", "phonemedelay", "phonemefilter", "phonemesnap",
        "phys_impactforcescale", "phys_penetration_error_time", "phys_pushscale", "phys_speeds", "phys_spinspeed",
        "phys_stressbodyweights", "phys_swap", "phys_timescale", "phys_upimpactforcescale", "physcannon_ball_cone",
        "physcannon_chargetime", "physcannon_cone", "physcannon_maxforce", "physcannon_maxmass",
        "physcannon_mega_enabled", "physcannon_minforce", "physcannon_pullforce", "physcannon_tracelength",
        "physgun_DampingFactor", "physgun_drawbeams", "physgun_halo", "physgun_limited", "physgun_maxAngular",
        "physgun_maxAngularDamping", "physgun_maxrange", "physgun_maxSpeed", "physgun_maxSpeedDamping",
        "physgun_rotation_sensitivity", "physgun_teleportDistance", "physgun_timeToArrive", "physgun_timeToArriveRagdoll",
        "physgun_wheelspeed", "physics_budget", "physics_constraints", "physics_debug_entity", "physics_highlight_active",
        "physics_report_active", "physics_select", "physicsshadowupdate_render", "physprop_gravity_toggle",
        "physprop_material", "picker", "ping", "pipeline_static_props", "pixelvis_debug", "play", "playdemo",
        "player_debug_print_damage", "player_limit_jump_speed", "player_old_armor", "player_showpredictedposition",
        "player_showpredictedposition_timestep", "player_squad_autosummon_debug",
        "player_squad_autosummon_move_tolerance", "player_squad_autosummon_player_tolerance",
        "player_squad_autosummon_time", "player_squad_autosummon_time_after_combat", "player_squad_double_tap_time",
        "player_squad_transient_commands", "player_throwforce", "playflush", "playgamesound", "playsoundscape",
        "playvideo", "playvol", "plugin_pause", "plugin_pause_all", "plugin_print", "plugin_unload", "plugin_unpause",
        "plugin_unpause_all", "poster", "pp_bloom", "pp_bloom_color", "pp_bloom_color_b", "pp_bloom_color_g",
        "pp_bloom_color_r", "pp_bloom_darken", "pp_bloom_multiply", "pp_bloom_passes", "pp_bloom_sizex", "pp_bloom_sizey",
        "pp_bokeh", "pp_bokeh_blur", "pp_bokeh_distance", "pp_bokeh_focus", "pp_colormod", "pp_colormod_addb",
        "pp_colormod_addg", "pp_colormod_addr", "pp_colormod_brightness", "pp_colormod_color", "pp_colormod_contrast",
        "pp_colormod_inv", "pp_colormod_mulb", "pp_colormod_mulg", "pp_colormod_mulr", "pp_dof", "pp_dof_initlength",
        "pp_dof_spacing", "pp_fb", "pp_fb_frames", "pp_fb_shutter", "pp_mat_overlay", "pp_mat_overlay_refractamount",
        "pp_motionblur", "pp_motionblur_addalpha", "pp_motionblur_delay", "pp_motionblur_drawalpha", "pp_sharpen",
        "pp_sharpen_contrast", "pp_sharpen_distance", "pp_sobel", "pp_sobel_threshold", "pp_stereoscopy",
        "pp_stereoscopy_size", "pp_sunbeams", "pp_sunbeams_darken", "pp_sunbeams_multiply", "pp_sunbeams_sunsize",
        "pp_superdof", "pp_texturize", "pp_texturize_scale", "pp_toytown", "pp_toytown_passes", "pp_toytown_size",
        "press_x360_button", "print_colorcorrection", "progress_enable", "prop_active_gib_limit",
        "prop_active_gib_max_fade_time", "prop_crosshair", "prop_debug", "prop_dynamic_create", "prop_physics_create",
        "props_break_max_pieces", "props_break_max_pieces_perframe", "pulley_color_b", "pulley_color_g", "pulley_color_r",
        "pulley_forcelimit", "pulley_material", "pulley_rigid", "pulley_width", "pwatchent", "pwatchvar",
        "pyro_max_intensity", "pyro_max_rate", "pyro_max_side_length", "pyro_max_side_width", "pyro_min_intensity",
        "pyro_min_rate", "pyro_min_side_length", "pyro_min_side_width", "pyro_vignette", "pyro_vignette_distortion",
        "quit", "r_3dsky", "r_AirboatPitchCurveLinear", "r_AirboatPitchCurveZero", "r_AirboatRollCurveLinear",
        "r_AirboatRollCurveZero", "r_AirboatViewBlendTo", "r_AirboatViewBlendToScale", "r_AirboatViewBlendToTime",
        "r_ambientboost", "r_ambientfactor", "r_ambientfraction", "r_ambientlightingonly", "r_ambientmin",
        "r_aspectratio", "r_avglight", "r_avglightmap", "r_bloomtintb", "r_bloomtintexponent", "r_bloomtintg",
        "r_bloomtintr", "r_cheapwaterend", "r_cheapwaterstart", "r_cleardecals", "r_ClipAreaFrustums",
        "r_ClipAreaPortals", "r_colorstaticprops", "r_debugcheapwater", "r_debugrandomstaticlighting",
        "r_decal_cover_count", "r_decal_cullsize", "r_decal_overlap_area", "r_decal_overlap_count", "r_decals",
        "r_decalstaticprops", "r_depthoverlay", "r_DispBuildable", "r_DispDrawAxes", "r_DispWalkable",
        "r_dopixelvisibility", "r_drawbatchdecals", "r_DrawBeams", "r_drawbrushmodels", "r_drawclipbrushes",
        "r_drawdecals", "r_drawdetailprops", "r_DrawDisp", "r_drawentities", "r_drawflecks", "r_drawfuncdetail",
        "r_drawleaf", "r_drawlightcache", "r_drawlightinfo", "r_drawlights", "r_drawmodeldecals",
        "r_DrawModelLightOrigin", "r_drawmodelstatsoverlay", "r_drawmodelstatsoverlaydistance",
        "r_drawmodelstatsoverlaymax", "r_drawmodelstatsoverlaymin", "r_drawopaquerenderables",
        "r_drawopaquestaticpropslast", "r_drawopaqueworld", "r_drawothermodels", "r_drawparticles",
        "r_drawpixelvisibility", "r_DrawPortals", "r_DrawRain", "r_drawrenderboxes", "r_drawropes", "r_drawskybox",
        "r_DrawSpecificStaticProp", "r_drawsprites", "r_drawstaticprops", "r_drawtranslucentrenderables",
        "r_drawtranslucentworld", "r_drawvgui", "r_drawviewmodel", "r_drawworld", "r_dscale_basefov", "r_dscale_fardist",
        "r_dscale_farscale", "r_dscale_neardist", "r_dscale_nearscale", "r_dynamic", "r_dynamiclighting", "r_entityclips",
        "r_eyeglintlodpixels", "r_eyemove", "r_eyes", "r_eyeshift_x", "r_eyeshift_y", "r_eyeshift_z", "r_eyesize",
        "r_eyewaterepsilon", "r_farz", "r_fastzreject", "r_fastzrejectdisp", "r_flashlightambient", "r_flashlightclip",
        "r_flashlightconstant", "r_flashlightculldepth", "r_flashlightdepthres", "r_flashlightdepthtexture",
        "r_flashlightdrawclip", "r_flashlightdrawdepth", "r_flashlightdrawfrustum", "r_flashlightdrawfrustumbbox",
        "r_flashlightdrawsweptbbox", "r_flashlightfar", "r_flashlightfov", "r_flashlightladderdist", "r_flashlightlinear",
        "r_flashlightlockposition", "r_flashlightmodels", "r_flashlightnear", "r_flashlightnodraw", "r_flashlightoffsetx",
        "r_flashlightoffsety", "r_flashlightoffsetz", "r_flashlightquadratic", "r_flashlightrender",
        "r_flashlightrendermodels", "r_flashlightrenderworld", "r_flashlightscissor", "r_flashlightshadowatten",
        "r_flashlightupdatedepth", "r_flashlightvisualizetrace", "r_flex", "r_flushlod", "r_ForceWaterLeaf",
        "r_frustumcullworld", "r_glint_alwaysdraw", "r_glint_procedural", "r_hunkalloclightmaps", "r_hwmorph",
        "r_itemblinkmax", "r_itemblinkrate", "r_JeepFOV", "r_JeepViewBlendTo", "r_JeepViewBlendToScale",
        "r_JeepViewBlendToTime", "r_lightaverage", "r_lightcache_numambientsamples", "r_lightcache_zbuffercache",
        "r_lightcachecenter", "r_lightcachemodel", "r_lightinterp", "r_lightmap", "r_lightstyle", "r_lightwarpidentity",
        "r_lockpvs", "r_lod", "r_mapextents", "r_maxdlights", "r_maxmodeldecal", "r_maxnewsamples", "r_maxsampledist",
        "r_minnewsamples", "r_modelwireframedecal", "r_newflashlight", "r_nohw", "r_norefresh", "r_nosw", "r_novis",
        "r_occludeemaxarea", "r_occluderminarea", "r_occludermincount", "r_occlusion", "r_occlusionspew",
        "r_oldlightselection", "r_overlayfadeenable", "r_overlayfademax", "r_overlayfademin", "r_overlaywireframe",
        "r_particle_sim_spike_threshold_ms", "r_partition_level", "r_PhysPropStaticLighting", "r_pix_recordframes",
        "r_pix_start", "r_pixelfog", "r_pixelvisibility_partial", "r_pixelvisibility_spew", "r_portalscloseall",
        "r_portalsopenall", "r_PortalTestEnts", "r_printdecalinfo", "r_projectedtexture_filter", "r_proplightingfromdisk",
        "r_proplightingpooling", "r_propsmaxdist", "r_queued_ropes", "r_radiosity", "r_rainalpha", "r_rainalphapow",
        "r_raindensity", "r_RainHack", "r_rainlength", "r_RainProfile", "r_RainRadius", "r_RainSideVel", "r_RainSimulate",
        "r_rainspeed", "r_RainSplashPercentage", "r_rainwidth", "r_randomflex", "r_renderoverlayfragment", "r_rimlight",
        "r_rootlod", "r_ropetranslucent", "r_screenfademaxsize", "r_screenfademinsize", "r_screenoverlay",
        "r_sequence_debug", "r_shader_srgb", "r_shadow_allowbelow", "r_shadow_allowdynamic", "r_shadow_lightpos_lerptime",
        "r_shadow_shortenfactor", "r_shadowangles", "r_shadowblobbycutoff", "r_shadowcolor", "r_shadowdir",
        "r_shadowdist", "r_shadowfromanyworldlight", "r_shadowfromworldlights", "r_shadowids", "r_shadowlod",
        "r_shadowlodbias", "r_shadowmaxrendered", "r_shadowrendertotexture", "r_shadows", "r_shadows_gamecontrol",
        "r_shadowwireframe", "r_showenvcubemap", "r_ShowViewerArea", "r_showz_power", "r_skin", "r_skybox",
        "r_snapportal", "r_SnowColorBlue", "r_SnowColorGreen", "r_SnowColorRed", "r_SnowDebugBox", "r_SnowEnable",
        "r_SnowEndAlpha", "r_SnowEndSize", "r_SnowFallSpeed", "r_SnowInsideRadius", "r_SnowOutsideRadius",
        "r_SnowParticles", "r_SnowPosScale", "r_SnowRayEnable", "r_SnowRayLength", "r_SnowRayRadius", "r_SnowSpeedScale",
        "r_SnowStartAlpha", "r_SnowStartSize", "r_SnowWindScale", "r_SnowZoomOffset", "r_SnowZoomRadius", "r_spewleaf",
        "r_spray_lifetime", "r_sse2", "r_sse_s", "r_staticprop_lod", "r_staticpropinfo", "r_studio_stats",
        "r_studio_stats_lock", "r_studio_stats_mode", "r_swingflashlight", "r_teeth", "r_threaded_particles",
        "r_unloadlightmaps", "r_updaterefracttexture", "r_vehicleBrakeRate", "r_VehicleViewClamp", "r_VehicleViewDampen",
        "r_visambient", "r_visocclusion", "r_visualizelighttraces", "r_visualizelighttracesshowfulltrace",
        "r_visualizeproplightcaching", "r_visualizetraces", "r_WaterDrawReflection", "r_WaterDrawRefraction",
        "r_waterforceexpensive", "r_waterforcereflectentities", "r_worldlightmin", "r_worldlights", "r_worldlistcache",
        "radar_range", "ragdoll_sleepaftertime", "rate", "rcon", "rcon_address", "rcon_password", "record",
        "record_screenshot", "refresh_options_dialog", "reload", "reload_legacy_addons", "reload_materials", "removeid",
        "removeip", "replay_debug", "report_entities", "report_simthinklist", "report_soundpatch", "report_touchlinks",
        "respawn_entities", "restart", "retry", "room_type", "rope_addlength", "rope_averagelight", "rope_collide",
        "rope_color_b", "rope_color_g", "rope_color_r", "rope_forcelimit", "rope_material", "rope_rendersolid",
        "rope_rigid", "rope_shake", "rope_smooth", "rope_smooth_enlarge", "rope_smooth_maxalpha",
        "rope_smooth_maxalphawidth", "rope_smooth_minalpha", "rope_smooth_minwidth", "rope_solid_maxalpha",
        "rope_solid_maxwidth", "rope_solid_minalpha", "rope_solid_minwidth", "rope_subdiv", "rope_width",
        "rope_wind_dist", "rr_debug_qa", "rr_debugresponses", "rr_debugrule", "rr_dumpresponses",
        "rr_reloadresponsesystems", "save", "save_async", "save_asyncdelay", "save_console", "save_disable",
        "save_finish_async", "save_history_count", "save_huddelayframes", "save_in_memory", "save_noxsave",
        "save_publish", "save_screenshot", "save_spew", "say", "say_team", "sb_filter_incompatible_versions",
        "sb_mod_suggested_maxplayers", "sb_quick_list_bit_field", "sb_showblacklists", "sbox_bonemanip_misc",
        "sbox_bonemanip_npc", "sbox_bonemanip_player", "sbox_godmode", "sbox_maxballoons", "sbox_maxbuttons",
        "sbox_maxcameras", "sbox_maxdynamite", "sbox_maxeffects", "sbox_maxemitters", "sbox_maxhoverballs",
        "sbox_maxlamps", "sbox_maxlights", "sbox_maxnpcs", "sbox_maxprops", "sbox_maxragdolls", "sbox_maxsents",
        "sbox_maxthrusters", "sbox_maxvehicles", "sbox_maxwheels", "sbox_noclip", "sbox_persist",
        "sbox_playershurtplayers", "sbox_search_maxresults", "sbox_weapons", "sc_joystick_map",
        "scene_async_prefetch_spew", "scene_clamplookat", "scene_clientflex", "scene_flatturn", "scene_flush",
        "scene_forcecombined", "scene_maxcaptionradius", "scene_print", "scene_showfaceto", "scene_showlook",
        "scene_showmoveto", "scene_showunlock", "scr_centertime", "screenshot", "sensitivity", "sensor_color_scale",
        "sensor_color_show", "sensor_color_x", "sensor_color_y", "sensor_debugragdoll", "sensor_stretchragdoll",
        "server_game_time", "servercfgfile", "setang", "setang_exact", "setinfo", "setpause", "setpos", "setpos_exact",
        "shake", "shake_show", "shake_stop", "showbudget_texture", "showbudget_texture_global_dumpstats",
        "showbudget_texture_global_sum", "showconsole", "showhitlocation", "showpanel", "showparticlecounts",
        "showschemevisualizer", "showsniperdist", "showsniperlines", "showtriggers", "showtriggers_toggle",
        "simple_bot_add", "singlestep", "sk_advisor_health", "sk_agrunt_dmg_punch", "sk_agrunt_health",
        "sk_airboat_drain_rate", "sk_airboat_max_ammo", "sk_airboat_recharge_rate", "sk_allow_autoaim",
        "sk_ally_regen_time", "sk_ammo_qty_scale1", "sk_ammo_qty_scale2", "sk_ammo_qty_scale3",
        "sk_antlion_air_attack_dmg", "sk_antlion_health", "sk_antlion_jump_damage", "sk_antlion_swipe_damage",
        "sk_antlion_worker_burst_damage", "sk_antlion_worker_burst_radius", "sk_antlion_worker_health",
        "sk_antlion_worker_spit_grenade_dmg", "sk_antlion_worker_spit_grenade_poison_ratio",
        "sk_antlion_worker_spit_grenade_radius", "sk_antlion_worker_spit_speed", "sk_antlionguard_dmg_charge",
        "sk_antlionguard_dmg_shove", "sk_antlionguard_health", "sk_apache_health", "sk_apc_health",
        "sk_apc_missile_damage", "sk_auto_reload_time", "sk_autoaim_mode", "sk_autoaim_scale1", "sk_autoaim_scale2",
        "sk_barnacle_health", "sk_barney_health", "sk_battery", "sk_bigmomma_dmg_blast", "sk_bigmomma_dmg_slash",
        "sk_bigmomma_health_factor", "sk_bigmomma_radius_blast", "sk_bullseye_health", "sk_bullsquid_dmg_bite",
        "sk_bullsquid_dmg_spit", "sk_bullsquid_dmg_whip", "sk_bullsquid_health", "sk_citizen_giveammo_player_delay",
        "sk_citizen_heal_ally", "sk_citizen_heal_ally_delay", "sk_citizen_heal_ally_min_pct", "sk_citizen_heal_player",
        "sk_citizen_heal_player_delay", "sk_citizen_heal_player_min_forced", "sk_citizen_heal_player_min_pct",
        "sk_citizen_heal_toss_player_delay", "sk_citizen_health", "sk_citizen_player_stare_dist",
        "sk_citizen_player_stare_time", "sk_citizen_stare_heal_time", "sk_combine_ball_search_radius",
        "sk_combine_guard_health", "sk_combine_guard_kick", "sk_combine_s_health", "sk_combine_s_kick",
        "sk_combineball_guidefactor", "sk_combineball_seek_angle", "sk_combineball_seek_kill", "sk_controller_dmgball",
        "sk_controller_dmgzap", "sk_controller_health", "sk_controller_speedball", "sk_crow_health", "sk_crow_melee_dmg",
        "sk_crowbar_lead_time", "sk_dmg_homer_grenade", "sk_dmg_inflict_scale1", "sk_dmg_inflict_scale2",
        "sk_dmg_inflict_scale3", "sk_dmg_pathfollower_grenade", "sk_dmg_sniper_penetrate_npc",
        "sk_dmg_sniper_penetrate_plr", "sk_dmg_take_scale1", "sk_dmg_take_scale2", "sk_dmg_take_scale3",
        "sk_dropship_container_health", "sk_dynamic_resupply_modifier", "sk_env_headcrabcanister_shake_amplitude",
        "sk_env_headcrabcanister_shake_radius", "sk_env_headcrabcanister_shake_radius_vehicle", "sk_fraggrenade_radius",
        "sk_gargantua_dmg_fire", "sk_gargantua_dmg_slash", "sk_gargantua_dmg_stomp", "sk_gargantua_health",
        "sk_grubnugget_enabled", "sk_grubnugget_health_large", "sk_grubnugget_health_medium",
        "sk_grubnugget_health_small", "sk_gunship_burst_dist", "sk_gunship_burst_min", "sk_gunship_burst_size",
        "sk_gunship_health_increments", "sk_hassassin_health", "sk_headcrab_dmg_bite", "sk_headcrab_fast_health",
        "sk_headcrab_health", "sk_headcrab_melee_dmg", "sk_headcrab_poison_health", "sk_headcrab_poison_npc_damage",
        "sk_healthcharger", "sk_healthkit", "sk_healthvial", "sk_helicopter_burstcount", "sk_helicopter_drone_speed",
        "sk_helicopter_firingcone", "sk_helicopter_grenade_puntscale", "sk_helicopter_grenadedamage",
        "sk_helicopter_grenadeforce", "sk_helicopter_grenaderadius", "sk_helicopter_health", "sk_helicopter_num_bombs1",
        "sk_helicopter_num_bombs2", "sk_helicopter_num_bombs3", "sk_helicopter_roundsperburst", "sk_hgrunt_gspeed",
        "sk_hgrunt_health", "sk_hgrunt_kick", "sk_hgrunt_pellets", "sk_hl1barnacle_health", "sk_hl1barney_health",
        "sk_hl1headcrab_health", "sk_hl1ichthyosaur_health", "sk_hl1zombie_dmg_both_slash", "sk_hl1zombie_dmg_one_slash",
        "sk_hl1zombie_health", "sk_homer_grenade_radius", "sk_houndeye_dmg_blast", "sk_houndeye_health",
        "sk_hunter_buckshot_damage_scale", "sk_hunter_bullet_damage_scale", "sk_hunter_charge_damage_scale",
        "sk_hunter_citizen_damage_scale", "sk_hunter_dmg_charge", "sk_hunter_dmg_flechette",
        "sk_hunter_dmg_from_striderbuster", "sk_hunter_dmg_one_slash", "sk_hunter_flechette_explode_dmg",
        "sk_hunter_flechette_explode_radius", "sk_hunter_health", "sk_hunter_vehicle_damage_scale",
        "sk_ichthyosaur_health", "sk_ichthyosaur_melee_dmg", "sk_ichthyosaur_shake", "sk_islave_dmg_claw",
        "sk_islave_dmg_clawrake", "sk_islave_dmg_zap", "sk_islave_health", "sk_jeep_gauss_damage", "sk_leech_dmg_bite",
        "sk_leech_health", "sk_manhack_health", "sk_manhack_melee_dmg", "sk_manhack_v2", "sk_max_357",
        "sk_max_357_bullet", "sk_max_9mm_bullet", "sk_max_alyxgun", "sk_max_ar2", "sk_max_ar2_altfire", "sk_max_buckshot",
        "sk_max_crossbow", "sk_max_gauss_round", "sk_max_grenade", "sk_max_hl1buckshot", "sk_max_hl1grenade",
        "sk_max_hl1satchel", "sk_max_hl1tripmine", "sk_max_hornet", "sk_max_mp5_grenade", "sk_max_pistol",
        "sk_max_rpg_rocket", "sk_max_rpg_round", "sk_max_smg1", "sk_max_smg1_grenade", "sk_max_snark",
        "sk_max_sniper_round", "sk_max_uranium", "sk_max_xbow_bolt", "sk_metropolice_health",
        "sk_metropolice_simple_health", "sk_metropolice_stitch_along_hitcount", "sk_metropolice_stitch_at_hitcount",
        "sk_metropolice_stitch_behind_hitcount", "sk_metropolice_stitch_distance", "sk_metropolice_stitch_reaction",
        "sk_metropolice_stitch_tight_hitcount", "sk_miniturret_health", "sk_mp5_grenade_radius", "sk_nihilanth_health",
        "sk_nihilanth_zap", "sk_npc_arm", "sk_npc_chest", "sk_npc_dmg_12mm_bullet", "sk_npc_dmg_357",
        "sk_npc_dmg_9mm_bullet", "sk_npc_dmg_9mmAR_bullet", "sk_npc_dmg_airboat", "sk_npc_dmg_alyxgun", "sk_npc_dmg_ar2",
        "sk_npc_dmg_buckshot", "sk_npc_dmg_combineball", "sk_npc_dmg_crossbow", "sk_npc_dmg_crowbar",
        "sk_npc_dmg_dropship", "sk_npc_dmg_fraggrenade", "sk_npc_dmg_grenade", "sk_npc_dmg_gunship",
        "sk_npc_dmg_gunship_to_plr", "sk_npc_dmg_helicopter", "sk_npc_dmg_helicopter_to_plr", "sk_npc_dmg_hornet",
        "sk_npc_dmg_pistol", "sk_npc_dmg_rpg_round", "sk_npc_dmg_satchel", "sk_npc_dmg_smg1", "sk_npc_dmg_smg1_grenade",
        "sk_npc_dmg_sniper_round", "sk_npc_dmg_stunstick", "sk_npc_dmg_tripmine", "sk_npc_head", "sk_npc_leg",
        "sk_npc_stomach", "sk_pathfollower_grenade_radius", "sk_player_arm", "sk_player_chest", "sk_player_head",
        "sk_player_leg", "sk_player_stomach", "sk_plr_dmg_357", "sk_plr_dmg_357_bullet", "sk_plr_dmg_9mm_bullet",
        "sk_plr_dmg_airboat", "sk_plr_dmg_alyxgun", "sk_plr_dmg_ar2", "sk_plr_dmg_buckshot", "sk_plr_dmg_crossbow",
        "sk_plr_dmg_crowbar", "sk_plr_dmg_egon_narrow", "sk_plr_dmg_egon_wide", "sk_plr_dmg_fraggrenade",
        "sk_plr_dmg_gauss", "sk_plr_dmg_grenade", "sk_plr_dmg_hl1buckshot", "sk_plr_dmg_hl1crowbar",
        "sk_plr_dmg_hl1grenade", "sk_plr_dmg_hl1satchel", "sk_plr_dmg_hl1tripmine", "sk_plr_dmg_hornet",
        "sk_plr_dmg_mp5_grenade", "sk_plr_dmg_pistol", "sk_plr_dmg_rpg", "sk_plr_dmg_rpg_round", "sk_plr_dmg_satchel",
        "sk_plr_dmg_smg1", "sk_plr_dmg_smg1_grenade", "sk_plr_dmg_sniper_round", "sk_plr_dmg_stunstick",
        "sk_plr_dmg_tripmine", "sk_plr_dmg_xbow_bolt_npc", "sk_plr_dmg_xbow_bolt_plr", "sk_plr_grenade_drop_time",
        "sk_plr_health_drop_time", "sk_plr_num_shotgun_pellets", "sk_rollermine_shock", "sk_rollermine_stun_delay",
        "sk_rollermine_vehicle_intercept", "sk_satchel_radius", "sk_scanner_dmg_dive", "sk_scanner_health",
        "sk_scientist_heal", "sk_scientist_health", "sk_sentry_health", "sk_smg1_grenade_radius", "sk_snark_dmg_bite",
        "sk_snark_dmg_pop", "sk_snark_health", "sk_stalker_health", "sk_stalker_melee_dmg", "sk_strider_health",
        "sk_strider_num_missiles1", "sk_strider_num_missiles2", "sk_strider_num_missiles3",
        "sk_striderbuster_magnet_multiplier", "sk_suitcharger", "sk_suitcharger_citadel",
        "sk_suitcharger_citadel_maxarmor", "sk_tripmine_radius", "sk_turret_health", "sk_vortigaunt_armor_charge",
        "sk_vortigaunt_armor_charge_per_token", "sk_vortigaunt_dmg_claw", "sk_vortigaunt_dmg_rake",
        "sk_vortigaunt_dmg_zap", "sk_vortigaunt_health", "sk_vortigaunt_vital_antlion_worker_dmg",
        "sk_vortigaunt_zap_range", "sk_weapon_ar2_alt_fire_duration", "sk_weapon_ar2_alt_fire_mass",
        "sk_weapon_ar2_alt_fire_radius", "sk_zombie_dmg_both_slash", "sk_zombie_dmg_one_slash", "sk_zombie_health",
        "sk_zombie_poison_dmg_spit", "sk_zombie_poison_health", "sk_zombie_soldier_health", "skill", "slider_color_b",
        "slider_color_g", "slider_color_r", "slider_material", "slider_width", "slot0", "slot1", "slot10", "slot2",
        "slot3", "slot4", "slot5", "slot6", "slot7", "slot8", "slot9", "smoke_trail", "smoothstairs", "snapto",
        "snd_async_flush", "snd_async_fullyasync", "snd_async_minsize", "snd_async_showmem", "snd_async_spew_blocking",
        "snd_async_stream_spew", "snd_buildcache", "snd_cull_duplicates", "snd_defer_trace", "snd_delay_sound_shift",
        "snd_disable_mixer_duck", "snd_duckerattacktime", "snd_duckerreleasetime", "snd_duckerthreshold",
        "snd_ducktovolume", "snd_dumpclientsounds", "snd_fixed_rate", "snd_foliage_db_loss", "snd_gain", "snd_gain_max",
        "snd_gain_min", "snd_legacy_surround", "snd_lockpartial", "snd_mix_async", "snd_mixahead", "snd_musicvolume",
        "snd_mute_losefocus", "snd_noextraupdate", "snd_obscured_gain_dB", "snd_pitchquality", "snd_profile", "snd_refdb",
        "snd_refdist", "snd_restart", "snd_show", "snd_showclassname", "snd_showmixer", "snd_showstart",
        "snd_ShowThreadFrameTime", "snd_soundmixer", "snd_spatialize_roundrobin", "snd_surround_speakers",
        "snd_visualize", "snd_vox_captiontrace", "snd_vox_globaltimeout", "snd_vox_sectimetout", "snd_vox_seqtimetout",
        "sndplaydelay", "sniper_xbox_delay", "sniperspeak", "sniperviewdist", "soundfade", "soundinfo", "soundlist",
        "soundpatch_captionlength", "soundscape_debug", "soundscape_dumpclient", "soundscape_fadetime",
        "soundscape_flush", "spawnicon_queue", "spawnicon_sharpen", "spawnmenu_border", "spawnmenu_reload", "speak",
        "spec_autodirector", "spec_freeze_distance_max", "spec_freeze_distance_min", "spec_freeze_time",
        "spec_freeze_traveltime", "spec_pos", "spec_track", "spew_consolelog_to_debugstring", "spike", "star_memory",
        "startdemos", "startmovie", "startupmenu", "stats", "status", "steam_controller_status", "step_spline", "stop",
        "stopdemo", "stopsound", "stopsoundscape", "strider_always_use_procedural_height", "strider_ar2_altfire_dmg",
        "strider_distributed_fire", "strider_eyepositions", "strider_free_knowledge",
        "strider_free_pass_after_escorts_dead", "strider_free_pass_cover_dist", "strider_free_pass_duration",
        "strider_free_pass_move_tolerance", "strider_free_pass_refill_rate", "strider_free_pass_start_time",
        "strider_free_pass_tolerance_after_escorts_dead", "strider_idle_test", "strider_immolate",
        "strider_missile_suppress_dist", "strider_missile_suppress_time", "strider_pct_height_no_crouch_move",
        "strider_peek_eye_dist", "strider_peek_eye_dist_z", "strider_peek_time", "strider_peek_time_after_damage",
        "strider_show_cannonlos", "strider_show_focus", "strider_show_weapon_los_condition", "strider_show_weapon_los_z",
        "strider_test_height", "striderbuster_allow_all_damage", "striderbuster_autoaim_radius",
        "striderbuster_debugseek", "striderbuster_die_detach", "striderbuster_dive_force", "striderbuster_falloff_power",
        "striderbuster_health", "striderbuster_leg_stick_dist", "striderbuster_magnetic_force_hunter",
        "striderbuster_magnetic_force_strider", "striderbuster_shot_velocity", "striderbuster_use_particle_flare",
        "stringtabletotals", "studio_queue_mode", "stuffcmds", "suitvolume", "surfaceprop", "sv_accelerate",
        "sv_airaccelerate", "sv_allow_color_correction", "sv_allow_voice_from_file", "sv_allow_votes", "sv_allowcslua",
        "sv_allowdownload", "sv_allowupload", "sv_alltalk", "sv_alternateticks", "sv_autojump", "sv_autoladderdismount",
        "sv_autosave", "sv_benchmark_autovprofrecord", "sv_benchmark_numticks", "sv_bonus_map_challenge_update",
        "sv_bonus_map_complete", "sv_bonus_map_unlock", "sv_cacheencodedents", "sv_cheats", "sv_clearhinthistory",
        "sv_client_cmdrate_difference", "sv_client_max_interp_ratio", "sv_client_min_interp_ratio", "sv_client_predict",
        "sv_clockcorrection_msecs", "sv_consistency", "sv_contact", "sv_crazyphysics_defuse", "sv_crazyphysics_remove",
        "sv_crazyphysics_vehicles", "sv_crazyphysics_warning", "sv_crazyphysics_wheels", "sv_debug_player_use",
        "sv_debugmanualmode", "sv_debugtempentities", "sv_defaultdeployspeed", "sv_deltaprint", "sv_deltatime",
        "sv_disable_querycache", "sv_downloadurl", "sv_dumpstringtables", "sv_enableoldqueries", "sv_filterban",
        "sv_footsteps", "sv_forcepreload", "sv_friction", "sv_gamename_override", "sv_gravity", "sv_hibernate_drop_bots",
        "sv_hibernate_think", "sv_hudhint_sound", "sv_infinite_aux_power", "sv_kickerrornum", "sv_ladder_useonly",
        "sv_ladderautomountdot", "sv_lagcompensateself", "sv_lagcompensationforcerestore", "sv_lan", "sv_loadingurl",
        "sv_location", "sv_log_onefile", "sv_logbans", "sv_logblocks", "sv_logdownloadlist", "sv_logecho", "sv_logfile",
        "sv_logfilecompress", "sv_logfilename_format", "sv_logflush", "sv_logsdir", "sv_logsecret", "sv_lowedict_action",
        "sv_lowedict_threshold", "sv_massreport", "sv_master_share_game_socket", "sv_max_connects_sec",
        "sv_max_connects_sec_global", "sv_max_connects_window", "sv_max_queries_sec", "sv_max_queries_sec_global",
        "sv_max_queries_window", "sv_max_userinfo", "sv_maxcmdrate", "sv_maxrate", "sv_maxreplay", "sv_maxroutable",
        "sv_maxupdaterate", "sv_maxusrcmdprocessticks", "sv_maxusrcmdprocessticks_holdaim",
        "sv_maxusrcmdprocessticks_warning", "sv_maxvelocity", "sv_memlimit", "sv_mincmdrate", "sv_minrate",
        "sv_minupdaterate", "sv_mumble_positionalaudio", "sv_namechange_cooldown_seconds", "sv_netspike",
        "sv_netspike_on_reliable_snapshot_overflow", "sv_netspike_output", "sv_netspike_sendtime_ms", "sv_no_ain_files",
        "sv_noclipaccelerate", "sv_noclipduringpause", "sv_noclipspeed", "sv_npc_talker_maxdist",
        "sv_parallel_packentities", "sv_parallel_sendsnapshot", "sv_password", "sv_pausable",
        "sv_player_display_usercommand_errors", "sv_playerforcedupdate", "sv_playerperfhistorycount",
        "sv_playerpickupallowed", "sv_precacheinfo", "sv_pure", "sv_pure_consensus", "sv_pure_kick_clients",
        "sv_pure_retiretime", "sv_pure_trace", "sv_pvsskipanimation", "sv_querycache_stats",
        "sv_quota_stringcmdspersecond", "sv_rcon_banpenalty", "sv_rcon_log", "sv_rcon_maxfailures",
        "sv_rcon_maxpacketbans", "sv_rcon_maxpacketsize", "sv_rcon_minfailures", "sv_rcon_minfailuretime",
        "sv_rcon_whitelist_address", "sv_region", "sv_restrict_aspect_ratio_fov", "sv_robust_explosions", "sv_rollangle",
        "sv_rollspeed", "sv_setsteamaccount", "sv_show_crosshair_target", "sv_showladders", "sv_showlagcompensation",
        "sv_showlagcompensation_duration", "sv_shutdown", "sv_shutdown_timeout_minutes", "sv_skyname",
        "sv_soundemitter_trace", "sv_specaccelerate", "sv_specnoclip", "sv_specspeed", "sv_startup_time", "sv_stats",
        "sv_steamblockingcheck", "sv_steamgroup", "sv_sticktoground", "sv_stickysprint", "sv_stickysprint_default",
        "sv_stopspeed", "sv_strict_notarget", "sv_test_scripted_sequences", "sv_teststepsimulation", "sv_thinktimecheck",
        "sv_timeout", "sv_timeout_signon", "sv_turbophysics", "sv_unlockedchapters", "sv_use_steam_voice",
        "sv_usermessage_maxsize", "sv_vehicle_autoaim_scale", "sv_visiblemaxplayers", "sv_voiceenable",
        "sv_vote_allow_spectators", "sv_vote_failure_timer", "sv_vote_ui_hide_disabled_issues", "sv_wateraccelerate",
        "sv_waterfriction", "sys_minidumpexpandedspew", "sys_minidumpspewlines", "systemlinkport", "template_debug",
        "Test_CreateEntity", "test_dispatcheffect", "Test_EHandle", "test_entity_blocker", "test_freezeframe",
        "Test_InitRandomEntitySpawner", "test_massive_dmg", "test_massive_dmg_clip", "Test_ProxyToggle_EnableProxy",
        "Test_ProxyToggle_EnsureValue", "Test_ProxyToggle_SetValue", "Test_RandomizeInPVS", "Test_RandomPlayerPosition",
        "Test_RemoveAllRandomEntities", "Test_SpawnRandomEntities", "testhudanim", "testscript_debug",
        "texture_budget_background_alpha", "texture_budget_panel_bottom_of_history_fraction",
        "texture_budget_panel_global", "texture_budget_panel_height", "texture_budget_panel_width",
        "texture_budget_panel_x", "texture_budget_panel_y", "tf_escort_score_rate", "tf_matprox_BurnLevel",
        "tf_matprox_InvulnLevel", "tf_matprox_spy_invis", "tf_matprox_YellowLevel", "think_limit", "thirdperson",
        "thirdperson_mayamode", "thirdperson_platformer", "thirdperson_screenspace", "threadpool_affinity",
        "thruster_collision", "thruster_damageable", "thruster_effect", "thruster_force", "thruster_keygroup",
        "thruster_keygroup_back", "thruster_model", "thruster_soundname", "thruster_toggle", "thumper_show_radius",
        "timedemo", "timedemo_runcount", "timedemoquit", "timerefresh", "toggle", "toggle_duck", "toggle_zoom",
        "toggleconsole", "toolmode_allow_axis", "toolmode_allow_balloon", "toolmode_allow_ballsocket",
        "toolmode_allow_button", "toolmode_allow_camera", "toolmode_allow_colour", "toolmode_allow_creator",
        "toolmode_allow_duplicator", "toolmode_allow_dynamite", "toolmode_allow_editentity", "toolmode_allow_elastic",
        "toolmode_allow_emitter", "toolmode_allow_example", "toolmode_allow_eyeposer", "toolmode_allow_faceposer",
        "toolmode_allow_finger", "toolmode_allow_hoverball", "toolmode_allow_hydraulic", "toolmode_allow_inflator",
        "toolmode_allow_lamp", "toolmode_allow_leafblower", "toolmode_allow_light", "toolmode_allow_material",
        "toolmode_allow_motor", "toolmode_allow_muscle", "toolmode_allow_nocollide", "toolmode_allow_paint",
        "toolmode_allow_physprop", "toolmode_allow_pulley", "toolmode_allow_remover", "toolmode_allow_rope",
        "toolmode_allow_slider", "toolmode_allow_thruster", "toolmode_allow_trails", "toolmode_allow_weld",
        "toolmode_allow_wheel", "toolmode_allow_winch", "tooltip_delay", "trace_report", "tracer_extra", "trails_a",
        "trails_b", "trails_endsize", "trails_g", "trails_length", "trails_material", "trails_r", "trails_startsize",
        "ttt_allow_discomb_jump", "ttt_credits_starting", "ttt_debug_preventwin", "ttt_det_credits_starting",
        "ttt_detective_hats", "ttt_detective_karma_min", "ttt_detective_max", "ttt_detective_min_players",
        "ttt_detective_pct", "ttt_firstpreptime", "ttt_haste", "ttt_haste_minutes_per_death",
        "ttt_haste_starting_minutes", "ttt_namechange_bantime", "ttt_namechange_kick", "ttt_no_nade_throw_during_prep",
        "ttt_postround_dm", "ttt_posttime_seconds", "ttt_preptime_seconds", "ttt_ragdoll_pinning",
        "ttt_ragdoll_pinning_innocents", "ttt_round_limit", "ttt_roundtime_minutes", "ttt_teleport_telefrags",
        "ttt_time_limit_minutes", "ttt_traitor_max", "ttt_traitor_pct", "tv_allow_camera_man", "tv_allow_static_shots",
        "tv_autorecord", "tv_autoretry", "tv_chatgroupsize", "tv_chattimelimit", "tv_clients", "tv_debug", "tv_delay",
        "tv_delaymapchange", "tv_deltacache", "tv_dispatchmode", "tv_enable", "tv_maxclients", "tv_maxrate", "tv_msg",
        "tv_name", "tv_nochat", "tv_overridemaster", "tv_password", "tv_port", "tv_record", "tv_relay",
        "tv_relaypassword", "tv_relayvoice", "tv_retry", "tv_snapshotrate", "tv_status", "tv_stop", "tv_stoprecord",
        "tv_timeout", "tv_title", "tv_transmitall", "ui_posedebug_fade_in_time", "ui_posedebug_fade_out_time", "unbind",
        "unbind_mac", "unbindall", "undo", "unpause", "use", "user", "user_context", "user_property", "users",
        "v_centermove", "v_centerspeed", "vcollide_wireframe", "vcr_verbose", "vehicle_flushscript", "version",
        "vgui_drawfocus", "vgui_drawtree", "vgui_drawtree_bounds", "vgui_drawtree_clear", "vgui_drawtree_draw_selected",
        "vgui_drawtree_freeze", "vgui_drawtree_hidden", "vgui_drawtree_panelalpha", "vgui_drawtree_panelptr",
        "vgui_drawtree_popupsonly", "vgui_drawtree_render_order", "vgui_drawtree_visible", "vgui_luapaint",
        "vgui_message_dialog_modal", "vgui_spew_fonts", "vgui_togglepanel", "vgui_visualizelayout", "vid_fps",
        "vid_sound", "vid_width", "viewmodel_fov", "violence_ablood", "violence_agibs", "violence_hblood",
        "violence_hgibs", "voice_clientdebug", "voice_debugfeedback", "voice_debugfeedbackfrom", "voice_enable",
        "voice_fadeouttime", "voice_forcemicrecord", "voice_gain_downward_multiplier", "voice_gain_max",
        "voice_gain_rate", "voice_gain_target", "voice_inputfromfile", "voice_loopback", "voice_modenable",
        "voice_overdrive", "voice_overdrivefadetime", "voice_profile", "voice_recordtofile", "voice_scale",
        "voice_serverdebug", "voice_showchannels", "voice_showincoming", "voice_steal", "voice_writevoices", "volume",
        "volume_sfx", "vox_reload", "voxeltree_box", "voxeltree_playerview", "voxeltree_sphere", "voxeltree_view",
        "vphys_sleep_timeout", "vprof", "vprof_adddebuggroup1", "vprof_cachemiss", "vprof_cachemiss_off",
        "vprof_cachemiss_on", "vprof_child", "vprof_collapse_all", "vprof_counters", "vprof_dump_groupnames",
        "vprof_dump_oninterval", "vprof_dump_spikes", "vprof_dump_spikes_budget_group", "vprof_dump_spikes_node",
        "vprof_expand_all", "vprof_expand_group", "vprof_generate_report", "vprof_generate_report_AI",
        "vprof_generate_report_AI_only", "vprof_generate_report_budget", "vprof_generate_report_hierarchy",
        "vprof_generate_report_map_load", "vprof_graph", "vprof_graphheight", "vprof_graphwidth", "vprof_nextsibling",
        "vprof_off", "vprof_on", "vprof_parent", "vprof_playback_average", "vprof_playback_start", "vprof_playback_step",
        "vprof_playback_stepback", "vprof_playback_stop", "vprof_prevsibling", "vprof_remote_start", "vprof_remote_stop",
        "vprof_reset", "vprof_reset_peaks", "vprof_scope", "vprof_scope_entity_gamephys", "vprof_scope_entity_thinks",
        "vprof_unaccounted_limit", "vprof_verbose", "vprof_vtune_group", "vprof_warningmsec", "vtune",
        "wc_air_edit_further", "wc_air_edit_nearer", "wc_air_node_edit", "wc_create", "wc_destroy", "wc_destroy_undo",
        "wc_link_edit", "weapon_showproficiency", "weld_forcelimit", "weld_nocollide", "wheel_bck", "wheel_forcelimit",
        "wheel_friction", "wheel_fwd", "wheel_model", "wheel_nocollide", "wheel_rx", "wheel_ry", "wheel_rz",
        "wheel_toggle", "wheel_torque", "whereis", "winch_bwd_group", "winch_bwd_speed", "winch_color_b", "winch_color_g",
        "winch_color_r", "winch_fwd_group", "winch_fwd_speed", "winch_rope_material", "winch_rope_width",
        "windows_speaker_config", "wipe_nav_attributes", "writeid", "writeip", "xbox_autothrottle",
        "xbox_steering_deadzone", "xbox_throttlebias", "xbox_throttlespoof", "xc_crouch_debounce", "xc_crouch_range",
        "xc_uncrouch_on_jump", "xc_use_crouch_limiter", "xload", "xlook", "xmove", "xsave", "zombie_ambushdist",
        "zombie_basemax", "zombie_basemin", "zombie_changemax", "zombie_changemin", "zombie_decaymax", "zombie_decaymin",
        "zombie_moanfreq", "zombie_stepfreq", "zoom_sensitivity_ratio"
    }

    for cmd in pairs(concommand.GetTable()) do
        table.insert(allCommands, cmd)
    end

    local exactMatches = {}
    local partialMatches = {}

    if command == "" then
        return partialMatches
    end

    for _, cmd in ipairs(allCommands) do
        if cmd:lower() == command:lower() then
            table.insert(exactMatches, cmd)
        elseif cmd:lower():find(command:lower()) then
            table.insert(partialMatches, cmd)
        end
    end

    if #exactMatches > 0 then
        return exactMatches
    else
        return partialMatches
    end
end

local function openConfigMenu()
    if not XPGUI then
        local notifyFrame = vgui.Create("DFrame")
        notifyFrame:SetTitle("[Commands Binding] XPGUI Not Installed")
        notifyFrame:SetSize(400, 200)
        notifyFrame:Center()
        notifyFrame:MakePopup()
        surface.PlaySound("buttons/button10.wav")

        local icon = vgui.Create("DImage", notifyFrame)
        icon:SetImage("icon16/error.png")
        icon:SetPos(10, 30)

        local label = vgui.Create("DLabel", notifyFrame)
        label:SetText("XPGUI is not installed. Please install it from the following link:")
        label:SizeToContents()
        label:SetPos(50, 40)

        local link = vgui.Create("DLabelURL", notifyFrame)
        link:SetText("Link To the Addon")
        link:SetURL("https://steamcommunity.com/workshop/filedetails/?id=2390567739") -- Gmod Url Style Look awful but it works
        link:SizeToContents()
        link:SetWide(300)
        link:SetPos(50, 60)

        local closeButton = vgui.Create("DButton", notifyFrame)
        closeButton:SetText("Close")
        closeButton:SetSize(100, 30)
        closeButton:SetPos(150, 150)
        closeButton.DoClick = function()
            notifyFrame:Close()
        end

        return
    end

    if IsValid(frame) then return end

    frame = vgui.Create("XPFrame")
    frame:SetTitle("Key Bind Manager")
    frame:SetSize(600, 450)
    frame:Center()
    frame:MakePopup()

    frame.OnClose = function()
        frame = nil
    end

    local commandLabel = vgui.Create("DLabel", frame)
    commandLabel:SetText("Command:")
    commandLabel:SetPos(10, 40)
    commandLabel:SizeToContents()

    local commandEntry = vgui.Create("XPTextEntry", frame)
    commandEntry:SetPos(100, 35)
    commandEntry:SetSize(frame:GetWide() - 110, 25)

    local parameterLabel = vgui.Create("DLabel", frame)
    parameterLabel:SetText("Parameter:")
    parameterLabel:SetPos(10, 70)
    parameterLabel:SizeToContents()

    local parameterEntry = vgui.Create("XPTextEntry", frame)
    parameterEntry:SetPos(100, 65)
    parameterEntry:SetSize(frame:GetWide() - 110, 25)

    local keyBinderLabel = vgui.Create("DLabel", frame)
    keyBinderLabel:SetText("Key Bind:")
    keyBinderLabel:SetPos(10, 100)
    keyBinderLabel:SizeToContents()

    local keyBinder = vgui.Create("DBinder", frame)
    keyBinder:SetPos(100, 95)
    keyBinder:SetSize(frame:GetWide() - 110, 50)

    local saveButton = vgui.Create("XPButton", frame)
    saveButton:SetText("Save")
    saveButton:SetPos((frame:GetWide() - 100) / 2, 160)
    saveButton:SetSize(100, 30)
    saveButton:SetEnabled(false)

    local statusPanel = vgui.Create("DPanel", frame)
    statusPanel:SetPos(10, 200)
    statusPanel:SetSize(frame:GetWide() - 20, 25)
    statusPanel:SetBackgroundColor(Color(255, 0, 0))
    statusPanel:SetVisible(false)

    local statusLabel = vgui.Create("DLabel", statusPanel)
    statusLabel:Dock(FILL)
    statusLabel:SetTextColor(Color(255, 255, 255))
    statusLabel:SetText("")
    statusLabel:SetContentAlignment(5)

    commandEntry.OnChange = function()
        local command = commandEntry:GetValue()

        if IsValid(SuggestionsList) then
            SuggestionsList:Remove()
        end

        if not commandEntry:IsEditing() or command == "" then
            statusPanel:SetVisible(false)
            saveButton:SetEnabled(false)
            return
        end

        if isValidCommand(command) then
            statusPanel:SetVisible(false)
            saveButton:SetEnabled(true)
        else
            statusLabel:SetText(
                "Invalid command. Only alphanumeric characters, spaces (if not alone), and + - _ * / ! are allowed.")
            statusPanel:SetVisible(true)
            statusPanel:MoveToFront()
            saveButton:SetEnabled(false)
        end

        if command == "" then
            return
        end
        local suggestions = GetCommandSuggestions(command)
        if #suggestions > 0 then
            SuggestionsList = vgui.Create("XPListView", frame)
            SuggestionsList:SetPos(100, 60)
            SuggestionsList:SetSize(frame:GetWide() - 110, 100)
            SuggestionsList:AddColumn("Suggestions")
            for _, suggestion in ipairs(suggestions) do
                SuggestionsList:AddLine(suggestion)
            end
            SuggestionsList.OnRowSelected = function(_, _, line)
                commandEntry:SetText(line:GetColumnText(1))
                SuggestionsList:Remove()
            end
        end
    end

    saveButton.DoClick = function()
        local command = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        local parameter = parameterEntry:GetValue()
        if command and key and isValidCommand(command) then
            for existingCommand, existingData in pairs(keyBinds) do
                if existingData.key == key and existingCommand ~= command then
                    showOverwriteConfirmation(command, key, existingCommand)
                    return
                end
                if existingData.parameter == parameter and existingCommand == command then
                    statusLabel:SetText("A command with the same name and parameter already exists.")
                    statusPanel:SetVisible(true)
                    return
                end
            end
            -- Add an asterisk if a command with the same name exists but with a different parameter (to differentiate them)
            if keyBinds[command] and keyBinds[command].parameter ~= parameter then
                command = command .. "*"
            end
            keyBinds[command] = { key = key, parameter = parameter }
            net.Start("KeyBindManager_Update")
            net.WriteString(command)
            net.WriteInt(key, 32)
            net.WriteString(parameter)
            net.SendToServer()
            RefreshKeyBindList()
        else
            statusLabel:SetText("Please enter a valid command and key bind.")
        end
    end

    function frame:PerformLayout()
        if IsValid(commandLabel) then
            commandLabel:SetPos(10, 40)
        end

        if IsValid(commandEntry) then
            commandEntry:SetPos(100, 35)
            commandEntry:SetSize(self:GetWide() - 110, 25)
        end

        if IsValid(parameterLabel) then
            parameterLabel:SetPos(10, 70)
        end

        if IsValid(parameterEntry) then
            parameterEntry:SetPos(100, 65)
            parameterEntry:SetSize(self:GetWide() - 110, 25)
        end

        if IsValid(keyBinderLabel) then
            keyBinderLabel:SetPos(10, 100)
        end

        if IsValid(keyBinder) then
            keyBinder:SetPos(100, 95)
            keyBinder:SetSize(self:GetWide() - 110, 50)
        end

        if IsValid(saveButton) then
            saveButton:SetPos((self:GetWide() - 100) / 2, 160)
        end

        if IsValid(statusPanel) then
            statusPanel:SetPos(10, 200)
            statusPanel:SetSize(self:GetWide() - 20, 25)
        end

        if IsValid(frame.keyBindList) then
            frame.keyBindList:SetSize(self:GetWide() - 20, self:GetTall() - 230)
        end
    end

    RefreshKeyBindList()
end

concommand.Add("open_keybind_manager", openConfigMenu)

if not XPGUI then
    hook.Add("Initialize", "OpenConfigMenuOnStart", function()
        openConfigMenu()
    end)
end

hook.Add("Think", "KeyBindManager_Think", function()
    if TypingInTextEntry then return end
    for command, data in pairs(keyBinds) do
        local key = data.key
        local parameter = data.parameter
        if type(key) == "number" and input.IsKeyDown(key) then
            if not keyPressStates[key] then
                keyPressStates[key] = true
                -- Remove the asterisk from the command before executing it (if there is one)
                local cleanCommand = string.gsub(command, "%*$", "")
                if parameter and parameter ~= "" then
                    if cleanCommand == "sv_cheats" then
                        sendCommandToServer(cleanCommand, parameter)
                    else
                        RunConsoleCommand(cleanCommand, parameter)
                    end
                else
                    if cleanCommand == "sv_cheats" then
                        sendCommandToServer(cleanCommand)
                    else
                        RunConsoleCommand(cleanCommand)
                    end
                end
            end
        else
            keyPressStates[key] = false
        end
    end
end)

hook.Add("Think", "CheckKeybinds", function()
    if TypingInTextEntry then return end
    for command, key in pairs(keyBinds) do
        if type(key) == "number" and input.IsKeyDown(key) and not keyPressStates[key] then
            keyPressStates[key] = true
            if command == "getpos" then
                getPlayerPosition()
            else
                LocalPlayer():ConCommand(command)
            end
        elseif type(key) == "number" and not input.IsKeyDown(key) and keyPressStates[key] then
            keyPressStates[key] = nil
        end
    end
end)
