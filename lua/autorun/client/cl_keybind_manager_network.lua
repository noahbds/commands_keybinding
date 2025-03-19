-- cl_keybind_manager_network.lua

net.Receive("CommandsKeyBinding_Config", function()
    local isGlobal = net.ReadBool()
    local bindData = net.ReadTable()

    if isGlobal then
        GlobalKeyBinds = bindData
    else
        PersonalKeyBinds = bindData
    end

    RefreshActiveKeyBinds()

    if IsValid(Frame) then
        RefreshKeyBindList()
    end
end)
