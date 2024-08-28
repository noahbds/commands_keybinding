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
        local parameter = net.ReadString()

        -- Check if the command already exists
        if key == 0 then
            -- Remove the specific command
            keyBinds[command] = nil
        else
            -- Add or update the command
            if keyBinds[command] then
                -- Command exists, check for numbered versions
                local baseCommand = command
                local suffix = 1
                while keyBinds[command] do
                    command = baseCommand .. tostring(suffix)
                    suffix = suffix + 1
                end
                keyBinds[command] = { key = key, parameter = parameter }
            else
                keyBinds[command] = { key = key, parameter = parameter }
            end
        end
        saveKeyBinds(keyBinds)
        -- Notify clients to refresh their key bind list
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
