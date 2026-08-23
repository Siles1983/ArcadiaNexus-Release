--[[
    Gaming Hub
    Games/Memory/Engine.lua
    Version: 2.0.0 – Nach Referenz-Addon Muster

    Kernprinzip aus MemoryPairs.lua:
      OnClick → grid[i][j].flipped = true → UpdateUI() → CheckForMatch()

    Unser Äquivalent:
      HandleFlip → FlipCard() → Renderer:UpdateBoard() → CheckMatch mit Delay
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_Engine = {}
local E = ArcadiaNexus.AP_Engine

E._sessionId = nil

E.activeGame = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()

local function PlayGameSound(event)
    local S = ArcadiaNexus.AP_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "flip"     and S:Get("soundOnFlip")     then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX") end
    if event == "match"    and S:Get("soundOnMatch")    then PlaySound(SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK or 888, "SFX") end
    if event == "mismatch" and S:Get("soundOnMismatch") then PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX") end
    if event == "win"      and S:Get("soundOnWin")      then PlaySound(SOUNDKIT.UI_GARRISON_MISSION_COMPLETE or 888, "SFX") end
    if event == "lose"     and S:Get("soundOnLose")     then PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX") end
end

function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ARCADIAPAIRS", E._sessionId)
    self:StopTimer()
    local S   = ArcadiaNexus.AP_Settings
    local cfg = {
        difficulty  = (config and config.difficulty) or (S and S:Get("difficulty")) or "easy",
        theme       = (config and config.theme)       or (S and S:Get("theme"))      or "classes",
        timerActive = false,
    }
    if config and config.timerActive ~= nil then
        cfg.timerActive = config.timerActive and true or false
    elseif S then
        cfg.timerActive = S:Get("timerActive") and true or false
    end
    local instance = ArcadiaNexus.AP_Game:New()
    instance:Init(cfg)
    self.activeGame   = instance
    self.activeConfig = cfg
    ArcadiaNexus.Engine:Emit("AP_GAME_STARTED", instance:GetBoardState())
    if cfg.timerActive then self:StartTimer() end
end

-- ============================================================
-- HandleFlip – direkt nach Referenz-Muster
--   1. Guard-Checks
--   2. FlipCard()
--   3. Renderer:UpdateBoard() – SOFORT, synchron
--   4. Bei 2 Karten: mit Delay CheckMatch
-- ============================================================
function E:HandleFlip(idx)
    if not self.activeGame then return end
    if self.activeGame:IsBlocked() then return end

    local result = self.activeGame:FlipCard(idx)
    if result ~= "flipped" then return end

    PlayGameSound("flip")

    -- SOFORTIGES Update des Renderers (wie UpdateUI() im Referenz-Addon)
    -- Direkt synchron, kein Event, kein Delay – garantiertes Rendering
    local Renderer = ArcadiaNexus.AP_Renderer
    if Renderer then Renderer:UpdateBoard() end

    -- Zweite Karte? → blockieren, dann prüfen
    local board = self.activeGame.board
    if #board.flippedIdx == 2 then
        local i1, i2 = board.flippedIdx[1], board.flippedIdx[2]
        self.activeGame:SetBlocked(true)

        -- Delay damit Spieler beide Karten sieht (wie C_Timer.After(1) im Referenz-Addon)
        _timerGuard:After(0.8, function()
            if not self.activeGame then return end

            local matchResult = self.activeGame:CheckMatch()

            if matchResult == "match" then
                PlayGameSound("match")
                self.activeGame:SetBlocked(false)
                if Renderer then Renderer:UpdateBoard() end

                local board2 = self.activeGame.board
                if board2.phase == "WON" then
                    self:StopTimer()
                    PlayGameSound("win")
                    ArcadiaNexus.Engine:Emit("AP_GAME_WON", self.activeGame:GetBoardState())
                    -- Score: pairs * difficulty-Faktor
                    local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
                    local scoreMap = { easy = 50, normal = 100, hard = 200 }
                    local base = scoreMap[diff] or 50
                    local pairsN = math.max(1, board2.pairs or 1)
                    local moves = math.max(pairsN, board2.moves or pairsN)
                    local score = math.max(1, math.floor(base * pairsN / moves))
                    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                        gameId = "ARCADIAPAIRS", difficulty = diff,
                        score = score, result = "WIN",
                        stats = {
                            moves = board2.moves or 0,
                            pairs = board2.pairs or 0,
                        },
                    })
                end

            else -- no_match
                -- Roter Flash
                if Renderer then Renderer:FlashMismatch(i1, i2) end

                _timerGuard:After(0.6, function()
                    if not self.activeGame then return end
                    self.activeGame:ResetFlipped()
                    PlayGameSound("mismatch")
                    self.activeGame:SetBlocked(false)
                    if Renderer then Renderer:UpdateBoard() end
                end)
            end
        end)
    end
end

function E:StartTimer()
    _timerGuard:Cancel()
    _timerGuard:EveryAfter(1, function()
        if not self.activeGame then return false end
        local result = self.activeGame:TickTimer(1)
        local state  = self.activeGame:GetBoardState()
        ArcadiaNexus.Engine:Emit("AP_TIMER_TICK", state)
        if result == "expired" then
            self:StopTimer()
            PlayGameSound("lose")
            ArcadiaNexus.Engine:Emit("AP_GAME_LOST", state)
            local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId = "ARCADIAPAIRS", difficulty = diff, score = 0, result = "LOSS",
                stats = {
                    moves = state.moves or 0,
                    pairs = state.pairs or 0,
                },
            })
            return false
        end
        return true
    end)
end

function E:StopTimer()
    _timerGuard:Cancel()
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARCADIAPAIRS", E._sessionId)
        E._sessionId = nil
    end
    self:StopTimer()
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("AP_GAME_STOPPED")
end
