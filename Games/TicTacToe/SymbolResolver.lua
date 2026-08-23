--[[
    Gaming Hub
    Games/TicTacToe/SymbolResolver.lua
    Version: 1.2.0 (Factions-Sprite mit TexCoord)

    Textur-Strategie für Fraktions-Wappen:
      Interface\Glues\CharacterCreate\UI-CharacterCreate-Factions.blp
      Diese Datei existiert seit WoW 1.0 und ist in allen Retail-Versionen garantiert.
      Sie enthält beide Wappen nebeneinander (Allianz links, Horde rechts).
      Über SetTexCoord() wird das gewünschte Wappen ausgeschnitten.

      Allianz: linke Hälfte  → SetTexCoord(0, 0.5, 0, 1)
      Horde:   rechte Hälfte → SetTexCoord(0.5, 1, 0, 1)

    SymbolDef-Typen:
      TEXT:    { mode="TEXT",    text="X"|"O", r, g, b }
      SPRITE:  { mode="SPRITE",  path="Interface\\...", left, right, top, bottom }

    Öffentliche API:
      ArcadiaNexus.TicTacToeSymbolResolver:Resolve()
      → { player1 = SymbolDef, player2 = SymbolDef }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TicTacToeSymbolResolver = {}

local Resolver = ArcadiaNexus.TicTacToeSymbolResolver

-- ============================================================
-- TEXTUR-PFAD (garantiert vorhanden in allen Retail-Versionen)
-- ============================================================

local FACTIONS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions"

-- TexCoords: { left, right, top, bottom }
local TEXCOORDS = {
    ALLIANCE = { 0,   0.5, 0, 1 },  -- linke Hälfte
    HORDE    = { 0.5, 1,   0, 1 },  -- rechte Hälfte
}

-- ============================================================
-- Standard TEXT-Symbole
-- ============================================================

local TEXT_SYMBOLS = {
    player1 = { mode="TEXT", text="X", r=0.20, g=0.60, b=1.00 },
    player2 = { mode="TEXT", text="O", r=1.00, g=0.25, b=0.25 },
}

-- ============================================================
-- INTERNE: Charakter-Fraktion ermitteln
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

-- ============================================================
-- INTERNE: SPRITE-SymbolDef für eine Fraktion bauen
-- ============================================================

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
    local S = ArcadiaNexus.TicTacToeSettings
    if not S then
        return { player1=TEXT_SYMBOLS.player1, player2=TEXT_SYMBOLS.player2 }
    end

    if S:Get("symbolMode") ~= "FACTION" then
        return { player1=TEXT_SYMBOLS.player1, player2=TEXT_SYMBOLS.player2 }
    end

    -- Fraktion bestimmen
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
