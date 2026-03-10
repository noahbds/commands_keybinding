-- ═══════════════════════════════════════════════════════
--  CKB — Blocked commands & engine bind detection
-- ═══════════════════════════════════════════════════════

local blockedCommands = {
    ["quit"] = true, ["exit"] = true, ["killserver"] = true,
    ["rcon"] = true, ["rcon_password"] = true, ["sv_password"] = true,
    ["banid"] = true, ["banip"] = true, ["kickid"] = true, ["kickid2"] = true,
    ["sv_cheats"] = true, ["changelevel"] = true, ["changelevel2"] = true,
    ["bind"] = true, ["unbind"] = true, ["unbindall"] = true,
    ["exec"] = true, ["alias"] = true, ["sv_allowcslua"] = true,
    ["lua_run"] = true, ["lua_run_cl"] = true, ["lua_openscript"] = true, ["lua_openscript_cl"] = true,
}

function CKB.IsConCommandBlocked(cmd)
    return blockedCommands[string.lower(cmd)] or false
end

-- ── Engine bind detection ─────────────────────────────

local engineBinds = {
    "+forward", "+back", "+moveleft", "+moveright",
    "+jump", "+duck", "+use", "+attack", "+attack2",
    "+reload", "+speed", "+walk", "+showscores",
    "+voicerecord", "impulse 100", "impulse 201",
    "noclip", "undo", "gm_showhelp", "gm_showteam",
    "gm_showspare1", "gm_showspare2",
    "messagemode", "messagemode2", "+menu", "+menu_context",
    "invnext", "invprev", "lastinv", "phys_swap",
    "slot1", "slot2", "slot3", "slot4", "slot5", "slot6",
    "screenshot", "jpeg", "toggleconsole",
    "+score", "+zoom", "drop",
}

function CKB.GetEngineBind(keyCode)
    local keyName = input.GetKeyName(keyCode)
    if not keyName then return nil end
    keyName = string.lower(keyName)

    for _, bind in ipairs(engineBinds) do
        local boundKey = input.LookupBinding(bind)
        if boundKey and string.lower(boundKey) == keyName then
            return bind
        end
    end
    return nil
end
