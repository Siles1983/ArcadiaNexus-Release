--[[
    Gaming Hub
    Games/Memory/SymbolResolver.lua
    Version: 1.0.0

    Kartenrückseite:
      NEUTRAL   → Interface\Icons\INV_Misc_QuestionMark
      ALLIANCE  → Interface\Icons\INV_BannerPVP_02  (Allianz-Wappen)
      HORDE     → Interface\Icons\INV_BannerPVP_01  (Horde-Wappen)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_SymbolResolver = {}
local SR = ArcadiaNexus.AP_SymbolResolver

local BACK_ICONS = {
    NEUTRAL  = "Interface\\Icons\\INV_Misc_QuestionMark",
    ALLIANCE = "Interface\\Icons\\INV_BannerPVP_02",
    HORDE    = "Interface\\Icons\\INV_BannerPVP_01",
}

-- Tint-Farben für Kartenrückseite
local BACK_TINT = {
    NEUTRAL  = { 0.70, 0.70, 0.70, 1 },
    ALLIANCE = { 0.40, 0.60, 1.00, 1 },
    HORDE    = { 1.00, 0.25, 0.25, 1 },
}

-- ============================================================
-- Aktuelle Fraktion des Spielers
-- ============================================================
local function DetectFaction()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then return "ALLIANCE" end
    if faction == "Horde"    then return "HORDE"    end
    return "NEUTRAL"
end

-- ============================================================
-- GetCardBackIcon
-- Gibt { icon, tint } zurück basierend auf Einstellungen
-- ============================================================
function SR:GetCardBack(settings)
    local mode = settings and settings.cardBackMode or "AUTO"

    local faction
    if mode == "AUTO" then
        faction = DetectFaction()
    elseif mode == "ALLIANCE" then
        faction = "ALLIANCE"
    elseif mode == "HORDE" then
        faction = "HORDE"
    else
        faction = "NEUTRAL"
    end

    return {
        icon = BACK_ICONS[faction]  or BACK_ICONS.NEUTRAL,
        tint = BACK_TINT[faction]   or BACK_TINT.NEUTRAL,
    }
end

-- ============================================================
-- Verfügbare Modi für Dropdown
-- ============================================================
function SR:GetModeList()
    return {
        { key = "AUTO",     label = "Automatisch (Fraktion)"  },
        { key = "ALLIANCE", label = "Allianz"                 },
        { key = "HORDE",    label = "Horde"                   },
        { key = "NEUTRAL",  label = "Neutral (Fragezeichen)"  },
    }
end
