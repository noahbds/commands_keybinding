-- ═══════════════════════════════════════════════════════
--  CKB — Popup dialogs (error, warning, edit)
-- ═══════════════════════════════════════════════════════

local THEME = CKB.THEME

-- ── Error popup ───────────────────────────────────────

function CKB.ShowError(message)
    Derma_Message(message, "Commands Key Binding — Error", "OK")
    surface.PlaySound("common/warning.wav")
end

-- ── Confirm save popup (engine bind + keybind manager conflicts) ──

function CKB.ShowSaveConfirmation(warnings, onConfirm)
    surface.PlaySound("common/warning.wav")

    local warningText = table.concat(warnings, "\n\n")

    local popup = vgui.Create("DFrame")
    popup:SetSize(420, 300)
    popup:SetTitle("")
    popup:MakePopup()
    popup:SetDeleteOnClose(true)
    popup:SetDraggable(true)
    popup:ShowCloseButton(false)
    if IsValid(popup.lblTitle) then popup.lblTitle:SetVisible(false) end

    local pulseStart = SysTime()
    popup.Paint = function(self, w, h)
        draw.RoundedBox(8, 2, 2, w, h, Color(0, 0, 0, 120))
        draw.RoundedBox(6, 0, 0, w, h, THEME.bg)
        local pulse = math.abs(math.sin((SysTime() - pulseStart) * 2.5))
        local barR = Lerp(pulse, 140, 200)
        local barG = Lerp(pulse, 25, 45)
        local barB = Lerp(pulse, 25, 35)
        draw.RoundedBoxEx(6, 0, 0, w, 32, Color(barR, barG, barB), true, true, false, false)
        surface.SetDrawColor(THEME.danger)
        surface.DrawRect(0, 32, w, 2)
        draw.SimpleText("\226\154\160", "DermaLarge", 12, 16, Color(255, 220, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("WARNING", "DermaDefaultBold", 36, 16, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local content = vgui.Create("DPanel", popup)
    content:Dock(TOP)
    content:DockMargin(12, 40, 12, 0)
    content.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.dangerBg)
        surface.SetDrawColor(THEME.danger)
        surface.DrawRect(0, 0, 3, h)
    end

    local msgLabel = vgui.Create("DLabel", content)
    msgLabel:Dock(TOP)
    msgLabel:DockMargin(12, 8, 8, 8)
    msgLabel:SetFont("DermaDefault")
    msgLabel:SetTextColor(Color(255, 180, 180))
    msgLabel:SetWrap(true)
    msgLabel:SetAutoStretchVertical(true)
    msgLabel:SetText(warningText)
    msgLabel:SetWide(420 - 24 - 20 - 3)

    local continueLabel = vgui.Create("DLabel", popup)
    continueLabel:Dock(TOP)
    continueLabel:DockMargin(12, 8, 12, 0)
    continueLabel:SetFont("DermaDefaultBold")
    continueLabel:SetTextColor(THEME.text)
    continueLabel:SetText("Are you sure you want to continue?")
    continueLabel:SizeToContents()

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

    timer.Simple(0, function()
        if not IsValid(popup) then return end
        msgLabel:InvalidateLayout(true)
        msgLabel:SizeToContentsY()
        content:SetTall(msgLabel:GetTall() + 16)
        content:InvalidateLayout(true)
        popup:InvalidateLayout(true)
        local finalH = btnPanel:GetY() + btnPanel:GetTall() + 12
        popup:SetTall(finalH)
        popup:Center()
    end)
end

-- ── Edit popup ────────────────────────────────────────

function CKB.OpenEditPopup(existingKey, existingCommand, existingArgument)
    local editFrame = vgui.Create("DFrame")
    editFrame:SetSize(450, 250)
    editFrame:Center()
    editFrame:MakePopup()
    editFrame:SetDeleteOnClose(true)
    CKB.StyleFrame(editFrame, "Edit Key Bind")

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
    CKB.StyleLabel(cmdLabel)

    local cmdEntry = vgui.Create("DTextEntry", cmdRow)
    cmdEntry:Dock(FILL)
    cmdEntry:SetText(string.gsub(existingCommand, "%d*$", ""))
    CKB.StyleTextEntry(cmdEntry)

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
    CKB.StyleLabel(argLabel)

    local argEntry = vgui.Create("DTextEntry", argRow)
    argEntry:Dock(FILL)
    argEntry:SetText(existingArgument or "")
    CKB.StyleTextEntry(argEntry)

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
    CKB.StyleLabel(keyLabel)

    local keyBinder = vgui.Create("DBinder", keyRow)
    keyBinder:Dock(FILL)
    keyBinder:SetValue(existingKey)
    CKB.StyleBinder(keyBinder)

    -- Save button
    local saveBtn = vgui.Create("DButton", container)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(34)
    saveBtn:DockMargin(60, 10, 60, 0)
    saveBtn:SetText("Save Changes")
    CKB.StyleButton(saveBtn, true)

    saveBtn.DoClick = function()
        local cmd = cmdEntry:GetValue()
        local arg = argEntry:GetValue()
        local newKey = keyBinder:GetValue()

        if not CKB.IsValidCommand(cmd) then
            CKB.ShowError("Invalid command.")
            return
        end
        if CKB.IsConCommandBlocked(cmd) then
            CKB.ShowError("This command is blocked.")
            return
        end
        if not newKey or newKey == 0 then
            CKB.ShowError("Please select a key.")
            return
        end

        if existingCommand == cmd then
            CKB.SendUpdate(cmd, newKey, arg)
        else
            CKB.SendUpdate(existingCommand, 0, "")
            timer.Simple(0.25, function()
                CKB.SendUpdate(cmd, newKey, arg)
            end)
        end
        editFrame:Close()
    end
end
