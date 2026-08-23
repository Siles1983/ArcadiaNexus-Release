--[[
    ArcadiaNexus – Goblin Blast
    Games/GoblinBlast/Engine.lua
    Version: 2.0.0  (Level-System, Resume, Timer)

    State-Machine: IDLE → PLAYING → LEVELWIN → PLAYING …
                                  ↘ GAMEOVER

    Events (GB_ Prefix):
      GB_GAME_STARTED(board)
      GB_GAME_STOPPED()

    Regeln (analog BlockBreaker):
      - GAME_RESULT "WIN" pro geschafftem Level, "LOSS" bei Game Over
      - StopGame mitten im Level speichert den Fortschritt (Resume)
      - Level-Sieg speichert den Fortschritt fuer das naechste Level
      - Game Over / Sieg im letzten Level loescht den Spielstand
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GB_Engine = {}
local E = ArcadiaNexus.GB_Engine

E._sessionId = nil

E.board       = nil
E.state       = "IDLE"   -- IDLE | PLAYING | LEVELWIN | GAMEOVER
E._generation = 0

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_GB_LoopFrame")

-- ============================================================
-- Sound
-- ============================================================
local function PlayGB(event)
    local S = ArcadiaNexus.GB_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "start" then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    elseif event == "explosion" and S:Get("soundOnExplode") then
        PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX")
    elseif event == "powerup" and S:Get("soundOnPowerup") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 775, "SFX")
    elseif (event == "hit" or event == "lost") and S:Get("soundOnDie") then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847, "SFX")
    elseif (event == "level_won" or event == "final_won") and S:Get("soundOnWin") then
        PlaySound(SOUNDKIT.READY_CHECK or 8960, "SFX")
    end
end

-- ============================================================
-- Fortschritt (Resume)
-- ============================================================
function E:_SaveProgress(level)
    local S     = ArcadiaNexus.GB_Settings
    local board = self.board
    if not S or not board then return end
    S:SaveProgress({
        level    = level or board.level,
        score    = board.score,
        lives    = board.lives,
        diff     = board.difficulty,
        radius   = board.player.radius,
        bombsMax = board.player.bombsMax,
        time     = board.time,
        stats    = board.stats,
    })
end

-- ============================================================
-- Update-Loop
-- ============================================================
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function() return E.state == "PLAYING" end,
    })
end

function E:_StopLoop()
    _gameLoop:Stop()
end

function E:_Tick(dt)
    if self.state ~= "PLAYING" or not self.board then return end
    local gen    = self._generation
    local board  = self.board
    local Logic  = ArcadiaNexus.GB_Logic
    local R      = ArcadiaNexus.GB_Renderer

    -- Sehr grosse dt (Ladehaenger) begrenzen, sonst springen Timer
    if dt > 0.1 then dt = 0.1 end

    local events = Logic:Update(board, dt)
    if self._generation ~= gen then return end   -- StopGame in einem Event-Callback

    for _, ev in ipairs(events) do
        if ev.type ~= "level_won" then PlayGB(ev.type) end
    end

    if R and R.OnFrame then R:OnFrame(board, events) end

    if board.state == "LEVEL_WON" then
        self:_HandleLevelWin()
    elseif board.state == "LOST" then
        self:_HandleGameOver()
    end
end

-- ============================================================
-- StartGame – neuer Durchlauf oder Resume
-- ============================================================
function E:StartGame(config, resumeSaved)
    local S = ArcadiaNexus.GB_Settings
    if type(config) ~= "table" then
        config = { slot = S and S:GetActiveSlot() or 1, mode = resumeSaved and "continue" or "new" }
    end
    local slot = config.slot or (S and S:GetActiveSlot()) or 1
    if S and (slot < 1 or slot > S.MAX_SLOTS) then return end
    local mode = config.mode or (resumeSaved and "continue" or "new")
    if S then S:SetActiveSlot(slot) end
    self.activeSlot = slot

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("GOBLINBLAST", E._sessionId)

    -- laufende Session verwerfen (ohne Speichern/Events)
    self._generation = self._generation + 1
    self:_StopLoop()

    local cfg = {
        difficulty = config.difficulty or (S and S:Get("difficulty")) or "easy",
    }

    if mode == "continue" and S then
        local saved = S:LoadProgress(slot)
        if saved then
            cfg.difficulty = saved.diff or cfg.difficulty
            cfg.level      = saved.level
            cfg.score      = saved.score
            cfg.lives      = saved.lives
            cfg.radius     = saved.radius
            cfg.bombsMax   = saved.bombsMax
            cfg.time       = saved.time
            cfg.stats      = saved.stats
        end
    elseif mode == "new" and S then
        S:ResetSlot(slot)
    end

    self.board = ArcadiaNexus.GB_Logic:NewBoard(cfg)
    self.state = "PLAYING"

    PlayGB("start")
    ArcadiaNexus.Engine:Emit("GB_GAME_STARTED", self.board)

    self:_StartLoop()
end

-- ============================================================
-- Level geschafft
-- ============================================================
function E:_HandleLevelWin()
    local board  = self.board
    local S      = ArcadiaNexus.GB_Settings
    local R      = ArcadiaNexus.GB_Renderer
    local Levels = ArcadiaNexus.GB_Levels
    if not board then return end

    local isFinal = board.level >= Levels.COUNT
    PlayGB(isFinal and "final_won" or "level_won")

    local payload = {
        gameId     = "GOBLINBLAST",
        difficulty = board.difficulty,
        score      = board.score or 0,
        result     = "WIN",
        stats      = {
            walls        = board.stats.walls,
            enemies      = board.stats.enemies,
            powerups     = board.stats.powerups,
            maxChain     = board.stats.maxChain,
            levelReached = board.level,
        },
    }
    ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
    local isNew = payload.newHighscore == true

    if isFinal then
        self.state = "GAMEOVER"
        if S then S:ClearProgress() end
        if E._sessionId then
            ArcadiaNexus.Lifecycle:EndGame("GOBLINBLAST", E._sessionId)
            E._sessionId = nil
        end
        if R and R.ShowFinalWin then R:ShowFinalWin(board, isNew) end
    else
        self.state = "LEVELWIN"
        self:_SaveProgress(board.level + 1)   -- Resume startet im naechsten Level
        if R and R.ShowLevelWin then R:ShowLevelWin(board, isNew) end
    end
end

-- ============================================================
-- Naechstes Level (vom Renderer-Button aufgerufen)
-- ============================================================
function E:ContinueToNextLevel()
    local board = self.board
    if self.state ~= "LEVELWIN" or not board then return end

    self.board = ArcadiaNexus.GB_Logic:NewBoard({
        difficulty = board.difficulty,
        level      = board.level + 1,
        score      = board.score,
        lives      = board.lives,
        radius     = board.player.radius,
        bombsMax   = board.player.bombsMax,
        time       = board.time,
        stats      = board.stats,
    })
    self.state = "PLAYING"

    local R = ArcadiaNexus.GB_Renderer
    if R and R.OnLevelAdvanced then R:OnLevelAdvanced(self.board) end
    self:_StartLoop()
end

-- ============================================================
-- Game Over
-- ============================================================
function E:_HandleGameOver()
    self.state = "GAMEOVER"
    local board = self.board
    local S     = ArcadiaNexus.GB_Settings
    local R     = ArcadiaNexus.GB_Renderer
    if not board then return end

    if S then S:ClearProgress() end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("GOBLINBLAST", E._sessionId)
        E._sessionId = nil
    end

    local payload = {
        gameId     = "GOBLINBLAST",
        difficulty = board.difficulty,
        score      = board.score or 0,
        result     = "LOSS",
        stats      = {
            walls        = board.stats.walls,
            enemies      = board.stats.enemies,
            powerups     = board.stats.powerups,
            maxChain     = board.stats.maxChain,
            levelReached = board.level,
        },
    }
    ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
    local isNew = payload.newHighscore == true

    if R and R.OnGameLost then R:OnGameLost(board, isNew) end
end

-- ============================================================
-- Eingabe (vom Renderer-KeyFrame)
-- ============================================================
function E:HandleKeyDown(key)
    if self.state ~= "PLAYING" or not self.board then
        if key == "ESCAPE" then self:StopGame() end
        return
    end
    local Logic = ArcadiaNexus.GB_Logic

    if key == "W" or key == "UP" then
        Logic:PressDir(self.board, "up")
    elseif key == "S" or key == "DOWN" then
        Logic:PressDir(self.board, "down")
    elseif key == "A" or key == "LEFT" then
        Logic:PressDir(self.board, "left")
    elseif key == "D" or key == "RIGHT" then
        Logic:PressDir(self.board, "right")
    elseif key == "SPACE" then
        Logic:PlaceBomb(self.board)
    elseif key == "ESCAPE" then
        self:SaveAndPause()
        local R = ArcadiaNexus.GB_Renderer
        if R and R.EnterIdleState then R:EnterIdleState() end
    end
end

function E:HandleKeyUp(key)
    if not self.board then return end
    local Logic = ArcadiaNexus.GB_Logic

    if key == "W" or key == "UP" then
        Logic:ReleaseDir(self.board, "up")
    elseif key == "S" or key == "DOWN" then
        Logic:ReleaseDir(self.board, "down")
    elseif key == "A" or key == "LEFT" then
        Logic:ReleaseDir(self.board, "left")
    elseif key == "D" or key == "RIGHT" then
        Logic:ReleaseDir(self.board, "right")
    end
end

-- ============================================================
-- SaveAndPause (OnHide / Beenden)
-- ============================================================
function E:SaveAndPause()
    if self.state == "PLAYING" and self.board then
        self:_SaveProgress(self.board.level)
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("GOBLINBLAST", E._sessionId)
    end
    self.state       = "IDLE"
    self.board       = nil
    self._generation = self._generation + 1
    self:_StopLoop()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("GOBLINBLAST", E._sessionId)
        E._sessionId = nil
    end
end

-- ============================================================
-- StopGame (Abbruch nach Game-Over)
-- ============================================================
function E:StopGame()
    if self.state == "PLAYING" and self.board then
        self:_SaveProgress(self.board.level)
    end

    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("GOBLINBLAST", E._sessionId)
        E._sessionId = nil
    end
    self.state       = "IDLE"
    self.board       = nil
    self._generation = self._generation + 1
    self:_StopLoop()

    ArcadiaNexus.Engine:Emit("GB_GAME_STOPPED")
    local R = ArcadiaNexus.GB_Renderer
    if R and R.EnterIdleState then R:EnterIdleState() end
end
