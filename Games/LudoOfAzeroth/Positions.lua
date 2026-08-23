--[[
    Ludo of Azeroth – Positions.lua
    Pixel-Koordinaten relativ zum fieldFrame (TOPLEFT, y nach unten positiv).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Positions = {}
local P = ArcadiaNexus.LOA_Positions

P.MAIN = {
    [1] = { x = 332, y = 25 },
    [2] = { x = 332, y = 50 },
    [3] = { x = 332, y = 85 },
    [4] = { x = 332, y = 115 },
    [5] = { x = 352, y = 145 },
    [6] = { x = 380, y = 173 },
    [7] = { x = 410, y = 173 },
    [8] = { x = 440, y = 173 },
    [9] = { x = 475, y = 173 },
    [10] = { x = 475, y = 205 },
    [11] = { x = 475, y = 230 },
    [12] = { x = 445, y = 230 },
    [13] = { x = 413, y = 230 },
    [14] = { x = 383, y = 230 },
    [15] = { x = 353, y = 260 },
    [16] = { x = 330, y = 290 },
    [17] = { x = 330, y = 325 },
    [18] = { x = 330, y = 355 },
    [19] = { x = 330, y = 390 },
    [20] = { x = 300, y = 390 },
    [21] = { x = 265, y = 390 },
    [22] = { x = 265, y = 355 },
    [23] = { x = 265, y = 325 },
    [24] = { x = 265, y = 290 },
    [25] = { x = 240, y = 260 },
    [26] = { x = 218, y = 230 },
    [27] = { x = 178, y = 230 },
    [28] = { x = 144, y = 230 },
    [29] = { x = 127, y = 230 },
    [30] = { x = 127, y = 210 },
    [31] = { x = 127, y = 173 },
    [32] = { x = 145, y = 173 },
    [33] = { x = 188, y = 173 },
    [34] = { x = 218, y = 173 },
    [35] = { x = 247, y = 145 },
    [36] = { x = 267, y = 115 },
    [37] = { x = 267, y = 85 },
    [38] = { x = 267, y = 25 },
    [39] = { x = 267, y = 25 },
    [40] = { x = 300, y = 25 },
}

P.HOME = {
    [1] = { -- Stormwind
        [1] = { x = 150, y = 200 },
        [2] = { x = 185, y = 200 },
        [3] = { x = 220, y = 200 },
        [4] = { x = 246, y = 200 },
    },
    [2] = { -- Orgrimmar
        [1] = { x = 300, y = 93 },
        [2] = { x = 300, y = 120 },
        [3] = { x = 300, y = 149 },
        [4] = { x = 300, y = 177 },
    },
    [3] = { -- Thunder Bluff
        [1] = { x = 297, y = 381 },
        [2] = { x = 297, y = 335 },
        [3] = { x = 297, y = 290 },
        [4] = { x = 297, y = 260 },
    },
    [4] = { -- Ironforge
        [1] = { x = 445, y = 200 },
        [2] = { x = 420, y = 200 },
        [3] = { x = 377, y = 200 },
        [4] = { x = 355, y = 200 },
    },
}

P.BASE = {
    [1] = {
        [1] = { x = 120, y = 100 },
        [2] = { x = 165, y = 100 },
        [3] = { x = 120, y = 140 },
        [4] = { x = 165, y = 140 },
    },
    [2] = {
        [1] = { x = 440, y = 100 },
        [2] = { x = 485, y = 100 },
        [3] = { x = 440, y = 140 },
        [4] = { x = 485, y = 140 },
    },
    [3] = {
        [1] = { x = 115, y = 365 },
        [2] = { x = 160, y = 365 },
        [3] = { x = 115, y = 405 },
        [4] = { x = 160, y = 405 },
    },
    [4] = {
        [1] = { x = 440, y = 365 },
        [2] = { x = 485, y = 365 },
        [3] = { x = 440, y = 405 },
        [4] = { x = 485, y = 405 },
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
