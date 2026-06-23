CKB_SV = CKB_SV or {}

CKB_SV.MAX_KEYBINDS = 50
CKB_SV.RATE_LIMIT = 0.2
CKB_SV.DIR = "commands_keybinding"
CKB_SV.PlayerRateLimits = {}
CKB_SV.Cache = CKB_SV.Cache or {}

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
    local token = string.match(cmd or "", "^%s*(%S+)")
    if not token then return false end
    return blockedCommands[string.lower(token)] or false
end

-- ── Player identity / file path ───────────────────────

function CKB_SV.GetPlayerKey(ply)
    return ply:SteamID64() or ("ent_" .. ply:EntIndex())
end

function CKB_SV.GetPlayerFile(ply)
    return CKB_SV.DIR .. "/" .. CKB_SV.GetPlayerKey(ply) .. ".json"
end

-- ── Load / save raw data ──────────────────────────────

function CKB_SV.LoadPlayerData(ply)
    local cacheKey = CKB_SV.GetPlayerKey(ply)
    local cached = CKB_SV.Cache[cacheKey]
    if cached then return cached end

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
            CKB_SV.Cache[cacheKey] = tbl
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
    CKB_SV.Cache[CKB_SV.GetPlayerKey(ply)] = data
    file.CreateDir(CKB_SV.DIR)
    file.Write(CKB_SV.GetPlayerFile(ply), util.TableToJSON(data, true))
end

function CKB_SV.ClearCache(ply)
    CKB_SV.Cache[CKB_SV.GetPlayerKey(ply)] = nil
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
