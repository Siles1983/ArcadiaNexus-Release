--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    Games/Codebreaker/Engine.lua

    Events (CB_ Prefix):
      CB_GAME_STARTED(state)
      CB_SLOT_SET(state, slotIdx)        – Symbol in Slot gesetzt
      CB_SLOT_CLEARED(state, slotIdx)    – Slot geleert
      CB_GUESS_SUBMITTED(state, result)  – Versuch geprüft: result = "won"|"lost"|"continue"
      CB_GAME_WON(state)
      CB_GAME_LOST(state)
      CB_GAME_STOPPED
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CB_Engine = {}
local E = ArcadiaNexus.CB_Engine

E._sessionId = nil

E.activeGame = nil

-- ============================================================
-- Sounds
-- ============================================================
local function PlayGameSound(event)
    local S = ArcadiaNexus.CB_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "place"  and S:Get("soundOnPlace")  then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX") end
    if event == "submit" and S:Get("soundOnSubmit") then PlaySound(SOUNDKIT.IG_ABILITY_ICONUPDATE or 857, "SFX") end
    if event == "win"    and S:Get("soundOnWin")    then PlaySound(SOUNDKIT.UI_GARRISON_MISSION_COMPLETE or 888, "SFX") end
    if event == "lose"   and S:Get("soundOnLose")   then PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX") end
end

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("CODEBREAKER", E._sessionId)
    local S   = ArcadiaNexus.CB_Settings
    local cfg = {
        difficulty  = (config and config.difficulty)  or S:Get("difficulty"),
        theme       = (config and config.theme)        or S:Get("theme"),
        codeLength  = (config and config.codeLength)   or S:Get("codeLength"),
        duplicates  = (config and config.duplicates ~= nil) and config.duplicates or S:Get("duplicates"),
    }
    local instance = ArcadiaNexus.CB_Game:New()
    instance:Init(cfg)
    self.activeGame   = instance
    self.activeConfig = cfg
    ArcadiaNexus.Engine:Emit("CB_GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandleSetSlot – Spieler klickt Symbol für Slot
-- ============================================================
function E:HandleSetSlot(slotIdx, symbolIdx)
    if not self.activeGame then return end
    local result = self.activeGame:SetSlot(slotIdx, symbolIdx)
    if result == "ok" then
        PlayGameSound("place")
        -- Direkt Renderer updaten (wie Memory-Muster)
        local R = ArcadiaNexus.CB_Renderer
        if R then R:UpdateInputRow() end
    end
end

-- ============================================================
-- HandleClearSlot – Rechtsklick auf Slot leert ihn
-- ============================================================
function E:HandleClearSlot(slotIdx)
    if not self.activeGame then return end
    self.activeGame:ClearSlot(slotIdx)
    local R = ArcadiaNexus.CB_Renderer
    if R then R:UpdateInputRow() end
end

-- ============================================================
-- HandleSubmit – "Prüfen"-Button
-- ============================================================
function E:HandleSubmit()
    if not self.activeGame then return end
    if not self.activeGame:IsGuessComplete() then
        -- Visuelles Feedback: unvollständige Slots blinken lassen
        local R = ArcadiaNexus.CB_Renderer
        if R then R:FlashIncomplete() end
        return
    end

    PlayGameSound("submit")
    local result = self.activeGame:SubmitGuess()
    local state  = self.activeGame:GetBoardState()

    -- Renderer sofort updaten
    local R = ArcadiaNexus.CB_Renderer
    if R then R:UpdateBoard() end

    if result == "won" then
        PlayGameSound("win")
        ArcadiaNexus.Engine:Emit("CB_GAME_WON", state)
        local diff = (self.activeConfig and self.activeConfig.difficulty) or "normal"
        local scoreMap = { easy = 50, normal = 100, hard = 200 }
        local base = scoreMap[diff] or 100
        local maxA = math.max(1, state.maxAttempts or 1)
        local used = math.min(maxA, math.max(1, state.attemptCount or maxA))
        local score = math.max(1, math.floor(base * (maxA - used + 1) / maxA))
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId = "CODEBREAKER", difficulty = diff,
            score = score, result = "WIN",
            stats = {
                attemptCount = state.attemptCount or 0,
            },
        })
    elseif result == "lost" then
        PlayGameSound("lose")
        ArcadiaNexus.Engine:Emit("CB_GAME_LOST", state)
        local diff = (self.activeConfig and self.activeConfig.difficulty) or "normal"
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId = "CODEBREAKER", difficulty = diff, score = 0, result = "LOSS",
            stats = {
                attemptCount = state.attemptCount or 0,
            },
        })
    end
    -- "continue": Renderer zeigt neue leere Eingabezeile
end

-- ============================================================
-- StopGame
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("CODEBREAKER", E._sessionId)
        E._sessionId = nil
    end
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("CB_GAME_STOPPED")
end
