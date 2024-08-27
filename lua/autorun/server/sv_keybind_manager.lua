util.AddNetworkString("KeyBindManager_Config")
util.AddNetworkString("KeyBindManager_Update")

local keyBindFile = "keybind_manager/keybinds.json"

-- Load the key binds from the file
local function loadKeyBinds()
    if file.Exists(keyBindFile, "DATA") then
        local data = file.Read(keyBindFile, "DATA")
        return util.JSONToTable(data)
    else
        return {}
    end
end

-- Save the key binds to the file
local function saveKeyBinds(keyBinds)
    file.CreateDir("keybind_manager")
    file.Write(keyBindFile, util.TableToJSON(keyBinds))
end

local keyBinds = loadKeyBinds()

-- Network message handler to update the key binds
net.Receive("KeyBindManager_Update", function(len, ply)
    if ply:IsAdmin() then
        local command = net.ReadString()
        local key = net.ReadInt(32)
        if key == 0 then
            keyBinds[command] = nil
        else
            keyBinds[command] = key
        end
        saveKeyBinds(keyBinds)
        net.Start("KeyBindManager_Config")
        net.WriteTable(keyBinds)
        net.Send(ply)
    end
end)

-- Send the current key binds to the client
hook.Add("PlayerInitialSpawn", "SendKeyBindManager", function(ply)
    net.Start("KeyBindManager_Config")
    net.WriteTable(keyBinds)
    net.Send(ply)
end)
