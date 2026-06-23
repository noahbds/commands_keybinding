CKB_SV.PendingShares = CKB_SV.PendingShares or {}

CreateConVar("ckb_allow_player_sharing", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Allow non-admin players to share profiles (0 = admin only, 1 = everyone)", 0, 1)

-- ── Admin check ───────────────────────────────────────

function CKB_SV.IsAdmin(ply)
    if not IsValid(ply) then return false end
    local hookResult = hook.Run("CKB_IsAdmin", ply)
    if hookResult ~= nil then return hookResult end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

-- ── Rank level for hierarchy checks ───────────────────

function CKB_SV.GetRankLevel(ply)
    if not IsValid(ply) then return 0 end
    if ply:IsSuperAdmin() then return 3 end
    if ply:IsAdmin() then return 2 end
    return 1
end

-- ── Can player share? ─────────────────────────────────

function CKB_SV.CanShare(ply)
    if CKB_SV.IsAdmin(ply) then return true end
    local data = CKB_SV.LoadPlayerData(ply)
    if data.sharingAllowed == false then return false end
    return true
end

-- ── Share request: sender → server ────────────────────

net.Receive("CKB_ShareProfile", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end
    if not CKB_SV.CanShare(ply) then
        net.Start("CKB_ShareResult")
        net.WriteString("")
        net.WriteBool(false)
        net.WriteString("share_not_allowed")
        net.Send(ply)
        return
    end

    local profileId = net.ReadString()
    local targetId = net.ReadString()

    local target = player.GetBySteamID64(targetId)
    if not IsValid(target) or target == ply then return end

    local data = CKB_SV.LoadPlayerData(ply)
    if not data.profiles[profileId] then return end

    local profile = data.profiles[profileId]

    -- Store pending share keyed by target + sender to prevent spam
    local pendingKey = target:SteamID64() .. "_" .. ply:SteamID64()
    CKB_SV.PendingShares[pendingKey] = {
        sender = ply,
        target = target,
        profileName = profile.name,
        binds = table.Copy(profile.binds),
    }

    -- Notify target
    net.Start("CKB_ShareIncoming")
    net.WriteString(ply:Nick())
    net.WriteString(ply:SteamID64())
    net.WriteString(profile.name)
    local bindCount = table.Count(profile.binds)
    net.WriteUInt(bindCount, 16)
    net.Send(target)
end)

-- ── Accept share ──────────────────────────────────────

net.Receive("CKB_ShareAccept", function(len, ply)
    if not IsValid(ply) then return end
    if not CKB_SV.CheckRateLimit(ply) then return end

    local senderSteamId = net.ReadString()
    local pendingKey = ply:SteamID64() .. "_" .. senderSteamId

    local pending = CKB_SV.PendingShares[pendingKey]
    if not pending then return end

    CKB_SV.PendingShares[pendingKey] = nil

    -- Create as new profile on recipient
    local data = CKB_SV.LoadPlayerData(ply)
    local newId = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    data.profiles[newId] = {
        name = pending.profileName,
        binds = table.Copy(pending.binds),
    }
    CKB_SV.SavePlayerData(ply, data)
    CKB_SV.SendProfileList(ply)

    -- Notify sender
    if IsValid(pending.sender) then
        net.Start("CKB_ShareResult")
        net.WriteString(ply:Nick())
        net.WriteBool(true)
        net.WriteString("")
        net.Send(pending.sender)
    end
end)

-- ── Decline share ─────────────────────────────────────

net.Receive("CKB_ShareDecline", function(len, ply)
    if not IsValid(ply) then return end

    local senderSteamId = net.ReadString()
    local pendingKey = ply:SteamID64() .. "_" .. senderSteamId

    local pending = CKB_SV.PendingShares[pendingKey]
    if not pending then return end

    CKB_SV.PendingShares[pendingKey] = nil

    -- Notify sender
    if IsValid(pending.sender) then
        net.Start("CKB_ShareResult")
        net.WriteString(ply:Nick())
        net.WriteBool(false)
        net.WriteString("")
        net.Send(pending.sender)
    end
end)

-- ── Cleanup pending shares on disconnect ──────────────

hook.Add("PlayerDisconnected", "CKB_CleanupShares", function(ply)
    local sid = ply:SteamID64()
    for key in pairs(CKB_SV.PendingShares) do
        if string.find(key, sid, 1, true) then
            CKB_SV.PendingShares[key] = nil
        end
    end
end)
