--[[
    ArcadiaNexus
    UI/WelcomePanel.lua

    Willkommens-Panel: Wird angezeigt wenn kein Spiel aktiv ist.
    Enthält: Begrüßung, Spiel des Tages (klickbar), Neue Spiele, Changelog.

    Exportiert:
        ArcadiaNexus.UI.WelcomePanel.Build(parent)
        ArcadiaNexus.UI.WelcomePanel.Show()
        ArcadiaNexus.UI.WelcomePanel.Hide()

    Abhängigkeiten:
        UI/UIHelpers.lua       (UI.CreateBox, CreateNexusScrollbar, UI.UpdateScrollbar)
        Core/ChallengeManager  (ChallengeManager:GetGameOfDay)
        UI/Language.lua        (ArcadiaNexus.GetLocaleTable "UI")
]]

local ArcadiaNexus = _G.ArcadiaNexus
local UI = ArcadiaNexus.UI

local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key] or key
end

-- ============================================================
-- KONSTANTEN (aus LayoutConfig bei Build)
-- ============================================================
local PAD = 14

-- ============================================================
-- MODULE
-- ============================================================
local WP = {}
ArcadiaNexus.UI.WelcomePanel = WP

WP._frame   = nil
WP._sf      = nil
WP._sc      = nil
WP._gotdBtn = nil

-- ============================================================
-- DIVIDER-HELPER (absolutes Y auf sc)
-- ============================================================
local function MakeDivider(parent, y, innerW)

    local div = parent:CreateTexture(nil, "ARTWORK")

    div:SetColorTexture(0.85, 0.70, 0.30, 0.6)

    div:SetWidth(innerW * 0.65)   -- gleiche visuelle Breite wie Content
    div:SetHeight(2)
    div:SetAlpha(0.7)
    div:SetPoint("TOP", parent, "TOP", 0, -y)

    return div
end

-- ============================================================
-- BUILD
-- ============================================================
function WP:Build(parent)
    if self._frame then return end

    local gamesW, gamesH = ArcadiaNexus.Layout.GetGamesPanelSize()
    local boxW  = math.max(472, math.min(600, gamesW - 40))
    local boxH  = math.min(530, math.max(470, gamesH - 28))
    local innerW = boxW - 10

    -- Wrapper: zentriert im content-Panel
    local wrapper = CreateFrame("Frame", "NexusWelcomePanel", parent)
    wrapper:SetSize(boxW, boxH)
    wrapper:SetPoint("CENTER", parent, "CENTER", 0, 0)
    wrapper:Hide()
    self._frame = wrapper

    -- Box (BackdropTemplate) – explizite Größe identisch mit wrapper
    local box = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
    box:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
    box:SetSize(boxW, boxH)
    box:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    box:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
    box:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

    -- ── LOGO ────────────────────────────────────────────────
    local logoH = ArcadiaNexus.UI.WelcomeLogo:Build(box)

    -- Divider unter Logo
    local logoDivider = box:CreateTexture(nil, "ARTWORK", nil, 1)
    logoDivider:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
    logoDivider:SetPoint("TOPLEFT",  box, "TOPLEFT",   4, -(logoH + 10))
    logoDivider:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -(logoH + 10))
    logoDivider:SetHeight(8)
    logoDivider:SetHorizTile(true)

    -- ── SPIEL DES TAGES (fest, außerhalb ScrollFrame) ───────
    local GOTD_TOP = logoH + 25   -- 25px Abstand unter Logo

    local gotdHeader = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gotdHeader:SetPoint("TOP", box, "TOP", 0, -GOTD_TOP)
    gotdHeader:SetWidth(boxW - 32)
    gotdHeader:SetJustifyH("CENTER")
    gotdHeader:SetText("|cffffd700" .. L("welcome_gotd_header") .. "|r")

    local gotdBtn = ArcadiaNexus.UI.CreateArcadiaButton(box, "…")
    gotdBtn:SetPoint("TOP", box, "TOP", 0, -(GOTD_TOP + 22))
    gotdBtn._gameId = nil
    gotdBtn:SetScript("OnClick", function(self)
        if self._gameId then
            local fn = ArcadiaNexus.UI._ActivateGameFn
            if fn then WP:Hide(); fn(self._gameId) end
        end
    end)

    -- ── SCROLLFRAME (beginnt unterhalb GOTD-Block) ──────────
    local SCROLL_TOP = GOTD_TOP + 22 + 36   -- GOTD-Block-Höhe + Abstand
    local sf = CreateFrame("ScrollFrame", "NexusWelcomePanelScroll", box)
    sf:SetPoint("TOPLEFT",     box, "TOPLEFT",       6, -SCROLL_TOP)
    sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -28,  6)
    sf:EnableMouseWheel(true)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(innerW)
    sc:SetHeight(1)   -- wird nach dem Inhalt korrekt gesetzt
    sf:SetScrollChild(sc)

    CreateNexusScrollbar(sf, box)

    -- ── INHALT ──────────────────────────────────────────────
    local curY = PAD

    -- 1. DIVIDER (Trenner vor Neue Spiele)
    MakeDivider(sc, curY, innerW)
    curY = curY + 16
    local newHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    newHeader:SetPoint("TOP", sc, "TOP", 0, -curY)
    newHeader:SetWidth(innerW)
    newHeader:SetJustifyH("CENTER")
    newHeader:SetText("|cffffd700" .. L("welcome_new_games_header") .. "|r")
    curY = curY + 20 -- Abstand Neue Spiele zu Neue Spiele Changelog

    local newFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    newFS:SetPoint("TOP", sc, "TOP", 0, -curY)
    newFS:SetWidth(innerW)
    newFS:SetJustifyH("CENTER")
    newFS:SetWordWrap(true)
    newFS:SetText(L("welcome_new_games_placeholder"))
    newFS:SetTextColor(0.75, 0.70, 0.55)
    curY = curY + 30 -- Abstand Neue Spiele zu Divider

    -- 4. DIVIDER
    MakeDivider(sc, curY, innerW)
    curY = curY + 16 -- Abstand Divider zu Changelog

    -- 5. CHANGELOG Header
    local clHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clHeader:SetPoint("TOP", sc, "TOP", 0, -curY)
    clHeader:SetWidth(innerW)
    clHeader:SetJustifyH("CENTER")
    clHeader:SetText("|cffffd700" .. L("welcome_changelog_header") .. "|r")
    curY = curY + 20 -- Abstand Changelog zu Changelog Text

    local clFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clFS:SetPoint("TOP", sc, "TOP", 0, -curY)
    clFS:SetWidth(innerW)
    clFS:SetJustifyH("CENTER")
    clFS:SetWordWrap(true)
    clFS:SetText(L("welcome_changelog_text"))
    clFS:SetTextColor(0.75, 0.70, 0.55)
    curY = curY + 80   -- feste Reserve für mehrzeiligen Text
	
	-- 6. DIVIDER
    MakeDivider(sc, curY, innerW)
    curY = curY + 0 -- Abstand letzter Divider nach Changelog Text

    -- Gesamt-Höhe des Scroll-Contents
    local totalH = curY + PAD
    sc:SetHeight(totalH)

    -- Refs speichern
    self._sf      = sf
    self._sc      = sc
    self._gotdBtn = gotdBtn
    self._box     = box
end

-- ============================================================
-- SHOW / HIDE
-- ============================================================
function WP:Show()
    if not self._frame then return end

    -- Alle Spiel-Container verstecken (kein Spiel aktiv)
    if ArcadiaNexus.GameRegistry then
        ArcadiaNexus.GameRegistry.HideAllContainers()
    end
    NexusTabs.StopAllGames()

    -- Content-Label verstecken solange WelcomePanel aktiv
    local F = ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF()
    if F and F.contentLabelFS then F.contentLabelFS:Hide() end

    -- GOTD aktualisieren
    local CM = ArcadiaNexus.ChallengeManager
    if CM and CM.GetGameOfDay and self._gotdBtn then
        local gotdId = CM:GetGameOfDay()
        if gotdId then
            local GR = ArcadiaNexus.GameRegistry
            local label = GR and GR.GetLabel(gotdId) or gotdId
            self._gotdBtn:SetLabel(label)
            self._gotdBtn._gameId = gotdId
            self._gotdBtn:Enable()
        else
            self._gotdBtn:SetLabel("–")
            self._gotdBtn:Disable()
        end
    end

    self._frame:Show()

    -- Scrollbar-Sichtbarkeit: nach einem Frame wenn Layout berechnet ist
    C_Timer.After(0.05, function()
        if self._sf and self._sc then
            ArcadiaNexus.UI.UpdateScrollbar(self._sf, self._sc)
        end
    end)
end

function WP:Hide()
    if not self._frame then return end
    self._frame:Hide()
    -- Content-Label wieder zeigen
    local F = ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF()
    if F and F.contentLabelFS then F.contentLabelFS:Show() end
end
