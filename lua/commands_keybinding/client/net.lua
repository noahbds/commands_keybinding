-- ═══════════════════════════════════════════════════════
--  CKB — Net: receive keybinds & profiles from server
-- ═══════════════════════════════════════════════════════

-- ── Receive active keybinds ───────────────────────────

net.Receive("CKB_Config", function()
    CKB.KeyBinds = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        local command = net.ReadString()
        local key = net.ReadInt(32)
        local argument = net.ReadString()
        CKB.KeyBinds[command] = { key = key, argument = argument }
    end
    if IsValid(CKB.Frame) and CKB.Frame.RefreshList then
        CKB.Frame:RefreshList()
    end
end)

-- ── Receive profile list ──────────────────────────────

net.Receive("CKB_ProfileList", function()
    CKB.Profiles = {}
    CKB.ActiveProfile = net.ReadString()
    local count = net.ReadUInt(16)
    for i = 1, count do
        local id = net.ReadString()
        local name = net.ReadString()
        CKB.Profiles[id] = name
    end
    if IsValid(CKB.Frame) and CKB.Frame.RefreshProfiles then
        CKB.Frame:RefreshProfiles()
    end
end)

-- ── Send keybind update to server ─────────────────────

function CKB.SendUpdate(command, key, argument)
    net.Start("CKB_Update")
    net.WriteString(command)
    net.WriteInt(key, 32)
    net.WriteString(argument or "")
    net.SendToServer()
end

-- ── Profile operations ────────────────────────────────

function CKB.SendProfileSwitch(profileId)
    net.Start("CKB_ProfileSwitch")
    net.WriteString(profileId)
    net.SendToServer()
end

function CKB.SendProfileCreate(name, cloneFromId)
    net.Start("CKB_ProfileCreate")
    net.WriteString(name)
    net.WriteString(cloneFromId or "")
    net.SendToServer()
end

function CKB.SendProfileDelete(profileId)
    net.Start("CKB_ProfileDelete")
    net.WriteString(profileId)
    net.SendToServer()
end

function CKB.SendProfileRename(profileId, newName)
    net.Start("CKB_ProfileRename")
    net.WriteString(profileId)
    net.WriteString(newName)
    net.SendToServer()
end
