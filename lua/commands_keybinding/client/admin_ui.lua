-- ═══════════════════════════════════════════════════════
--  CKB — Client: admin panel UI
-- ═══════════════════════════════════════════════════════

local THEME = CKB.THEME

-- ── Net send helpers ──────────────────────────────────

function CKB.SendAdminGetPlayers()
    net.Start("CKB_AdminGetPlayers")
    net.SendToServer()
end

function CKB.SendAdminGetBinds(steamId)
    net.Start("CKB_AdminGetBinds")
    net.WriteString(steamId)
    net.SendToServer()
end

function CKB.SendAdminUpdateBind(targetSteamId, profileId, command, key, argument)
    net.Start("CKB_AdminUpdateBind")
    net.WriteString(targetSteamId)
    net.WriteString(profileId)
    net.WriteString(command)
    net.WriteInt(key, 32)
    net.WriteString(argument or "")
    net.SendToServer()
end

function CKB.SendAdminToggleSharing(steamId, enabled)
    net.Start("CKB_AdminToggleSharing")
    net.WriteString(steamId)
    net.WriteBool(enabled)
    net.SendToServer()
end

-- ── State for the admin panel ─────────────────────────

CKB.AdminViewData = nil

-- ── Open admin panel ──────────────────────────────────

function CKB.OpenAdminPanel()
    if IsValid(CKB.AdminFrame) then
        CKB.AdminFrame:MakePopup()
        return
    end

    local frame = vgui.Create("DFrame")
    CKB.AdminFrame = frame
    frame:SetSize(750, 500)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame:SetSizable(true)
    frame:SetMinWidth(600)
    frame:SetMinHeight(400)
    CKB.StyleFrame(frame, "CKB — Admin Panel")

    frame.OnClose = function()
        CKB.AdminFrame = nil
        CKB.AdminViewData = nil
    end

    -- Left: player list
    local leftPanel = vgui.Create("DPanel", frame)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(300)
    leftPanel:DockMargin(8, 8, 0, 8)
    leftPanel:DockPadding(0, 0, 0, 0)
    leftPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, THEME.bgLight)
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local leftHeader = vgui.Create("DLabel", leftPanel)
    leftHeader:Dock(TOP)
    leftHeader:SetTall(24)
    leftHeader:DockMargin(8, 4, 8, 0)
    leftHeader:SetText("Online Players")
    leftHeader:SetFont("DermaDefaultBold")
    leftHeader:SetTextColor(THEME.textBright)

    local playerList = vgui.Create("DListView", leftPanel)
    playerList:Dock(FILL)
    playerList:DockMargin(4, 4, 4, 4)
    playerList:SetMultiSelect(false)
    CKB.StyleListView(playerList)
    playerList:AddColumn("Player"):SetFixedWidth(120)
    playerList:AddColumn("Profiles")
    playerList:AddColumn("Active")
    playerList:AddColumn("Sharing")

    local btnRefresh = vgui.Create("DButton", leftPanel)
    btnRefresh:Dock(BOTTOM)
    btnRefresh:SetTall(28)
    btnRefresh:DockMargin(4, 0, 4, 4)
    btnRefresh:SetText("Refresh")
    CKB.StyleButton(btnRefresh)

    -- Right: selected player's binds
    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:Dock(FILL)
    rightPanel:DockMargin(8, 8, 8, 8)
    rightPanel:DockPadding(0, 0, 0, 0)
    rightPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, THEME.bgLight)
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local rightHeader = vgui.Create("DLabel", rightPanel)
    rightHeader:Dock(TOP)
    rightHeader:SetTall(24)
    rightHeader:DockMargin(8, 4, 8, 0)
    rightHeader:SetText("Select a player to view their keybinds")
    rightHeader:SetFont("DermaDefaultBold")
    rightHeader:SetTextColor(THEME.textDim)

    -- Profile selector for the viewed player
    local profileCombo = vgui.Create("DComboBox", rightPanel)
    profileCombo:Dock(TOP)
    profileCombo:SetTall(26)
    profileCombo:DockMargin(8, 4, 8, 0)
    profileCombo:SetFont("DermaDefault")
    profileCombo:SetTextColor(THEME.textBright)
    profileCombo:SetSortItems(false)
    profileCombo:SetVisible(false)
    profileCombo:SetContentAlignment(4)
    profileCombo:SetTextInset(6, 0)

    profileCombo.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.border)
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, THEME.bgInput)
        draw.SimpleText("\226\150\188", "DermaDefault", w - 14, h / 2, THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local bindList = vgui.Create("DListView", rightPanel)
    bindList:Dock(FILL)
    bindList:DockMargin(4, 4, 4, 4)
    bindList:SetMultiSelect(false)
    CKB.StyleListView(bindList)
    bindList:AddColumn("Command"):SetFixedWidth(180)
    bindList:AddColumn("Argument"):SetFixedWidth(140)
    bindList:AddColumn("Key")

    -- State
    local viewedSteamId = nil
    local viewedProfileId = nil

    -- ── Populate bind list for a profile ──────────────

    local function showProfileBinds(profileId)
        bindList:Clear()
        viewedProfileId = profileId
        if not CKB.AdminViewData or not CKB.AdminViewData.profiles then return end

        local profile = CKB.AdminViewData.profiles[profileId]
        if not profile then return end

        for command, bind in SortedPairs(profile.binds) do
            local displayCmd = string.gsub(command, "%d*$", "")
            local keyName = input.GetKeyName(bind.key) or "?"
            local line = bindList:AddLine(displayCmd, bind.argument or "", keyName)
            line._ckbCommand = command
            line._ckbKey = bind.key
            line._ckbArgument = bind.argument or ""
        end
    end

    -- ── Right-click to edit/delete a player's bind ────

    bindList.OnRowRightClick = function(_, _, line)
        if not viewedSteamId or not viewedProfileId then return end

        local menu = DermaMenu()
        menu:AddOption("Edit", function()
            CKB.OpenAdminEditBind(viewedSteamId, viewedProfileId, line._ckbCommand, line._ckbKey, line._ckbArgument)
        end):SetIcon("icon16/pencil.png")
        menu:AddSpacer()
        menu:AddOption("Delete", function()
            CKB.SendAdminUpdateBind(viewedSteamId, viewedProfileId, line._ckbCommand, 0, "")
        end):SetIcon("icon16/cross.png")
        menu:Open()
    end

    bindList.DoDoubleClick = function(_, _, line)
        if not viewedSteamId or not viewedProfileId then return end
        CKB.OpenAdminEditBind(viewedSteamId, viewedProfileId, line._ckbCommand, line._ckbKey, line._ckbArgument)
    end

    -- ── Profile combo change ──────────────────────────

    profileCombo.OnSelect = function(_, _, _, data)
        if data then showProfileBinds(data) end
    end

    -- ── Receive player list ───────────────────────────

    local myRankLevel = 1

    net.Receive("CKB_AdminPlayerList", function()
        local count = net.ReadUInt(16)
        playerList:Clear()
        for i = 1, count do
            local nick = net.ReadString()
            local steamId = net.ReadString()
            local profileCount = net.ReadUInt(16)
            local activeProfile = net.ReadString()
            local sharingAllowed = net.ReadBool()
            local rankLevel = net.ReadUInt(8)
            local line = playerList:AddLine(nick, profileCount, activeProfile, sharingAllowed and "\226\156\147" or "\226\156\151")
            line._steamId = steamId
            line._sharingAllowed = sharingAllowed
            line._rankLevel = rankLevel
        end
        myRankLevel = net.ReadUInt(8)
    end)

    playerList.OnRowRightClick = function(_, _, line)
        if not line._steamId then return end
        local menu = DermaMenu()

        -- Only show sharing toggle for strictly lower-rank players
        if line._rankLevel < myRankLevel then
            local newState = not line._sharingAllowed
            menu:AddOption(newState and "Enable Sharing" or "Disable Sharing", function()
                CKB.SendAdminToggleSharing(line._steamId, newState)
                timer.Simple(0.3, function() CKB.SendAdminGetPlayers() end)
            end):SetIcon(newState and "icon16/accept.png" or "icon16/cancel.png")
        end

        menu:Open()
    end

    -- ── Receive a player's full data ──────────────────

    net.Receive("CKB_AdminBindsData", function()
        local steamId = net.ReadString()
        local nick = net.ReadString()
        local activeProfileId = net.ReadString()
        local profileCount = net.ReadUInt(16)

        local profiles = {}
        for i = 1, profileCount do
            local pid = net.ReadString()
            local pname = net.ReadString()
            local bindCount = net.ReadUInt(16)
            local binds = {}
            for j = 1, bindCount do
                local cmd = net.ReadString()
                local key = net.ReadInt(32)
                local arg = net.ReadString()
                binds[cmd] = { key = key, argument = arg }
            end
            profiles[pid] = { name = pname, binds = binds }
        end

        CKB.AdminViewData = {
            steamId = steamId,
            nick = nick,
            activeProfile = activeProfileId,
            profiles = profiles,
        }

        viewedSteamId = steamId
        rightHeader:SetText("Keybinds — " .. nick)
        rightHeader:SetTextColor(THEME.textBright)

        profileCombo:Clear()
        profileCombo:SetVisible(true)

        local firstId = nil
        for pid, profile in SortedPairsByMemberValue(profiles, "name") do
            local display = profile.name
            if pid == activeProfileId then
                display = display .. " (active)"
            end
            profileCombo:AddChoice(display, pid, pid == activeProfileId)
            if not firstId then firstId = pid end
        end

        showProfileBinds(activeProfileId or firstId)
    end)

    -- ── Click player → load their data ────────────────

    playerList.OnRowSelected = function(_, _, line)
        if line._steamId then
            CKB.SendAdminGetBinds(line._steamId)
        end
    end

    -- ── Refresh button ────────────────────────────────

    btnRefresh.DoClick = function()
        CKB.SendAdminGetPlayers()
    end

    -- Auto-load on open
    CKB.SendAdminGetPlayers()
end

-- ── Admin edit bind popup ─────────────────────────────

function CKB.OpenAdminEditBind(targetSteamId, profileId, existingCommand, existingKey, existingArgument)
    local editFrame = vgui.Create("DFrame")
    editFrame:SetSize(450, 250)
    editFrame:Center()
    editFrame:MakePopup()
    editFrame:SetDeleteOnClose(true)
    CKB.StyleFrame(editFrame, "Admin — Edit Keybind")

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
    saveBtn:SetTall(32)
    saveBtn:DockMargin(80, 8, 80, 0)
    saveBtn:SetText("Save")
    CKB.StyleButton(saveBtn, true)

    saveBtn.DoClick = function()
        local cmd = cmdEntry:GetValue()
        local key = keyBinder:GetValue()
        local argument = argEntry:GetValue()

        if not CKB.IsValidCommand(cmd) then return end
        if not key or key == 0 then return end

        -- Delete old bind if command changed
        if cmd ~= existingCommand then
            CKB.SendAdminUpdateBind(targetSteamId, profileId, existingCommand, 0, "")
        end

        CKB.SendAdminUpdateBind(targetSteamId, profileId, cmd, key, argument)
        editFrame:Close()
    end
end
