-- ═══════════════════════════════════════════════════════
--  CKB — Server: data persistence & profile storage
-- ═══════════════════════════════════════════════════════

CKB_SV = CKB_SV or {}

CKB_SV.MAX_KEYBINDS = 50
CKB_SV.RATE_LIMIT = 0.2
CKB_SV.DIR = "commands_keybinding"

CKB_SV.PlayerRateLimits = {}

-- ── Blocked commands (shared with client) ─────────────

local blockedCommands = {
    ["quit"] = true, ["exit"] = true, ["killserver"] = true,
    ["rcon"] = true, ["rcon_password"] = true, ["sv_password"] = true,
    ["banid"] = true, ["banip"] = true, ["kickid"] = true, ["kickid2"] = true,
    ["sv_cheats"] = true, ["changelevel"] = true, ["changelevel2"] = true,
    ["bind"] = true, ["unbind"] = true, ["unbindall"] = true,
    ["exec"] = true, ["alias"] = true, ["sv_allowcslua"] = true,
    ["lua_run"] = true, ["lua_run_cl"] = true, ["lua_openscript"] = true, ["lua_openscript_cl"] = true,
}

function CKB_SV.IsConCommandBlocked(cmd)
    return blockedCommands[string.lower(cmd)] or false
end

-- ── Player file path ──────────────────────────────────

function CKB_SV.GetPlayerFile(ply)
    return CKB_SV.DIR .. "/" .. ply:SteamID64() .. ".json"
end

-- ── Load / save raw data ──────────────────────────────

function CKB_SV.LoadPlayerData(ply)
    local path = CKB_SV.GetPlayerFile(ply)
    if file.Exists(path, "DATA") then
        local raw = file.Read(path, "DATA")
        local tbl = util.JSONToTable(raw)
        if istable(tbl) then
            -- Auto-migrate old flat format to new profile format
            if not tbl.profiles then
                local profileId = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
                tbl = {
                    activeProfile = profileId,
                    profiles = {
                        [profileId] = {
                            name = "Default",
                            binds = tbl,
                        },
                    },
                }
                CKB_SV.SavePlayerData(ply, tbl)
            end
            return tbl
        end
    end

    -- New player: create default empty profile
    local profileId = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    local data = {
        activeProfile = profileId,
        profiles = {
            [profileId] = {
                name = "Default",
                binds = {},
            },
        },
    }
    CKB_SV.SavePlayerData(ply, data)
    return data
end

function CKB_SV.SavePlayerData(ply, data)
    file.CreateDir(CKB_SV.DIR)
    file.Write(CKB_SV.GetPlayerFile(ply), util.TableToJSON(data, true))
end

-- ── Profile helpers ───────────────────────────────────

function CKB_SV.GetActiveBinds(ply)
    local data = CKB_SV.LoadPlayerData(ply)
    local profile = data.profiles[data.activeProfile]
    if profile then return profile.binds end
    return {}
end

function CKB_SV.SetActiveBinds(ply, binds)
    local data = CKB_SV.LoadPlayerData(ply)
    local profile = data.profiles[data.activeProfile]
    if profile then
        profile.binds = binds
        CKB_SV.SavePlayerData(ply, data)
    end
end

-- ── Validation ────────────────────────────────────────

function CKB_SV.IsValidCommandStr(cmd)
    if not isstring(cmd) or #cmd == 0 or #cmd > 128 then return false end
    if not string.match(cmd, "^[%w%+%-_%*/!%s]+$") then return false end
    if not string.match(cmd, "%S") then return false end
    return true
end

-- ── Rate limiting ─────────────────────────────────────

function CKB_SV.CheckRateLimit(ply)
    local now = CurTime()
    if CKB_SV.PlayerRateLimits[ply] and now - CKB_SV.PlayerRateLimits[ply] < CKB_SV.RATE_LIMIT then
        return false
    end
    CKB_SV.PlayerRateLimits[ply] = now
    return true
end
