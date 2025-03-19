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

-- Initialisation des dossiers
file.CreateDir(CONFIG.SAVE_PATH)
file.CreateDir(CONFIG.PLAYER_BINDS_PATH)

local keyBinds = {}
local playerProfiles = {}

-- Journalisation des modifications
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

-- Sauvegarde avec système de rotation
local function saveKeyBinds()
    -- Créer une sauvegarde rotative
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

    -- Écriture du fichier principal
    file.Write(CONFIG.GLOBAL_BINDS_FILE, util.TableToJSON(keyBinds, true))
    logChange(nil, "AUTO_SAVE", "Global keybinds saved")
end

-- Chargement des raccourcis globaux
local function loadKeyBinds()
    if file.Exists(CONFIG.GLOBAL_BINDS_FILE, "DATA") then
        local data = file.Read(CONFIG.GLOBAL_BINDS_FILE, "DATA")
        local success, result = pcall(util.JSONToTable, data)

        if success and result then
            return result
        else
            ErrorNoHalt("[KeyBindManager] Error loading keybinds: Invalid JSON data\n")
            logChange(nil, "ERROR", "Failed to load global keybinds - JSON parse error")

            -- Récupérer une sauvegarde si disponible
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

-- Chargement des profils personnels des joueurs
local function loadPlayerProfile(steamID)
    local profileFile = CONFIG.PLAYER_BINDS_PATH .. steamID .. ".json"

    if file.Exists(profileFile, "DATA") then
        local data = file.Read(profileFile, "DATA")
        local success, result = pcall(util.JSONToTable, data)

        if success and result then
            return result
        end
    end

    -- Créer un nouveau profil vide
    return {
        useGlobalBinds = true,
        personalBinds = {},
        lastUpdate = os.time()
    }
end

-- Sauvegarder le profil d'un joueur
local function savePlayerProfile(steamID, profile)
    if not profile then return end

    profile.lastUpdate = os.time()
    local profileFile = CONFIG.PLAYER_BINDS_PATH .. steamID .. ".json"
    file.Write(profileFile, util.TableToJSON(profile, true))
end

-- Sauvegarde périodique
timer.Create("KeyBindManager_AutoSave", CONFIG.AUTO_SAVE_INTERVAL, 0, function()
    saveKeyBinds()

    -- Sauvegarder les profils des joueurs connectés
    for _, ply in ipairs(player.GetAll()) do
        local steamID = ply:SteamID64()
        if playerProfiles[steamID] then
            savePlayerProfile(steamID, playerProfiles[steamID])
        end
    end
end)

-- Initialisation des données
keyBinds = loadKeyBinds()

-- Valider une commande
local function isValidCommand(command, key, argument)
    -- Vérifier si la commande est valide
    if not isstring(command) or string.len(command) < 1 then return false end
    if not isnumber(key) then return false end

    -- À personnaliser selon vos besoins
    return true
end

-- Envoyer la configuration à un joueur
local function sendConfigToPlayer(ply)
    local steamID = ply:SteamID64()

    -- Charger le profil du joueur s'il n'est pas déjà chargé
    if not playerProfiles[steamID] then
        playerProfiles[steamID] = loadPlayerProfile(steamID)
    end

    local profile = playerProfiles[steamID]

    -- Envoyer les touches globales si le joueur les utilise
    if profile.useGlobalBinds then
        net.Start("CommandsKeyBinding_Config")
        net.WriteBool(true) -- Indique si ce sont des raccourcis globaux
        net.WriteTable(keyBinds)
        net.Send(ply)
    end

    -- Envoyer aussi les touches personnelles
    net.Start("CommandsKeyBinding_Config")
    net.WriteBool(false) -- Indique si ce sont des raccourcis personnels
    net.WriteTable(profile.personalBinds)
    net.Send(ply)
end

-- Mise à jour des raccourcis
net.Receive("CommandsKeyBinding_Update", function(len, ply)
    local isGlobal = net.ReadBool() -- Si la modification est pour les raccourcis globaux
    local command = net.ReadString()
    local key = net.ReadInt(32)
    local argument = net.ReadString()
    local useCtrl = net.ReadBool()
    local useAlt = net.ReadBool()

    -- Vérifier les permissions
    if isGlobal and not ply:IsAdmin() then
        ply:ChatPrint("[KeyBindManager] Vous devez être administrateur pour modifier les raccourcis globaux.")
        return
    end

    -- Vérifier la validité de la commande
    if not isValidCommand(command, key, argument) then
        ply:ChatPrint("[KeyBindManager] Commande invalide.")
        return
    end

    if isGlobal then
        -- Mise à jour des raccourcis globaux
        if key == 0 then
            if keyBinds[command] then
                keyBinds[command] = nil
                logChange(ply, "DELETE_GLOBAL", command)
            end
        else
            keyBinds[command] = {
                key = key,
                argument = argument,
                ctrl = useCtrl,
                alt = useAlt,
                lastModified = os.time(),
                modifiedBy = ply:SteamID64()
            }
            logChange(ply, "UPDATE_GLOBAL", command .. " -> " .. key)
        end

        -- Sauvegarder et synchroniser avec tous les clients
        saveKeyBinds()

        -- Envoyer uniquement aux joueurs qui utilisent les raccourcis globaux
        for _, client in ipairs(player.GetAll()) do
            local clientID = client:SteamID64()
            if playerProfiles[clientID] and playerProfiles[clientID].useGlobalBinds then
                net.Start("CommandsKeyBinding_Config")
                net.WriteBool(true) -- Raccourcis globaux
                net.WriteTable(keyBinds)
                net.Send(client)
            end
        end
    else
        -- Mise à jour des raccourcis personnels
        local steamID = ply:SteamID64()

        if not playerProfiles[steamID] then
            playerProfiles[steamID] = loadPlayerProfile(steamID)
        end

        if key == 0 then
            if playerProfiles[steamID].personalBinds[command] then
                playerProfiles[steamID].personalBinds[command] = nil
                logChange(ply, "DELETE_PERSONAL", command)
            end
        else
            playerProfiles[steamID].personalBinds[command] = {
                key = key,
                argument = argument,
                ctrl = useCtrl,
                alt = useAlt,
                lastModified = os.time()
            }
            logChange(ply, "UPDATE_PERSONAL", command .. " -> " .. key)
        end

        -- Sauvegarder le profil personnel
        savePlayerProfile(steamID, playerProfiles[steamID])

        -- Envoyer uniquement au joueur concerné
        net.Start("CommandsKeyBinding_Config")
        net.WriteBool(false) -- Raccourcis personnels
        net.WriteTable(playerProfiles[steamID].personalBinds)
        net.Send(ply)
    end
end)

-- Gestion des profils
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

    -- Synchroniser le client
    sendConfigToPlayer(ply)

    logChange(ply, "PROFILE_SETTING", "Set useGlobalBinds to " .. tostring(useGlobal))
end)

-- Le client demande la liste des profils disponibles (administrateur uniquement)
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

-- Un client demande spécifiquement la configuration
net.Receive("CommandsKeyBinding_Request", function(len, ply)
    sendConfigToPlayer(ply)
end)

-- Initialisation des joueurs
hook.Add("PlayerInitialSpawn", "SendCommandsKeyBinding", function(ply)
    -- Attendre un peu pour s'assurer que le client est prêt
    timer.Simple(2, function()
        if IsValid(ply) then
            sendConfigToPlayer(ply)
        end
    end)
end)

-- Déchargement des profils à la déconnexion pour économiser de la mémoire
hook.Add("PlayerDisconnected", "SavePlayerKeyBindProfile", function(ply)
    local steamID = ply:SteamID64()

    if playerProfiles[steamID] then
        savePlayerProfile(steamID, playerProfiles[steamID])
        playerProfiles[steamID] = nil
    end
end)

-- Compatibilité avec l'ancien format
hook.Add("Initialize", "MigrateOldKeybindsFormat", function()
    local oldFile = "commands_keybinding/commands_keybinds.json"
    if file.Exists(oldFile, "DATA") and not file.Exists(CONFIG.GLOBAL_BINDS_FILE, "DATA") then
        file.Write(CONFIG.GLOBAL_BINDS_FILE, file.Read(oldFile, "DATA"))
        file.Write(oldFile .. ".migrated", file.Read(oldFile, "DATA"))
        logChange(nil, "MIGRATION", "Migrated from old format to new format")
    end
end)

print("[KeyBindManager] Version " .. CONFIG.VERSION .. " initialized")
