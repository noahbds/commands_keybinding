if SERVER then return end

-- ═══════════════════════════════════════════════════════
--  Commands Key Binding — Client
-- ═══════════════════════════════════════════════════════

local keyBinds = {}
local keyPressStates = {}
local frame

local typingInTextEntry = false
local MAX_SUGGESTIONS = 20

-- ── Theme colors ──────────────────────────────────────

local THEME = {
    bg          = Color(22, 22, 30),
    bgLight     = Color(32, 32, 42),
    bgInput     = Color(18, 18, 26),
    border      = Color(55, 55, 70),
    borderFocus = Color(90, 130, 240),
    accent      = Color(70, 115, 235),
    accentHover = Color(90, 135, 255),
    accentDim   = Color(50, 85, 180),
    text        = Color(210, 215, 225),
    textDim     = Color(130, 135, 150),
    textBright  = Color(255, 255, 255),
    danger      = Color(220, 60, 60),
    dangerBg    = Color(60, 20, 20),
    success     = Color(60, 200, 120),
    titleBar    = Color(28, 28, 38),
    rowEven     = Color(26, 26, 36),
    rowOdd      = Color(32, 32, 44),
    rowHover    = Color(45, 50, 70),
    rowSelected = Color(50, 70, 120),
    headerBg    = Color(35, 35, 48),
    shadow      = Color(0, 0, 0, 80),
}

-- ── Styled element factories ──────────────────────────

local function styleFrame(f, title)
    f:SetTitle("")
    if IsValid(f.lblTitle) then f.lblTitle:SetVisible(false) end
    f._title = title

    f.Paint = function(self, w, h)
        -- Shadow
        draw.RoundedBox(8, 2, 2, w, h, THEME.shadow)
        -- Body
        draw.RoundedBox(6, 0, 0, w, h, THEME.bg)
        -- Title bar
        draw.RoundedBoxEx(6, 0, 0, w, 28, THEME.titleBar, true, true, false, false)
        -- Accent line under title
        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, 28, w, 2)
        -- Title text
        draw.SimpleText(self._title or "", "DermaDefaultBold", 10, 14, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    f.btnClose.Paint = function(self, w, h)
        if self:IsDown() then
            draw.RoundedBox(4, 0, 0, w, h, Color(180, 40, 40))
        elseif self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(200, 50, 50, 200))
        end
        local textCol = self:IsHovered() and THEME.textBright or THEME.textDim
        draw.SimpleText("x", "DermaDefaultBold", w / 2, h / 2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function styleTextEntry(entry)
    entry:SetFont("DermaDefault")
    entry:SetTextColor(THEME.text)
    entry:SetCursorColor(THEME.text)
    entry:SetHighlightColor(THEME.accent)

    entry.Paint = function(self, w, h)
        local focused = self:HasFocus()
        local col = focused and THEME.borderFocus or THEME.border
        draw.RoundedBox(4, 0, 0, w, h, col)
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, THEME.bgInput)
        self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)

        if not focused and self:GetValue() == "" and self:GetPlaceholderText() then
            draw.SimpleText(self:GetPlaceholderText(), "DermaDefault", 5, h / 2, THEME.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function styleButton(btn, isAccent)
    btn:SetFont("DermaDefaultBold")
    btn:SetTextColor(THEME.textBright)

    btn.Paint = function(self, w, h)
        local bg
        if not self:IsEnabled() then
            bg = Color(40, 40, 50)
            self:SetTextColor(THEME.textDim)
        elseif self:IsDown() then
            bg = isAccent and Color(40, 160, 80) or THEME.accentDim
            self:SetTextColor(THEME.textBright)
        elseif self:IsHovered() then
            bg = isAccent and Color(50, 180, 100) or Color(55, 60, 75)
            self:SetTextColor(THEME.textBright)
        else
            bg = isAccent and THEME.accent or Color(45, 48, 60)
            self:SetTextColor(THEME.text)
        end
        draw.RoundedBox(4, 0, 0, w, h, bg)
    end
end

local function styleBinder(binder)
    -- Hide the default DButton/DLabel text and tooltip
    binder:SetText("")
    binder.SetText = function() end
    binder:SetTooltip(nil)
    binder.SetTooltip = function() end
    binder.UpdateText = function(self)
        self:SetText("")
    end

    binder.Paint = function(self, w, h)
        local focused = self.Depressed
        local col = focused and THEME.accentHover or THEME.border
        draw.RoundedBox(4, 0, 0, w, h, col)
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, THEME.bgInput)

        local keyName = self:GetValue() ~= 0 and input.GetKeyName(self:GetValue()) or "Click to bind..."
        local textCol = self:GetValue() ~= 0 and THEME.text or THEME.textDim
        if focused then
            keyName = "Press a key..."
            textCol = THEME.accentHover
        end
        draw.SimpleText(string.upper(keyName), "DermaDefaultBold", w / 2, h / 2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function styleLabel(label)
    label:SetFont("DermaDefaultBold")
    label:SetTextColor(THEME.textDim)
end

local function styleListView(listView)
    listView.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

    -- Style the header
    local origAddColumn = listView.AddColumn
    listView.AddColumn = function(self, name, ...)
        local col = origAddColumn(self, name, ...)
        col.Header.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, THEME.headerBg)
            surface.SetDrawColor(THEME.border)
            surface.DrawRect(0, h - 1, w, 1)
        end
        col.Header:SetFont("DermaDefaultBold")
        col.Header:SetTextColor(THEME.textDim)
        return col
    end
end

-- ── Blocked commands ──────────────────────────────────

local blockedCommands = {
    ["quit"] = true, ["exit"] = true, ["killserver"] = true,
    ["rcon"] = true, ["rcon_password"] = true, ["sv_password"] = true,
    ["banid"] = true, ["banip"] = true, ["kickid"] = true, ["kickid2"] = true,
    ["sv_cheats"] = true, ["changelevel"] = true, ["changelevel2"] = true,
    ["bind"] = true, ["unbind"] = true, ["unbindall"] = true,
    ["exec"] = true, ["alias"] = true, ["sv_allowcslua"] = true,
    ["lua_run"] = true, ["lua_run_cl"] = true, ["lua_openscript"] = true, ["lua_openscript_cl"] = true,
}

local function IsConCommandBlocked(cmd)
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

local function GetEngineBind(keyCode)
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

-- ── Text entry focus tracking ─────────────────────────

hook.Add("OnTextEntryGetFocus", "CKB_Typing", function()
    typingInTextEntry = true
end)

hook.Add("OnTextEntryLoseFocus", "CKB_NotTyping", function()
    typingInTextEntry = false
end)

-- ── Net: receive keybinds from server ─────────────────

net.Receive("CommandsKeyBinding_Config", function()
    keyBinds = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        local command = net.ReadString()
        local key = net.ReadInt(32)
        local argument = net.ReadString()
        keyBinds[command] = { key = key, argument = argument }
    end
    if IsValid(frame) and frame.RefreshList then
        frame:RefreshList()
    end
end)

-- ── Validation ────────────────────────────────────────

local function isValidCommand(cmd)
    if not cmd or cmd == "" then return false end
    return string.match(cmd, "^[%w%+%-_%*/!%s]+$") ~= nil and string.match(cmd, "%S") ~= nil
end

-- ── Suggestions ───────────────────────────────────────

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

local function GetCommandSuggestions(text)
    if not text or text == "" then return {} end
    text = string.lower(text)
    local textLen = #text

    if not mergedCommands then BuildMergedCommands() end

    -- Two-pass: prefix matches first, then substring matches
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

    -- Combine: prefix first, then substring, capped at MAX_SUGGESTIONS
    local results = {}
    for _, cmd in ipairs(prefixResults) do
        table.insert(results, cmd)
        if #results >= MAX_SUGGESTIONS then break end
    end
    if #results < MAX_SUGGESTIONS then
        for _, cmd in ipairs(substringResults) do
            table.insert(results, cmd)
            if #results >= MAX_SUGGESTIONS then break end
        end
    end

    return results
end

-- ── Net: send update to server ────────────────────────

local function sendUpdate(command, key, argument)
    net.Start("CommandsKeyBinding_Update")
    net.WriteString(command)
    net.WriteInt(key, 32)
    net.WriteString(argument or "")
    net.SendToServer()
end

-- ── Error popup ───────────────────────────────────────

local function showError(message)
    Derma_Message(message, "Commands Key Binding — Error", "OK")
    surface.PlaySound("common/warning.wav")
end

-- ── Confirm save popup (engine bind + keybind manager conflicts) ──

local function showSaveConfirmation(warnings, onConfirm)
    surface.PlaySound("common/warning.wav")

    local warningText = table.concat(warnings, "\n\n")

    local popup = vgui.Create("DFrame")
    popup:SetSize(420, 300) -- generous initial; shrunk to fit after layout
    popup:SetTitle("")
    popup:MakePopup()
    popup:SetDeleteOnClose(true)
    popup:SetDraggable(true)
    popup:ShowCloseButton(false)
    if IsValid(popup.lblTitle) then popup.lblTitle:SetVisible(false) end

    -- Pulsing danger stripe
    local pulseStart = SysTime()
    popup.Paint = function(self, w, h)
        -- Shadow
        draw.RoundedBox(8, 2, 2, w, h, Color(0, 0, 0, 120))
        -- Body
        draw.RoundedBox(6, 0, 0, w, h, THEME.bg)
        -- Danger title bar
        local pulse = math.abs(math.sin((SysTime() - pulseStart) * 2.5))
        local barR = Lerp(pulse, 140, 200)
        local barG = Lerp(pulse, 25, 45)
        local barB = Lerp(pulse, 25, 35)
        draw.RoundedBoxEx(6, 0, 0, w, 32, Color(barR, barG, barB), true, true, false, false)
        -- Danger accent line
        surface.SetDrawColor(THEME.danger)
        surface.DrawRect(0, 32, w, 2)
        -- Warning icon + title
        draw.SimpleText("⚠", "DermaLarge", 12, 16, Color(255, 220, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("WARNING", "DermaDefaultBold", 36, 16, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Content area
    local content = vgui.Create("DPanel", popup)
    content:Dock(TOP)
    content:DockMargin(12, 40, 12, 0)
    content.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.dangerBg)
        -- Left danger stripe
        surface.SetDrawColor(THEME.danger)
        surface.DrawRect(0, 0, 3, h)
    end

    -- Warning message label
    local msgLabel = vgui.Create("DLabel", content)
    msgLabel:Dock(TOP)
    msgLabel:DockMargin(12, 8, 8, 8)
    msgLabel:SetFont("DermaDefault")
    msgLabel:SetTextColor(Color(255, 180, 180))
    msgLabel:SetWrap(true)
    msgLabel:SetAutoStretchVertical(true)
    msgLabel:SetText(warningText)
    -- Force label to calculate its wrapped height based on available width
    msgLabel:SetWide(420 - 24 - 20 - 3) -- popup width minus margins and stripe

    -- "Continue anyway?" label
    local continueLabel = vgui.Create("DLabel", popup)
    continueLabel:Dock(TOP)
    continueLabel:DockMargin(12, 8, 12, 0)
    continueLabel:SetFont("DermaDefaultBold")
    continueLabel:SetTextColor(THEME.text)
    continueLabel:SetText("Are you sure you want to continue?")
    continueLabel:SizeToContents()

    -- Buttons
    local btnPanel = vgui.Create("DPanel", popup)
    btnPanel:Dock(TOP)
    btnPanel:DockMargin(12, 10, 12, 12)
    btnPanel:SetTall(32)
    btnPanel.Paint = function() end

    local btnNo = vgui.Create("DButton", btnPanel)
    btnNo:Dock(RIGHT)
    btnNo:SetWide(100)
    btnNo:SetText("Cancel")
    btnNo:SetFont("DermaDefaultBold")
    btnNo:SetTextColor(THEME.textBright)
    btnNo.Paint = function(self, w, h)
        local bg
        if self:IsDown() then bg = THEME.accentDim
        elseif self:IsHovered() then bg = Color(55, 60, 75)
        else bg = Color(45, 48, 60) end
        draw.RoundedBox(4, 0, 0, w, h, bg)
    end
    btnNo.DoClick = function()
        popup:Close()
    end

    local btnYes = vgui.Create("DButton", btnPanel)
    btnYes:Dock(RIGHT)
    btnYes:DockMargin(0, 0, 6, 0)
    btnYes:SetWide(130)
    btnYes:SetText("Continue Anyway")
    btnYes:SetFont("DermaDefaultBold")
    btnYes:SetTextColor(THEME.textBright)
    btnYes.Paint = function(self, w, h)
        local bg
        if self:IsDown() then bg = Color(180, 40, 40)
        elseif self:IsHovered() then bg = Color(220, 60, 60)
        else bg = Color(160, 35, 35) end
        draw.RoundedBox(4, 0, 0, w, h, bg)
    end
    btnYes.DoClick = function()
        popup:Close()
        if onConfirm then onConfirm() end
    end

    -- Shrink to fit after layout settles
    timer.Simple(0, function()
        if not IsValid(popup) then return end
        msgLabel:InvalidateLayout(true)
        msgLabel:SizeToContentsY()
        content:SetTall(msgLabel:GetTall() + 16)
        content:InvalidateLayout(true)
        popup:InvalidateLayout(true)
        -- Read actual position of bottom element after re-layout
        local finalH = btnPanel:GetY() + btnPanel:GetTall() + 12
        popup:SetTall(finalH)
        popup:Center()
    end)
end

-- ── Edit popup ────────────────────────────────────────

local function openEditPopup(existingKey, existingCommand, existingArgument)
    local editFrame = vgui.Create("DFrame")
    editFrame:SetSize(450, 250)
    editFrame:Center()
    editFrame:MakePopup()
    editFrame:SetDeleteOnClose(true)
    styleFrame(editFrame, "Edit Key Bind")

    local container = vgui.Create("DPanel", editFrame)
    container:Dock(FILL)
    container:DockMargin(8, 8, 8, 8)
    container:DockPadding(8, 8, 8, 8)
    container.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

    -- Command row
    local cmdRow = vgui.Create("DPanel", container)
    cmdRow:Dock(TOP)
    cmdRow:SetTall(28)
    cmdRow:DockMargin(0, 0, 0, 6)
    cmdRow.Paint = function() end

    local cmdLabel = vgui.Create("DLabel", cmdRow)
    cmdLabel:Dock(LEFT)
    cmdLabel:SetWide(80)
    cmdLabel:SetText("Command:")
    styleLabel(cmdLabel)

    local cmdEntry = vgui.Create("DTextEntry", cmdRow)
    cmdEntry:Dock(FILL)
    cmdEntry:SetText(string.gsub(existingCommand, "%d*$", ""))
    styleTextEntry(cmdEntry)

    -- Argument row
    local argRow = vgui.Create("DPanel", container)
    argRow:Dock(TOP)
    argRow:SetTall(28)
    argRow:DockMargin(0, 0, 0, 6)
    argRow.Paint = function() end

    local argLabel = vgui.Create("DLabel", argRow)
    argLabel:Dock(LEFT)
    argLabel:SetWide(80)
    argLabel:SetText("Argument:")
    styleLabel(argLabel)

    local argEntry = vgui.Create("DTextEntry", argRow)
    argEntry:Dock(FILL)
    argEntry:SetText(existingArgument or "")
    styleTextEntry(argEntry)

    -- Key binder row
    local keyRow = vgui.Create("DPanel", container)
    keyRow:Dock(TOP)
    keyRow:SetTall(35)
    keyRow:DockMargin(0, 0, 0, 6)
    keyRow.Paint = function() end

    local keyLabel = vgui.Create("DLabel", keyRow)
    keyLabel:Dock(LEFT)
    keyLabel:SetWide(80)
    keyLabel:SetText("Key Bind:")
    styleLabel(keyLabel)

    local keyBinder = vgui.Create("DBinder", keyRow)
    keyBinder:Dock(FILL)
    keyBinder:SetValue(existingKey)
    styleBinder(keyBinder)

    -- Save button
    local saveBtn = vgui.Create("DButton", container)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(34)
    saveBtn:DockMargin(60, 10, 60, 0)
    saveBtn:SetText("Save Changes")
    styleButton(saveBtn, true)

    saveBtn.DoClick = function()
        local cmd = cmdEntry:GetValue()
        local arg = argEntry:GetValue()
        local newKey = keyBinder:GetValue()

        if not isValidCommand(cmd) then
            showError("Invalid command.")
            return
        end
        if IsConCommandBlocked(cmd) then
            showError("This command is blocked.")
            return
        end
        if not newKey or newKey == 0 then
            showError("Please select a key.")
            return
        end

        if existingCommand == cmd then
            -- Same command name: single update (overwrite)
            sendUpdate(cmd, newKey, arg)
        else
            -- Command name changed: delete old, then add new after rate limit
            sendUpdate(existingCommand, 0, "")
            timer.Simple(0.25, function()
                sendUpdate(cmd, newKey, arg)
            end)
        end
        editFrame:Close()
    end
end

-- ── Suggestions panel ─────────────────────────────────

local activeSuggestionPanel

local function closeSuggestions()
    if IsValid(activeSuggestionPanel) then
        activeSuggestionPanel:Remove()
        activeSuggestionPanel = nil
    end
end

local function showSuggestions(parent, cmdEntry, suggestions)
    closeSuggestions()
    if #suggestions == 0 then return end

    local panel = vgui.Create("DScrollPanel", parent)
    local x, y = cmdEntry:LocalToScreen(0, cmdEntry:GetTall())
    x, y = parent:ScreenToLocal(x, y)
    local panelH = math.min(#suggestions * 26, 180)
    local frameW, frameH = parent:GetSize()
    -- Flip above if would go below frame
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

    -- Style scrollbar
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

        local isBlocked = IsConCommandBlocked(cmd)

        btn.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(0, 2, 1, w - 4, h - 2, THEME.accent)
            elseif idx % 2 == 0 then
                draw.RoundedBox(0, 2, 1, w - 4, h - 2, Color(28, 28, 38, 100))
            end

            local textCol = isBlocked and THEME.danger or (self:IsHovered() and THEME.textBright or THEME.text)
            draw.SimpleText(cmd, "DermaDefault", 10, h / 2, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            if isBlocked then
                draw.SimpleText("BLOCKED", "DermaDefault", w - 10, h / 2, THEME.danger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        btn.DoClick = function()
            if isBlocked then
                showError("This command is blocked.")
                cmdEntry:SetText("")
            else
                cmdEntry:SetText(cmd)
            end
            closeSuggestions()
        end
    end

    activeSuggestionPanel = panel
end

-- ── Main config menu ──────────────────────────────────

local function openConfigMenu()
    if IsValid(frame) then
        frame:MakePopup()
        return
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(650, 530)
    frame:Center()
    frame:MakePopup()
    frame:SetSizable(true)
    frame:SetMinWidth(500)
    frame:SetMinHeight(400)
    frame:SetDeleteOnClose(true)
    styleFrame(frame, "Commands Key Binding")

    frame.OnClose = function()
        closeSuggestions()
        frame = nil
    end

    -- ── Top panel: inputs ─────────────────────────────

    local topPanel = vgui.Create("DPanel", frame)
    topPanel:Dock(TOP)
    topPanel:SetTall(190)
    topPanel:DockMargin(8, 8, 8, 0)
    topPanel:DockPadding(12, 8, 12, 8)
    topPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, THEME.bgLight)
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Status bar
    local statusBar = vgui.Create("DPanel", topPanel)
    statusBar:Dock(BOTTOM)
    statusBar:SetTall(24)
    statusBar:DockMargin(0, 4, 0, 0)
    statusBar:SetVisible(false)
    statusBar.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.dangerBg)
        surface.SetDrawColor(THEME.danger)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local statusLabel = vgui.Create("DLabel", statusBar)
    statusLabel:Dock(FILL)
    statusLabel:DockMargin(8, 0, 8, 0)
    statusLabel:SetContentAlignment(5)
    statusLabel:SetTextColor(THEME.danger)
    statusLabel:SetFont("DermaDefault")

    local function setStatus(msg)
        if msg then
            statusLabel:SetText(msg)
            statusBar:SetVisible(true)
            timer.Create("CKB_HideStatus", 4, 1, function()
                if IsValid(statusBar) then statusBar:SetVisible(false) end
            end)
        else
            statusBar:SetVisible(false)
        end
    end

    -- Command row
    local cmdRow = vgui.Create("DPanel", topPanel)
    cmdRow:Dock(TOP)
    cmdRow:SetTall(28)
    cmdRow:DockMargin(0, 2, 0, 5)
    cmdRow.Paint = function() end

    local cmdLabel = vgui.Create("DLabel", cmdRow)
    cmdLabel:Dock(LEFT)
    cmdLabel:SetWide(80)
    cmdLabel:SetText("Command:")
    styleLabel(cmdLabel)

    local commandEntry = vgui.Create("DTextEntry", cmdRow)
    commandEntry:Dock(FILL)
    commandEntry:SetPlaceholderText("Type a command...")
    styleTextEntry(commandEntry)

    -- Argument row
    local argRow = vgui.Create("DPanel", topPanel)
    argRow:Dock(TOP)
    argRow:SetTall(28)
    argRow:DockMargin(0, 0, 0, 5)
    argRow.Paint = function() end

    local argLabel = vgui.Create("DLabel", argRow)
    argLabel:Dock(LEFT)
    argLabel:SetWide(80)
    argLabel:SetText("Argument:")
    styleLabel(argLabel)

    local argumentEntry = vgui.Create("DTextEntry", argRow)
    argumentEntry:Dock(FILL)
    argumentEntry:SetPlaceholderText("Optional argument...")
    styleTextEntry(argumentEntry)

    -- Key binder row
    local keyRow = vgui.Create("DPanel", topPanel)
    keyRow:Dock(TOP)
    keyRow:SetTall(35)
    keyRow:DockMargin(0, 0, 0, 5)
    keyRow.Paint = function() end

    local keyLabel = vgui.Create("DLabel", keyRow)
    keyLabel:Dock(LEFT)
    keyLabel:SetWide(80)
    keyLabel:SetText("Key Bind:")
    styleLabel(keyLabel)

    local keyBinder = vgui.Create("DBinder", keyRow)
    keyBinder:Dock(FILL)
    styleBinder(keyBinder)

    -- Save button
    local saveButton = vgui.Create("DButton", topPanel)
    saveButton:Dock(TOP)
    saveButton:SetTall(32)
    saveButton:DockMargin(100, 4, 100, 0)
    saveButton:SetText("Save Key Bind")
    saveButton:SetEnabled(false)
    styleButton(saveButton, true)

    -- ── Suggestions logic ─────────────────────────────

    local debounceTimer = "CKB_Debounce"

    commandEntry.OnChange = function(self)
        timer.Remove(debounceTimer)
        local cmd = self:GetValue()

        closeSuggestions()

        if not self:IsEditing() or cmd == "" then
            setStatus(nil)
            saveButton:SetEnabled(false)
            return
        end

        if isValidCommand(cmd) and keyBinder:GetValue() ~= 0 then
            saveButton:SetEnabled(true)
        else
            saveButton:SetEnabled(false)
        end

        if not isValidCommand(cmd) then
            setStatus("Invalid: Only alphanumeric, +, -, _, *, /, ! and spaces allowed.")
            return
        end

        if IsConCommandBlocked(cmd) then
            setStatus("This command is blocked.")
            self:SetText("")
            saveButton:SetEnabled(false)
            return
        end

        setStatus(nil)

        timer.Create(debounceTimer, 0.15, 1, function()
            if not IsValid(self) or not IsValid(frame) then return end
            local suggestions = GetCommandSuggestions(self:GetValue())
            if #suggestions > 0 and self:IsEditing() then
                showSuggestions(frame, self, suggestions)
            end
        end)
    end

    keyBinder.OnChange = function(self, key)
        if key and key ~= 0 and isValidCommand(commandEntry:GetValue()) then
            saveButton:SetEnabled(true)
        end
    end

    -- ── Save logic ────────────────────────────────────

    saveButton.DoClick = function()
        local cmd = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        local argument = argumentEntry:GetValue()

        if not isValidCommand(cmd) then
            setStatus("Please enter a valid command.")
            return
        end
        if IsConCommandBlocked(cmd) then
            setStatus("This command is blocked.")
            return
        end
        if not key or key == 0 then
            setStatus("Please select a key.")
            return
        end

        -- Collect all warnings
        local warnings = {}
        local existingConflict = nil

        -- Check keybind manager conflict
        for existingCmd, data in pairs(keyBinds) do
            if data.key == key and existingCmd ~= cmd then
                existingConflict = existingCmd
                table.insert(warnings, 'The key "' .. input.GetKeyName(key) .. '" is already bound to "' .. existingCmd .. '" in the Keybind Manager. It will be overwritten.')
                break
            end
        end

        -- Check engine bind conflict
        local engineBind = GetEngineBind(key)
        if engineBind then
            table.insert(warnings, 'The key "' .. input.GetKeyName(key) .. '" is already bound to "' .. engineBind .. '" in Garry\'s Mod. The engine bind will take priority over the Keybind Manager binding, causing the command not to work while the engine bind is active. It is recommended to choose a different key.')
        end

        local function doSave()
            if existingConflict then
                sendUpdate(existingConflict, 0, "")
                timer.Simple(0.25, function()
                    sendUpdate(cmd, key, argument)
                end)
            else
                sendUpdate(cmd, key, argument)
            end
            commandEntry:SetText("")
            argumentEntry:SetText("")
            keyBinder:SetValue(0)
            saveButton:SetEnabled(false)
            setStatus(nil)
        end

        if #warnings > 0 then
            showSaveConfirmation(warnings, doSave)
        else
            doSave()
        end
    end

    -- ── Bottom panel: keybind list ────────────────────

    local bottomPanel = vgui.Create("DPanel", frame)
    bottomPanel:Dock(FILL)
    bottomPanel:DockMargin(8, 8, 8, 8)
    bottomPanel:DockPadding(0, 0, 0, 0)
    bottomPanel.Paint = function() end

    -- Search filter
    local searchEntry = vgui.Create("DTextEntry", bottomPanel)
    searchEntry:Dock(TOP)
    searchEntry:SetTall(26)
    searchEntry:DockMargin(0, 0, 0, 6)
    searchEntry:SetPlaceholderText("Search keybinds...")
    styleTextEntry(searchEntry)

    -- List
    local listView = vgui.Create("DListView", bottomPanel)
    listView:Dock(FILL)
    listView:SetMultiSelect(false)
    styleListView(listView)
    listView:AddColumn("Command"):SetFixedWidth(200)
    listView:AddColumn("Argument"):SetFixedWidth(150)
    listView:AddColumn("Key")

    -- Style list rows
    local origAddLine = listView.AddLine
    listView.AddLine = function(self, ...)
        local line = origAddLine(self, ...)
        local lineIdx = #self:GetLines()

        line.Paint = function(s, w, h)
            local bgCol
            if s:IsSelected() then
                bgCol = THEME.rowSelected
            elseif s:IsHovered() then
                bgCol = THEME.rowHover
            elseif lineIdx % 2 == 0 then
                bgCol = THEME.rowEven
            else
                bgCol = THEME.rowOdd
            end
            draw.RoundedBox(0, 0, 0, w, h, bgCol)
        end

        for _, col in ipairs(line.Columns) do
            col:SetTextColor(THEME.text)
            col:SetFont("DermaDefault")
        end

        return line
    end

    -- ── Refresh function ──────────────────────────────

    function frame:RefreshList(filter)
        listView:Clear()
        filter = filter and string.lower(filter) or nil

        for command, data in SortedPairs(keyBinds) do
            if type(data) == "table" then
                local displayCommand = string.gsub(command, "%d*$", "")
                local keyName = input.GetKeyName(data.key) or "?"
                local argument = data.argument or ""

                if not filter or filter == ""
                    or string.find(string.lower(displayCommand), filter, 1, true)
                    or string.find(string.lower(argument), filter, 1, true)
                    or string.find(string.lower(keyName), filter, 1, true) then

                    local line = listView:AddLine(displayCommand, argument, keyName)
                    line._ckbKey = data.key
                    line._ckbCommand = command
                    line._ckbArgument = argument
                end
            end
        end
    end

    searchEntry.OnChange = function(self)
        if IsValid(frame) then
            frame:RefreshList(self:GetValue())
        end
    end

    listView.OnRowRightClick = function(_, _, line)
        local menu = DermaMenu()
        menu:AddOption("Edit", function()
            openEditPopup(line._ckbKey, line._ckbCommand, line._ckbArgument)
        end):SetIcon("icon16/pencil.png")
        menu:AddSpacer()
        menu:AddOption("Delete", function()
            sendUpdate(line._ckbCommand, 0, "")
        end):SetIcon("icon16/cross.png")
        menu:Open()
    end

    listView.DoDoubleClick = function(_, _, line)
        openEditPopup(line._ckbKey, line._ckbCommand, line._ckbArgument)
    end

    frame:RefreshList()
end

concommand.Add("open_commands_keybinding", openConfigMenu)

-- ── Think: execute keybinds ───────────────────────────

hook.Add("Think", "CKB_ExecuteBinds", function()
    if typingInTextEntry then return end
    if gui.IsConsoleVisible() then return end
    if IsValid(LocalPlayer()) and LocalPlayer():IsTyping() then return end
    if vgui.CursorVisible() then return end

    for command, data in pairs(keyBinds) do
        local key = data.key
        if type(key) ~= "number" then continue end

        if input.IsKeyDown(key) then
            if not keyPressStates[key] then
                keyPressStates[key] = true
                local cleanCommand = string.gsub(command, "%d*$", "")
                local argument = data.argument
                if argument and argument ~= "" then
                    RunConsoleCommand(cleanCommand, argument)
                else
                    RunConsoleCommand(cleanCommand)
                end
            end
        else
            keyPressStates[key] = false
        end
    end
end)
