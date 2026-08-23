--[[
    Gaming Hub
    Games/Chess/Engine.lua
    Version: 1.0.0

    Events (CHE_ Prefix):
      CHE_GAME_STARTED(state)
      CHE_PIECE_SELECTED(state)     – Figur ausgewählt, Felder grün
      CHE_PIECE_DESELECTED(state)   – Auswahl aufgehoben
      CHE_MOVE_MADE(state, result)  – Zug ausgeführt
      CHE_AI_MOVE(state, result)    – KI-Zug ausgeführt
      CHE_GAME_OVER(state)          – Schachmatt / Patt / Aufgabe
      CHE_GAME_STOPPED
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Chess_Engine = {}
local E = ArcadiaNexus.Chess_Engine

E._sessionId = nil

E.activeGame    = nil
E.aiPending     = false   -- verhindert doppelte KI-Züge

-- ============================================================
-- Sound
-- ============================================================

local SOUNDS = {
    move         = 774,   -- IG_MAINMENU_OPEN
    captureEnemy = 1115,  -- IG_ABILITY_PAGE_TURN (Spieler schlaegt)
    captureOwn   = 8959,  -- Raid-Warnung-Impact (Gegner schlaegt)
    check        = 847,
    win          = 888,   -- LEVELUP
    loss         = 847,   -- RAID_WARNING
}

local SOUND_KEYS = {
    captureEnemy = "soundOnCaptureEnemy",
    captureOwn   = "soundOnCaptureOwn",
    win          = "soundOnWin",
    loss         = "soundOnLoss",
}

local function PlayGameSound(event)
    local S = ArcadiaNexus.Chess_Settings
    if not S or not S:Get("soundEnabled") then return end
    local settingKey = SOUND_KEYS[event]
    if settingKey and not S:Get(settingKey) then return end
    local id = SOUNDS[event]
    if id then PlaySound(id, "SFX") end
end

-- ============================================================
-- StartGame
-- ============================================================

function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("CHESS", E._sessionId)
    self.aiPending = false
    local S   = ArcadiaNexus.Chess_Settings
    local cfg = {
        difficulty = (config and config.difficulty)
            or (S and S:Get("difficulty"))
            or "easy",
    }

    local instance = ArcadiaNexus.Chess_Game:New()
    instance:Init(cfg)
    self.activeGame   = instance
    self.activeConfig = cfg
    self._moveCount   = 0  -- Stats: Spieler-Züge zählen

    ArcadiaNexus.Engine:Emit("CHE_GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandleCellClick – Spieler klickt ein Feld
-- ============================================================

function E:HandleCellClick(r, c)
    if not self.activeGame then return end
    if self.aiPending then return end  -- KI ist am Zug

    local game  = self.activeGame
    local state = game:GetBoardState()

    if state.phase ~= "PLAYING" then return end

    -- Hat der Spieler bereits eine Figur ausgewählt?
    if state.selected then
        -- Versuche Zug
        local result = game:MoveSelected(r, c)
        local newState = game:GetBoardState()

        if result == "moved" or result == "captured" or result == "check" then
            PlayGameSound(result == "captured" and "captureEnemy" or "move")
            self._moveCount = (self._moveCount or 0) + 1
            ArcadiaNexus.Engine:Emit("CHE_MOVE_MADE", newState, result)
            -- KI-Zug verzögert starten
            self:ScheduleAIMove()

        elseif result == "checkmate" or result == "stalemate" then
            PlayGameSound("win")
            ArcadiaNexus.Engine:Emit("CHE_MOVE_MADE", newState, result)
            ArcadiaNexus.Engine:Emit("CHE_GAME_OVER", newState)
            -- Spieler hat gewonnen (Schachmatt durch Spieler = white_wins)
            local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
            local scoreMap = { easy = 100, normal = 150, hard = 200 }
            local gr = (result == "stalemate") and "DRAW" or "WIN"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId     = "CHESS",
                difficulty = diff,
                score      = (gr == "WIN") and (scoreMap[diff] or 100) or 50,
                result     = gr,
                stats      = { moveCount = self._moveCount or 0 },
            })

        elseif result == "selected" then
            -- Andere eigene Figur ausgewählt
            ArcadiaNexus.Engine:Emit("CHE_PIECE_SELECTED", newState)

        else
            -- Ungültig → Auswahl aufheben
            ArcadiaNexus.Engine:Emit("CHE_PIECE_DESELECTED", newState)
        end
    else
        -- Figur auswählen
        local result = game:SelectPiece(r, c)
        local newState = game:GetBoardState()

        if result == "selected" then
            ArcadiaNexus.Engine:Emit("CHE_PIECE_SELECTED", newState)
        elseif result == "deselected" then
            ArcadiaNexus.Engine:Emit("CHE_PIECE_DESELECTED", newState)
        end
        -- "invalid" → nichts emittieren
    end
end

-- ============================================================
-- ScheduleAIMove – KI-Zug mit kurzer Verzögerung (0.4s)
-- ============================================================

function E:ScheduleAIMove()
    if not self.activeGame then return end
    if self.aiPending then return end
    self.aiPending = true

    C_Timer.After(0.4, function()
        if not self.activeGame then
            self.aiPending = false
            return
        end
        local result   = self.activeGame:DoAIMove()
        self.aiPending = false
        local newState = self.activeGame:GetBoardState()

        if result == "checkmate" or result == "stalemate" then
            PlayGameSound("loss")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
            ArcadiaNexus.Engine:Emit("CHE_GAME_OVER", newState)
            -- KI hat gewonnen (black_wins) oder Patt
            local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
            local gr = (result == "stalemate") and "DRAW" or "LOSS"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId     = "CHESS",
                difficulty = diff,
                score      = 0,
                result     = gr,
                stats      = { moveCount = self._moveCount or 0 },
            })
        elseif result == "check" then
            PlayGameSound("check")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
        elseif result == "captured" then
            PlayGameSound("captureOwn")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
        else
            PlayGameSound("move")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
        end
    end)
end

-- ============================================================
-- Resign
-- ============================================================

function E:HandleResign()
    if not self.activeGame then return end
    self.aiPending = false
    self.activeGame:Resign()
    local state = self.activeGame:GetBoardState()
    ArcadiaNexus.Engine:Emit("CHE_GAME_OVER", state)
    -- Aufgabe = LOSS, kein Score
    local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "CHESS",
        difficulty = diff,
        score      = 0,
        result     = "LOSS",
        stats      = { moveCount = self._moveCount or 0 },
    })
end

-- ============================================================
-- StopGame
-- ============================================================

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("CHESS", E._sessionId)
        E._sessionId = nil
    end
    self.aiPending  = false
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("CHE_GAME_STOPPED")
end
