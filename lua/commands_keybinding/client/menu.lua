local THEME = CKB.THEME

function CKB.OpenConfigMenu()
    if IsValid(CKB.Frame) then
        CKB.Frame:MakePopup()
        return
    end

    local frame = vgui.Create("DFrame")
    CKB.Frame = frame
    frame:SetSize(650, 530)
    frame:Center()
    frame:MakePopup()
    frame:SetSizable(true)
    frame:SetMinWidth(500)
    frame:SetMinHeight(400)
    frame:SetDeleteOnClose(true)
    CKB.StyleFrame(frame, CKB.L("title"))

    frame.OnClose = function()
        CKB.CloseSuggestions()
        CKB.Frame = nil
    end

    -- ── Profile selector bar ──────────────────────────

    local profileBar = CKB.CreateProfileBar(frame)

    function frame:RefreshProfiles()
        if IsValid(profileBar) and profileBar.RefreshProfiles then
            profileBar.RefreshProfiles()
        end
    end

    -- ── Admin button (visible only to admins) ─────────

    if LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin() then
        local adminBtn = vgui.Create("DButton", frame)
        adminBtn:Dock(TOP)
        adminBtn:SetTall(28)
        adminBtn:DockMargin(8, 4, 8, 0)
        adminBtn:SetText(CKB.L("admin_button"))
        CKB.StyleButton(adminBtn)
        adminBtn.DoClick = function()
            CKB.OpenAdminPanel()
        end
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
    cmdLabel:SetText(CKB.L("command_label"))
    CKB.StyleLabel(cmdLabel)

    local commandEntry = vgui.Create("DTextEntry", cmdRow)
    commandEntry:Dock(FILL)
    commandEntry:SetPlaceholderText(CKB.L("command_placeholder"))
    CKB.StyleTextEntry(commandEntry)

    -- Argument row
    local argRow = vgui.Create("DPanel", topPanel)
    argRow:Dock(TOP)
    argRow:SetTall(28)
    argRow:DockMargin(0, 0, 0, 5)
    argRow.Paint = function() end

    local argLabel = vgui.Create("DLabel", argRow)
    argLabel:Dock(LEFT)
    argLabel:SetWide(80)
    argLabel:SetText(CKB.L("argument_label"))
    CKB.StyleLabel(argLabel)

    local argumentEntry = vgui.Create("DTextEntry", argRow)
    argumentEntry:Dock(FILL)
    argumentEntry:SetPlaceholderText(CKB.L("argument_placeholder"))
    CKB.StyleTextEntry(argumentEntry)

    -- Key binder row
    local keyRow = vgui.Create("DPanel", topPanel)
    keyRow:Dock(TOP)
    keyRow:SetTall(35)
    keyRow:DockMargin(0, 0, 0, 5)
    keyRow.Paint = function() end

    local keyLabel = vgui.Create("DLabel", keyRow)
    keyLabel:Dock(LEFT)
    keyLabel:SetWide(80)
    keyLabel:SetText(CKB.L("keybind_label"))
    CKB.StyleLabel(keyLabel)

    local keyBinder = vgui.Create("DBinder", keyRow)
    keyBinder:Dock(FILL)
    CKB.StyleBinder(keyBinder)

    -- Save button
    local saveButton = vgui.Create("DButton", topPanel)
    saveButton:Dock(TOP)
    saveButton:SetTall(32)
    saveButton:DockMargin(100, 4, 100, 0)
    saveButton:SetText(CKB.L("save_keybind"))
    saveButton:SetEnabled(false)
    CKB.StyleButton(saveButton, true)

    -- ── Suggestions logic ─────────────────────────────

    local debounceTimer = "CKB_Debounce"

    commandEntry.OnChange = function(self)
        timer.Remove(debounceTimer)
        local cmd = self:GetValue()

        CKB.CloseSuggestions()

        if not self:IsEditing() or cmd == "" then
            setStatus(nil)
            saveButton:SetEnabled(false)
            return
        end

        if CKB.IsValidCommand(cmd) and keyBinder:GetValue() ~= 0 then
            saveButton:SetEnabled(true)
        else
            saveButton:SetEnabled(false)
        end

        if not CKB.IsValidCommand(cmd) then
            setStatus(CKB.L("invalid_chars"))
            return
        end

        if CKB.IsConCommandBlocked(cmd) then
            setStatus(CKB.L("command_blocked"))
            self:SetText("")
            saveButton:SetEnabled(false)
            return
        end

        setStatus(nil)

        timer.Create(debounceTimer, 0.15, 1, function()
            if not IsValid(self) or not IsValid(frame) then return end
            local suggestions = CKB.GetCommandSuggestions(self:GetValue())
            if #suggestions > 0 and self:IsEditing() then
                CKB.ShowSuggestions(frame, self, suggestions)
            end
        end)
    end

    keyBinder.OnChange = function(self, key)
        if key and key ~= 0 and CKB.IsValidCommand(commandEntry:GetValue()) then
            saveButton:SetEnabled(true)
        end
    end

    -- ── Save logic ────────────────────────────────────

    saveButton.DoClick = function()
        local cmd = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        local argument = argumentEntry:GetValue()

        if not CKB.IsValidCommand(cmd) then
            setStatus(CKB.L("enter_valid_command"))
            return
        end
        if CKB.IsConCommandBlocked(cmd) then
            setStatus(CKB.L("command_blocked"))
            return
        end
        if not key or key == 0 then
            setStatus(CKB.L("select_key"))
            return
        end

        local warnings = {}

        for existingCmd, data in pairs(CKB.KeyBinds) do
            if data.key == key and existingCmd ~= cmd then
                table.insert(warnings, CKB.L("warn_overwrite", input.GetKeyName(key), existingCmd))
                break
            end
        end

        local engineBind = CKB.GetEngineBind(key)
        if engineBind then
            table.insert(warnings, CKB.L("warn_engine", input.GetKeyName(key), engineBind))
        end

        local function doSave()
            -- The server clears any other command bound to this key, so a
            -- single message is enough even when overwriting a conflict.
            CKB.SendUpdate(cmd, key, argument)
            commandEntry:SetText("")
            argumentEntry:SetText("")
            keyBinder:SetValue(0)
            saveButton:SetEnabled(false)
            setStatus(nil)
        end

        if #warnings > 0 then
            CKB.ShowSaveConfirmation(warnings, doSave)
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
    searchEntry:SetPlaceholderText(CKB.L("search_placeholder"))
    CKB.StyleTextEntry(searchEntry)

    -- List
    local listView = vgui.Create("DListView", bottomPanel)
    listView:Dock(FILL)
    listView:SetMultiSelect(false)
    CKB.StyleListView(listView)
    listView:AddColumn(CKB.L("col_command")):SetFixedWidth(200)
    listView:AddColumn(CKB.L("col_argument")):SetFixedWidth(150)
    listView:AddColumn(CKB.L("col_key"))

    -- ── Refresh function ──────────────────────────────

    function frame:RefreshList(filter)
        listView:Clear()
        filter = filter and string.lower(filter) or nil

        for command, data in SortedPairs(CKB.KeyBinds) do
            if type(data) == "table" then
                local displayCommand = command
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
        menu:AddOption(CKB.L("edit"), function()
            CKB.OpenEditPopup(line._ckbKey, line._ckbCommand, line._ckbArgument)
        end):SetIcon("icon16/pencil.png")
        menu:AddSpacer()
        menu:AddOption(CKB.L("delete"), function()
            CKB.SendUpdate(line._ckbCommand, 0, "")
        end):SetIcon("icon16/cross.png")
        menu:Open()
    end

    listView.DoDoubleClick = function(_, _, line)
        CKB.OpenEditPopup(line._ckbKey, line._ckbCommand, line._ckbArgument)
    end

    frame:RefreshList()
end

concommand.Add("open_commands_keybinding", CKB.OpenConfigMenu)
