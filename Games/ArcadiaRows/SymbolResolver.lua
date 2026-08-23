--[[
    Gaming Hub
    Games/ArcadiaRows/SymbolResolver.lua
    Version: 1.0.0

    Identische Logik wie TicTacToe/SymbolResolver.lua.
    Liest aus ArcadiaNexus.AR_Settings.
    Gibt SymbolDef zurück: TEXT oder SPRITE (Fraktions-Wappen).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_SymbolResolver = {}

local Resolver = ArcadiaNexus.AR_SymbolResolver

-- ============================================================
-- Fraktions-Textur
-- ============================================================

local FACTIONS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions"

local TEXCOORDS = {
    ALLIANCE = { 0,   0.5, 0, 1 },
    HORDE    = { 0.5, 1,   0, 1 },
}

-- ============================================================
-- Standard-Symbole für Vier Gewinnt
-- Klassische Farben: Gelb (Spieler 1) und Rot (Spieler 2)
-- ============================================================

local TEXT_SYMBOLS = {
    player1 = { mode="TEXT", text="O", r=1.00, g=0.85, b=0.00 },  -- Gelb
    player2 = { mode="TEXT", text="O", r=1.00, g=0.15, b=0.15 },  -- Rot
}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function DetectPlayerFaction()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then return "ALLIANCE" end
    if faction == "Horde"    then return "HORDE"    end
    return "ALLIANCE"
end

local function OppositeFaction(faction)
    return faction == "ALLIANCE" and "HORDE" or "ALLIANCE"
end

local function FactionSymbol(faction)
    local tc = TEXCOORDS[faction]
    return {
        mode   = "SPRITE",
        path   = FACTIONS_TEXTURE,
        left   = tc[1],
        right  = tc[2],
        top    = tc[3],
        bottom = tc[4],
    }
end

-- ============================================================
-- PUBLIC API: Resolve
-- ============================================================

function Resolver:Resolve()
    local S = ArcadiaNexus.AR_Settings
    if not S then
        return { player1 = TEXT_SYMBOLS.player1, player2 = TEXT_SYMBOLS.player2 }
    end

    if S:Get("symbolMode") ~= "FACTION" then
        return { player1 = TEXT_SYMBOLS.player1, player2 = TEXT_SYMBOLS.player2 }
    end

    local p1Faction
    if S:Get("symbolAutoDetect") then
        p1Faction = DetectPlayerFaction()
    else
        local manual = S:Get("player1Symbol")
        p1Faction = (manual == "ALLIANCE" or manual == "HORDE") and manual
            or DetectPlayerFaction()
    end

    return {
        player1 = FactionSymbol(p1Faction),
        player2 = FactionSymbol(OppositeFaction(p1Faction)),
    }
end
