--[[
    Gaming Hub
    Games/AzerothConquest/Engine.lua
    Version: 1.0.0

    Events (AC_ Prefix):
      AC_GAME_STARTED(state)
      AC_PLACEMENT_UPDATED(state)   – nach jedem platzierten Schiff
      AC_BATTLE_STARTED(state)      – alle Schiffe platziert, Kampf beginnt
      AC_SHOT_FIRED(state)          – nach Spieler-Schuss (inkl. KI-Antwort)
      AC_GAME_OVER(result)
      AC_GAME_STOPPED
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AC_Engine = {}
local E = ArcadiaNexus.AC_Engine

E._sessionId = nil

E.activeGame = nil

-- ============================================================
-- Sound
-- ============================================================

local SND_BASE = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\sounds\\"

local function PlayGameSound(event)
    local S = ArcadiaNexus.AC_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "WIN"  and S:Get("soundOnWin")  then PlaySound(888, "SFX") end
    if event == "LOSS" and S:Get("soundOnLoss") then PlaySound(847, "SFX") end
    if event == "HIT"  and S:Get("soundOnHit")  then PlaySoundFile(SND_BASE .. "hit.wav",  "SFX") end
    if event == "MISS" and S:Get("soundOnMiss") then PlaySoundFile(SND_BASE .. "miss.wav", "SFX") end
    if event == "SUNK" and S:Get("soundOnSunk") then PlaySoundFile(SND_BASE .. "sink.wav", "SFX") end
end

-- ============================================================
-- StartGame
-- ============================================================

function E:StartGame(config)
    local gameClass = ArcadiaNexus.AC_Game
    if not gameClass then
        GH_LogError("AC_Engine", "AC_Game nicht registriert.")
        return
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("AZEROTHCONQUEST", E._sessionId)

    local S   = ArcadiaNexus.AC_Settings
    local cfg = {
        size         = (config and config.size)         or (S and S:Get("gridSize"))     or 10,
        aiDifficulty = (config and config.aiDifficulty) or (S and S:Get("aiDifficulty")) or "easy",
    }

    local instance = gameClass:New()
    instance:Init(cfg)
    self.activeGame   = instance
    self.activeConfig = cfg

    ArcadiaNexus.Engine:Emit("AC_GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandlePlacement – Spieler klickt Feld in Placement-Phase
-- ============================================================

function E:HandlePlacement(r, c)
    if not self.activeGame then return end

    local success = self.activeGame:PlaceShip(r, c)
    if not success then return end

    local state = self.activeGame:GetBoardState()

    if state.phase == "BATTLE" then
        ArcadiaNexus.Engine:Emit("AC_BATTLE_STARTED", state)
    else
        ArcadiaNexus.Engine:Emit("AC_PLACEMENT_UPDATED", state)
    end
end

-- ============================================================
-- HandleRandomPlacement
-- ============================================================

function E:HandleRandomPlacement()
    if not self.activeGame then return end

    self.activeGame:PlaceAllRandom()

    local state = self.activeGame:GetBoardState()
    ArcadiaNexus.Engine:Emit("AC_BATTLE_STARTED", state)
end

-- ============================================================
-- ToggleOrientation – R-Taste
-- ============================================================

function E:ToggleOrientation()
    if not self.activeGame then return end
    self.activeGame:ToggleOrientation()
    ArcadiaNexus.Engine:Emit("AC_PLACEMENT_UPDATED", self.activeGame:GetBoardState())
end

-- ============================================================
-- HandleShot – Spieler schießt auf KI-Board
-- ============================================================

function E:HandleShot(r, c)
    if not self.activeGame then return end

    local before = self.activeGame:GetBoardState()
    if before.phase ~= "BATTLE" or before.gameOver then return end

    self.activeGame:HandleShot(r, c)

    local state = self.activeGame:GetBoardState()
    if not state.lastShot then return  end  -- already_shot oder invalid

    -- Sound für Spieler-Schuss
    local shotResult = state.lastShot.result
    if shotResult == "SUNK" then
        PlayGameSound("SUNK")
    elseif shotResult == "HIT" then
        PlayGameSound("HIT")
    elseif shotResult == "MISS" then
        PlayGameSound("MISS")
    end

    ArcadiaNexus.Engine:Emit("AC_SHOT_FIRED", state)

    if state.gameOver then
        PlayGameSound(state.result)
        ArcadiaNexus.Engine:Emit("AC_GAME_OVER", state.result)

        -- Zentraler GAME_RESULT-Event
        local diff = (self.activeConfig and self.activeConfig.aiDifficulty) or "easy"
        local scoreMap = { easy = 100, normal = 150, hard = 200 }
        local score = (state.result == "WIN") and (scoreMap[diff] or 100) or 0
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "AZEROTHCONQUEST",
            difficulty = diff,
            score      = score,
            result     = state.result,
            stats      = {
                shotsTotal = state.totalShots or 0,
                misses     = state.totalMisses or 0,
            },
        })
    end
end

-- ============================================================
-- StopGame
-- ============================================================

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("AZEROTHCONQUEST", E._sessionId)
        E._sessionId = nil
    end
    if not self.activeGame then return end
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("AC_GAME_STOPPED")
end
