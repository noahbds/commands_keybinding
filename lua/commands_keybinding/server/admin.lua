-- ═══════════════════════════════════════════════════════
--  CKB — Server: admin features
-- ═══════════════════════════════════════════════════════

-- ── Request online players with profile summaries ─────

net.Receive("CKB_AdminGetPlayers", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.IsAdmin(ply) then return end

    local players = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local data = CKB_SV.LoadPlayerData(p)
            local profileCount = table.Count(data.profiles)
            local activeName = "?"
            if data.profiles[data.activeProfile] then
                activeName = data.profiles[data.activeProfile].name
            end
            local sharingAllowed = data.sharingAllowed ~= false
            table.insert(players, {
                nick = p:Nick(),
                steamId = p:SteamID64(),
                profileCount = profileCount,
                activeProfile = activeName,
                sharingAllowed = sharingAllowed,
                rankLevel = CKB_SV.GetRankLevel(p),
            })
        end
    end

    net.Start("CKB_AdminPlayerList")
    net.WriteUInt(#players, 16)
    for _, p in ipairs(players) do
        net.WriteString(p.nick)
        net.WriteString(p.steamId)
        net.WriteUInt(p.profileCount, 16)
        net.WriteString(p.activeProfile)
        net.WriteBool(p.sharingAllowed)
        net.WriteUInt(p.rankLevel, 8)
    end
    net.WriteUInt(CKB_SV.GetRankLevel(ply), 8)
    net.Send(ply)
end)

net.Receive("CKB_AdminGetBinds", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.IsAdmin(ply) then return end

    local targetSteamId = net.ReadString()
    local target = player.GetBySteamID64(targetSteamId)
    if not IsValid(target) then return end

    local data = CKB_SV.LoadPlayerData(target)

    net.Start("CKB_AdminBindsData")
    net.WriteString(targetSteamId)
    net.WriteString(target:Nick())
    net.WriteString(data.activeProfile or "")

    local profileCount = table.Count(data.profiles)
    net.WriteUInt(profileCount, 16)

    for profileId, profile in pairs(data.profiles) do
        net.WriteString(profileId)
        net.WriteString(profile.name or "Unnamed")

        local bindCount = table.Count(profile.binds)
        net.WriteUInt(bindCount, 16)

        for command, bind in pairs(profile.binds) do
            net.WriteString(command)
            net.WriteInt(bind.key, 32)
            net.WriteString(bind.argument or "")
        end
    end
    net.Send(ply)
end)

-- ── Admin modifies a player's keybind ─────────────────

net.Receive("CKB_AdminUpdateBind", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.IsAdmin(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local targetSteamId = net.ReadString()
    local profileId = net.ReadString()
    local command = net.ReadString()
    local key = net.ReadInt(32)
    local argument = net.ReadString()

    local target = player.GetBySteamID64(targetSteamId)
    if not IsValid(target) then return end

    if not CKB_SV.IsValidCommandStr(command) then return end
    local cleanCmd = string.gsub(command, "%d*$", ""):lower()
    if CKB_SV.IsConCommandBlocked(cleanCmd) then return end

    local data = CKB_SV.LoadPlayerData(target)
    if not data.profiles[profileId] then return end

    local binds = data.profiles[profileId].binds

    if key == 0 then
        binds[command] = nil
    else
        if not binds[command] and table.Count(binds) >= CKB_SV.MAX_KEYBINDS then return end
        binds[command] = { key = key, argument = argument or "" }
    end

    CKB_SV.SavePlayerData(target, data)

    -- If modifying target's active profile, refresh their client
    if data.activeProfile == profileId then
        CKB_SV.SendKeyBindsToPlayer(target, binds)
    end

    -- Resend updated data back to admin
    CKB_SV.SendKeyBindsToPlayer(target, data.profiles[data.activeProfile].binds)

    -- Re-send the binds data to the admin who made the change
    net.Start("CKB_AdminBindsData")
    net.WriteString(targetSteamId)
    net.WriteString(target:Nick())
    net.WriteString(data.activeProfile or "")

    local profileCount = table.Count(data.profiles)
    net.WriteUInt(profileCount, 16)

    for pid, profile in pairs(data.profiles) do
        net.WriteString(pid)
        net.WriteString(profile.name or "Unnamed")

        local bindCount = table.Count(profile.binds)
        net.WriteUInt(bindCount, 16)

        for cmd, bind in pairs(profile.binds) do
            net.WriteString(cmd)
            net.WriteInt(bind.key, 32)
            net.WriteString(bind.argument or "")
        end
    end
    net.Send(ply)
end)

-- ── Admin toggles player sharing ──────────────────────

net.Receive("CKB_AdminToggleSharing", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.IsAdmin(ply) then return end

    local targetSteamId = net.ReadString()
    local enabled = net.ReadBool()

    local target = player.GetBySteamID64(targetSteamId)
    if not IsValid(target) then return end

    -- Hierarchy: can only toggle sharing for players of strictly lower rank
    if CKB_SV.GetRankLevel(target) >= CKB_SV.GetRankLevel(ply) then return end

    local data = CKB_SV.LoadPlayerData(target)
    data.sharingAllowed = enabled
    CKB_SV.SavePlayerData(target, data)
end)
