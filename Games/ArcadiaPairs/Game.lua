--[[
    Gaming Hub
    Games/Memory/Game.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus

local AP_Game = {}
AP_Game.__index = AP_Game
ArcadiaNexus.AP_Game = AP_Game

function AP_Game:New()
    return setmetatable({}, self)
end

function AP_Game:Init(config)
    self.config     = config or {}
    self.logic      = ArcadiaNexus.AP_Logic
    self.difficulty = self.config.difficulty  or "easy"
    self.theme      = self.config.theme       or "classes"
    self.timerActive= self.config.timerActive or false
    self.board      = self.logic:NewGame({
        difficulty  = self.difficulty,
        theme       = self.theme,
        timerActive = self.timerActive,
    })
end

function AP_Game:FlipCard(idx)
    return self.logic:FlipCard(self.board, idx)
end

function AP_Game:CheckMatch()
    return self.logic:CheckMatch(self.board)
end

function AP_Game:ResetFlipped()
    return self.logic:ResetFlipped(self.board)
end

function AP_Game:SetBlocked(v)
    self.board.blocked = v
end

function AP_Game:IsBlocked()
    return self.board.blocked == true
end

function AP_Game:TickTimer(dt)
    return self.logic:TickTimer(self.board, dt)
end

function AP_Game:GetBoardState()
    return self.logic:GetBoardState(self.board)
end

function AP_Game:Reset()
    self:Init(self.config)
end
