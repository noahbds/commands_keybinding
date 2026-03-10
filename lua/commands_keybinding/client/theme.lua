-- ═══════════════════════════════════════════════════════
--  CKB — Theme colors & styled element factories
-- ═══════════════════════════════════════════════════════

CKB.THEME = {
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

local THEME = CKB.THEME

-- ── Styled element factories ──────────────────────────

function CKB.StyleFrame(f, title)
    f:SetTitle("")
    if IsValid(f.lblTitle) then f.lblTitle:SetVisible(false) end
    f._title = title

    f.Paint = function(self, w, h)
        draw.RoundedBox(8, 2, 2, w, h, THEME.shadow)
        draw.RoundedBox(6, 0, 0, w, h, THEME.bg)
        draw.RoundedBoxEx(6, 0, 0, w, 28, THEME.titleBar, true, true, false, false)
        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, 28, w, 2)
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

function CKB.StyleTextEntry(entry)
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

function CKB.StyleButton(btn, isAccent)
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

function CKB.StyleBinder(binder)
    binder:SetText("")
    binder.SetText = function() end
    binder:SetTooltip(nil)
    binder.SetTooltip = function() end
    binder.UpdateText = function(self)
        self:SetText("")
    end

    binder.Paint = function(self, w, h)
        local focused = self.Trapping or self.m_bBinding or false
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

function CKB.StyleLabel(label)
    label:SetFont("DermaDefaultBold")
    label:SetTextColor(THEME.textDim)
end

function CKB.StyleListView(listView)
    listView.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, THEME.bgLight)
    end

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
            col:SetTextColor(THEME.textBright)
            col:SetFont("DermaDefault")
        end

        return line
    end
end
