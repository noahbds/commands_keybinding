-- ── Send keybinds to a player ─────────────────────────

function CKB_SV.SendKeyBindsToPlayer(ply, keyBinds)
    net.Start("CKB_Config")
    local count = table.Count(keyBinds)
    net.WriteUInt(count, 16)
    for command, data in pairs(keyBinds) do
        net.WriteString(command)
        net.WriteInt(data.key, 32)
        net.WriteString(data.argument or "")
    end
    net.Send(ply)
end

-- ── Send profile list to a player ─────────────────────

function CKB_SV.SendProfileList(ply)
    local data = CKB_SV.LoadPlayerData(ply)
    net.Start("CKB_ProfileList")
    net.WriteString(data.activeProfile or "")
    net.WriteUInt(table.Count(data.profiles), 16)
    for id, profile in pairs(data.profiles) do
        net.WriteString(id)
        net.WriteString(profile.name or "Unnamed")
    end
    net.Send(ply)
end

-- ── Receive keybind update ────────────────────────────

net.Receive("CKB_Update", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local command = net.ReadString()
    local key = net.ReadInt(32)
    local argument = net.ReadString()
    local oldCommand = net.ReadString()

    if not CKB_SV.IsValidCommandStr(command) then return end
    if CKB_SV.IsConCommandBlocked(command) then return end

    local keyBinds = CKB_SV.GetActiveBinds(ply)

    if oldCommand ~= "" and oldCommand ~= command then
        keyBinds[oldCommand] = nil
    end

    if key == 0 then
        keyBinds[command] = nil
    else
        for cmd, data in pairs(keyBinds) do
            if cmd ~= command and data.key == key then
                keyBinds[cmd] = nil
            end
        end
        if not keyBinds[command] and table.Count(keyBinds) >= CKB_SV.MAX_KEYBINDS then return end
        keyBinds[command] = { key = key, argument = argument or "" }
    end

    CKB_SV.SetActiveBinds(ply, keyBinds)
    CKB_SV.SendKeyBindsToPlayer(ply, keyBinds)
end)

-- ── Profile switching ─────────────────────────────────

net.Receive("CKB_ProfileSwitch", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local profileId = net.ReadString()
    local data = CKB_SV.LoadPlayerData(ply)

    if not data.profiles[profileId] then return end

    data.activeProfile = profileId
    CKB_SV.SavePlayerData(ply, data)
    CKB_SV.SendKeyBindsToPlayer(ply, data.profiles[profileId].binds)
    CKB_SV.SendProfileList(ply)
end)

-- ── Profile create ────────────────────────────────────

net.Receive("CKB_ProfileCreate", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local name = net.ReadString()
    local cloneFromId = net.ReadString()

    if not name or #name == 0 or #name > 64 then return end

    local data = CKB_SV.LoadPlayerData(ply)

    local newId = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    local binds = {}

    if cloneFromId ~= "" and data.profiles[cloneFromId] then
        for k, v in pairs(data.profiles[cloneFromId].binds) do
            binds[k] = { key = v.key, argument = v.argument or "" }
        end
    end

    data.profiles[newId] = { name = name, binds = binds }
    data.activeProfile = newId
    CKB_SV.SavePlayerData(ply, data)
    CKB_SV.SendKeyBindsToPlayer(ply, binds)
    CKB_SV.SendProfileList(ply)
end)

-- ── Profile delete ────────────────────────────────────

net.Receive("CKB_ProfileDelete", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local profileId = net.ReadString()
    local data = CKB_SV.LoadPlayerData(ply)

    if not data.profiles[profileId] then return end

    -- Cannot delete the last profile
    if table.Count(data.profiles) <= 1 then return end

    data.profiles[profileId] = nil

    -- Switch to another profile if the deleted one was active
    if data.activeProfile == profileId then
        for id in pairs(data.profiles) do
            data.activeProfile = id
            break
        end
    end

    CKB_SV.SavePlayerData(ply, data)
    CKB_SV.SendKeyBindsToPlayer(ply, data.profiles[data.activeProfile].binds)
    CKB_SV.SendProfileList(ply)
end)

-- ── Profile rename ────────────────────────────────────

net.Receive("CKB_ProfileRename", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local profileId = net.ReadString()
    local newName = net.ReadString()

    if not newName or #newName == 0 or #newName > 64 then return end

    local data = CKB_SV.LoadPlayerData(ply)
    if not data.profiles[profileId] then return end

    data.profiles[profileId].name = newName
    CKB_SV.SavePlayerData(ply, data)
    CKB_SV.SendProfileList(ply)
end)

-- ── Player lifecycle hooks ────────────────────────────

hook.Add("PlayerInitialSpawn", "CKB_SendConfig", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        local keyBinds = CKB_SV.GetActiveBinds(ply)
        CKB_SV.SendKeyBindsToPlayer(ply, keyBinds)
        CKB_SV.SendProfileList(ply)
    end)
end)

hook.Add("PlayerDisconnected", "CKB_Cleanup", function(ply)
    CKB_SV.PlayerRateLimits[ply] = nil
    CKB_SV.ClearCache(ply)
end)
