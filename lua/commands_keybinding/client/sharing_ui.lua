local THEME = CKB.THEME

-- ── Send share request ────────────────────────────────

function CKB.SendShareProfile(profileId, targetSteamId)
    net.Start("CKB_ShareProfile")
    net.WriteString(profileId)
    net.WriteString(targetSteamId)
    net.SendToServer()
end

function CKB.SendShareAccept(senderSteamId)
    net.Start("CKB_ShareAccept")
    net.WriteString(senderSteamId)
    net.SendToServer()
end

function CKB.SendShareDecline(senderSteamId)
    net.Start("CKB_ShareDecline")
    net.WriteString(senderSteamId)
    net.SendToServer()
end

-- ── Player picker popup ───────────────────────────────

function CKB.OpenSharePlayerPicker(profileId)
    local popup = vgui.Create("DFrame")
    popup:SetSize(320, 350)
    popup:Center()
    popup:MakePopup()
    popup:SetDeleteOnClose(true)
    CKB.StyleFrame(popup, CKB.L("share_picker_title"))

    local container = vgui.Create("DPanel", popup)
    container:Dock(FILL)
    container:DockMargin(8, 8, 8, 8)
    container:DockPadding(0, 0, 0, 0)
    container.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

    local listView = vgui.Create("DListView", container)
    listView:Dock(FILL)
    listView:SetMultiSelect(false)
    CKB.StyleListView(listView)
    listView:AddColumn(CKB.L("col_player")):SetFixedWidth(180)
    listView:AddColumn(CKB.L("col_steamid"))

    local me = LocalPlayer()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply ~= me then
            local line = listView:AddLine(ply:Nick(), ply:SteamID64())
            line._steamId = ply:SteamID64()
        end
    end

    listView.DoDoubleClick = function(_, _, line)
        if line._steamId then
            CKB.SendShareProfile(profileId, line._steamId)
            popup:Close()
            chat.AddText(THEME.accent, CKB.L("chat_prefix"), THEME.text, CKB.L("share_sent"))
        end
    end

    local btnRow = vgui.Create("DPanel", container)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(36)
    btnRow:DockMargin(6, 4, 6, 6)
    btnRow.Paint = function() end

    local btnCancel = vgui.Create("DButton", btnRow)
    btnCancel:Dock(RIGHT)
    btnCancel:SetWide(80)
    btnCancel:SetText(CKB.L("cancel"))
    CKB.StyleButton(btnCancel)
    btnCancel.DoClick = function() popup:Close() end

    local btnSend = vgui.Create("DButton", btnRow)
    btnSend:Dock(RIGHT)
    btnSend:DockMargin(0, 0, 6, 0)
    btnSend:SetWide(80)
    btnSend:SetText(CKB.L("share"))
    CKB.StyleButton(btnSend, true)
    btnSend.DoClick = function()
        local _, line = listView:GetSelectedLine()
        if line and line._steamId then
            CKB.SendShareProfile(profileId, line._steamId)
            popup:Close()
            chat.AddText(THEME.accent, CKB.L("chat_prefix"), THEME.text, CKB.L("share_sent"))
        end
    end
end

-- ── Incoming share notification ───────────────────────

net.Receive("CKB_ShareIncoming", function()
    local senderName = net.ReadString()
    local senderSteamId = net.ReadString()
    local profileName = net.ReadString()
    local bindCount = net.ReadUInt(16)

    surface.PlaySound("buttons/button15.wav")

    local popup = vgui.Create("DFrame")
    popup:SetSize(400, 180)
    popup:Center()
    popup:MakePopup()
    popup:SetDeleteOnClose(true)
    CKB.StyleFrame(popup, CKB.L("incoming_share_title"))

    local container = vgui.Create("DPanel", popup)
    container:Dock(FILL)
    container:DockMargin(8, 8, 8, 8)
    container:DockPadding(12, 8, 12, 8)
    container.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

    local msg = vgui.Create("DLabel", container)
    msg:Dock(TOP)
    msg:SetTall(50)
    msg:SetWrap(true)
    msg:SetFont("DermaDefault")
    msg:SetTextColor(THEME.textBright)
    msg:SetText(CKB.L("share_incoming_msg", senderName, profileName, bindCount))

    local btnRow = vgui.Create("DPanel", container)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(32)
    btnRow.Paint = function() end

    local btnDecline = vgui.Create("DButton", btnRow)
    btnDecline:Dock(RIGHT)
    btnDecline:SetWide(80)
    btnDecline:SetText(CKB.L("decline"))
    CKB.StyleButton(btnDecline)
    btnDecline.DoClick = function()
        CKB.SendShareDecline(senderSteamId)
        popup:Close()
    end

    local btnAccept = vgui.Create("DButton", btnRow)
    btnAccept:Dock(RIGHT)
    btnAccept:DockMargin(0, 0, 6, 0)
    btnAccept:SetWide(80)
    btnAccept:SetText(CKB.L("accept"))
    CKB.StyleButton(btnAccept, true)
    btnAccept.DoClick = function()
        CKB.SendShareAccept(senderSteamId)
        popup:Close()
        chat.AddText(THEME.accent, CKB.L("chat_prefix"), THEME.success, CKB.L("profile_received"))
    end
end)

-- ── Share result notification (for sender) ────────────

net.Receive("CKB_ShareResult", function()
    local targetName = net.ReadString()
    local accepted = net.ReadBool()
    local reason = net.ReadString()

    if reason and reason ~= "" then
        -- The server sends a translation key (e.g. "share_not_allowed").
        chat.AddText(THEME.accent, CKB.L("chat_prefix"), THEME.danger, CKB.L(reason))
    elseif accepted then
        chat.AddText(THEME.accent, CKB.L("chat_prefix"), THEME.success, CKB.L("share_accepted", targetName))
    else
        chat.AddText(THEME.accent, CKB.L("chat_prefix"), THEME.danger, CKB.L("share_declined", targetName))
    end
end)
