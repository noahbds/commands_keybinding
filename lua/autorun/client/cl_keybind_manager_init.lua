-- cl_keybind_manager_init.lua

-- Ensure the XPGUI library is included (It's Workshop Library Addon)
hook.Add("Initialize", "LoadXPGUI", function()
    if not XPGUI then
        include("xpgui.lua")
    end
end)

KeyBindManager = KeyBindManager or {}
KeyBindManager.Languages = KeyBindManager.Languages or {}
KeyBindManager.CurrentLanguage = GetConVar("gmod_language"):GetString() or "en"

include("cl_keybind_manager_language.lua")
include("cl_keybind_manager_core.lua")
include("cl_keybind_manager_network.lua")
include("cl_keybind_manager_utils.lua")
include("cl_keybind_manager_ui.lua")

CreateClientConVar("keybind_debug", "0", true, false, "Activer les messages de débogage pour les raccourcis clavier")
CreateClientConVar("keybind_silent", "0", true, false, "Désactiver les sons de notification")

concommand.Add("open_commands_keybinding", function()
    if KeyBindManager.OpenConfigMenu then
        KeyBindManager.OpenConfigMenu()
    end
end)

print("[Command KeyBinding] Client Finished Loading")

if not XPGUI then
    hook.Add("Initialize", "OpenConfigMenuOnStart", function()
        timer.Simple(2, function()
            if KeyBindManager.OpenConfigMenu then
                KeyBindManager.OpenConfigMenu()
            end
        end)
    end)
end
