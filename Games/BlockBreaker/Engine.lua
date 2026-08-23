-- ============================================================
--  BlockBreaker – Engine.lua
--  Spielfluss, State-Machine, OnUpdate-Loop, Pause/Resume.
--
--  State-Machine: IDLE → PLAYING → PAUSED → PLAYING
--                                         ↘ GAMEOVER
--
--  Regeln:
--  - GameLoop (Core/GameLoop) für OnUpdate-Loop
--  - OnHide → SaveAndPause (kein Spiel läuft im Hintergrund)
--  - GAME_RESULT-Event bei Win/Loss (uppercase)
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
-- ============================================================

ArcadiaNexus.BB_Engine = {}
local E = ArcadiaNexus.BB_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_BB_LoopFrame")

-- ── Highscore (ScoreManager) ──────────────────────────────────
local function GetHighScore(difficulty)
    local SM = ArcadiaNexus.ScoreManager
    if SM then return SM:GetBestScore("BLOCKBREAKER", difficulty) end
    return 0
end

-- ── OnUpdate-Loop ─────────────────────────────────────────────
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function() return E.state == "PLAYING" end,
    })
end

function E:_StopLoop()
    _gameLoop:Stop()
end

-- ── Sound-Helfer ──────────────────────────────────────────────
-- Direkte Integer-IDs (wie WhackAMole) — kein SOUNDKIT-nil-Risiko.
-- Eigene Sound-Dateien
local SND_PATH      = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\sounds\\"
local SND_BLOCK_HIT = SND_PATH .. "block_hit.wav"
local SND_PADDLE    = SND_PATH .. "paddle_side_hit.wav"
local SND_POWERUP   = SND_PATH .. "power_up.wav"
local SND_WALL_HIT  = SND_PATH .. "wall_hit.wav"

-- SOUNDKIT-IDs für Sounds ohne eigene Datei
local SND_LIFELOST = 847   -- INTERFACE_SOUND_LOST_TARGET_UNIT
local SND_WIN      = 8959  -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_LOSE     = 847   -- IG_QUEST_ABANDON

-- Eigene Sound-Datei abspielen (nur wenn Sound aktiviert)
local function PlayBBFile(Settings, key, path)
    if Settings and Settings:Get("soundEnabled") and Settings:Get(key) then
        PlaySoundFile(path, "Master")
    end
end

-- SOUNDKIT-Sound abspielen
local function PlayBBSound(Settings, key, soundId)
    if Settings and Settings:Get("soundEnabled") and Settings:Get(key) then
        PlaySound(soundId, "Master")
    end
end

-- ── Tick ──────────────────────────────────────────────────────
function E:_Tick(dt)
    local Logic    = ArcadiaNexus.BB_Logic
    local Renderer = ArcadiaNexus.BB_Renderer
    local Settings = ArcadiaNexus.BB_Settings
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    local actions = Logic:Tick(gs, dt)

    -- Bug-Fix 3: doGameOver/doLevelWin flags statt sofortigem return.
    -- Renderer:UpdatePhysics läuft IMMER durch, damit der letzte zerstörte
    -- Block visuell verschwindet, bevor das Overlay eingeblendet wird.
    local doGameOver = false
    local doLevelWin = false

    for _, act in ipairs(actions) do
        if act.type == "bounce_wall" then
            PlayBBFile(Settings, "soundOnBounce", SND_PADDLE)
        elseif act.type == "bounce_paddle" then
            PlayBBFile(Settings, "soundOnBounce", SND_PADDLE)
        elseif act.type == "break_block" then
            PlayBBFile(Settings, "soundOnBreak", SND_BLOCK_HIT)
            Renderer:OnBlockBroken(act.row, act.col, act.blockType, gs)
        elseif act.type == "damage_block" then
            -- Gepanzerter/unzerstörbarer Block getroffen
            PlayBBFile(Settings, "soundOnBreak", SND_WALL_HIT)
            Renderer:OnBlockDamaged(act.row, act.col, act.newTyp, gs)
        elseif act.type == "powerup_drop" then
            Renderer:OnPowerUpDropped(act.puType, act.x, act.y, gs)
        elseif act.type == "powerup_collect" then
            PlayBBFile(Settings, "soundOnPowerUp", SND_POWERUP)
            Renderer:OnPowerUpCollected(act.puType, gs)
        elseif act.type == "score_bonus" then
            Renderer:UpdateHUD(gs)
        elseif act.type == "lives_gained" then
            Renderer:UpdateHUD(gs)
        elseif act.type == "powerup_expired" then
            Renderer:OnPowerUpExpired(act.puType, gs)
        elseif act.type == "life_lost" then
            PlayBBSound(Settings, "soundOnLifeLost", SND_LIFELOST)
            if Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(1, 0.1, 0.1)
            end
            Renderer:UpdateHUD(gs)
            if not gs.gameOver then
                E.state = "PAUSED"
                self:_StopLoop()
                local respawnSession = E._sessionId
                C_Timer.After(1.0, function()
                    if not ArcadiaNexus.GameSession:IsSession(E, respawnSession) then return end
                    if E.state == "PAUSED" and E.gameState == gs then
                        Logic:ResetBall(gs)
                        E.state = "PLAYING"
                        E:_StartLoop()
                        Renderer:UpdateHUD(gs)
                    end
                end)
            end
        elseif act.type == "game_over" then
            doGameOver = true
        elseif act.type == "level_win" then
            doLevelWin = true
        end
    end

    -- Renderer immer aktualisieren (auch vor Win/GameOver-Overlay)
    Renderer:UpdatePhysics(gs)
    Renderer:UpdateHUD(gs)

    if doGameOver then
        self:_HandleGameOver(false)
    elseif doLevelWin then
        self:_HandleLevelWin()
    end
end

-- ── Tastatur-Input ────────────────────────────────────────────
function E:HandleKey(key)
    local gs = self.gameState
    if key == "LEFT_DOWN"  then if gs then gs.keyLeft  = true  end
    elseif key == "LEFT_UP"   then if gs then gs.keyLeft  = false end
    elseif key == "RIGHT_DOWN" then if gs then gs.keyRight = true  end
    elseif key == "RIGHT_UP"  then if gs then gs.keyRight = false end
    elseif key == "PAUSE" then
        if E.state == "PLAYING" then
            self:Pause()
        elseif E.state == "PAUSED" then
            self:Resume()
        end
    end
end

-- ── StartGame ──────────────────────────────────────────────────
function E:StartGame(difficulty, resumeSaved)
    local Logic    = ArcadiaNexus.BB_Logic
    local Renderer = ArcadiaNexus.BB_Renderer
    local Settings = ArcadiaNexus.BB_Settings
    if not Logic or not Renderer then return end

    local config = difficulty
    if type(difficulty) ~= "table" then
        config = {
            slot       = Settings and Settings:GetActiveSlot() or 1,
            mode       = resumeSaved and "continue" or "new",
            difficulty = difficulty,
        }
    end
    local slot = config.slot or (Settings and Settings:GetActiveSlot()) or 1
    if Settings and (slot < 1 or slot > Settings.MAX_SLOTS) then return end
    local mode = config.mode or "continue"
    if Settings then Settings:SetActiveSlot(slot) end
    self.activeSlot = slot

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("BLOCKBREAKER", E._sessionId)

    self:_StopLoop()

    local diff = config.difficulty or (Settings and Settings:Get("difficulty")) or "easy"

    local savedProgress = nil
    if mode == "continue" and Settings then
        savedProgress = Settings:LoadProgress(slot)
        if savedProgress then
            diff = savedProgress.diff or diff
        end
    elseif mode == "new" and Settings then
        Settings:ResetSlot(slot)
    end

    local gs = Logic:NewState(diff, savedProgress)
    gs.highScore = GetHighScore(diff)
    Logic:ParseLevel(gs, gs.level)
    Logic:ResetBall(gs)

    self.gameState = gs
    E.state = "PLAYING"

    Renderer:OnGameStarted(gs)
    self:_StartLoop()
end

-- ── StopGame ──────────────────────────────────────────────────
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("BLOCKBREAKER", E._sessionId)
        E._sessionId = nil
    end
    -- Fortschritt speichern bevor State gelöscht wird (nicht nach Game Over)
    local gs       = self.gameState
    local Settings = ArcadiaNexus.BB_Settings
    if gs and Settings and E.state ~= "GAMEOVER" then
        Settings:SaveProgress(gs.level, gs.score, gs.lives, gs.difficulty, gs.levelWon)
    end
    self:_StopLoop()
    E.state = "IDLE"
    self.gameState = nil
    local R = ArcadiaNexus.BB_Renderer
    if R then R:EnterIdleState() end
end

-- ── Pause / Resume ────────────────────────────────────────────
function E:Pause()
    if E.state ~= "PLAYING" then return end
    E.state = "PAUSED"
    self:_StopLoop()
    -- Tastendruck-State resetten
    if self.gameState then
        self.gameState.keyLeft  = false
        self.gameState.keyRight = false
    end
    local R = ArcadiaNexus.BB_Renderer
    if R then R:ShowPause() end
end

function E:Resume()
    if E.state ~= "PAUSED" then return end
    E.state = "PLAYING"
    local R = ArcadiaNexus.BB_Renderer
    if R then R:HidePause() end
    self:_StartLoop()
end

-- ── SaveAndPause (OnHide-Handler) ─────────────────────────────
function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("BLOCKBREAKER", E._sessionId)
    end
    local gs       = self.gameState
    local Settings = ArcadiaNexus.BB_Settings
    if gs and Settings then
        Settings:SaveProgress(gs.level, gs.score, gs.lives, gs.difficulty, gs.levelWon)
    end
    self:_StopLoop()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("BLOCKBREAKER", E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
    self.gameState = nil
end

-- ── Level-Win ─────────────────────────────────────────────────
function E:_HandleLevelWin()
    self:_StopLoop()
    E.state = "PAUSED"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.BB_Settings
    local Renderer = ArcadiaNexus.BB_Renderer
    if not gs then return end

    if gs.score > (gs.highScore or 0) then gs.highScore = gs.score end
    gs.levelWon = true

    if Settings and Settings:Get("soundEnabled") and Settings:Get("soundOnWin") then
        PlaySound(SND_WIN, "Master")
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "BLOCKBREAKER",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "WIN",
        stats      = {
            levelReached = gs.level or 1,
            maxCombo     = gs.maxCombo or 0,
        },
    })

    if Renderer then Renderer:ShowLevelWin(gs) end
end

-- ── Nächstes Level (aufgerufen vom Renderer-Button) ───────────
function E:ContinueToNextLevel()
    local Logic    = ArcadiaNexus.BB_Logic
    local Renderer = ArcadiaNexus.BB_Renderer
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    Logic:AdvanceLevel(gs)
    gs.levelWon = false
    E.state = "PLAYING"
    Renderer:OnLevelAdvanced(gs)
    self:_StartLoop()
end

-- ── Aktuelles Level wiederholen ────────────────────────────────
function E:RetryLevel()
    local Logic    = ArcadiaNexus.BB_Logic
    local Renderer = ArcadiaNexus.BB_Renderer
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    Logic:RetryLevel(gs)
    gs.levelWon = false
    E.state = "PLAYING"
    Renderer:OnLevelAdvanced(gs)
    self:_StartLoop()
end

-- ── Game Over ──────────────────────────────────────────────────
function E:_HandleGameOver(isWin)
    self:_StopLoop()
    E.state = "GAMEOVER"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.BB_Settings
    local Renderer = ArcadiaNexus.BB_Renderer
    if not gs then return end

    if gs.score > (gs.highScore or 0) then gs.highScore = gs.score end

    if Settings and Settings:Get("soundEnabled") then
        if isWin then
            if Settings:Get("soundOnWin") then
                PlaySound(SND_WIN, "Master")
            end
        else
            if Settings:Get("soundOnLose") then
                PlaySound(SND_LOSE, "Master")
            end
        end
    end

    if Settings then Settings:ClearProgress() end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "BLOCKBREAKER",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "LOSS",
        stats      = {
            levelReached = gs.level or 1,
            maxCombo     = gs.maxCombo or 0,
        },
    })

    if Renderer then Renderer:ShowGameOver(gs) end
end
