--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    Games/Codebreaker/Game.lua
    Dünner Wrapper um Logic. Hält das Board als self.board.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CB_Game = {}
local G = ArcadiaNexus.CB_Game

function G:New()
    local obj = setmetatable({}, { __index = G })
    obj.board = nil
    return obj
end

function G:Init(config)
    local L      = ArcadiaNexus.CB_Logic
    local T      = ArcadiaNexus.CB_Themes
    local theme  = T:GetTheme(config.theme)
    local cfg = {
        difficulty   = config.difficulty,
        codeLength   = config.codeLength,
        duplicates   = config.duplicates,
        theme        = config.theme,
        themeName    = theme.name,
        symbolCount  = T:GetSymbolCount(config.theme),
    }
    self.board = L:NewBoard(cfg)
end

function G:SetSlot(slotIdx, symbolIdx)
    return ArcadiaNexus.CB_Logic:SetSlot(self.board, slotIdx, symbolIdx)
end

function G:ClearSlot(slotIdx)
    return ArcadiaNexus.CB_Logic:ClearSlot(self.board, slotIdx)
end

function G:IsGuessComplete()
    return ArcadiaNexus.CB_Logic:IsGuessComplete(self.board)
end

function G:SubmitGuess()
    return ArcadiaNexus.CB_Logic:SubmitGuess(self.board)
end

function G:GetBoardState()
    return ArcadiaNexus.CB_Logic:GetBoardState(self.board)
end
