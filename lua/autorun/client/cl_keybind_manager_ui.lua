-- cl_keybind_manager_ui.lua

function CreateNotificationFrame()
    local notifyFrame = vgui.Create("DFrame")
    notifyFrame:SetTitle(KeyBindManager.GetPhrase("xpgui_not_installed"))
    notifyFrame:SetSize(400, 200)
    notifyFrame:Center()
    notifyFrame:MakePopup()
    surface.PlaySound("buttons/button10.wav")

    local icon = vgui.Create("DImage", notifyFrame)
    icon:SetImage("icon16/error.png")
    icon:SetPos(10, 30)

    local label = vgui.Create("DLabel", notifyFrame)
    label:SetText(KeyBindManager.GetPhrase("xpgui_error_message"))
    label:SizeToContents()
    label:SetPos(50, 40)

    local link = vgui.Create("DLabelURL", notifyFrame)
    link:SetText(KeyBindManager.GetPhrase("link_to_addon"))
    link:SizeToContents()
    link:SetWide(300)
    link:SetPos(50, 60)

    local closeButton = vgui.Create("DButton", notifyFrame)
    closeButton:SetText(KeyBindManager.GetPhrase("close"))
    closeButton:SetSize(100, 30)
    closeButton:SetPos(150, 150)
    closeButton.DoClick = function()
        notifyFrame:Close()
    end

    return notifyFrame
end

function CreateErrorFrame(message)
    local errorFrame = vgui.Create("XPFrame")
    errorFrame:SetTitle(KeyBindManager.GetPhrase("error"))
    errorFrame:SetSize(300, 100)
    errorFrame:Center()
    errorFrame:MakePopup()

    local errorLabel = vgui.Create("DLabel", errorFrame)
    errorLabel:SetText(message)
    errorLabel:Dock(FILL)
    errorLabel:SetContentAlignment(5)
    errorLabel:SetTextColor(Color(255, 0, 0))

    surface.PlaySound("common/warning.wav")

    if IsValid(Frame) then
        Frame:SetMouseInputEnabled(false)
        Frame:SetKeyboardInputEnabled(false)
    end

    errorFrame.OnClose = function()
        if IsValid(Frame) then
            Frame:SetMouseInputEnabled(true)
            Frame:SetKeyboardInputEnabled(true)
        end
    end

    return errorFrame
end

function ShowOverwriteConfirmation(Command, keyInfo, existingCommand)
    local confirmFrame = vgui.Create("XPFrame")
    confirmFrame:SetTitle(KeyBindManager.GetPhrase("overwrite_keybind_title"))
    confirmFrame:SetSize(300, 150)
    confirmFrame:Center()
    confirmFrame:MakePopup()

    local confirmLabel = vgui.Create("DLabel", confirmFrame)
    confirmLabel:SetText(KeyBindManager.GetPhrase("overwrite_keybind_text"))
    confirmLabel:SetWrap(true)
    confirmLabel:SetContentAlignment(5)
    confirmLabel:SetPos(10, 30)
    confirmLabel:SetSize(280, 40)

    local confirmButton = vgui.Create("XPButton", confirmFrame)
    confirmButton:SetText(KeyBindManager.GetPhrase("yes"))
    confirmButton:SetPos(50, 80)
    confirmButton:SetSize(80, 30)

    local cancelButton = vgui.Create("XPButton", confirmFrame)
    cancelButton:SetText(KeyBindManager.GetPhrase("no"))
    cancelButton:SetPos(170, 80)
    cancelButton:SetSize(80, 30)

    confirmButton.DoClick = function()
        if existingCommand and Command then
            net.Start("CommandsKeyBinding_Update")
            net.WriteBool(false)
            net.WriteString(existingCommand)
            net.WriteInt(0, 32)
            net.WriteString("")
            net.WriteBool(false)
            net.WriteBool(false)
            net.SendToServer()

            net.Start("CommandsKeyBinding_Update")
            net.WriteBool(false)
            net.WriteString(Command)
            net.WriteInt(keyInfo.key, 32)
            net.WriteString(keyInfo.argument or "")
            net.WriteBool(keyInfo.ctrl or false)
            net.WriteBool(keyInfo.alt or false)
            net.SendToServer()

            confirmFrame:Close()
        end
    end

    cancelButton.DoClick = function()
        confirmFrame:Close()
    end
end

function CreateMainFrame()
    local Frame = vgui.Create("XPFrame")
    Frame:SetTitle(KeyBindManager.GetPhrase("keybind_manager"))
    Frame:SetSize(800, 600)
    Frame:Center()
    Frame:MakePopup()

    local tabPanel = vgui.Create("DPropertySheet", Frame)
    tabPanel:Dock(FILL)
    tabPanel:DockMargin(5, 5, 5, 5)

    local bindingsPanel = vgui.Create("DPanel", tabPanel)
    bindingsPanel:Dock(FILL)
    bindingsPanel.Paint = function() end
    tabPanel:AddSheet(KeyBindManager.GetPhrase("keybindings"), bindingsPanel, "icon16/keyboard.png")

    local settingsPanel = vgui.Create("DPanel", tabPanel)
    settingsPanel:Dock(FILL)
    settingsPanel.Paint = function() end
    tabPanel:AddSheet(KeyBindManager.GetPhrase("settings"), settingsPanel, "icon16/cog.png")

    if IsAdmin then
        local adminPanel = vgui.Create("DPanel", tabPanel)
        adminPanel:Dock(FILL)
        adminPanel.Paint = function() end
        tabPanel:AddSheet(KeyBindManager.GetPhrase("administration"), adminPanel, "icon16/shield.png")

        CreateAdminInterface(adminPanel)
    end

    CreateToolbar(bindingsPanel)

    CreateKeyBindInterface(bindingsPanel)

    CreateSettingsInterface(settingsPanel)

    Frame.OnClose = function()
        Frame = nil
    end

    return Frame
end

function CreateToolbar(parent)
    local toolBar = vgui.Create("DPanel", parent)
    toolBar:SetSize(parent:GetWide(), 30)
    toolBar:Dock(TOP)
    toolBar:DockMargin(0, 0, 0, 5)
    toolBar:SetPaintBackground(true)
    toolBar:SetBackgroundColor(Color(50, 50, 50))

    local importButton = vgui.Create("XPButton", toolBar)
    importButton:SetText(KeyBindManager.GetPhrase("import"))
    importButton:SetPos(5, 3)
    importButton:SetSize(90, 24)
    importButton.DoClick = function() ImportKeyBinds() end

    local exportButton = vgui.Create("XPButton", toolBar)
    exportButton:SetText(KeyBindManager.GetPhrase("export"))
    exportButton:SetPos(100, 3)
    exportButton:SetSize(90, 24)
    exportButton.DoClick = function() ExportKeyBinds() end

    local bindTypeLabel = vgui.Create("DLabel", toolBar)
    bindTypeLabel:SetPos(200, 7)
    bindTypeLabel:SetText(KeyBindManager.GetPhrase("mode"))
    bindTypeLabel:SizeToContents()

    local bindType = vgui.Create("DComboBox", toolBar)
    bindType:SetPos(240, 3)
    bindType:SetSize(150, 24)
    bindType:AddChoice(KeyBindManager.GetPhrase("personal"), "personal")
    bindType:AddChoice(KeyBindManager.GetPhrase("global_keybinds") .. " (Admin)", "global")
    bindType:SetValue(KeyBindManager.GetPhrase("personal"))
    bindType.OnSelect = function(_, _, _, data)
        IsEditingGlobal = (data == "global")
        ShowNotification(
            KeyBindManager.GetPhrase("edit_mode",
                IsEditingGlobal and KeyBindManager.GetPhrase("global_keybinds") or
                KeyBindManager.GetPhrase("personal_keybinds")),
            Color(0, 200, 255))
    end

    if not IsAdmin then
        bindType:SetEnabled(false)
    end

    local searchBox = vgui.Create("XPTextEntry", toolBar)
    searchBox:SetPos(parent:GetWide() - 205, 3)
    searchBox:SetSize(200, 24)
    searchBox:SetPlaceholderText(KeyBindManager.GetPhrase("search"))
    searchBox.OnChange = function() FilterKeyBindList(searchBox:GetValue()) end

    return toolBar
end

function CreateKeyBindInterface(parent)
    local controlPanel = vgui.Create("DPanel", parent)
    controlPanel:SetSize(parent:GetWide(), 190)
    controlPanel:Dock(TOP)
    controlPanel:DockMargin(5, 5, 5, 5)
    controlPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 150))
    end

    local commandLabel = vgui.Create("DLabel", controlPanel)
    commandLabel:SetText(KeyBindManager.GetPhrase("Command"))
    commandLabel:SetPos(10, 15)
    commandLabel:SizeToContents()

    local commandEntry = vgui.Create("XPTextEntry", controlPanel)
    commandEntry:SetPos(100, 10)
    commandEntry:SetSize(controlPanel:GetWide() - 110, 25)

    local argumentLabel = vgui.Create("DLabel", controlPanel)
    argumentLabel:SetText(KeyBindManager.GetPhrase("argument"))
    argumentLabel:SetPos(10, 45)
    argumentLabel:SizeToContents()

    local argumentEntry = vgui.Create("XPTextEntry", controlPanel)
    argumentEntry:SetPos(100, 40)
    argumentEntry:SetSize(controlPanel:GetWide() - 110, 25)

    local keyBinderLabel = vgui.Create("DLabel", controlPanel)
    keyBinderLabel:SetText(KeyBindManager.GetPhrase("key"))
    keyBinderLabel:SetPos(10, 75)
    keyBinderLabel:SizeToContents()

    local keyBinder = vgui.Create("DBinder", controlPanel)
    keyBinder:SetPos(100, 70)
    keyBinder:SetSize(controlPanel:GetWide() - 220, 30)

    local ctrlCheck = vgui.Create("DCheckBoxLabel", controlPanel)
    ctrlCheck:SetText(KeyBindManager.GetPhrase("ctrl"))
    ctrlCheck:SetPos(controlPanel:GetWide() - 110, 70)
    ctrlCheck:SetValue(false)

    local altCheck = vgui.Create("DCheckBoxLabel", controlPanel)
    altCheck:SetText(KeyBindManager.GetPhrase("alt"))
    altCheck:SetPos(controlPanel:GetWide() - 110, 95)
    altCheck:SetValue(false)

    local statusPanel = vgui.Create("DPanel", controlPanel)
    statusPanel:SetPos(10, 105)
    statusPanel:SetSize(controlPanel:GetWide() - 20, 25)
    statusPanel:SetBackgroundColor(Color(255, 0, 0))
    statusPanel:SetVisible(false)

    local statusLabel = vgui.Create("DLabel", statusPanel)
    statusLabel:Dock(FILL)
    statusLabel:SetTextColor(Color(255, 255, 255))
    statusLabel:SetText("")
    statusLabel:SetContentAlignment(5)

    local saveButton = vgui.Create("XPButton", controlPanel)
    saveButton:SetText(KeyBindManager.GetPhrase("save"))
    saveButton:SetPos((controlPanel:GetWide() - 100) / 2, 135)
    saveButton:SetSize(100, 30)
    saveButton:SetEnabled(false)

    KeyBinderClicked = false

    function UpdateSaveButtonState()
        Command = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        if KeyBinderClicked and IsValidCommand(Command) then
            saveButton:SetEnabled(true)
        else
            saveButton:SetEnabled(false)
        end
    end

    commandEntry.OnChange = function()
        local Command = commandEntry:GetValue()

        if IsValid(parent.SuggestionsList) then
            parent.SuggestionsList:Remove()
        end

        if not commandEntry:IsEditing() or Command == "" then
            statusPanel:SetVisible(false)
            UpdateSaveButtonState()
            return
        end

        local suggestions = GetCommandSuggestions(Command)
        if #suggestions > 0 then
            parent.SuggestionsList = vgui.Create("XPListView", controlPanel)
            parent.SuggestionsList:SetPos(100, 35)
            parent.SuggestionsList:SetSize(controlPanel:GetWide() - 110, 150)
            parent.SuggestionsList:AddColumn("Suggestions")
            for _, suggestion in ipairs(suggestions) do
                parent.SuggestionsList:AddLine(suggestion)
            end
            parent.SuggestionsList.OnRowSelected = function(_, _, line)
                local selectedCommand = line:GetColumnText(1)
                if not IsConCommandBlocked(selectedCommand) then
                    commandEntry:SetText(selectedCommand)
                else
                    commandEntry:SetText("")
                    CreateErrorFrame("Cette commande est sur liste noire.")
                end
                parent.SuggestionsList:Remove()
            end
        end

        if IsValidCommand(Command) then
            if IsConCommandBlocked(Command) then
                if IsValid(parent.SuggestionsList) then
                    parent.SuggestionsList:Remove()
                end
                CreateErrorFrame(KeyBindManager.GetPhrase("blacklisted_command"))
                commandEntry:SetText("")
                statusPanel:SetVisible(false)
                UpdateSaveButtonState()
            else
                statusPanel:SetVisible(false)
                UpdateSaveButtonState()
            end
        else
            statusLabel:SetText(KeyBindManager.GetPhrase("invalid_command"))
            statusPanel:SetVisible(true)
            statusPanel:MoveToFront()
            UpdateSaveButtonState()
        end
    end

    keyBinder.OnChange = function()
        KeyBinderClicked = true
        UpdateSaveButtonState()
    end

    saveButton.DoClick = function()
        Command = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        local argument = argumentEntry:GetValue()
        local useCtrl = ctrlCheck:GetChecked()
        local useAlt = altCheck:GetChecked()

        if Command and key and IsValidCommand(Command) then
            local keyInfo = {
                key = key,
                argument = argument,
                ctrl = useCtrl,
                alt = useAlt
            }

            for existingCommand, existingData in pairs(ActiveKeyBinds) do
                if existingData.key == key and
                    existingData.ctrl == useCtrl and
                    existingData.alt == useAlt and
                    existingCommand ~= Command then
                    ShowOverwriteConfirmation(Command, keyInfo, existingCommand)
                    return
                end
            end

            net.Start("CommandsKeyBinding_Update")
            net.WriteBool(IsEditingGlobal or false)
            net.WriteString(Command)
            net.WriteInt(key, 32)
            net.WriteString(argument or "")
            net.WriteBool(useCtrl)
            net.WriteBool(useAlt)
            net.SendToServer()
            ShowNotification(KeyBindManager.GetPhrase("keybind_saved"), Color(0, 255, 0))
        else
            ShowNotification(KeyBindManager.GetPhrase("select_command_key"), Color(255, 0, 0))
        end
    end

    local bindList = vgui.Create("XPListView", parent)
    bindList:Dock(FILL)
    bindList:DockMargin(5, 0, 5, 5)
    bindList:AddColumn(KeyBindManager.GetPhrase("Command"))
    bindList:AddColumn(KeyBindManager.GetPhrase("argument"))
    bindList:AddColumn(KeyBindManager.GetPhrase("key"))
    bindList:AddColumn(KeyBindManager.GetPhrase("modifiers"))
    bindList:AddColumn(KeyBindManager.GetPhrase("type"))

    parent.keyBindList = bindList

    bindList.OnRowRightClick = function(_, _, line)
        local menu = vgui.Create("XPMenu")
        menu:AddOption(KeyBindManager.GetPhrase("delete"), function()
            local cmd = line.Command
            local isGlobal = line.isGlobal

            net.Start("CommandsKeyBinding_Update")
            net.WriteBool(isGlobal)
            net.WriteString(cmd)
            net.WriteInt(0, 32)
            net.WriteString("")
            net.WriteBool(false)
            net.WriteBool(false)
            net.SendToServer()

            ShowNotification(KeyBindManager.GetPhrase("keybind_deleted"), Color(0, 255, 0))
        end)
        menu:AddOption(KeyBindManager.GetPhrase("edit"), function()
            commandEntry:SetText(line.Command)
            argumentEntry:SetText(line.argument or "")
            keyBinder:SetValue(line.key)
            ctrlCheck:SetValue(line.ctrl or false)
            altCheck:SetValue(line.alt or false)
            IsEditingGlobal = line.isGlobal
            KeyBinderClicked = true
            UpdateSaveButtonState()
        end)
        menu:Open()
    end

    return controlPanel, bindList
end

function CreateSettingsInterface(parent)
    local settingsForm = vgui.Create("DForm", parent)
    settingsForm:Dock(FILL)
    settingsForm:DockMargin(10, 10, 10, 10)
    settingsForm:SetLabel(KeyBindManager.GetPhrase("user_settings"))

    local useGlobalCheck = vgui.Create("DCheckBoxLabel")
    useGlobalCheck:SetText(KeyBindManager.GetPhrase("use_global_binds"))
    useGlobalCheck:SetValue(UseGlobalBinds)
    useGlobalCheck.OnChange = function(_, value)
        UseGlobalBinds = value

        net.Start("CommandsKeyBinding_ProfileSwitch")
        net.WriteBool(value)
        net.SendToServer()

        RefreshActiveKeyBinds()
        RefreshKeyBindList()
    end

    settingsForm:AddItem(useGlobalCheck)

    local clearCacheButton = vgui.Create("XPButton")
    clearCacheButton:SetText(KeyBindManager.GetPhrase("clear_suggestions_cache"))
    clearCacheButton.DoClick = function()
        ClearCommandSuggestionsCache()
        ShowNotification(KeyBindManager.GetPhrase("cache_cleared"), Color(0, 200, 0))
    end

    settingsForm:AddItem(clearCacheButton)

    return settingsForm
end

function CreateAdminInterface(parent)
    local adminForm = vgui.Create("DForm", parent)
    adminForm:Dock(FILL)
    adminForm:DockMargin(10, 10, 10, 10)
    adminForm:SetLabel(KeyBindManager.GetPhrase("profile_management"))

    local profileList = vgui.Create("XPListView")
    profileList:SetSize(0, 300)
    profileList:AddColumn(KeyBindManager.GetPhrase("user"))
    profileList:AddColumn(KeyBindManager.GetPhrase("keybinds"))
    profileList:AddColumn(KeyBindManager.GetPhrase("uses_global_keybinds"))
    profileList:AddColumn(KeyBindManager.GetPhrase("last_update"))

    adminForm:AddItem(profileList)

    local refreshButton = vgui.Create("XPButton")
    refreshButton:SetText(KeyBindManager.GetPhrase("refresh_list"))
    refreshButton.DoClick = function()
        net.Start("CommandsKeyBinding_ProfileList")
        net.SendToServer()
    end

    adminForm:AddItem(refreshButton)

    net.Receive("CommandsKeyBinding_AdminSync", function()
        local profileData = net.ReadTable()

        profileList:Clear()

        for steamID, data in pairs(profileData) do
            local useGlobal = data.UseGlobalBinds and "Oui" or "Non"
            local lastUpdate = os.date("%d/%m/%Y %H:%M", data.lastUpdate)
            profileList:AddLine(steamID, data.bindCount, useGlobal, lastUpdate)
        end
    end)

    timer.Simple(0.5, function()
        net.Start("CommandsKeyBinding_ProfileList")
        net.SendToServer()
    end)

    return adminForm
end

function RefreshKeyBindList()
    if not IsValid(Frame) or not IsValid(Frame.keyBindList) then return end

    Frame.keyBindList:Clear()

    if UseGlobalBinds then
        for Command, data in pairs(GlobalKeyBinds) do
            if type(data) == "table" then
                local modifiers = ""
                if data.ctrl then modifiers = modifiers .. "Ctrl+" end
                if data.alt then modifiers = modifiers .. "Alt+" end

                local line = Frame.keyBindList:AddLine(
                    Command,
                    data.argument or "",
                    input.GetKeyName(data.key),
                    modifiers,
                    "Global"
                )
                line.key = data.key
                line.Command = Command
                line.argument = data.argument
                line.ctrl = data.ctrl
                line.alt = data.alt
                line.isGlobal = true
            end
        end
    end

    for Command, data in pairs(PersonalKeyBinds) do
        if type(data) == "table" then
            local modifiers = ""
            if data.ctrl then modifiers = modifiers .. "Ctrl+" end
            if data.alt then modifiers = modifiers .. "Alt+" end

            local line = Frame.keyBindList:AddLine(
                Command,
                data.argument or "",
                input.GetKeyName(data.key),
                modifiers,
                "Personnel"
            )
            line.key = data.key
            line.Command = Command
            line.argument = data.argument
            line.ctrl = data.ctrl
            line.alt = data.alt
            line.isGlobal = false
        end
    end
end

function FilterKeyBindList(filter)
    if not IsValid(Frame) or not IsValid(Frame.keyBindList) then return end

    for _, line in pairs(Frame.keyBindList:GetLines()) do
        Command = line:GetColumnText(1)
        local argument = line:GetColumnText(2)
        local key = line:GetColumnText(3)
        local modifiers = line:GetColumnText(4)
        local bindType = line:GetColumnText(5)

        if filter == "" then
            line:SetVisible(true)
        else
            filter = string.lower(filter)
            local visible = string.find(string.lower(Command), filter) or
                string.find(string.lower(argument or ""), filter) or
                string.find(string.lower(key or ""), filter) or
                string.find(string.lower(modifiers or ""), filter) or
                string.find(string.lower(bindType), filter)
            line:SetVisible(visible ~= nil)
        end
    end

    Frame.keyBindList:InvalidateLayout()
end
