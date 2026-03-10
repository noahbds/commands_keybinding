-- ═══════════════════════════════════════════════════════
--  CKB — Profile selector UI (embedded in main menu)
-- ═══════════════════════════════════════════════════════

local THEME = CKB.THEME

-- ── Create profile bar (docked into parent) ───────────

function CKB.CreateProfileBar(parent)
    local bar = vgui.Create("DPanel", parent)
    bar:Dock(TOP)
    bar:SetTall(36)
    bar:DockMargin(8, 8, 8, 0)
    bar:DockPadding(8, 4, 8, 4)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, THEME.bgLight)
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Profile label
    local label = vgui.Create("DLabel", bar)
    label:Dock(LEFT)
    label:SetWide(50)
    label:SetText("Profile:")
    label:SetFont("DermaDefaultBold")
    label:SetTextColor(THEME.textBright)

    -- Profile dropdown
    local combo = vgui.Create("DComboBox", bar)
    combo:Dock(LEFT)
    combo:SetWide(180)
    combo:DockMargin(4, 0, 0, 0)
    combo:SetFont("DermaDefault")
    combo:SetTextColor(THEME.textBright)
    combo:SetSortItems(false)
    combo:SetContentAlignment(4)
    combo:SetTextInset(6, 0)

    combo.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.border)
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, THEME.bgInput)
        draw.SimpleText("\226\150\188", "DermaDefault", w - 14, h / 2, THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    combo.OnSelect = function(_, _, _, data)
        if data and data ~= CKB.ActiveProfile then
            CKB.SendProfileSwitch(data)
        end
    end

    -- Buttons
    local btnNew = vgui.Create("DButton", bar)
    btnNew:Dock(LEFT)
    btnNew:SetWide(28)
    btnNew:DockMargin(6, 0, 0, 0)
    btnNew:SetText("+")
    btnNew:SetTooltip("New profile")
    CKB.StyleButton(btnNew)

    local btnClone = vgui.Create("DButton", bar)
    btnClone:Dock(LEFT)
    btnClone:SetWide(50)
    btnClone:DockMargin(4, 0, 0, 0)
    btnClone:SetText("Clone")
    btnClone:SetTooltip("Clone current profile")
    CKB.StyleButton(btnClone)

    local btnRename = vgui.Create("DButton", bar)
    btnRename:Dock(LEFT)
    btnRename:SetWide(60)
    btnRename:DockMargin(4, 0, 0, 0)
    btnRename:SetText("Rename")
    btnRename:SetTooltip("Rename current profile")
    CKB.StyleButton(btnRename)

    local btnDelete = vgui.Create("DButton", bar)
    btnDelete:Dock(LEFT)
    btnDelete:SetWide(28)
    btnDelete:DockMargin(4, 0, 0, 0)
    btnDelete:SetText("X")
    btnDelete:SetTooltip("Delete current profile")

    local btnShare = vgui.Create("DButton", bar)
    btnShare:Dock(LEFT)
    btnShare:SetWide(50)
    btnShare:DockMargin(4, 0, 0, 0)
    btnShare:SetText("Share")
    btnShare:SetTooltip("Share current profile with a player")
    CKB.StyleButton(btnShare)
    btnDelete:SetFont("DermaDefaultBold")
    btnDelete:SetTextColor(THEME.danger)
    btnDelete.Paint = function(self, w, h)
        local bg
        if not self:IsEnabled() then
            bg = Color(40, 40, 50)
            self:SetTextColor(THEME.textDim)
        elseif self:IsDown() then
            bg = Color(180, 40, 40)
            self:SetTextColor(THEME.textBright)
        elseif self:IsHovered() then
            bg = THEME.dangerBg
            self:SetTextColor(THEME.danger)
        else
            bg = Color(45, 48, 60)
            self:SetTextColor(THEME.danger)
        end
        draw.RoundedBox(4, 0, 0, w, h, bg)
    end

    -- ── Refresh dropdown ──────────────────────────────

    local function refreshDropdown()
        combo:Clear()
        local count = 0
        for id, name in SortedPairsByValue(CKB.Profiles) do
            local display = name
            if id == CKB.ActiveProfile then
                display = name .. " *"
            end
            combo:AddChoice(display, id, id == CKB.ActiveProfile)
            count = count + 1
        end
        btnDelete:SetEnabled(count > 1)
    end

    -- ── Button actions ────────────────────────────────

    btnNew.DoClick = function()
        CKB.OpenProfileNamePopup("New Profile", "", function(name)
            CKB.SendProfileCreate(name)
        end)
    end

    btnClone.DoClick = function()
        if not CKB.ActiveProfile then return end
        local currentName = CKB.Profiles[CKB.ActiveProfile] or "Profile"
        CKB.OpenProfileNamePopup("Clone Profile", currentName .. " (Copy)", function(name)
            CKB.SendProfileCreate(name, CKB.ActiveProfile)
        end)
    end

    btnRename.DoClick = function()
        if not CKB.ActiveProfile then return end
        local currentName = CKB.Profiles[CKB.ActiveProfile] or ""
        CKB.OpenProfileNamePopup("Rename Profile", currentName, function(name)
            CKB.SendProfileRename(CKB.ActiveProfile, name)
        end)
    end

    btnDelete.DoClick = function()
        if not CKB.ActiveProfile then return end
        local name = CKB.Profiles[CKB.ActiveProfile] or "this profile"
        CKB.OpenProfileConfirmDelete(name, function()
            CKB.SendProfileDelete(CKB.ActiveProfile)
        end)
    end

    btnShare.DoClick = function()
        if not CKB.ActiveProfile then return end
        CKB.OpenSharePlayerPicker(CKB.ActiveProfile)
    end

    -- Initial populate
    refreshDropdown()

    -- Expose refresh so menu.lua can call it on net receive
    bar.RefreshProfiles = refreshDropdown

    return bar
end

-- ── Name input popup (create / clone / rename) ────────

function CKB.OpenProfileNamePopup(title, defaultText, onConfirm)
    local popup = vgui.Create("DFrame")
    popup:SetSize(340, 150)
    popup:Center()
    popup:MakePopup()
    popup:SetDeleteOnClose(true)
    CKB.StyleFrame(popup, title)

    local container = vgui.Create("DPanel", popup)
    container:Dock(FILL)
    container:DockMargin(8, 8, 8, 8)
    container:DockPadding(8, 8, 8, 8)
    container.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

    local nameEntry = vgui.Create("DTextEntry", container)
    nameEntry:Dock(TOP)
    nameEntry:SetTall(28)
    nameEntry:SetPlaceholderText("Profile name...")
    nameEntry:SetText(defaultText or "")
    CKB.StyleTextEntry(nameEntry)

    local btnRow = vgui.Create("DPanel", container)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(32)
    btnRow.Paint = function() end

    local btnCancel = vgui.Create("DButton", btnRow)
    btnCancel:Dock(RIGHT)
    btnCancel:SetWide(80)
    btnCancel:SetText("Cancel")
    CKB.StyleButton(btnCancel)
    btnCancel.DoClick = function() popup:Close() end

    local btnOk = vgui.Create("DButton", btnRow)
    btnOk:Dock(RIGHT)
    btnOk:DockMargin(0, 0, 6, 0)
    btnOk:SetWide(80)
    btnOk:SetText("OK")
    CKB.StyleButton(btnOk, true)

    btnOk.DoClick = function()
        local name = string.Trim(nameEntry:GetValue())
        if name == "" or #name > 64 then
            surface.PlaySound("common/warning.wav")
            return
        end
        popup:Close()
        onConfirm(name)
    end

    nameEntry.OnEnter = function()
        btnOk:DoClick()
    end

    timer.Simple(0, function()
        if IsValid(nameEntry) then
            nameEntry:RequestFocus()
            nameEntry:SelectAllText()
        end
    end)
end

-- ── Delete confirmation popup ─────────────────────────

function CKB.OpenProfileConfirmDelete(profileName, onConfirm)
    local popup = vgui.Create("DFrame")
    popup:SetSize(360, 150)
    popup:Center()
    popup:MakePopup()
    popup:SetDeleteOnClose(true)
    CKB.StyleFrame(popup, "Delete Profile")

    local container = vgui.Create("DPanel", popup)
    container:Dock(FILL)
    container:DockMargin(8, 8, 8, 8)
    container:DockPadding(8, 8, 8, 8)
    container.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

    local msg = vgui.Create("DLabel", container)
    msg:Dock(TOP)
    msg:SetTall(40)
    msg:SetWrap(true)
    msg:SetFont("DermaDefault")
    msg:SetTextColor(THEME.textBright)
    msg:SetText('Are you sure you want to delete "' .. profileName .. '"?\nThis action cannot be undone.')

    local btnRow = vgui.Create("DPanel", container)
    btnRow:Dock(TOP)
    btnRow:SetTall(32)
    btnRow:DockMargin(0, 8, 0, 0)
    btnRow.Paint = function() end

    local btnCancel = vgui.Create("DButton", btnRow)
    btnCancel:Dock(RIGHT)
    btnCancel:SetWide(80)
    btnCancel:SetText("Cancel")
    CKB.StyleButton(btnCancel)
    btnCancel.DoClick = function() popup:Close() end

    local btnDel = vgui.Create("DButton", btnRow)
    btnDel:Dock(RIGHT)
    btnDel:DockMargin(0, 0, 6, 0)
    btnDel:SetWide(100)
    btnDel:SetText("Delete")
    btnDel:SetFont("DermaDefaultBold")
    btnDel:SetTextColor(THEME.textBright)
    btnDel.Paint = function(self, w, h)
        local bg
        if self:IsDown() then bg = Color(180, 40, 40)
        elseif self:IsHovered() then bg = Color(220, 60, 60)
        else bg = Color(160, 35, 35) end
        draw.RoundedBox(4, 0, 0, w, h, bg)
    end
    btnDel.DoClick = function()
        popup:Close()
        onConfirm()
    end
end
