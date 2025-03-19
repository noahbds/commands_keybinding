util.AddNetworkString("CommandsKeyBinding_Config")
util.AddNetworkString("CommandsKeyBinding_Update")
util.AddNetworkString("CommandsKeyBinding_Request")
util.AddNetworkString("CommandsKeyBinding_AdminSync")
util.AddNetworkString("CommandsKeyBinding_ProfileList")
util.AddNetworkString("CommandsKeyBinding_ProfileSwitch")

-- Configuration
local CONFIG = {
    SAVE_PATH = "commands_keybinding",
    GLOBAL_BINDS_FILE = "commands_keybinding/global_keybinds.json",
    PLAYER_BINDS_PATH = "commands_keybinding/player_profiles/",
    LOG_FILE = "commands_keybinding/bind_changes.log",
    BACKUP_COUNT = 5,
    AUTO_SAVE_INTERVAL = 300, -- 5 minutes
    VERSION = "1.2.0"
}


file.CreateDir(CONFIG.SAVE_PATH)
file.CreateDir(CONFIG.PLAYER_BINDS_PATH)

local keyBinds = {}
local playerProfiles = {}

local function logChange(ply, action, details)
    if not file.Exists(CONFIG.LOG_FILE, "DATA") then
        file.Write(CONFIG.LOG_FILE, "---- Keybind Manager Log ----\n")
    end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = string.format("[%s] %s (%s) %s: %s\n",
        timestamp,
        IsValid(ply) and ply:Nick() or "CONSOLE",
        IsValid(ply) and ply:SteamID() or "CONSOLE",
        action,
        details
    )

    file.Append(CONFIG.LOG_FILE, logEntry)
end

local function saveKeyBinds()
    if file.Exists(CONFIG.GLOBAL_BINDS_FILE, "DATA") then
        for i = CONFIG.BACKUP_COUNT, 1, -1 do
            local srcFile = i == 1
                and CONFIG.GLOBAL_BINDS_FILE
                or string.format("%s.bak%d", CONFIG.GLOBAL_BINDS_FILE, i - 1)

            local dstFile = string.format("%s.bak%d", CONFIG.GLOBAL_BINDS_FILE, i)

            if file.Exists(srcFile, "DATA") then
                file.Write(dstFile, file.Read(srcFile, "DATA"))
            end
        end
    end

    file.Write(CONFIG.GLOBAL_BINDS_FILE, util.TableToJSON(keyBinds, true))
    logChange(nil, "AUTO_SAVE", "Global keybinds saved")
end

local function loadKeyBinds()
    if file.Exists(CONFIG.GLOBAL_BINDS_FILE, "DATA") then
        local data = file.Read(CONFIG.GLOBAL_BINDS_FILE, "DATA")
        local success, result = pcall(util.JSONToTable, data)

        if success and result then
            return result
        else
            ErrorNoHalt("[KeyBindManager] Error loading keybinds: Invalid JSON data\n")
            logChange(nil, "ERROR", "Failed to load global keybinds - JSON parse error")

            for i = 1, CONFIG.BACKUP_COUNT do
                local backupFile = string.format("%s.bak%d", CONFIG.GLOBAL_BINDS_FILE, i)
                if file.Exists(backupFile, "DATA") then
                    local backupData = file.Read(backupFile, "DATA")
                    success, result = pcall(util.JSONToTable, backupData)
                    if success and result then
                        logChange(nil, "RECOVERY", "Loaded backup file " .. backupFile)
                        return result
                    end
                end
            end
        end
    end
    return {}
end

local function loadPlayerProfile(steamID)
    local profileFile = CONFIG.PLAYER_BINDS_PATH .. steamID .. ".json"

    if file.Exists(profileFile, "DATA") then
        local data = file.Read(profileFile, "DATA")
        local success, result = pcall(util.JSONToTable, data)

        if success and result then
            return result
        end
    end

    return {
        useGlobalBinds = true,
        personalBinds = {},
        lastUpdate = os.time()
    }
end

local function savePlayerProfile(steamID, profile)
    if not profile then return end

    profile.lastUpdate = os.time()
    local profileFile = CONFIG.PLAYER_BINDS_PATH .. steamID .. ".json"
    file.Write(profileFile, util.TableToJSON(profile, true))
end

timer.Create("KeyBindManager_AutoSave", CONFIG.AUTO_SAVE_INTERVAL, 0, function()
    saveKeyBinds()

    for _, ply in ipairs(player.GetAll()) do
        local steamID = ply:SteamID64()
        if playerProfiles[steamID] then
            savePlayerProfile(steamID, playerProfiles[steamID])
        end
    end
end)

keyBinds = loadKeyBinds()

local function sendConfigToPlayer(ply)
    local steamID = ply:SteamID64()

    if not playerProfiles[steamID] then
        playerProfiles[steamID] = loadPlayerProfile(steamID)
    end

    local profile = playerProfiles[steamID]

    if profile.useGlobalBinds then
        net.Start("CommandsKeyBinding_Config")
        net.WriteBool(true)
        net.WriteTable(keyBinds)
        net.Send(ply)
    end

    net.Start("CommandsKeyBinding_Config")
    net.WriteBool(false)
    net.WriteTable(profile.personalBinds)
    net.Send(ply)
end

net.Receive("CommandsKeyBinding_Update", function(len, ply)
    local isGlobal = net.ReadBool()
    local key = net.ReadInt(32)
    local argument = net.ReadString()
    local useCtrl = net.ReadBool()
    local useAlt = net.ReadBool()

    if isGlobal and not ply:IsAdmin() then
        ply:ChatPrint("[KeyBindManager] Vous devez être administrateur pour modifier les raccourcis globaux.")
        return
    end

    if not IsValidCommand(Command, key, argument) then
        ply:ChatPrint("[KeyBindManager] Commande invalide.")
        return
    end

    if isGlobal then
        if key == 0 then
            if keyBinds[Command] then
                keyBinds[Command] = nil
                logChange(ply, "DELETE_GLOBAL", Command)
            end
        else
            keyBinds[Command] = {
                key = key,
                argument = argument,
                ctrl = useCtrl,
                alt = useAlt,
                lastModified = os.time(),
                modifiedBy = ply:SteamID64()
            }
            logChange(ply, "UPDATE_GLOBAL", Command .. " -> " .. key)
        end

        saveKeyBinds()

        for _, client in ipairs(player.GetAll()) do
            local clientID = client:SteamID64()
            if playerProfiles[clientID] and playerProfiles[clientID].useGlobalBinds then
                net.Start("CommandsKeyBinding_Config")
                net.WriteBool(true)
                net.WriteTable(keyBinds)
                net.Send(client)
            end
        end
    else
        local steamID = ply:SteamID64()

        if not playerProfiles[steamID] then
            playerProfiles[steamID] = loadPlayerProfile(steamID)
        end

        if key == 0 then
            if playerProfiles[steamID].personalBinds[Command] then
                playerProfiles[steamID].personalBinds[Command] = nil
                logChange(ply, "DELETE_PERSONAL", Command)
            end
        else
            playerProfiles[steamID].personalBinds[Command] = {
                key = key,
                argument = argument,
                ctrl = useCtrl,
                alt = useAlt,
                lastModified = os.time()
            }
            logChange(ply, "UPDATE_PERSONAL", Command .. " -> " .. key)
        end

        savePlayerProfile(steamID, playerProfiles[steamID])

        net.Start("CommandsKeyBinding_Config")
        net.WriteBool(false)
        net.WriteTable(playerProfiles[steamID].personalBinds)
        net.Send(ply)
    end
end)

net.Receive("CommandsKeyBinding_ProfileSwitch", function(len, ply)
    local useGlobal = net.ReadBool()
    local steamID = ply:SteamID64()

    if not playerProfiles[steamID] then
        playerProfiles[steamID] = loadPlayerProfile(steamID)
    end

    playerProfiles[steamID].useGlobalBinds = useGlobal
    savePlayerProfile(steamID, playerProfiles[steamID])

    ply:ChatPrint("[KeyBindManager] Vous utilisez maintenant les raccourcis " ..
        (useGlobal and "globaux et personnels." or "uniquement personnels."))

    sendConfigToPlayer(ply)

    logChange(ply, "PROFILE_SETTING", "Set useGlobalBinds to " .. tostring(useGlobal))
end)

net.Receive("CommandsKeyBinding_ProfileList", function(len, ply)
    if not ply:IsAdmin() then return end

    local profiles = {}
    local files = file.Find(CONFIG.PLAYER_BINDS_PATH .. "*.json", "DATA")

    for _, f in ipairs(files) do
        local steamID = string.match(f, "([^/]+)%.json$")
        local data = file.Read(CONFIG.PLAYER_BINDS_PATH .. f, "DATA")
        local profileData = util.JSONToTable(data)

        if steamID and profileData then
            profiles[steamID] = {
                bindCount = table.Count(profileData.personalBinds),
                useGlobalBinds = profileData.useGlobalBinds,
                lastUpdate = profileData.lastUpdate
            }
        end
    end

    net.Start("CommandsKeyBinding_AdminSync")
    net.WriteTable(profiles)
    net.Send(ply)
end)

net.Receive("CommandsKeyBinding_Request", function(len, ply)
    sendConfigToPlayer(ply)
end)

hook.Add("PlayerInitialSpawn", "SendCommandsKeyBinding", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            sendConfigToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerDisconnected", "SavePlayerKeyBindProfile", function(ply)
    local steamID = ply:SteamID64()

    if playerProfiles[steamID] then
        savePlayerProfile(steamID, playerProfiles[steamID])
        playerProfiles[steamID] = nil
    end
end)

hook.Add("Initialize", "MigrateOldKeybindsFormat", function()
    local oldFile = "commands_keybinding/commands_keybinds.json"
    if file.Exists(oldFile, "DATA") and not file.Exists(CONFIG.GLOBAL_BINDS_FILE, "DATA") then
        file.Write(CONFIG.GLOBAL_BINDS_FILE, file.Read(oldFile, "DATA"))
        file.Write(oldFile .. ".migrated", file.Read(oldFile, "DATA"))
        logChange(nil, "MIGRATION", "Migrated from old format to new format")
    end
end)

print("[KeyBindManager] Version " .. CONFIG.VERSION .. " initialized")
