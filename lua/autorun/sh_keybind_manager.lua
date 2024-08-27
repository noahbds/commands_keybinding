
if SERVER then
    hook.Add("PlayerSay", "KeyBindManager_ConfigCommand", function(ply, text)
        if ply:IsAdmin() and text == "!configure_keybind" then
            ply:ConCommand("open_keybind_manager")
            return ""
        end
    end)
end
