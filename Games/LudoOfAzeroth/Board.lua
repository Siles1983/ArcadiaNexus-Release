--[[
    Ludo of Azeroth – Board.lua
    Logische Brett-Topologie für den gemeinsamen 40-Feld-Hauptpfad.

    Farben auf dem Asset (background_loa.tga):
      1 = Blau   → Basis oben links
      2 = Rot    → Basis oben rechts
      3 = Grün   → Basis unten links
      4 = Gelb   → Basis unten rechts

    PLAYER_OFFSET bestimmt, welches MAIN[i] bei relPos=1 (Einstieg) gilt.
    Abgeleitet aus kalibrierten Pixel-Positionen (HOME-Eingang / Außenbahn).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Board = {}
local B = ArcadiaNexus.LOA_Board

-- Legacy Grid-Indizes (nur noch für gridIdx in der Spiellogik / Schlagen)
B.MAIN_PATH = {
    45, 46, 47, 48, 49,
    39, 28, 17, 6,
    7,
    8,
    19, 30, 41, 52,
    53, 54, 55, 56,
    67,
    78,
    77, 76, 75, 74,
    84, 95, 106, 117,
    116,
    115,
    104, 93, 82, 71,
    70, 69, 68, 67,
    56,
}

B.HOME_PATH = {
    [1] = { 57, 58, 59, 60 },
    [2] = { 17, 28, 39, 50 },
    [3] = { 75, 74, 73, 72 },
    [4] = { 105, 94, 83, 72 },
}

B.BASE_FIELDS = {
    [1] = { 1,  2,  12, 13  },
    [2] = { 10, 11, 21, 22  },
    [3] = { 100, 101, 111, 112 },
    [4] = { 110, 111, 120, 121 },
}

-- relPos=1 → Positions.MAIN[offset + 1]  (Debug-verifiziert)
-- Blau: MAIN[31] | Rot: MAIN[1] | Grün: MAIN[21] | Gelb: MAIN[11]
B.PLAYER_OFFSET = {
    [1] = 30,   -- Blau  – { x = 86,  y = 210 }
    [2] = 0,    -- Rot   – { x = 338, y = 46  }
    [3] = 20,   -- Grün  – { x = 258, y = 448 }
    [4] = 10,   -- Gelb  – { x = 514, y = 273 }
}

B.PLAYER_ENTRY_MAIN = {
    [1] = 31,
    [2] = 1,
    [3] = 21,
    [4] = 11,
}

B.PLAYER_ENTRY = {}
for pID = 1, 4 do
    local globalIdx = B.PLAYER_ENTRY_MAIN[pID]
    B.PLAYER_ENTRY[pID] = B.MAIN_PATH[globalIdx] or globalIdx
end

B.CENTER_FIELD = 61

-- Einstiegsfelder sind keine Safe-Zone: dort wird ebenfalls geschlagen.
B.SAFE_FIELDS = {}

function B:GetMainGlobalIdx(colorIdx, relPos)
    if relPos <= 0 or relPos > 40 then return nil end
    local offset = self.PLAYER_OFFSET[colorIdx] or 0
    return ((relPos + offset - 1) % 40) + 1
end

function B:GetGridIndex(playerID, relPos)
    if relPos <= 40 then
        local globalIdx = self:GetMainGlobalIdx(playerID, relPos)
        return self.MAIN_PATH[globalIdx]
    end
    local homeIdx  = relPos - 40
    local homePath = self.HOME_PATH[playerID]
    if homePath and homePath[homeIdx] then
        return homePath[homeIdx]
    end
    return nil
end

function B:IsGameField(gridIdx)
    for _, v in ipairs(self.MAIN_PATH) do
        if v == gridIdx then return true end
    end
    for _, path in ipairs(self.HOME_PATH) do
        for _, v in ipairs(path) do
            if v == gridIdx then return true end
        end
    end
    for _, base in ipairs(self.BASE_FIELDS) do
        for _, v in ipairs(base) do
            if v == gridIdx then return true end
        end
    end
    if gridIdx == self.CENTER_FIELD then return true end
    return false
end

B.PLAYER_COLORS = {
    [1] = { 0.2, 0.5, 1.0 },
    [2] = { 1.0, 0.2, 0.2 },
    [3] = { 0.2, 0.9, 0.2 },
    [4] = { 1.0, 0.9, 0.1 },
}

B.PLAYER_NAMES = {
    [1] = "Stormwind",
    [2] = "Orgrimmar",
    [3] = "Thunder Bluff",
    [4] = "Ironforge",
}

function B:GetFactionName(colorIdx)
    local loc = ArcadiaNexus.GetLocaleTable("LOA")
    local key = ({ [1] = "faction_stormwind", [2] = "faction_orgrimmar",
        [3] = "faction_thunder_bluff", [4] = "faction_ironforge" })[colorIdx]
    return (key and loc[key]) or self.PLAYER_NAMES[colorIdx] or "?"
end

B.CORNER_NAMES = {
    [1] = "oben links",
    [2] = "oben rechts",
    [3] = "unten links",
    [4] = "unten rechts",
}
