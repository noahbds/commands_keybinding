util.AddNetworkString("KeyBindManager_Config")
util.AddNetworkString("KeyBindManager_Update")

local keyBindFile = "keybind_commands/keybinds.json"

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
    file.CreateDir("keybind_commands")
    file.Write(keyBindFile, util.TableToJSON(keyBinds))
end

local keyBinds = loadKeyBinds()

net.Receive("KeyBindManager_Update", function(len, ply)
    if ply:IsAdmin() then
        local command = net.ReadString()
        local key = net.ReadInt(32)
        local argument = net.ReadString()

        if key == 0 then
            keyBinds[command] = nil
        else
            if keyBinds[command] then
                -- If Command exists, check for numbered versions (This was hard to implement)
                local baseCommand = command
                local suffix = 1
                while keyBinds[command] do
                    command = baseCommand .. tostring(suffix)
                    suffix = suffix + 1
                end
                keyBinds[command] = { key = key, argument = argument }
            else
                keyBinds[command] = { key = key, argument = argument }
            end
        end
        saveKeyBinds(keyBinds)
        net.Start("KeyBindManager_Config")
        net.WriteTable(keyBinds)
        net.Broadcast()
    end
end)

-- Send the current key binds to the client
hook.Add("PlayerInitialSpawn", "SendKeyBindManager", function(ply)
    net.Start("KeyBindManager_Config")
    net.WriteTable(keyBinds)
    net.Send(ply)
end)
