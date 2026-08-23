--[[
    ArcadiaNexus – Core/GameResultProcessor.lua
    Sequenzielle Verarbeitungskette für GAME_RESULT-Events.

    Pipeline (synchron, ohne Frame-Delays):
      1. ScoreManager      → leaderboard, data.newHighscore
      2. XPManager         → Profil-XP, Level-Up
      3. AchievementManager → Achievements prüen / freischalten
      4. ChallengeManager  → Daily/Weekly-Fortschritt

    API:
      ArcadiaNexus.GameResultProcessor:Init()
      ArcadiaNexus.GameResultProcessor:Process(data)
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.GameResultProcessor = {}

local GRP = ArcadiaNexus.GameResultProcessor

-- ============================================================
-- INIT
-- ============================================================

function GRP:Init()
    ArcadiaNexus.Engine:On("GAME_RESULT", function(data)
        self:Process(data)
    end)
    GH_LogInfo("GameResultProcessor", "GAME_RESULT-Pipeline registriert")
end

-- ============================================================
-- PIPELINE
-- ============================================================

function GRP:Process(data)
    if not data or not data.gameId or not data.result then return end

    self:_RunStep("ScoreManager", ArcadiaNexus.ScoreManager, "HandleGameResult", data)
    self:_RunStep("XPManager", ArcadiaNexus.XPManager, "HandleGameResult", data)
    self:_RunStep("AchievementManager", ArcadiaNexus.AchievementManager, "HandleGameResult", data)
    self:_RunStep("ChallengeManager", ArcadiaNexus.ChallengeManager, "HandleGameResult", data)
end

function GRP:_RunStep(label, module, method, data)
    if not module or not module[method] then return end
    local ok, err = pcall(module[method], module, data)
    if not ok then
        GH_LogError("GameResultProcessor", label .. ": " .. tostring(err))
    end
end
