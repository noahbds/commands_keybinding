function CKB.RebuildKeyMap()
    local map = {}
    for command, data in pairs(CKB.KeyBinds) do
        local key = data.key
        if type(key) == "number" and key ~= 0 then
            local list = map[key]
            if not list then
                list = {}
                map[key] = list
            end
            list[#list + 1] = { command = command, argument = data.argument }
        end
    end
    CKB.ActiveKeyMap = map
end

hook.Add("Think", "CKB_ExecuteBinds", function()
    if CKB.TypingInTextEntry then return end
    if gui.IsConsoleVisible() then return end
    if vgui.CursorVisible() then return end

    local ply = LocalPlayer()
    if IsValid(ply) and ply:IsTyping() then return end

    local states = CKB.KeyPressStates
    for key, commands in pairs(CKB.ActiveKeyMap) do
        if input.IsKeyDown(key) then
            if not states[key] then
                states[key] = true
                for i = 1, #commands do
                    local bind = commands[i]
                    if bind.argument and bind.argument ~= "" then
                        RunConsoleCommand(bind.command, bind.argument)
                    else
                        RunConsoleCommand(bind.command)
                    end
                end
            end
        else
            states[key] = false
        end
    end
end)
