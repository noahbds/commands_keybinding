if SERVER then
    hook.Add("PlayerSay", "CKB_ChatCommand", function(ply, text)
        local lower = string.lower(string.Trim(text))
        if lower == "!ckb" or lower == "!keybind" or lower == "!keybinds" then
            ply:ConCommand("open_commands_keybinding")
            return ""
        end
    end)
end
