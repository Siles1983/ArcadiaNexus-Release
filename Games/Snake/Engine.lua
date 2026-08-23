--[[
    Gaming Hub – Snake
    Games/Snake/Engine.lua

    Events (SNK_ Prefix):
      SNK_GAME_STARTED(board)
      SNK_GAME_WON(board, isNewHighscore)
      SNK_GAME_LOST(board, isNewHighscore)
      SNK_GAME_STOPPED()

    Renderer wird für zeitkritische Darstellung direkt aufgerufen.
    C_Timer.After → Ticker-Loop.
    Tastatur-Input via KeyDown-Hook auf dem Game-Frame.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Engine = {}
local E = ArcadiaNexus.SNK_Engine

E._sessionId = nil

E.activeGame      = nil
E._running        = false
E._tickRate       = 0.18
E._tickGeneration = 0  -- Erhöht sich bei jedem StartGame. Verhindert dass Callbacks
                       -- eines alten Spiels in den neuen Tick-Loop einlaufen.

-- ============================================================
-- Sound
-- ============================================================
local function PlaySNK(event)
    local S = ArcadiaNexus.SNK_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "eat" and S:Get("soundOnEat") then
        PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX")
    elseif event == "die" and S:Get("soundOnDie") then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847, "SFX")
    elseif event == "start" and S:Get("soundOnStart") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    end
end

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(config)
    self:StopGame()

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("SNAKE", E._sessionId)

    local S   = ArcadiaNexus.SNK_Settings
    local T   = ArcadiaNexus.SNK_Themes
    local cfg = {
        difficulty = (config and config.difficulty) or S:Get("difficulty"),
        theme      = (config and config.theme)      or S:Get("theme"),
    }

    local board    = ArcadiaNexus.SNK_Logic:NewBoard(cfg)
    local diff     = T:GetDiff(cfg.difficulty)
    self.activeGame      = { board = board }
    self._running        = true
    self._tickRate       = diff.tickRate
    self._tickGeneration = self._tickGeneration + 1  -- Invalidiert alle alten Timer-Closures

    PlaySNK("start")
    ArcadiaNexus.Engine:Emit("SNK_GAME_STARTED", board)

    -- Tick-Loop starten
    self:ScheduleTick()
end

-- ============================================================
-- ScheduleTick – plant den nächsten Tick
-- ============================================================
function E:ScheduleTick()
    if not self._running then return end
    local gen = self._tickGeneration  -- Generation zum Zeitpunkt der Planung einfrieren
    C_Timer.After(self._tickRate, function()
        -- Abbrechen wenn dieser Callback zu einem alten Spiel gehört
        if not self._running or self._tickGeneration ~= gen then return end
        self:DoTick()
    end)
end

-- ============================================================
-- DoTick – einen Spielschritt
-- ============================================================
function E:DoTick()
    if not self.activeGame or not self._running then return end
    local board  = self.activeGame.board
    local R      = ArcadiaNexus.SNK_Renderer

    -- Schwanz merken BEVOR Logic den Tick macht
    if R then
        local snake = board.snake
        if snake[#snake] then
            R._lastTail = { r=snake[#snake].r, c=snake[#snake].c }
        end
    end

    local result = ArcadiaNexus.SNK_Logic:Tick(board)

    if R then R:OnTick(board, result) end

    if result == "ate" then
        PlaySNK("eat")
        self:ScheduleTick()
    elseif result == "moved" then
        self:ScheduleTick()
    elseif result == "died" then
        PlaySNK("die")
        self._running = false
        local payload = {
            gameId = "SNAKE", difficulty = board.difficulty,
            score = board.score or 0, result = "LOSS",
            stats = {
                length = board.snake and #board.snake or 0,
                fruitsEaten = board.fruitsEaten or 0,
            },
        }
        ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
        local isNew = payload.newHighscore == true
        if R then R:OnGameLost(board, isNew) end
        ArcadiaNexus.Engine:Emit("SNK_GAME_LOST", board, isNew)
    elseif result == "won" then
        self._running = false
        local payload = {
            gameId = "SNAKE", difficulty = board.difficulty,
            score = board.score or 0, result = "WIN",
            stats = {
                length = board.snake and #board.snake or 0,
                fruitsEaten = board.fruitsEaten or 0,
            },
        }
        ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
        local isNew = payload.newHighscore == true
        if R then R:OnGameWon(board, isNew) end
        ArcadiaNexus.Engine:Emit("SNK_GAME_WON", board, isNew)
    end
end

-- ============================================================
-- HandleKey – Richtungseingabe
-- ============================================================
function E:HandleKey(key)
    if not self.activeGame or not self._running then return end
    local board = self.activeGame.board
    local L     = ArcadiaNexus.SNK_Logic
    if     key == "W" or key == "UP"    then L:QueueDir(board, -1,  0)
    elseif key == "S" or key == "DOWN"  then L:QueueDir(board,  1,  0)
    elseif key == "A" or key == "LEFT"  then L:QueueDir(board,  0, -1)
    elseif key == "D" or key == "RIGHT" then L:QueueDir(board,  0,  1)
    end
end

-- ============================================================
-- StopGame
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SNAKE", E._sessionId)
        E._sessionId = nil
    end
    self._running   = false
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("SNK_GAME_STOPPED")
    local R = ArcadiaNexus.SNK_Renderer
    if R and R.EnterIdleState then R:EnterIdleState() end
end
