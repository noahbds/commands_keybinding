util.AddNetworkString("CommandsKeyBinding_Config")
util.AddNetworkString("CommandsKeyBinding_Update")

local MAX_KEYBINDS = 50
local RATE_LIMIT = 0.2 -- seconds between updates per player
local DIR = "commands_keybinding"

local playerRateLimits = {}

local blockedCommands = {
    ["quit"] = true, ["exit"] = true, ["killserver"] = true,
    ["rcon"] = true, ["rcon_password"] = true, ["sv_password"] = true,
    ["banid"] = true, ["banip"] = true, ["kickid"] = true, ["kickid2"] = true,
    ["sv_cheats"] = true, ["changelevel"] = true, ["changelevel2"] = true,
    ["bind"] = true, ["unbind"] = true, ["unbindall"] = true,
    ["exec"] = true, ["alias"] = true, ["sv_allowcslua"] = true,
    ["lua_run"] = true, ["lua_run_cl"] = true, ["lua_openscript"] = true, ["lua_openscript_cl"] = true,
}

local function getPlayerFile(ply)
    return DIR .. "/" .. ply:SteamID64() .. ".json"
end

local function loadKeyBinds(ply)
    local path = getPlayerFile(ply)
    if file.Exists(path, "DATA") then
        local data = file.Read(path, "DATA")
        local tbl = util.JSONToTable(data)
        if istable(tbl) then return tbl end
    end
    return {}
end

local function saveKeyBinds(ply, keyBinds)
    file.CreateDir(DIR)
    file.Write(getPlayerFile(ply), util.TableToJSON(keyBinds, true))
end

local function isValidCommandStr(cmd)
    if not isstring(cmd) or #cmd == 0 or #cmd > 128 then return false end
    if not string.match(cmd, "^[%w%+%-_%*/!%s]+$") then return false end
    if not string.match(cmd, "%S") then return false end
    return true
end

local function sendKeyBindsToPlayer(ply, keyBinds)
    net.Start("CommandsKeyBinding_Config")
    local count = table.Count(keyBinds)
    net.WriteUInt(count, 16)
    for command, data in pairs(keyBinds) do
        net.WriteString(command)
        net.WriteInt(data.key, 32)
        net.WriteString(data.argument or "")
    end
    net.Send(ply)
end

net.Receive("CommandsKeyBinding_Update", function(len, ply)
    if not IsValid(ply) then return end

    -- Rate limiting
    local now = CurTime()
    if playerRateLimits[ply] and now - playerRateLimits[ply] < RATE_LIMIT then return end
    playerRateLimits[ply] = now

    local command = net.ReadString()
    local key = net.ReadInt(32)
    local argument = net.ReadString()

    -- Validate command string
    if not isValidCommandStr(command) then return end

    -- Check blocked commands
    local cleanCmd = string.gsub(command, "%d*$", ""):lower()
    if blockedCommands[cleanCmd] then return end

    local keyBinds = loadKeyBinds(ply)

    if key == 0 then
        -- Delete
        keyBinds[command] = nil
    else
        -- Check max keybinds limit
        if not keyBinds[command] and table.Count(keyBinds) >= MAX_KEYBINDS then return end
        keyBinds[command] = { key = key, argument = argument or "" }
    end

    saveKeyBinds(ply, keyBinds)
    sendKeyBindsToPlayer(ply, keyBinds)
end)

hook.Add("PlayerInitialSpawn", "CKB_SendConfig", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        local keyBinds = loadKeyBinds(ply)
        sendKeyBindsToPlayer(ply, keyBinds)
    end)
end)

hook.Add("PlayerDisconnected", "CKB_Cleanup", function(ply)
    playerRateLimits[ply] = nil
end)
