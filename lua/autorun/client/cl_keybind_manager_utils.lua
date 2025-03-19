-- cl_keybind_manager_utils.lua

local CommandSuggestionsCache = {}

function ClearCommandSuggestionsCache()
    CommandSuggestionsCache = {}
end

function IsValidCommand(cmd)
    return string.match(cmd, "^[%w%+%-_%*/!%s]+$") ~= nil and string.match(cmd, "%S")
end

function GetCommandSuggestions(command)
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

function ShowNotification(text, color, duration)
    if not IsValid(Frame) then return end

    duration = duration or 3

    for _, child in pairs(Frame:GetChildren()) do
        if child.isNotification and child.text == text then
            child:Remove()
        end
    end

    local notif = vgui.Create("DPanel", Frame)
    notif:SetSize(350, 50)
    notif:SetPos((Frame:GetWide() - 350) / 2, Frame:GetTall() - 60)
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

function ExportKeyBinds()
    local IsEditingGlobal = IsEditingGlobal or false
    local dataToExport = {}

    if IsEditingGlobal and IsAdmin then
        dataToExport = GlobalKeyBinds
    else
        dataToExport = PersonalKeyBinds
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

    local files = file.Find("keybind_exports/*.txt", "DATA")
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

            local targetBindType = IsAdmin and vgui.Create("DComboBox", optionsFrame) or nil
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

                if isGlobal and not IsAdmin then
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

                if isGlobal and not IsAdmin then
                    ShowNotification(KeyBindManager.GetPhrase("admin_required"), Color(200, 0, 0))
                    return
                end

                local existingBinds = isGlobal and GlobalKeyBinds or PersonalKeyBinds
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
