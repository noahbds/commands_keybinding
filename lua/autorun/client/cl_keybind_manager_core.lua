-- cl_keybind_manager_core.lua

-- Global variables
GlobalKeyBinds = {}
PersonalKeyBinds = {}
ActiveKeyBinds = {}
KeyPressStates = {}
Frame = CreateMainFrame()
UseGlobalBinds = true
IsAdmin = false
IsEditingGlobal = false
TypingInTextEntry = false
KeyBinderClicked = false

hook.Add("OnTextEntryGetFocus", "IsTyping", function()
    TypingInTextEntry = true
end)

hook.Add("OnTextEntryLoseFocus", "IsNotTyping", function()
    TypingInTextEntry = false
end)

function RefreshActiveKeyBinds()
    ActiveKeyBinds = {}

    if UseGlobalBinds then
        for cmd, data in pairs(GlobalKeyBinds) do
            ActiveKeyBinds[cmd] = data
        end
    end

    for cmd, data in pairs(PersonalKeyBinds) do
        ActiveKeyBinds[cmd] = data
    end
end

hook.Add("Think", "CommandsKeyBinding_Think", function()
    if TypingInTextEntry or LocalPlayer():IsTyping() then return end

    local ctrlDown = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
    local altDown = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
    local shiftDown = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

    for command, data in pairs(ActiveKeyBinds) do
        local key = data.key
        local argument = data.argument
        local requiresCtrl = data.ctrl or false
        local requiresAlt = data.alt or false
        local requiresShift = data.shift or false

        if type(key) == "number" and input.IsKeyDown(key) and
            ctrlDown == requiresCtrl and altDown == requiresAlt and shiftDown == (requiresShift or false) then
            if not KeyPressStates[command] then
                KeyPressStates[command] = true

                local cleanCommand = string.gsub(command, "%d*$", "")

                if argument and argument ~= "" then
                    if string.find(argument, "%s") then
                        local args = string.Explode("%s", argument)
                        RunConsoleCommand(cleanCommand, unpack(args))
                    else
                        RunConsoleCommand(cleanCommand, argument)
                    end
                else
                    RunConsoleCommand(cleanCommand)
                end

                if GetConVar("keybind_debug"):GetBool() then
                    print("[KeyBinds] Exécution de " .. command .. (argument and (" avec arg: " .. argument) or ""))
                end
            end
        else
            KeyPressStates[command] = false
        end
    end
end)

local function openConfigMenu()
    if not XPGUI then
        CreateNotificationFrame()
        return
    end

    if IsValid(Frame) then return end

    IsAdmin = LocalPlayer():IsAdmin()

    net.Start("CommandsKeyBinding_Request")
    net.SendToServer()
end

concommand.Add("open_commands_keybinding", openConfigMenu)

if not XPGUI then
    hook.Add("Initialize", "OpenConfigMenuOnStart", function()
        timer.Simple(2, function()
            openConfigMenu()
        end)
    end)
end
