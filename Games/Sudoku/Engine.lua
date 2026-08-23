--[[
    Gaming Hub
    Games/Sudoku/Engine.lua
    Version: 1.0.0

    Events (SDK_ Prefix):
      SDK_GAME_STARTED(state)
      SDK_CELL_SELECTED(state)     – Zelle ausgewählt, Popup öffnen
      SDK_BOARD_UPDATED(state)     – nach jeder Zahlen-Platzierung
      SDK_CELL_CLEARED(state)      – nach Rechtsklick-Löschen
      SDK_GAME_COMPLETE(state)     – Puzzle gelöst
      SDK_GAME_STOPPED
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SDK_Engine = {}
local E = ArcadiaNexus.SDK_Engine

E._sessionId = nil

E.activeGame = nil

-- ============================================================
-- Sound
-- ============================================================

local function PlayGameSound(event)
    local S = ArcadiaNexus.SDK_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "place" and S:Get("soundOnPlace") then
        PlaySound(1115, "SFX")   -- Click
    end
    if event == "error" and S:Get("soundOnError") then
        PlaySound(847, "SFX")    -- Error
    end
    if event == "complete" and S:Get("soundOnComplete") then
        PlaySound(888, "SFX")    -- Victory
    end
    if event == "clear" and S:Get("soundOnPlace") then
        PlaySound(1116, "SFX")
    end
end

-- ============================================================
-- StartGame
-- ============================================================

function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("SUDOKU", E._sessionId)
    local S   = ArcadiaNexus.SDK_Settings
    local cfg = {
        difficulty = (config and config.difficulty)
            or (S and S:Get("difficulty"))
            or "normal",
    }

    local instance = ArcadiaNexus.SDK_Game:New()
    instance:Init(cfg)
    self.activeGame   = instance
    self.activeConfig = cfg

    ArcadiaNexus.Engine:Emit("SDK_GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandleCellClick – Linksklick
-- ============================================================

function E:HandleCellClick(r, c)
    if not self.activeGame then return end

    local opened = self.activeGame:SelectCell(r, c)
    local state  = self.activeGame:GetBoardState()

    if opened then
        ArcadiaNexus.Engine:Emit("SDK_CELL_SELECTED", state)
    else
        -- Feste Zelle → nur Highlight aktualisieren
        ArcadiaNexus.Engine:Emit("SDK_BOARD_UPDATED", state)
    end
end

-- ============================================================
-- HandleNumberInput – Zahl aus Popup gewählt
-- ============================================================

function E:HandleNumberInput(num)
    if not self.activeGame then return end

    local result = self.activeGame:PlaceNumber(num)
    local state  = self.activeGame:GetBoardState()

    if result == "ok" then
        PlayGameSound("place")
        ArcadiaNexus.Engine:Emit("SDK_BOARD_UPDATED", state)
    elseif result == "error" then
        PlayGameSound("error")
        ArcadiaNexus.Engine:Emit("SDK_BOARD_UPDATED", state)
    elseif result == "complete" then
        PlayGameSound("complete")
        ArcadiaNexus.Engine:Emit("SDK_BOARD_UPDATED", state)
        ArcadiaNexus.Engine:Emit("SDK_GAME_COMPLETE", state)

        -- Zentraler GAME_RESULT-Event
        local diff = (self.activeConfig and self.activeConfig.difficulty) or "normal"
        local scoreMap = { easy = 50, normal = 100, hard = 200 }
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "SUDOKU",
            difficulty = diff,
            score      = scoreMap[diff] or 100,
            result     = "WIN",
        })
    end
    -- "no_selection", "invalid_fixed" → nichts tun
end

-- ============================================================
-- HandleCellRightClick – Rechtsklick löscht Zahl
-- ============================================================

function E:HandleCellRightClick(r, c)
    if not self.activeGame then return end

    local cleared = self.activeGame:ClearCell(r, c)
    if cleared then
        PlayGameSound("clear")
        ArcadiaNexus.Engine:Emit("SDK_CELL_CLEARED", self.activeGame:GetBoardState())
    end
end

-- ============================================================
-- StopGame
-- ============================================================

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SUDOKU", E._sessionId)
        E._sessionId = nil
    end
    if not self.activeGame then return end
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("SDK_GAME_STOPPED")
end
