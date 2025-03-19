-- Ensure the XPGUI library is included (It's Workshop Library Addon)
hook.Add("Initialize", "LoadXPGUI", function()
    if not XPGUI then
        include("xpgui.lua")
    end
end)

KeyBindManager = KeyBindManager or {}
KeyBindManager.Languages = KeyBindManager.Languages or {}
KeyBindManager.CurrentLanguage = GetConVar("gmod_language"):GetString() or "en"

local function LoadLanguages()
    local files, _ = file.Find("lua/autorun/client/languages/*.lua", "GAME")
    for _, f in ipairs(files) do
        include("languages/" .. f)
    end
end

function KeyBindManager.AddLanguage(code, name, phrases)
    KeyBindManager.Languages[code] = {
        name = name,
        phrases = phrases
    }

    if code == KeyBindManager.CurrentLanguage then
        KeyBindManager.ActivePhrases = phrases
    end
end

function KeyBindManager.GetPhrase(key, ...)
    if not KeyBindManager.ActivePhrases then
        KeyBindManager.ActivePhrases = (KeyBindManager.Languages[KeyBindManager.CurrentLanguage] or KeyBindManager.Languages["en"] or {})
            .phrases or {}
    end

    local phrase = KeyBindManager.ActivePhrases[key] or KeyBindManager.Languages["en"].phrases[key] or key
    return string.format(phrase, ...)
end

hook.Add("Initialize", "KeyBindManager_LoadLanguages", LoadLanguages)

local globalKeyBinds = {}
local personalKeyBinds = {}
local activeKeyBinds = {}
local keyPressStates = {}
local frame

local useGlobalBinds = true
local isAdmin = false

TypingInTextEntry = false
local keyBinderClicked = false

hook.Add("OnTextEntryGetFocus", "IsTyping", function()
    TypingInTextEntry = true
end)

hook.Add("OnTextEntryLoseFocus", "IsNotTyping", function()
    TypingInTextEntry = false
end)

net.Receive("CommandsKeyBinding_Config", function()
    local isGlobal = net.ReadBool()
    local bindData = net.ReadTable()

    if isGlobal then
        globalKeyBinds = bindData
    else
        personalKeyBinds = bindData
    end

    RefreshActiveKeyBinds()

    if IsValid(frame) then
        RefreshKeyBindList()
    end
end)

function RefreshActiveKeyBinds()
    activeKeyBinds = {}

    if useGlobalBinds then
        for cmd, data in pairs(globalKeyBinds) do
            activeKeyBinds[cmd] = data
        end
    end

    for cmd, data in pairs(personalKeyBinds) do
        activeKeyBinds[cmd] = data
    end
end

local function isValidCommand(cmd)
    return string.match(cmd, "^[%w%+%-_%*/!%s]+$") ~= nil and string.match(cmd, "%S")
end

local function showOverwriteConfirmation(command, keyInfo, existingCommand)
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
        if existingCommand and command then
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
            net.WriteString(command)
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

local CommandSuggestionsCache = {}
function ClearCommandSuggestionsCache()
    CommandSuggestionsCache = {}
end

local function GetCommandSuggestions(command)
    local cacheKey = command
    if CommandSuggestionsCache[cacheKey] then
        return CommandSuggestionsCache[cacheKey]
    end

    local results = {}
    local limit = 50
    local count = 0

    for _, cmd in ipairs(AllCommands) do
        if string.find(cmd, "^" .. command) then
            table.insert(results, cmd)
            count = count + 1
            if count >= limit then break end
        end
    end

    if count < limit then
        for _, cmd in ipairs(AllCommands) do
            if not string.find(cmd, "^" .. command) and string.find(cmd, command) then
                table.insert(results, cmd)
                count = count + 1
                if count >= limit then break end
            end
        end
    end

    CommandSuggestionsCache[cacheKey] = results
    return results
end

local function createNotificationFrame()
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
    -- link:SetUrl("https://steamcommunity.com/sharedfiles/filedetails/?id=244392122")
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

    if IsValid(frame) then
        frame:SetMouseInputEnabled(false)
        frame:SetKeyboardInputEnabled(false)
    end

    errorFrame.OnClose = function()
        if IsValid(frame) then
            frame:SetMouseInputEnabled(true)
            frame:SetKeyboardInputEnabled(true)
        end
    end

    return errorFrame
end

function CreateMainFrame()
    local frame = vgui.Create("XPFrame")
    frame:SetTitle(KeyBindManager.GetPhrase("keybind_manager"))
    frame:SetSize(800, 600)
    frame:Center()
    frame:MakePopup()

    local tabPanel = vgui.Create("DPropertySheet", frame)
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

    if isAdmin then
        local adminPanel = vgui.Create("DPanel", tabPanel)
        adminPanel:Dock(FILL)
        adminPanel.Paint = function() end
        tabPanel:AddSheet(KeyBindManager.GetPhrase("administration"), adminPanel, "icon16/shield.png")

        CreateAdminInterface(adminPanel)
    end

    CreateToolbar(bindingsPanel)

    CreateKeyBindInterface(bindingsPanel)

    CreateSettingsInterface(settingsPanel)

    frame.OnClose = function()
        frame = nil
    end

    return frame
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

    if not isAdmin then
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
    commandLabel:SetText(KeyBindManager.GetPhrase("command"))
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

    keyBinderClicked = false

    local function UpdateSaveButtonState()
        local command = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        if keyBinderClicked and isValidCommand(command) then
            saveButton:SetEnabled(true)
        else
            saveButton:SetEnabled(false)
        end
    end

    commandEntry.OnChange = function()
        local command = commandEntry:GetValue()

        if IsValid(parent.SuggestionsList) then
            parent.SuggestionsList:Remove()
        end

        if not commandEntry:IsEditing() or command == "" then
            statusPanel:SetVisible(false)
            UpdateSaveButtonState()
            return
        end

        local suggestions = GetCommandSuggestions(command)
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

        if isValidCommand(command) then
            if IsConCommandBlocked(command) then
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
        keyBinderClicked = true
        UpdateSaveButtonState()
    end

    saveButton.DoClick = function()
        local command = commandEntry:GetValue()
        local key = keyBinder:GetValue()
        local argument = argumentEntry:GetValue()
        local useCtrl = ctrlCheck:GetChecked()
        local useAlt = altCheck:GetChecked()

        if command and key and isValidCommand(command) then
            local keyInfo = {
                key = key,
                argument = argument,
                ctrl = useCtrl,
                alt = useAlt
            }

            for existingCommand, existingData in pairs(activeKeyBinds) do
                if existingData.key == key and
                    existingData.ctrl == useCtrl and
                    existingData.alt == useAlt and
                    existingCommand ~= command then
                    showOverwriteConfirmation(command, keyInfo, existingCommand)
                    return
                end
            end

            net.Start("CommandsKeyBinding_Update")
            net.WriteBool(IsEditingGlobal or false)
            net.WriteString(command)
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
    bindList:AddColumn(KeyBindManager.GetPhrase("command"))
    bindList:AddColumn(KeyBindManager.GetPhrase("argument"))
    bindList:AddColumn(KeyBindManager.GetPhrase("key"))
    bindList:AddColumn(KeyBindManager.GetPhrase("modifiers"))
    bindList:AddColumn(KeyBindManager.GetPhrase("type"))

    parent.keyBindList = bindList

    bindList.OnRowRightClick = function(_, _, line)
        local menu = vgui.Create("XPMenu")
        menu:AddOption(KeyBindManager.GetPhrase("delete"), function()
            local cmd = line.command
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
            commandEntry:SetText(line.command)
            argumentEntry:SetText(line.argument or "")
            keyBinder:SetValue(line.key)
            ctrlCheck:SetValue(line.ctrl or false)
            altCheck:SetValue(line.alt or false)
            IsEditingGlobal = line.isGlobal
            keyBinderClicked = true
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
    useGlobalCheck:SetValue(useGlobalBinds)
    useGlobalCheck.OnChange = function(_, value)
        useGlobalBinds = value

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
            local useGlobal = data.useGlobalBinds and "Oui" or "Non"
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
    if not IsValid(frame) or not IsValid(frame.keyBindList) then return end

    frame.keyBindList:Clear()

    if useGlobalBinds then
        for command, data in pairs(globalKeyBinds) do
            if type(data) == "table" then
                local modifiers = ""
                if data.ctrl then modifiers = modifiers .. "Ctrl+" end
                if data.alt then modifiers = modifiers .. "Alt+" end

                local line = frame.keyBindList:AddLine(
                    command,
                    data.argument or "",
                    input.GetKeyName(data.key),
                    modifiers,
                    "Global"
                )
                line.key = data.key
                line.command = command
                line.argument = data.argument
                line.ctrl = data.ctrl
                line.alt = data.alt
                line.isGlobal = true
            end
        end
    end

    for command, data in pairs(personalKeyBinds) do
        if type(data) == "table" then
            local modifiers = ""
            if data.ctrl then modifiers = modifiers .. "Ctrl+" end
            if data.alt then modifiers = modifiers .. "Alt+" end

            local line = frame.keyBindList:AddLine(
                command,
                data.argument or "",
                input.GetKeyName(data.key),
                modifiers,
                "Personnel"
            )
            line.key = data.key
            line.command = command
            line.argument = data.argument
            line.ctrl = data.ctrl
            line.alt = data.alt
            line.isGlobal = false
        end
    end
end

function FilterKeyBindList(filter)
    if not IsValid(frame) or not IsValid(frame.keyBindList) then return end

    for _, line in pairs(frame.keyBindList:GetLines()) do
        local command = line:GetColumnText(1)
        local argument = line:GetColumnText(2)
        local key = line:GetColumnText(3)
        local modifiers = line:GetColumnText(4)
        local bindType = line:GetColumnText(5)

        if filter == "" then
            line:SetVisible(true)
        else
            filter = string.lower(filter)
            local visible = string.find(string.lower(command), filter) or
                string.find(string.lower(argument or ""), filter) or
                string.find(string.lower(key or ""), filter) or
                string.find(string.lower(modifiers or ""), filter) or
                string.find(string.lower(bindType), filter)
            line:SetVisible(visible ~= nil)
        end
    end

    frame.keyBindList:InvalidateLayout()
end

local function openConfigMenu()
    if not XPGUI then
        createNotificationFrame()
        return
    end

    if IsValid(frame) then return end

    isAdmin = LocalPlayer():IsAdmin()

    net.Start("CommandsKeyBinding_Request")
    net.SendToServer()

    frame = CreateMainFrame()
end

concommand.Add("open_commands_keybinding", openConfigMenu)

if not XPGUI then
    hook.Add("Initialize", "OpenConfigMenuOnStart", function()
        timer.Simple(2, function()
            openConfigMenu()
        end)
    end)
end

hook.Add("Think", "CommandsKeyBinding_Think", function()
    if TypingInTextEntry or LocalPlayer():IsTyping() then return end

    local ctrlDown = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
    local altDown = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
    local shiftDown = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

    for command, data in pairs(activeKeyBinds) do
        local key = data.key
        local argument = data.argument
        local requiresCtrl = data.ctrl or false
        local requiresAlt = data.alt or false
        local requiresShift = data.shift or false

        if type(key) == "number" and input.IsKeyDown(key) and
            ctrlDown == requiresCtrl and altDown == requiresAlt and shiftDown == (requiresShift or false) then
            if not keyPressStates[command] then
                keyPressStates[command] = true

                local cleanCommand = string.gsub(command, "%d*$", "")

                if argument and argument ~= "" then
                    if string.find(argument, "%s") then
                        local args = string.Explode("%s", argument)
                        RunConsoleCommand(cleanCommand, unpack(args))
                    else
                        RunConsoleCommand(cleanCommand, argument)
                    end
                else
                    RunConsoleCommand(cleanCommand)
                end

                if GetConVar("keybind_debug"):GetBool() then
                    print("[KeyBinds] Exécution de " .. command .. (argument and (" avec arg: " .. argument) or ""))
                end
            end
        else
            keyPressStates[command] = false
        end
    end
end)

function ExportKeyBinds()
    local IsEditingGlobal = IsEditingGlobal or false
    local dataToExport = {}

    if IsEditingGlobal and isAdmin then
        dataToExport = globalKeyBinds
    else
        dataToExport = personalKeyBinds
    end

    local dataJson = util.TableToJSON(dataToExport)
    local compressedData = util.Compress(dataJson)
    local exportCode = util.Base64Encode(compressedData)

    local exportFrame = vgui.Create("XPFrame")
    exportFrame:SetTitle(KeyBindManager.GetPhrase("export_keybinds"))
    exportFrame:SetSize(550, 400)
    exportFrame:Center()
    exportFrame:MakePopup()

    local infoLabel = vgui.Create("DLabel", exportFrame)
    infoLabel:SetText(KeyBindManager.GetPhrase("exporting",
        IsEditingGlobal and KeyBindManager.GetPhrase("global_keybinds") or KeyBindManager.GetPhrase("personal_keybinds"),
        table.Count(dataToExport)))
    infoLabel:SetPos(10, 30)
    infoLabel:SizeToContents()

    local exportText = vgui.Create("XPTextEntry", exportFrame)
    exportText:SetPos(10, 55)
    exportText:SetSize(530, 290)
    exportText:SetMultiline(true)
    exportText:SetText(exportCode)
    exportText:SelectAllText()

    local copyButton = vgui.Create("XPButton", exportFrame)
    copyButton:SetText(KeyBindManager.GetPhrase("copy_to_clipboard"))
    copyButton:SetPos(10, 355)
    copyButton:SetSize(200, 35)
    copyButton.DoClick = function()
        SetClipboardText(exportCode)
        ShowNotification(KeyBindManager.GetPhrase("export_copied"), Color(0, 200, 0))
    end

    local saveButton = vgui.Create("XPButton", exportFrame)
    saveButton:SetText(KeyBindManager.GetPhrase("save_to_file"))
    saveButton:SetPos(220, 355)
    saveButton:SetSize(200, 35)
    saveButton.DoClick = function()
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local bindType = IsEditingGlobal and "globaux" or "personnels"
        local fileName = "keybinds_" .. bindType .. "_" .. timestamp .. ".txt"

        file.CreateDir("keybind_exports")
        file.Write("keybind_exports/" .. fileName, exportCode)

        ShowNotification(KeyBindManager.GetPhrase("keybinds_saved", fileName), Color(0, 200, 0))
    end

    local bindCount = vgui.Create("DLabel", exportFrame)
    bindCount:SetText(KeyBindManager.GetPhrase("keybinds_exported", table.Count(dataToExport)))
    bindCount:SetPos(430, 30)
    bindCount:SizeToContents()
end

function ImportKeyBinds()
    local importFrame = vgui.Create("XPFrame")
    importFrame:SetTitle(KeyBindManager.GetPhrase("import_keybinds"))
    importFrame:SetSize(550, 400)
    importFrame:Center()
    importFrame:MakePopup()

    local infoLabel = vgui.Create("DLabel", importFrame)
    infoLabel:SetText(KeyBindManager.GetPhrase("paste_or_select"))
    infoLabel:SetPos(10, 30)
    infoLabel:SizeToContents()

    local importText = vgui.Create("XPTextEntry", importFrame)
    importText:SetPos(10, 55)
    importText:SetSize(530, 250)
    importText:SetMultiline(true)
    importText:SetPlaceholderText(KeyBindManager.GetPhrase("paste_here"))

    local savedFilesList = vgui.Create("DListView", importFrame)
    savedFilesList:SetPos(10, 315)
    savedFilesList:SetSize(340, 75)
    savedFilesList:AddColumn(KeyBindManager.GetPhrase("saved_files"))
    savedFilesList:SetMultiSelect(false)

    local files = file.Find("keybind_exports/_.txt", "DATA")
    for _, f in ipairs(files) do
        savedFilesList:AddLine(f)
    end

    savedFilesList.OnRowSelected = function(_, _, line)
        local fileName = line:GetValue(1)
        local fileContent = file.Read("keybind_exports/" .. fileName, "DATA")
        importText:SetText(fileContent)
    end

    local loadButton = vgui.Create("XPButton", importFrame)
    loadButton:SetText(KeyBindManager.GetPhrase("load"))
    loadButton:SetPos(360, 315)
    loadButton:SetSize(180, 30)
    loadButton.DoClick = function()
        if savedFilesList:GetSelectedLine() then
            local fileName = savedFilesList:GetLine(savedFilesList:GetSelectedLine()):GetValue(1)
            importText:SetText(file.Read("keybind_exports/" .. fileName, "DATA"))
            ShowNotification(KeyBindManager.GetPhrase("file_loaded"), Color(0, 200, 0))
        else
            ShowNotification(KeyBindManager.GetPhrase("select_file"), Color(200, 0, 0))
        end
    end

    local deleteButton = vgui.Create("XPButton", importFrame)
    deleteButton:SetText(KeyBindManager.GetPhrase("delete"))
    deleteButton:SetPos(360, 350)
    deleteButton:SetSize(180, 30)
    deleteButton.DoClick = function()
        if savedFilesList:GetSelectedLine() then
            local fileName = savedFilesList:GetLine(savedFilesList:GetSelectedLine()):GetValue(1)
            file.Delete("keybind_exports/" .. fileName)
            savedFilesList:RemoveLine(savedFilesList:GetSelectedLine())
            ShowNotification(KeyBindManager.GetPhrase("file_deleted"), Color(0, 200, 0))
        else
            ShowNotification(KeyBindManager.GetPhrase("select_file"), Color(200, 0, 0))
        end
    end

    local importButton = vgui.Create("XPButton", importFrame)
    importButton:SetText("Importer")
    importButton:SetPos(225, 400)
    importButton:SetSize(100, 35)
    importButton.DoClick = function()
        local code = importText:GetText()
        if not code or code == "" then
            ShowNotification(KeyBindManager.GetPhrase("invalid_import"), Color(200, 0, 0))
            return
        end

        local success, imported = pcall(function()
            local decoded = util.Base64Decode(code)
            local decompressed = util.Decompress(decoded)
            return util.JSONToTable(decompressed)
        end)

        if success and imported then
            local optionsFrame = vgui.Create("XPFrame")
            optionsFrame:SetTitle(KeyBindManager.GetPhrase("import_options"))
            optionsFrame:SetSize(400, 200)
            optionsFrame:Center()
            optionsFrame:MakePopup()

            local importInfoLabel = vgui.Create("DLabel", optionsFrame)
            importInfoLabel:SetText((table.Count(imported) .. KeyBindManager.GetPhrase("import_found")))
            importInfoLabel:SetPos(20, 40)
            importInfoLabel:SetWide(360)
            importInfoLabel:SetWrap(true)
            importInfoLabel:SetAutoStretchVertical(true)

            local targetBindType = isAdmin and vgui.Create("DComboBox", optionsFrame) or nil
            if targetBindType then
                targetBindType:SetPos(20, 80)
                targetBindType:SetSize(360, 25)
                targetBindType:AddChoice(KeyBindManager.GetPhrase("import_personal_shortcuts"), false)
                targetBindType:AddChoice(KeyBindManager.GetPhrase("import_global_shortcuts"), true)
                targetBindType:SetValue(KeyBindManager.GetPhrase("import_personal_shortcuts"))
            end

            local mergeButton = vgui.Create("XPButton", optionsFrame)
            mergeButton:SetText(KeyBindManager.GetPhrase("merge"))
            mergeButton:SetPos(20, 120)
            mergeButton:SetSize(170, 35)
            mergeButton.DoClick = function()
                local isGlobal = targetBindType and targetBindType:GetOptionData(targetBindType:GetSelectedID()) or false

                if isGlobal and not isAdmin then
                    ShowNotification(KeyBindManager.GetPhrase("admin_required"), Color(200, 0, 0))
                    return
                end

                for cmd, data in pairs(imported) do
                    net.Start("CommandsKeyBinding_Update")
                    net.WriteBool(isGlobal)
                    net.WriteString(cmd)
                    net.WriteInt(data.key, 32)
                    net.WriteString(data.argument or "")
                    net.WriteBool(data.ctrl or false)
                    net.WriteBool(data.alt or false)
                    net.SendToServer()
                end

                ShowNotification(table.Count(imported) .. KeyBindManager.GetPhrase("keybinds_imported"), Color(0, 200, 0))
                optionsFrame:Close()
                importFrame:Close()
            end

            local replaceButton = vgui.Create("XPButton", optionsFrame)
            replaceButton:SetText(KeyBindManager.GetPhrase("replace"))
            replaceButton:SetPos(210, 120)
            replaceButton:SetSize(170, 35)
            replaceButton.DoClick = function()
                local isGlobal = targetBindType and targetBindType:GetOptionData(targetBindType:GetSelectedID()) or false

                if isGlobal and not isAdmin then
                    ShowNotification(KeyBindManager.GetPhrase("admin_required"), Color(200, 0, 0))
                    return
                end

                local existingBinds = isGlobal and globalKeyBinds or personalKeyBinds
                for cmd, _ in pairs(existingBinds) do
                    net.Start("CommandsKeyBinding_Update")
                    net.WriteBool(isGlobal)
                    net.WriteString(cmd)
                    net.WriteInt(0, 32)
                    net.WriteString("")
                    net.WriteBool(false)
                    net.WriteBool(false)
                    net.SendToServer()
                end

                for cmd, data in pairs(imported) do
                    net.Start("CommandsKeyBinding_Update")
                    net.WriteBool(isGlobal)
                    net.WriteString(cmd)
                    net.WriteInt(data.key, 32)
                    net.WriteString(data.argument or "")
                    net.WriteBool(data.ctrl or false)
                    net.WriteBool(data.alt or false)
                    net.SendToServer()
                end

                ShowNotification(table.Count(imported) .. KeyBindManager.GetPhrase("all_keybinds_replaced"),
                    Color(0, 200, 0))
                optionsFrame:Close()
                importFrame:Close()
            end
        else
            ShowNotification(KeyBindManager.GetPhrase("invalid_import_code"), Color(200, 0, 0))
        end
    end

    local cancelButton = vgui.Create("XPButton", importFrame)
    cancelButton:SetText("Annuler")
    cancelButton:SetPos(400, 400)
    cancelButton:SetSize(100, 35)
    cancelButton.DoClick = function()
        importFrame:Close()
    end
end

function ShowNotification(text, color, duration)
    if not IsValid(frame) then return end

    duration = duration or 3

    for _, child in pairs(frame:GetChildren()) do
        if child.isNotification and child.text == text then
            child:Remove()
        end
    end

    local notif = vgui.Create("DPanel", frame)
    notif:SetSize(350, 50)
    notif:SetPos((frame:GetWide() - 350) / 2, frame:GetTall() - 60)
    notif.text = text
    notif.isNotification = true
    notif.startTime = SysTime()
    notif.duration = duration

    notif:SetAlpha(0)
    notif:AlphaTo(255, 0.3, 0)

    notif.Paint = function(self, w, h)
        local alpha = 255
        local timeLeft = self.startTime + self.duration - SysTime()
        if timeLeft < 1 then
            alpha = 255 * timeLeft
        end

        local bgColor = Color(color.r, color.g, color.b, alpha * 0.9)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
        draw.RoundedBox(6, 2, 2, w - 4, h - 4, Color(40, 40, 40, alpha * 0.7))
        draw.SimpleText(text, "DermaDefaultBold", w / 2 + 1, h / 2 + 1, Color(0, 0, 0, alpha * 0.8), TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER)
        draw.SimpleText(text, "DermaDefaultBold", w / 2, h / 2, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER)
    end

    timer.Simple(duration, function()
        if IsValid(notif) then
            notif:AlphaTo(0, 0.5, 0, function()
                if IsValid(notif) then notif:Remove() end
            end)
        end
    end)
    surface.PlaySound("buttons/button15.wav")
    return notif
end

CreateClientConVar("keybind_debug", "0", true, false, "Activer les messages de débogage pour les raccourcis clavier")
CreateClientConVar("keybind_silent", "0", true, false, "Désactiver les sons de notification")

print("[Gestionnaire de raccourcis] Client initialisé")
