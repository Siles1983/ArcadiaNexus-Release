--[[
    ArcadiaNexus – Achievement_Summary
    UI/Achievement_Summary.lua

    Einstiegspunkt der Achievement-Zusammenfassung.
    Wird von Achievement_UI.lua koordiniert — ShowSummary() ist der
    öffentliche Einstiegspunkt, der von BuildAchievementCategoryPanel
    bei Klick auf "Zusammenfassung" aufgerufen wird.

    Abhängig von (müssen VOR dieser Datei im TOC stehen):
        Achievement_Summary_Helpers.lua
        Achievement_Summary_Recent.lua
        Achievement_Summary_Progress.lua

    Öffentliche API (auf ArcadiaNexus.AchievementUI):
        AUI:ShowSummary()   – Zusammenfassung anzeigen
        AUI:IsSummary()     – gibt true zurück wenn aktuell Summary sichtbar ist
]]

local ArcadiaNexus = _G.ArcadiaNexus

-- AUI existiert bereits (wird in Achievement_UI.lua angelegt)
local AUI = ArcadiaNexus.AchievementUI

-- ============================================================
-- Interner State
-- ============================================================
local _summaryContent = nil   -- ScrollChild-Frame mit dem gebauten Inhalt
local _isSummary      = false

-- ============================================================
-- ShowSummary
-- ============================================================
function AUI:ShowSummary()
    _isSummary = true

    local sc = self:_GetSC()
    local sf = self:_GetSF()
    if not sc or not sf then return end

    -- Alten Inhalt entfernen (ShowGame-Zeilen)
    self:_ClearRows()

    local W = sf:GetWidth() or 0
    if W < 10 then
        C_Timer.After(0.05, function() AUI:ShowSummary() end)
        return
    end

    -- Bestehenden Summary-Content wiederverwenden
    if not _summaryContent then
        _summaryContent = CreateFrame("Frame", nil, sc)
    else
        if ArcadiaNexus.AchSumRecent and ArcadiaNexus.AchSumRecent.ReleaseAll then
            ArcadiaNexus.AchSumRecent.ReleaseAll()
        end
        if ArcadiaNexus.AchSumProgress and ArcadiaNexus.AchSumProgress.ReleaseAll then
            ArcadiaNexus.AchSumProgress.ReleaseAll()
        end
        _summaryContent:SetParent(sc)
    end

    local content = _summaryContent
    content:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
    content:SetWidth(math.max(W - 6, 10))
    content:SetHeight(1)
    content:Show()
    _summaryContent = content

    local PAD  = 4
    local yOff = PAD

    -- ── Block 1: Neueste Erfolge ─────────────────────────────
    local recentH = ArcadiaNexus.AchSumRecent.Build(content, yOff, 4)
    yOff = yOff + recentH + 6    -- Blizzard: y=+6 zwischen Achievements und Categories

    -- ── Block 2: Fortschrittsüberblick ───────────────────────
    local progressH = ArcadiaNexus.AchSumProgress.Build(content, yOff)
    yOff = yOff + progressH + PAD

    local totalH = math.max(yOff, 1)
    content:SetHeight(totalH)
    -- _sc auf Summary-Höhe setzen damit Scrollbar korrekt rechnet
    sc:SetHeight(totalH)
    sf:SetVerticalScroll(0)

    -- Scrollbar aktualisieren (UpdateScrollbar ist lokal in Achievement_UI.lua,
    -- daher via Timer triggern)
    C_Timer.After(0, function()
        if sf and sf.ScrollBar then
            local sb = sf.ScrollBar
            local contentH = content:GetHeight()
            local viewH    = sf:GetHeight()
            sb.visibleExtentPercentage = viewH / math.max(contentH, 1)
            if contentH <= viewH then
                sb:Hide()
                if sb.Track   then sb.Track:Hide()   end
                if sb.TrackBG then sb.TrackBG:Hide() end
            else
                sb:Show()
                if sb.Track   then sb.Track:Show()   end
                if sb.TrackBG then sb.TrackBG:Show() end
            end
        end
    end)
end

-- ============================================================
-- IsSummary
-- ============================================================
function AUI:IsSummary()
    return _isSummary
end

-- ============================================================
-- ShowGame überschreibt _isSummary-Flag
-- (wird von Achievement_UI.lua aus aufgerufen)
-- ============================================================
local _origShowGame = AUI.ShowGame
function AUI:ShowGame(gameId)
    _isSummary = false
    if _summaryContent then
        _summaryContent:Hide()
        local sc = self:_GetSC()
        if sc then sc:SetHeight(1) end
    end
    _origShowGame(self, gameId)
end
