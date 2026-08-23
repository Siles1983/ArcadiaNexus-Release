--[[
    ArcadiaNexus – Barrel Brawl
    Games/BarrelBrawl/Engine.lua
    Version: 1.0.0

    State-Machine: IDLE → PLAYING ⇄ PAUSED → GAMEOVER → IDLE

    Session-Ownership:
      StartGame: E._sessionId = Lifecycle:RestartGame("BARREL_BRAWL", E._sessionId)
      StopGame : Lifecycle:EndGame("BARREL_BRAWL", E._sessionId)
      Pause    : Lifecycle:PauseGame / ResumeGame (Session bleibt registriert)

    Timer/Loops:
      GameLoop   – Physik/Bewegung (Gravitation, Laufen, Klettern, Rollen)
      TimerGuard – periodischer Fass-Spawn (Intervall sinkt pro Level)

    Events (BRB_ Prefix):
      BRB_GAME_STARTED(board)
      BRB_GAME_STOPPED()
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BRB_Engine = {}
local E = ArcadiaNexus.BRB_Engine

local GAME_ID = "BARREL_BRAWL"

E._sessionId  = nil
E.board       = nil
E.state       = "IDLE"   -- IDLE | PLAYING | PAUSED | GAMEOVER
E._generation = 0

local _gameLoop   = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_BRB_LoopFrame")
local _timerGuard = ArcadiaNexus.TimerGuard.New()

-- ============================================================
-- Sound
-- ============================================================
local function PlayBRB(event)
    local S = ArcadiaNexus.BRB_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "start" then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    elseif event == "jumped" and S:Get("soundOnScore") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 775, "SFX")
    elseif (event == "hit" or event == "lost" or event == "timeout") and S:Get("soundOnHit") then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847, "SFX")
    elseif event == "rescue" and S:Get("soundOnWin") then
        PlaySound(SOUNDKIT.READY_CHECK or 8960, "SFX")
    end
end

-- ============================================================
-- Loop & Spawner
-- ============================================================
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function() return E.state == "PLAYING" end,
    })
end

--- Fass-Spawner (neu bewaffnet nach jedem Level, Intervall sinkt).
function E:_ArmSpawner()
    _timerGuard:Cancel()
    if not self.board then return end

    -- erstes Fass kurz nach Start/Levelwechsel, danach periodisch
    _timerGuard:After(1.0, function()
        if E.state == "PLAYING" and E.board then
            ArcadiaNexus.BRB_Logic:SpawnBarrel(E.board)
        end
    end)
    _timerGuard:EveryTicker(self.board.spawnInterval, function()
        if E.state == "PLAYING" and E.board then
            ArcadiaNexus.BRB_Logic:SpawnBarrel(E.board)
        end
    end)
end

function E:_Tick(dt)
    if self.state ~= "PLAYING" or not self.board then return end
    local gen   = self._generation
    local board = self.board
    local Logic = ArcadiaNexus.BRB_Logic
    local R     = ArcadiaNexus.BRB_Renderer

    local events = Logic:Update(board, dt)
    if self._generation ~= gen then return end   -- StopGame in einem Callback

    local rearm = false
    for _, ev in ipairs(events) do
        PlayBRB(ev.type)
        if ev.type == "rescue" then rearm = true end
    end
    if rearm then
        self:_ArmSpawner()   -- kuerzeres Intervall des neuen Levels uebernehmen
    end

    if R and R.OnFrame then R:OnFrame(board, events) end

    if board.state == "LOST" then
        self:_HandleGameOver()
    end
end

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(config)
    _timerGuard:Cancel()
    _gameLoop:Stop()
    self._generation = self._generation + 1

    local S = ArcadiaNexus.BRB_Settings
    if type(config) ~= "table" then config = {} end
    local slot = config.slot or (S and S:GetActiveSlot()) or 1
    if S and (slot < 1 or slot > S.MAX_SLOTS) then return end
    local mode = config.mode or "new"
    if S then S:SetActiveSlot(slot) end
    self.activeSlot = slot

    local boardCfg = {
        difficulty = config.difficulty or (S and S:Get("difficulty")) or "normal",
    }
    if mode == "continue" and S then
        local saved = S:LoadProgress(slot)
        if saved then
            boardCfg.difficulty = saved.diff or boardCfg.difficulty
            boardCfg.level      = saved.level
            boardCfg.score      = saved.score
            boardCfg.lives      = saved.lives
            boardCfg.time       = saved.time
            boardCfg.stats      = saved.stats
        end
    elseif mode == "new" and S then
        S:ResetSlot(slot)
    end

    local board = ArcadiaNexus.BRB_Logic:NewBoard(boardCfg)
    if not board then return end   -- Validierung vor BeginGame

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame(GAME_ID, E._sessionId)
    self.board = board
    self.state = "PLAYING"

    PlayBRB("start")
    ArcadiaNexus.Engine:Emit("BRB_GAME_STARTED", board)

    self:_StartLoop()
    self:_ArmSpawner()
end

-- ============================================================
-- Pause (P) – Session bleibt registriert
-- ============================================================
function E:TogglePause()
    local R = ArcadiaNexus.BRB_Renderer
    if self.state == "PLAYING" then
        if E._sessionId then
            ArcadiaNexus.Lifecycle:PauseGame(GAME_ID, E._sessionId)
        end
        self.state = "PAUSED"
        if R and R.OnPauseChanged then R:OnPauseChanged(true) end
    elseif self.state == "PAUSED" then
        if E._sessionId then
            ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID, E._sessionId)
        end
        self.state = "PLAYING"
        if R and R.OnPauseChanged then R:OnPauseChanged(false) end
    end
end

-- ============================================================
-- Game Over
-- ============================================================
function E:_HandleGameOver()
    self.state = "GAMEOVER"
    local board = self.board
    if not board then return end

    local S = ArcadiaNexus.BRB_Settings
    if S then S:ClearProgress() end

    _timerGuard:Cancel()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end

    local payload = {
        gameId     = GAME_ID,
        difficulty = board.difficulty,
        score      = board.score or 0,
        result     = (board.stats.rescues > 0) and "WIN" or "LOSS",
        stats      = {
            levelReached  = board.level,
            rescues       = board.stats.rescues,
            barrelsJumped = board.stats.jumped,
        },
    }
    ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
    local isNew = payload.newHighscore == true

    local R = ArcadiaNexus.BRB_Renderer
    if R and R.OnGameOver then R:OnGameOver(board, isNew) end
end

-- ============================================================
-- Eingabe (vom Renderer-KeyFrame)
-- ============================================================
function E:HandleKeyDown(key)
    if key == "ESCAPE" then
        if self.state ~= "IDLE" then
            self:SaveAndPause()
            local R = ArcadiaNexus.BRB_Renderer
            if R and R.EnterIdleState then R:EnterIdleState() end
        end
        return
    end
    if key == "P" then
        self:TogglePause()
        return
    end
    if self.state ~= "PLAYING" or not self.board then return end
    local Logic = ArcadiaNexus.BRB_Logic

    if key == "A" or key == "LEFT" then
        Logic:Press(self.board, "left")
    elseif key == "D" or key == "RIGHT" then
        Logic:Press(self.board, "right")
    elseif key == "W" or key == "UP" then
        Logic:Press(self.board, "up")
    elseif key == "S" or key == "DOWN" then
        Logic:Press(self.board, "down")
    elseif key == "SPACE" then
        Logic:QueueJump(self.board)
    end
end

function E:HandleKeyUp(key)
    if not self.board then return end
    local Logic = ArcadiaNexus.BRB_Logic

    if key == "A" or key == "LEFT" then
        Logic:Release(self.board, "left")
    elseif key == "D" or key == "RIGHT" then
        Logic:Release(self.board, "right")
    elseif key == "W" or key == "UP" then
        Logic:Release(self.board, "up")
    elseif key == "S" or key == "DOWN" then
        Logic:Release(self.board, "down")
    end
end

-- ============================================================
-- StopGame (Abbruch oder nach Game-Over-Dialog)
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    _timerGuard:Cancel()
    _gameLoop:Stop()
    self.state       = "IDLE"
    self.board       = nil
    self._generation = self._generation + 1

    ArcadiaNexus.Engine:Emit("BRB_GAME_STOPPED")
end

function E:SaveAndPause()
    local board = self.board
    local S     = ArcadiaNexus.BRB_Settings
    if board and S and self.state ~= "GAMEOVER" then
        S:SaveProgress({
            level = board.level,
            score = board.score,
            lives = board.lives,
            diff  = board.difficulty,
            time  = board.time,
            stats = board.stats,
        })
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame(GAME_ID, E._sessionId)
    end
    _timerGuard:Cancel()
    _gameLoop:Stop()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    self.state       = "IDLE"
    self.board       = nil
    self._generation = self._generation + 1
end
