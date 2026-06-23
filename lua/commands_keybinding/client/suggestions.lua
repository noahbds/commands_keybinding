local THEME = CKB.THEME
local mergedCommands

local function BuildMergedCommands()
    local seen = {}
    mergedCommands = {}

    if AllCommands then
        for _, cmd in ipairs(AllCommands) do
            local lower = string.lower(cmd)
            if not seen[lower] then
                seen[lower] = true
                table.insert(mergedCommands, cmd)
            end
        end
    end

    for cmd in pairs(concommand.GetTable()) do
        local lower = string.lower(cmd)
        if not seen[lower] then
            seen[lower] = true
            table.insert(mergedCommands, cmd)
        end
    end

    table.sort(mergedCommands, function(a, b) return a < b end)
end

function CKB.GetCommandSuggestions(text)
    if not text or text == "" then return {} end
    text = string.lower(text)
    local textLen = #text

    if not mergedCommands then BuildMergedCommands() end

    local prefixResults = {}
    local substringResults = {}

    for _, cmd in ipairs(mergedCommands) do
        local lower = string.lower(cmd)
        if string.sub(lower, 1, textLen) == text then
            table.insert(prefixResults, cmd)
        elseif string.find(lower, text, 1, true) then
            table.insert(substringResults, cmd)
        end
    end

    local results = {}
    for _, cmd in ipairs(prefixResults) do
        table.insert(results, cmd)
        if #results >= CKB.MAX_SUGGESTIONS then break end
    end
    if #results < CKB.MAX_SUGGESTIONS then
        for _, cmd in ipairs(substringResults) do
            table.insert(results, cmd)
            if #results >= CKB.MAX_SUGGESTIONS then break end
        end
    end

    return results
end

-- ── Suggestions panel UI ──────────────────────────────

local activeSuggestionPanel

function CKB.CloseSuggestions()
    if IsValid(activeSuggestionPanel) then
        activeSuggestionPanel:Remove()
        activeSuggestionPanel = nil
    end
end

function CKB.ShowSuggestions(parent, cmdEntry, suggestions)
    CKB.CloseSuggestions()
    if #suggestions == 0 then return end

    local panel = vgui.Create("DScrollPanel", parent)
    local x, y = cmdEntry:LocalToScreen(0, cmdEntry:GetTall())
    x, y = parent:ScreenToLocal(x, y)
    local panelH = math.min(#suggestions * 26, 180)
    local frameW, frameH = parent:GetSize()
    if y + 2 + panelH > frameH - 10 then
        panel:SetPos(x, y - cmdEntry:GetTall() - panelH - 2)
    else
        panel:SetPos(x, y + 2)
    end
    panel:SetSize(cmdEntry:GetWide(), panelH)
    panel:MoveToFront()

    panel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(18, 18, 28, 250))
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local sbar = panel:GetVBar()
    sbar:SetWide(6)
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, w - 2, h, THEME.textDim)
    end

    for idx, cmd in ipairs(suggestions) do
        local btn = vgui.Create("DButton", panel)
        btn:Dock(TOP)
        btn:SetTall(26)
        btn:SetText("")

        local isBlocked = CKB.IsConCommandBlocked(cmd)

        btn.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(0, 2, 1, w - 4, h - 2, THEME.accent)
            elseif idx % 2 == 0 then
                draw.RoundedBox(0, 2, 1, w - 4, h - 2, Color(28, 28, 38, 100))
            end

            local textCol = isBlocked and THEME.danger or (self:IsHovered() and THEME.textBright or THEME.text)
            draw.SimpleText(cmd, "DermaDefault", 10, h / 2, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            if isBlocked then
                draw.SimpleText(CKB.L("blocked"), "DermaDefault", w - 10, h / 2, THEME.danger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        btn.DoClick = function()
            if isBlocked then
                CKB.ShowError(CKB.L("command_blocked"))
                cmdEntry:SetText("")
            else
                cmdEntry:SetText(cmd)
            end
            CKB.CloseSuggestions()
        end
    end

    activeSuggestionPanel = panel
end
