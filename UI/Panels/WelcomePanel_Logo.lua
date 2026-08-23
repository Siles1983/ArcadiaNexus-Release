--[[
    ArcadiaNexus
    UI/WelcomePanel_Logo.lua

    Modulares Logo mit Stern-Sparkle und Arcane-Pulse Animation.
    Ersetzt den Willkommen-Titel im WelcomePanel.

    Assets (223×142, alle in UI/Assets/Logo/):
        an01.tga  – Logo (Basis)
        an02.tga  – Stern 1
        an03.tga  – Stern 2
        an04.tga  – Stern 3
        an05.tga  – Stern 4

    Exportiert:
        ArcadiaNexus.UI.WelcomeLogo.Build(parent)
        → gibt die Höhe des Logo-Frames zurück (142)
]]

local ArcadiaNexus = _G.ArcadiaNexus
local UI = ArcadiaNexus.UI

-- ============================================================
-- EINSTELLUNGEN
-- ============================================================

local LOGO_W = 223
local LOGO_H = 142

-- Stern-Fade
local FADE_MIN = 1.0
local FADE_MAX = 2.0
local WAIT_MIN = 0.5
local WAIT_MAX = 1.5

-- Arcane Pulse (magisches Glühen)
local PULSE_SPEED     = 4.0
local PULSE_ALPHA_MIN = 0.92
local PULSE_ALPHA_MAX = 1.0

local ASSET_PATH = "Interface/AddOns/ArcadiaNexus/UI/Assets/Logo/"

-- ============================================================
-- MODUL
-- ============================================================

local WL = {}
ArcadiaNexus.UI.WelcomeLogo = WL

-- ============================================================
-- INTERNER HELPER: Stern erstellen
-- ============================================================

local function CreateStar(parent, texturePath)

    local star = parent:CreateTexture(nil, "OVERLAY")
    star:SetSize(LOGO_W, LOGO_H)
    star:SetPoint("CENTER", parent, "CENTER", 0, 0)
    star:SetTexture(texturePath)
    star:SetAlpha(0)

    local ag = star:CreateAnimationGroup()

    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetOrder(1)

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetOrder(2)

    ag:SetScript("OnFinished", function()
        local wait = math.random() * (WAIT_MAX - WAIT_MIN) + WAIT_MIN
        C_Timer.After(wait, function()
            local duration = math.random() * (FADE_MAX - FADE_MIN) + FADE_MIN
            fadeIn:SetDuration(duration)
            fadeOut:SetDuration(duration)
            ag:Play()
        end)
    end)

    -- Versetzter Startimpuls damit Sterne nicht synchron faden
    local startDelay = math.random() * 3
    C_Timer.After(startDelay, function()
        local duration = math.random() * (FADE_MAX - FADE_MIN) + FADE_MIN
        fadeIn:SetDuration(duration)
        fadeOut:SetDuration(duration)
        ag:Play()
    end)
end

-- ============================================================
-- BUILD
-- ============================================================

function WL:Build(parent)

    -- Frame als Träger (Puls-Animationen brauchen Frame, nicht Texture)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(LOGO_W, LOGO_H)
    frame:SetPoint("TOP", parent, "TOP", 0, -6)

    -- Logo-Basis
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints(frame)
    logo:SetTexture(ASSET_PATH .. "an01.tga")

    -- Arcane Pulse
    local pulseGroup = logo:CreateAnimationGroup()
    pulseGroup:SetLooping("REPEAT")

    local pulseOut = pulseGroup:CreateAnimation("Alpha")
    pulseOut:SetFromAlpha(PULSE_ALPHA_MAX)
    pulseOut:SetToAlpha(PULSE_ALPHA_MIN)
    pulseOut:SetDuration(PULSE_SPEED * 0.5)
    pulseOut:SetSmoothing("IN_OUT")
    pulseOut:SetOrder(1)

    local pulseIn = pulseGroup:CreateAnimation("Alpha")
    pulseIn:SetFromAlpha(PULSE_ALPHA_MIN)
    pulseIn:SetToAlpha(PULSE_ALPHA_MAX)
    pulseIn:SetDuration(PULSE_SPEED * 0.5)
    pulseIn:SetSmoothing("IN_OUT")
    pulseIn:SetOrder(2)

    pulseGroup:Play()

    -- Sterne (zufälliges Funkeln)
    CreateStar(frame, ASSET_PATH .. "an02.tga")
    CreateStar(frame, ASSET_PATH .. "an03.tga")
    CreateStar(frame, ASSET_PATH .. "an04.tga")
    CreateStar(frame, ASSET_PATH .. "an05.tga")

    self._frame = frame
    return LOGO_H
end
