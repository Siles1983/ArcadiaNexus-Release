--[[
    ArcadiaNexus – UI/Dialogs/GameResultDialog.lua
    Zentraler Ergebnis-/GameOver-Dialog für alle Minigames.

    API:
      ArcadiaNexus.UI.ShowResultDialog(config)
      ArcadiaNexus.UI.HideResultDialog(parent)
      ArcadiaNexus.UI.IsResultDialogVisible(parent)

    config:
      parent        (Frame, required) – Anker-Frame (typisch _fieldFrame)
      title         (string)
      titleColor    ({r,g,b}, optional)
      subtitle      (string, optional)
      score         (number, optional)
      scoreLabel    (string, optional)
      xp            (number, optional – sonst aus gameId/result berechnet)
      gold          (number, optional)
      goldLabel     (string, optional)
      newHighscore  (bool, optional)
      highscore     (number, optional)
      hideHighscore (bool, optional – unterdrückt Auto-Lookup aus ScoreManager)
      lines         ({string}, optional – Zusatzzeilen)
      gameId        (string, optional – für XP-Berechnung)
      difficulty    (string, optional)
      result        ("WIN"|"LOSS"|"DRAW", optional – für XP-Berechnung)
      buttons       ({ { label, onClick, width?, height?, variant? } })
      mode          ("fullscreen"|"panel", default "fullscreen")
      fadeIn        (bool, default true)
      frameLevel    (number, optional)
      onShow        (function, optional)
      onHide        (function, optional)
]]

ArcadiaNexus    = ArcadiaNexus or {}
ArcadiaNexus.UI = ArcadiaNexus.UI or {}

local UI = ArcadiaNexus.UI

-- ============================================================
-- Konstanten
-- ============================================================

local PANEL_W       = 320
local PANEL_MIN_H   = 160
local BTN_W         = 120
local BTN_H         = 30
local BTN_GAP       = 10
local BTN_ROW_GAP   = 8
local PAD           = 16
local BADGE_H       = 22

local PANEL_BG  = { 0.05, 0.05, 0.08, 0.96 }
local PANEL_BR  = { 0.90, 0.75, 0.30, 1.00 }
-- Overlay bleibt klickdicht, aber ohne abdunkelnden Schatten über dem Spielfeld.
local OVERLAY_A = 0
local OVERLAY_LEVEL_BOOST = 80

local _instances = setmetatable({}, { __mode = "k" })

-- ============================================================
-- Locale
-- ============================================================

local function L(key, fallback)
    local loc = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI") or {}
    return loc[key] or fallback or key
end

-- ============================================================
-- Label-Auflösung (Platzhalter "[key]" von GetLocaleTable ignorieren)
-- ============================================================

local _uiLocaleCache = nil
local function UILocale()
    if not _uiLocaleCache then
        _uiLocaleCache = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI") or {}
    end
    return _uiLocaleCache
end

local function IsMissing(val, key)
    if val == nil or val == "" then return true end
    if val == key then return true end
    if val == ("[" .. key .. "]") then return true end
    return false
end

local function ResolveLabel(gameL, key)
    local val = gameL and gameL[key]
    if not IsMissing(val, key) then return val end
    local ui = UILocale()
    val = ui[key]
    if not IsMissing(val, key) then return val end
    return nil
end

local function FirstLabel(gameL, keys, fallbackKey)
    for _, key in ipairs(keys) do
        local val = ResolveLabel(gameL, key)
        if val then return val end
    end
    local fb = ResolveLabel(UILocale(), fallbackKey)
    if fb then return fb end
    return fallbackKey
end

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function ResolveXP(config)
    if config.xp ~= nil then return config.xp end
    if not config.gameId or not config.result then return nil end
    local XPM = ArcadiaNexus.XPManager
    if not XPM or not XPM.CalculateXP then return nil end
    return XPM:CalculateXP(config.gameId, config.difficulty, config.result)
end

local function ResolveHighscore(config)
    if config.hideHighscore then return nil end
    if config.highscore ~= nil then return config.highscore end
    if not config.gameId then return nil end
    local SM = ArcadiaNexus.ScoreManager
    if not SM then return nil end
    return SM:GetBestScore(config.gameId, config.difficulty)
end

local function ApplyTitleColor(fs, color)
    if color then
        fs:SetTextColor(color[1], color[2], color[3], 1)
    else
        fs:SetTextColor(1, 0.85, 0.10, 1)
    end
end

local DEFAULT_BTN_TEXT = { 1, 0.82, 0 }

local function InstallVariantHoverHandlers(btn)
    btn:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then return end
        self.glow:SetAlpha(0.35)
        if self._resultVariant == "danger" then
            self.text:SetTextColor(1, 0.35, 0.35)
        else
            self.text:SetTextColor(1, 0.9, 0.4)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.glow:SetAlpha(0)
        if self._resultVariant == "danger" then
            self.text:SetTextColor(1, 0.25, 0.25)
        else
            self.text:SetTextColor(DEFAULT_BTN_TEXT[1], DEFAULT_BTN_TEXT[2], DEFAULT_BTN_TEXT[3])
        end
    end)
end

local function ApplyButtonVariant(btn, variant)
    btn._resultVariant = variant
    if variant == "danger" then
        btn.text:SetTextColor(1, 0.25, 0.25)
    else
        btn.text:SetTextColor(DEFAULT_BTN_TEXT[1], DEFAULT_BTN_TEXT[2], DEFAULT_BTN_TEXT[3])
    end
end

local function ResetResultButton(frame)
    frame:SetScript("OnClick", nil)
    frame:ClearAllPoints()
    frame:Enable()
    frame:SetAlpha(1)
    frame:SetScale(1)
    frame._resultVariant = nil
    if frame.text then
        frame.text:SetText("")
        frame.text:SetTextColor(DEFAULT_BTN_TEXT[1], DEFAULT_BTN_TEXT[2], DEFAULT_BTN_TEXT[3])
        frame.text:SetShadowOffset(1, -1)
    end
    if frame.glow then
        frame.glow:SetAlpha(0)
    end
    if frame.content then
        frame.content:ClearAllPoints()
        frame.content:SetPoint("CENTER", 0, 0)
    end
    if frame.bg then
        frame.bg:SetVertexColor(1, 1, 1)
    end
    frame:Hide()
end

local function CreateButtonPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "GameResultDialog.Buttons",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = UI.CreateArcadiaButton(poolParent, "", BTN_W, BTN_H)
            InstallVariantHoverHandlers(btn)
            return btn
        end,
        onAcquire = function(frame, context)
            frame:SetParent(context.parent)
            frame:Show()
        end,
        onRelease = function(frame)
            ResetResultButton(frame)
            if poolParentRef then
                frame:SetParent(poolParentRef)
            end
        end,
    })
end

-- ============================================================
-- Shell erstellen (pro Parent gecacht)
-- ============================================================

local function CreateShell(parent)
    local overlay = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    overlay:SetAllPoints(parent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetToplevel(true)
    overlay:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 0 })
    overlay:SetBackdropColor(0, 0, 0, OVERLAY_A)
    overlay:EnableMouse(true)
    overlay:Hide()

    local panel = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    panel:SetWidth(PANEL_W)
    panel:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    panel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], PANEL_BG[4])
    panel:SetBackdropBorderColor(PANEL_BR[1], PANEL_BR[2], PANEL_BR[3], PANEL_BR[4])

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", panel, "TOP", 0, -PAD)
    titleFS:SetJustifyH("CENTER")
    titleFS:SetWidth(PANEL_W - PAD * 2)

    local subtitleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitleFS:SetPoint("TOP", titleFS, "BOTTOM", 0, -8)
    subtitleFS:SetJustifyH("CENTER")
    subtitleFS:SetWidth(PANEL_W - PAD * 2)
    subtitleFS:SetTextColor(0.90, 0.85, 0.70)

    local statsFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsFS:SetPoint("TOP", subtitleFS, "BOTTOM", 0, -6)
    statsFS:SetJustifyH("CENTER")
    statsFS:SetWidth(PANEL_W - PAD * 2)
    statsFS:SetTextColor(0.85, 0.80, 0.65)

    local extraFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    extraFS:SetPoint("TOP", statsFS, "BOTTOM", 0, -4)
    extraFS:SetJustifyH("CENTER")
    extraFS:SetWidth(PANEL_W - PAD * 2)
    extraFS:SetTextColor(0.75, 0.70, 0.55)

    local hsBadge = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    hsBadge:SetHeight(BADGE_H)
    hsBadge:SetPoint("TOP", extraFS, "BOTTOM", 0, -6)
    hsBadge:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, edgeSize = 10,
        insets = { left = 3, right = 3, top = 2, bottom = 2 },
    })
    hsBadge:SetBackdropColor(0.15, 0.10, 0.02, 0.95)
    hsBadge:SetBackdropBorderColor(1, 0.85, 0.20, 1)

    local hsBadgeFS = hsBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hsBadgeFS:SetPoint("CENTER", hsBadge, "CENTER", 0, 0)
    hsBadgeFS:SetText(L("result_new_hs", "|cffffd700Neuer Highscore!|r"))

    local btnBar = CreateFrame("Frame", nil, panel)
    btnBar:SetPoint("TOP", hsBadge, "BOTTOM", 0, -PAD)
    btnBar:SetSize(PANEL_W - PAD * 2, BTN_H * 2 + BTN_ROW_GAP)
    btnBar._buttons = {}

    return {
        overlay     = overlay,
        panel       = panel,
        titleFS     = titleFS,
        subtitleFS  = subtitleFS,
        statsFS     = statsFS,
        extraFS     = extraFS,
        hsBadge     = hsBadge,
        hsBadgeFS   = hsBadgeFS,
        btnBar      = btnBar,
        buttonPool  = CreateButtonPool(),
    }
end

local function GetShell(parent)
    if not parent then return nil end
    if not _instances[parent] then
        _instances[parent] = CreateShell(parent)
    end
    return _instances[parent]
end

-- ============================================================
-- Button-Bar layout
-- ============================================================

local function ClearButtons(btnBar, shell)
    if shell and shell.buttonPool then
        shell.buttonPool:ReleaseAll()
    end
    btnBar._buttons = {}
end

local function LayoutButtons(btnBar, buttons, shell)
    ClearButtons(btnBar, shell)
    if not buttons or #buttons == 0 then return 0 end

    local count = #buttons

    for i, cfg in ipairs(buttons) do
        local w = cfg.width  or BTN_W
        local h = cfg.height or BTN_H
        local btn = shell.buttonPool:Acquire({ parent = btnBar })
        btn:SetSize(w, h)
        if btn.content then btn.content:SetSize(w, h) end
        if btn.SetLabel then
            btn:SetLabel(cfg.label or "?")
        else
            btn.text:SetText(cfg.label or "?")
        end
        ApplyButtonVariant(btn, cfg.variant)
        btn:SetScript("OnClick", function()
            if cfg.onClick then cfg.onClick() end
        end)
        btnBar._buttons[i] = btn
    end

    if count == 1 then
        local btn = btnBar._buttons[1]
        btn:SetPoint("TOP", btnBar, "TOP", 0, 0)
        return BTN_H

    elseif count == 2 then
        local w1 = buttons[1].width or BTN_W
        local w2 = buttons[2].width or BTN_W
        btnBar._buttons[1]:SetPoint("TOP", btnBar, "TOP", -(w2 + BTN_GAP) / 2, 0)
        btnBar._buttons[2]:SetPoint("LEFT", btnBar._buttons[1], "RIGHT", BTN_GAP, 0)
        return BTN_H

    elseif count == 3 then
        local w = buttons[1].width or BTN_W
        btnBar._buttons[1]:SetPoint("TOP", btnBar, "TOP", -(w + BTN_GAP) / 2, 0)
        btnBar._buttons[1]:SetSize(w, BTN_H)
        btnBar._buttons[2]:SetPoint("LEFT", btnBar._buttons[1], "RIGHT", BTN_GAP, 0)
        btnBar._buttons[2]:SetSize(w, BTN_H)
        btnBar._buttons[3]:SetPoint("TOP", btnBar, "TOP", 0, -(BTN_H + BTN_ROW_GAP))
        btnBar._buttons[3]:SetSize(w, BTN_H)
        return BTN_H * 2 + BTN_ROW_GAP

    else
        -- 4+ Buttons: 2 pro Zeile
        local rows = math.ceil(count / 2)
        local rowH = BTN_H + BTN_ROW_GAP
        for i = 1, count do
            local btn = btnBar._buttons[i]
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local w = buttons[i].width or BTN_W
            btn:SetSize(w, BTN_H)
            if col == 0 then
                local w2 = (buttons[i + 1] and (buttons[i + 1].width or BTN_W)) or w
                local total = w + (buttons[i + 1] and (BTN_GAP + w2) or 0)
                btn:SetPoint("TOP", btnBar, "TOP", -total / 2, -(row * rowH))
            else
                btn:SetPoint("TOPLEFT", btnBar._buttons[i - 1], "TOPRIGHT", BTN_GAP, 0)
            end
        end
        return rows * rowH - BTN_ROW_GAP
    end
end

-- ============================================================
-- Inhalt befüllen
-- ============================================================

local function PopulateShell(shell, config)
    local titleFS    = shell.titleFS
    local subtitleFS = shell.subtitleFS
    local statsFS    = shell.statsFS
    local extraFS    = shell.extraFS
    local hsBadge    = shell.hsBadge
    local panel      = shell.panel
    local btnBar     = shell.btnBar

    titleFS:SetText(config.title or "")
    ApplyTitleColor(titleFS, config.titleColor)

    if config.subtitle and config.subtitle ~= "" then
        subtitleFS:SetText(config.subtitle)
        subtitleFS:Show()
    else
        subtitleFS:SetText("")
        subtitleFS:Hide()
    end

    local statParts = {}
    if config.score ~= nil then
        local label = config.scoreLabel or L("result_score", "Punkte")
        statParts[#statParts + 1] = label .. ": |cffffd700" .. tostring(config.score) .. "|r"
    end

    local xp = ResolveXP(config)
    if xp and xp > 0 then
        statParts[#statParts + 1] = L("result_xp", "XP") .. ": |cff00ff88+" .. tostring(xp) .. "|r"
    end

    if config.gold ~= nil and config.gold ~= 0 then
        local gLabel = config.goldLabel or L("result_gold", "Gold")
        local sign = config.gold >= 0 and "+" or ""
        local color = config.gold >= 0 and "cff00ff88" or "cffff4444"
        statParts[#statParts + 1] = gLabel .. ": |" .. color .. sign .. tostring(config.gold) .. "|r"
    end

    local hs = ResolveHighscore(config)
    if hs and hs > 0 and not config.newHighscore then
        statParts[#statParts + 1] = L("result_highscore", "Highscore") .. ": |cffffd700" .. tostring(hs) .. "|r"
    end

    if #statParts > 0 then
        statsFS:SetText(table.concat(statParts, "   "))
        statsFS:Show()
    else
        statsFS:SetText("")
        statsFS:Hide()
    end

    local extraLines = config.lines or {}
    if #extraLines > 0 then
        extraFS:SetText(table.concat(extraLines, "\n"))
        extraFS:Show()
    else
        extraFS:SetText("")
        extraFS:Hide()
    end

    if config.newHighscore then
        hsBadge:Show()
        hsBadge:SetWidth(PANEL_W - PAD * 4)
    else
        hsBadge:Hide()
    end

    local btnH = LayoutButtons(btnBar, config.buttons or {}, shell)
    btnBar:SetHeight(math.max(btnH, BTN_H))

    -- Panel-Höhe dynamisch
    local anchorFS = #extraLines > 0 and extraFS or statsFS
    if not statsFS:IsShown() and not extraFS:IsShown() then
        anchorFS = subtitleFS:IsShown() and subtitleFS or titleFS
    end
    btnBar:ClearAllPoints()
    if config.newHighscore then
        btnBar:SetPoint("TOP", hsBadge, "BOTTOM", 0, -PAD)
    else
        btnBar:SetPoint("TOP", anchorFS, "BOTTOM", 0, -PAD)
    end

    local totalH = PAD + titleFS:GetStringHeight() + 8
    if subtitleFS:IsShown() then totalH = totalH + subtitleFS:GetStringHeight() + 8 end
    if statsFS:IsShown()    then totalH = totalH + statsFS:GetStringHeight() + 6 end
    if extraFS:IsShown()    then totalH = totalH + extraFS:GetStringHeight() + 4 end
    if config.newHighscore  then totalH = totalH + BADGE_H + 6 end
    totalH = totalH + btnBar:GetHeight() + PAD

    panel:SetHeight(math.max(PANEL_MIN_H, totalH))
end

-- ============================================================
-- Öffentliche API
-- ============================================================

function UI.ShowResultDialog(config)
    if not config or not config.parent then return end
    local shell = GetShell(config.parent)
    if not shell then return end

    local overlay = shell.overlay
    local alreadyShown = overlay:IsShown()

    PopulateShell(shell, config)

    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetToplevel(true)
    local parentLevel = config.parent:GetFrameLevel() or 1
    local extra = config.frameLevel or 0
    overlay:SetFrameLevel(parentLevel + OVERLAY_LEVEL_BOOST + extra)

    overlay:SetAllPoints(config.parent)
    overlay:SetBackdropColor(0, 0, 0, OVERLAY_A)

    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(overlay)
    end

    -- Bereits sichtbar: Inhalt ersetzen, nicht ausblenden und neu einfaden
    -- (sonst wirkt es wie zwei hintereinander gebaute Dialoge).
    if alreadyShown then
        overlay:SetAlpha(1)
        overlay:Raise()
    else
        -- Alpha zuerst auf 0, sonst flasht Show() einen Frame bei Alpha 1.
        overlay:SetAlpha(0)
        overlay:Show()
        overlay:Raise()
        if config.fadeIn ~= false then
            UIFrameFadeIn(overlay, 0.35, 0, 1)
        else
            overlay:SetAlpha(1)
        end
    end

    if config.onShow then config.onShow() end
end

function UI.HideResultDialog(parent)
    if not parent then return end
    local shell = _instances[parent]
    if shell and shell.overlay then
        if UIFrameFadeRemoveFrame then
            UIFrameFadeRemoveFrame(shell.overlay)
        end
        shell.overlay:Hide()
        shell.overlay:SetAlpha(1)
    end
end

function UI.IsResultDialogVisible(parent)
    local shell = parent and _instances[parent]
    return shell and shell.overlay and shell.overlay:IsShown() or false
end

-- ============================================================
-- Button-Presets für häufige Szenarien
-- ============================================================

UI.ResultDialogButtons = {}

function UI.ResultDialogButtons.Arcade(L, onRetry, onExit)
    return {
        { label = FirstLabel(L, { "popup_play_again", "btn_new_game_ov", "btn_new_game", "btn_retry", "btn_restart", "btn_play_again" }, "btn_play_again"),
          onClick = onRetry },
        { label = FirstLabel(L, { "btn_exit", "btn_menu" }, "btn_exit"),
          onClick = onExit },
    }
end

function UI.ResultDialogButtons.Level(L, onNext, onSelect, onExit)
    return {
        { label = FirstLabel(L, { "btn_next_level", "popup_resume" }, "btn_next_level"), onClick = onNext },
        { label = FirstLabel(L, { "btn_level_select", "btn_menu" }, "btn_level_select"), onClick = onSelect },
        { label = FirstLabel(L, { "btn_exit" }, "btn_exit"), onClick = onExit },
    }
end

function UI.ResultDialogButtons.Round(L, onNext, onQuit)
    return {
        { label = FirstLabel(L, { "btn_next_round", "btn_new_round", "btn_continue", "btn_deal" }, "btn_next_round"), onClick = onNext },
        { label = FirstLabel(L, { "btn_give_up", "btn_stop", "btn_exit" }, "btn_give_up"), onClick = onQuit },
    }
end

function UI.ResultDialogButtons.Bankrupt(L, onReset, onExit)
    return {
        { label = FirstLabel(L, { "btn_reset_chips", "btn_bankrupt", "btn_start" }, "btn_reset_chips"),
          onClick = onReset, variant = "danger" },
        { label = FirstLabel(L, { "btn_exit" }, "btn_exit"), onClick = onExit },
    }
end
