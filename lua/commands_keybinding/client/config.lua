CKB = CKB or {}

CKB.KeyBinds = CKB.KeyBinds or {}
CKB.ActiveKeyMap = CKB.ActiveKeyMap or {}
CKB.KeyPressStates = CKB.KeyPressStates or {}
CKB.Frame = nil
CKB.TypingInTextEntry = false
CKB.MAX_SUGGESTIONS = 20
CKB.ActiveProfile = nil
CKB.Profiles = {}

-- ── Validation ────────────────────────────────────────

function CKB.IsValidCommand(cmd)
    if not cmd or cmd == "" then return false end
    return string.match(cmd, "^[%w%+%-_%*/!%s]+$") ~= nil and string.match(cmd, "%S") ~= nil
end

-- ── Text entry focus tracking ─────────────────────────

hook.Add("OnTextEntryGetFocus", "CKB_Typing", function()
    CKB.TypingInTextEntry = true
end)

hook.Add("OnTextEntryLoseFocus", "CKB_NotTyping", function()
    CKB.TypingInTextEntry = false
end)
