--[[
    Ludo of Azeroth – Positions.lua
    Pixel-Koordinaten relativ zum fieldFrame (TOPLEFT, y nach unten positiv).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Positions = {}
local P = ArcadiaNexus.LOA_Positions

P.MAIN = {
    [1] = { x = 333, y = 40 },
    [2] = { x = 334, y = 95 },
    [3] = { x = 334, y = 120 },
    [4] = { x = 334, y = 140 },
    [5] = { x = 355, y = 150 },
    [6] = { x = 386, y = 180 },
    [7] = { x = 419, y = 180 },
    [8] = { x = 453, y = 180 },
    [9] = { x = 486, y = 180 },
    [10] = { x = 489, y = 210 },
    [11] = { x = 489, y = 235 },
    [12] = { x = 455, y = 235 },
    [13] = { x = 421, y = 235 },
    [14] = { x = 385, y = 235 },
    [15] = { x = 359, y = 260 },
    [16] = { x = 336, y = 290 },
    [17] = { x = 335, y = 325 },
    [18] = { x = 337, y = 355 },
    [19] = { x = 337, y = 385 },
    [20] = { x = 300, y = 385 },
    [21] = { x = 264, y = 385 },
    [22] = { x = 264, y = 355 },
    [23] = { x = 264, y = 325 },
    [24] = { x = 264, y = 290 },
    [25] = { x = 240, y = 260 },
    [26] = { x = 213, y = 235 },
    [27] = { x = 178, y = 235 },
    [28] = { x = 144, y = 235 },
    [29] = { x = 110, y = 235 },
    [30] = { x = 111, y = 210 },
    [31] = { x = 111, y = 180 },
    [32] = { x = 145, y = 180 },
    [33] = { x = 178, y = 180 },
    [34] = { x = 212, y = 180 },
    [35] = { x = 243, y = 150 },
    [36] = { x = 265, y = 125 },
    [37] = { x = 265, y = 95 },
    [38] = { x = 265, y = 40 },
    [39] = { x = 265, y = 40 },
    [40] = { x = 300, y = 40 },
}

P.HOME = {
    [1] = {
        [1] = { x = 145, y = 205 },
        [2] = { x = 180, y = 205 },
        [3] = { x = 214, y = 205 },
        [4] = { x = 246, y = 205 },
    },
    [2] = {
        [1] = { x = 300, y = 93 },
        [2] = { x = 300, y = 120 },
        [3] = { x = 301, y = 149 },
        [4] = { x = 300, y = 177 },
    },
    [3] = {
        [1] = { x = 295, y = 381 },
        [2] = { x = 295, y = 335 },
        [3] = { x = 295, y = 295 },
        [4] = { x = 295, y = 260 },
    },
    [4] = {
        [1] = { x = 454, y = 234 },
        [2] = { x = 421, y = 234 },
        [3] = { x = 388, y = 234 },
        [4] = { x = 355, y = 234 },
    },
}

P.BASE = {
    [1] = {
        [1] = { x = 103, y = 110 },
        [2] = { x = 151, y = 110 },
        [3] = { x = 105, y = 150 },
        [4] = { x = 154, y = 150 },
    },
    [2] = {
        [1] = { x = 448, y = 110 },
        [2] = { x = 497, y = 110 },
        [3] = { x = 448, y = 150 },
        [4] = { x = 497, y = 150 },
    },
    [3] = {
        [1] = { x = 100, y = 360 },
        [2] = { x = 151, y = 360 },
        [3] = { x = 99, y = 400 },
        [4] = { x = 151, y = 400 },
    },
    [4] = {
        [1] = { x = 450, y = 360 },
        [2] = { x = 501, y = 360 },
        [3] = { x = 451, y = 400 },
        [4] = { x = 501, y = 400 },
    },
}

P.DICE = { x = 300, y = 230 }

P.COLOR_NAMES = {
    [1] = "Stormwind",
    [2] = "Orgrimmar",
    [3] = "Thunder Bluff",
    [4] = "Ironforge",
}

function P:GetMain(globalIdx)
    return self.MAIN[globalIdx]
end

function P:SetMain(globalIdx, pos)
    self.MAIN[globalIdx] = pos
end

function P:GetHome(colorIdx, slot)
    local t = self.HOME[colorIdx]
    return t and t[slot]
end

function P:SetHome(colorIdx, slot, pos)
    if not self.HOME[colorIdx] then self.HOME[colorIdx] = {} end
    self.HOME[colorIdx][slot] = pos
end

function P:GetBase(colorIdx, slot)
    local t = self.BASE[colorIdx]
    return t and t[slot]
end

function P:SetBase(colorIdx, slot, pos)
    if not self.BASE[colorIdx] then self.BASE[colorIdx] = {} end
    self.BASE[colorIdx][slot] = pos
end

function P:GetDice()
    return self.DICE
end

function P:SetDice(pos)
    self.DICE = pos
end

function P:GetPixelPos(colorIdx, relPos, baseSlot)
    if relPos == 0 then
        return self:GetBase(colorIdx, baseSlot or 1)
    end

    local board = ArcadiaNexus.LOA_Board
    if not board then return nil end

    if relPos <= 40 then
        local globalIdx = board:GetMainGlobalIdx(colorIdx, relPos)
        return self:GetMain(globalIdx)
    end

    if relPos <= 44 then
        return self:GetHome(colorIdx, relPos - 40)
    end

    return nil
end

function P:ExportLua()
    local lines = { "-- LOA_Positions (exportiert ingame)" }

    lines[#lines+1] = "P.MAIN = {"
    for i = 1, 40 do
        local pos = self.MAIN[i]
        if pos then
            lines[#lines+1] = string.format("    [%d] = { x = %d, y = %d },", i, pos.x, pos.y)
        end
    end
    lines[#lines+1] = "}"

    for c = 1, 4 do
        lines[#lines+1] = string.format("P.HOME[%d] = {", c)
        for s = 1, 4 do
            local pos = self.HOME[c] and self.HOME[c][s]
            if pos then
                lines[#lines+1] = string.format("    [%d] = { x = %d, y = %d },", s, pos.x, pos.y)
            end
        end
        lines[#lines+1] = "}"
    end

    for c = 1, 4 do
        lines[#lines+1] = string.format("P.BASE[%d] = {", c)
        for s = 1, 4 do
            local pos = self.BASE[c] and self.BASE[c][s]
            if pos then
                lines[#lines+1] = string.format("    [%d] = { x = %d, y = %d },", s, pos.x, pos.y)
            end
        end
        lines[#lines+1] = "}"
    end

    if self.DICE then
        lines[#lines+1] = string.format(
            "P.DICE = { x = %d, y = %d }",
            self.DICE.x, self.DICE.y)
    end

    return table.concat(lines, "\n")
end
