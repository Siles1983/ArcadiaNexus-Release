--[[
    Gaming Hub
    Games/Minesweeper/Game.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus

local MSGame = {}
MSGame.__index = MSGame
ArcadiaNexus.MS_Game = MSGame

function MSGame:New()
    return setmetatable({}, self)
end

function MSGame:Init(config)
    self.config     = config or {}
    self.logic      = ArcadiaNexus.MS_Logic
    self.difficulty = self.config.difficulty or "easy"
    self.board      = self.logic:NewBoard(self.difficulty)
    self.elapsedMs  = 0
end

function MSGame:RevealCell(r, c)
    if self.board.phase ~= "PLAYING" then return "game_over" end
    return self.logic:RevealCell(self.board, r, c)
end

function MSGame:ToggleFlag(r, c)
    if self.board.phase ~= "PLAYING" then return "game_over" end
    return self.logic:ToggleFlag(self.board, r, c)
end

function MSGame:GetBoardState()
    local state=self.logic:GetBoardState(self.board)
    state.elapsedMs,state.runId,state.resultPending=self.elapsedMs,self.runId,self.resultPending
    state.score=self.logic:GetScore(self.board)
    return state
end

function MSGame:Snapshot(elapsedMs)
    local state=self:GetBoardState()
    state.saveVersion,state.timestamp=1,GetServerTime()
    state.elapsedMs=elapsedMs or self.elapsedMs
    return state
end

function MSGame:Load(save)
    if not ArcadiaNexus.MS_Logic:ValidateSave(save) then return false end
    self.logic=ArcadiaNexus.MS_Logic
    self.board=self.logic:GetBoardState(save)
    self.difficulty,self.elapsedMs,self.runId,self.resultPending=save.difficulty,save.elapsedMs,save.runId,save.resultPending
    return true
end

function MSGame:Reset()
    self:Init(self.config)
end
