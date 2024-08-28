if SERVER then
    hook.Add("PlayerSay", "KeyBindManager_ConfigCommand", function(ply, text)
        if ply:IsAdmin() and text == "!keybind_commands" then
            ply:ConCommand("open_keybind_commands")
            return ""
        end
    end)
end
