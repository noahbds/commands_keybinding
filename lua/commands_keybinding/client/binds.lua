-- ═══════════════════════════════════════════════════════
--  CKB — Think hook: execute keybinds
-- ═══════════════════════════════════════════════════════

hook.Add("Think", "CKB_ExecuteBinds", function()
    if CKB.TypingInTextEntry then return end
    if gui.IsConsoleVisible() then return end
    if IsValid(LocalPlayer()) and LocalPlayer():IsTyping() then return end
    if vgui.CursorVisible() then return end

    for command, data in pairs(CKB.KeyBinds) do
        local key = data.key
        if type(key) ~= "number" then continue end

        if input.IsKeyDown(key) then
            if not CKB.KeyPressStates[key] then
                CKB.KeyPressStates[key] = true
                local cleanCommand = string.gsub(command, "%d*$", "")
                local argument = data.argument
                if argument and argument ~= "" then
                    RunConsoleCommand(cleanCommand, argument)
                else
                    RunConsoleCommand(cleanCommand)
                end
            end
        else
            CKB.KeyPressStates[key] = false
        end
    end
end)
