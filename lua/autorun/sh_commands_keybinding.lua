if SERVER then
    hook.Add("PlayerSay", "CommandsKeyBinding_ConfigCommand", function(ply, text)
        if text == "!ckb" then
            ply:ConCommand("open_commands_keybinding")
            return ""
        end
    end)
end
