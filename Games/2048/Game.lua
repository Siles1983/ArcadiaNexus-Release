-- 2048 session state. Rules and move traces belong to Logic.
local A = _G.ArcadiaNexus
local Game = {}
Game.__index = Game
A.TDG_Game = Game

function Game:New() return setmetatable({}, self) end

function Game:Init(config)
    self.logic = A.TDG_Logic
    self.config = { size = config.size }
    self.board = self.logic:CreateBoard(config.size)
    self.logic:SpawnTile(self.board)
    self.logic:SpawnTile(self.board)
    self.phase, self.reached2048 = "ACTIVE", false
    self:RefreshBestScore()
end

function Game:Load(save)
    self.logic = A.TDG_Logic
    if not self.logic:ValidateSave(save) then return false end
    self.config = { size = save.boardSize }
    self.board = self.logic:CreateBoard(save.boardSize)
    for r = 1, save.boardSize do
        for c = 1, save.boardSize do self.board.cells[r][c] = save.cells[r][c] end
    end
    self.board.score = save.score
    self.phase, self.reached2048, self.runId = save.phase, save.reached2048, save.runId
    self.resultPending = save.resultPending
    self:RefreshBestScore()
    return true
end

function Game:RefreshBestScore()
    self.bestScore = math.max(self.board.score, A.ScoreManager:GetBestScore("2048",
        self.logic:GetDifficulty(self.board.size)))
end

function Game:HandleMove(direction)
    if self.phase ~= "ACTIVE" then return false end
    self.lastSpawn, self.motions = nil, nil
    local moved, _, motions = self.logic:Move(self.board, direction)
    if not moved then return false end
    self.motions = motions
    local r, c, value = self.logic:SpawnTile(self.board)
    self.lastSpawn = r and { row = r, col = c, value = value } or nil
    local firstWin = not self.reached2048 and self.logic:HasWon(self.board)
    self.reached2048 = self.reached2048 or firstWin
    local hasMoves = self.logic:HasMoves(self.board)
    if firstWin and hasMoves then self.phase = "AWAITING_WIN_CHOICE"
    elseif not hasMoves then self.phase = "FINISHED" end
    self:RefreshBestScore()
    return true
end

function Game:GetBoardState()
    return {
        size = self.board.size, boardSize = self.board.size,
        cells = self.board.cells, board = self.board.cells, merged = self.board.merged,
        score = self.board.score, bestScore = self.bestScore,
        gameOver = self.phase ~= "ACTIVE", phase = self.phase,
        result = self.reached2048 and "WIN" or (self.phase == "FINISHED" and "LOSS" or nil),
        reached2048 = self.reached2048, highestTile = self.logic:HighestTile(self.board),
        difficulty = self.logic:GetDifficulty(self.board.size), runId = self.runId,
        lastSpawn = self.lastSpawn, motions = self.motions,
    }
end

function Game:Snapshot()
    local cells = {}
    for r = 1, self.board.size do
        cells[r] = {}
        for c = 1, self.board.size do cells[r][c] = self.board.cells[r][c] end
    end
    return { saveVersion = 1, runId = self.runId, boardSize = self.board.size,
        difficulty = self.logic:GetDifficulty(self.board.size), cells = cells,
        score = self.board.score, highestTile = self.logic:HighestTile(self.board),
        phase = self.phase, reached2048 = self.reached2048, resultPending = self.resultPending,
        timestamp = GetServerTime() }
end
