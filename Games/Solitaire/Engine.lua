-- ============================================================
--  Solitaire – Engine.lua
--  Spielfluss, State-Machine, Timer, Auto-Complete.
--  KEIN UI-Code, KEINE Spielregeln hier.
--
--  State-Machine:
--    IDLE → PLAYING → WIN
--                   ↘ GAMEOVER (keine Züge mehr)
--
--  Regeln:
--  - TimerGuard (Core/TimerGuard) für Elapsed-Timer
--  - OnHide → SaveAndPause (laufendes Spiel wird gespeichert)
--  - GAME_RESULT erst bei echtem Spielende (WIN/GAMEOVER)
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SOL_Engine = {}
local E = ArcadiaNexus.SOL_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil
E._autoRunning = false

local _timerGuard = ArcadiaNexus.TimerGuard.New()
local _autoGuard  = ArcadiaNexus.TimerGuard.New()

-- ── Sound-Konstanten ──────────────────────────────────────────
local SND_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\Solitaire\\Assets\\sounds\\"
local SND = {
    deal       = SND_PATH .. "select_card.wav",
    place      = SND_PATH .. "select_card.wav",
    foundation = SND_PATH .. "select_card.wav",
    invalid    = SND_PATH .. "missmatch.wav",
    win        = SND_PATH .. "win.wav",
    undo       = SND_PATH .. "select_card.wav",
}

-- ── Hilfsfunktionen ───────────────────────────────────────────
local function GetLogic()    return ArcadiaNexus.SOL_Logic    end
local function GetRenderer() return ArcadiaNexus.SOL_Renderer end
local function GetSettings() return ArcadiaNexus.SOL_Settings end

function E:_PlaySound(key)
    local S = GetSettings()
    if not S or not S:Get("soundEnabled") then return end
    local keyMap = {
        deal      = "soundOnDeal",
        place     = "soundOnPlace",
        foundation = "soundOnFnd",
        invalid   = "soundOnInval",
        win       = "soundOnWin",
        undo      = "soundOnUndo",
    }
    local settingKey = keyMap[key]
    if settingKey and not S:Get(settingKey) then return end
    local path = SND[key]
    if path then PlaySoundFile(path, "Master") end
end

-- ── Timer (C_Timer Generation-Pattern) ───────────────────────
function E:_StartTimer()
    _timerGuard:Cancel()
    _timerGuard:EveryAfter(1, function()
        if E.state ~= "PLAYING" then return false end
        local gs = E.gameState
        if gs then
            gs.elapsed = gs.elapsed + 1
            local R = GetRenderer()
            if R and R.UpdateHUD then R:UpdateHUD(gs) end
        end
        return true
    end)
end

function E:_StopTimer()
    _timerGuard:Cancel()
end

-- ── Spielstart ────────────────────────────────────────────────
function E:StartGame(mode, fromSave)
    local L = GetLogic()
    local S = GetSettings()
    if not L or not S then return end

    local config = mode
    if type(mode) ~= "table" then
        config = {
            slot = S:GetActiveSlot(),
            mode = fromSave and "continue" or "new",
            cardMode = mode,
        }
    end
    local slot = config.slot or S:GetActiveSlot()
    if slot < 1 or slot > S.MAX_SLOTS then return end
    local startMode = config.mode or "new"
    S:SetActiveSlot(slot)
    self.activeSlot = slot

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("SOLITAIRE", E._sessionId)

    _timerGuard:Cancel()
    _autoGuard:Cancel()
    E._autoRunning = false

    if startMode == "continue" and S:HasSavedGame(slot) then
        local saved = S:LoadGame(slot)
        E.gameState = L:NewGameState(saved.mode)
        E.gameState.stock      = saved.stock
        E.gameState.waste      = saved.waste
        E.gameState.foundation = saved.foundation
        E.gameState.tableau    = saved.tableau
        E.gameState.score      = saved.score
        E.gameState.elapsed    = saved.elapsed
        E.gameState.wastePass  = saved.wastePass
        E.gameState.undoStack  = {}
    else
        S:ResetSlot(slot)
        E.gameState = L:NewGameState(config.cardMode or S:Get("mode"))
        S:SaveGame(E.gameState)
    end

    E.state = "PLAYING"

    local R = GetRenderer()
    if R then
        R:Refresh(E.gameState)
        R:UpdateHUD(E.gameState)
        R:SetState("PLAYING")
    end

    E:_StartTimer()
    E:_PlaySound("deal")
    E:_CheckPostMove(E.gameState)
end

-- ── Spielende ─────────────────────────────────────────────────
function E:_Win()
    if E.state ~= "PLAYING" then return end
    E:_StopTimer()
    E.state = "WIN"

    local gs = E.gameState
    local L  = GetLogic()
    L:ApplyTimeBonus(gs)

    local R = GetRenderer()
    if R then
        R:Refresh(gs)
        R:UpdateHUD(gs)
        R:SetState("WIN")
        R:ShowResult("WIN", gs.score)
    end

    E:_PlaySound("win")

    local S = GetSettings()
    if S then S:ClearSave() end

    if ArcadiaNexus.Engine then
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "SOLITAIRE",
            difficulty = gs.mode,
            score      = gs.score,
            result     = "WIN",
        })
    end
end

function E:_GameOver()
    if E.state ~= "PLAYING" then return end
    E:_StopTimer()
    E.state = "GAMEOVER"

    local gs = E.gameState
    local R  = GetRenderer()
    if R then
        R:Refresh(gs)
        R:SetState("GAMEOVER")
        R:ShowResult("GAMEOVER", gs.score)
    end

    local S = GetSettings()
    if S then S:ClearSave() end

    if ArcadiaNexus.Engine then
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "SOLITAIRE",
            difficulty = gs.mode,
            score      = gs.score,
            result     = "LOSS",
        })
    end
end

-- ── Eingabe-Handler (werden vom Renderer aufgerufen) ──────────

-- Klick auf Stock
function E:OnStockClick()
    if E.state ~= "PLAYING" then return end
    local gs = E.gameState
    local L  = GetLogic()
    local ok, action = L:DrawFromStock(gs)
    if ok then
        E:_PlaySound("deal")
        local R = GetRenderer()
        if R then R:Refresh(gs) end
        E:_CheckPostMove(gs)
    end
end

-- Klick auf Karte (Klick-Klick-System)
function E:OnCardClick(zone, idx, cardIdx)
    if E.state ~= "PLAYING" then return end
    local gs = E.gameState
    local L  = GetLogic()
    local R  = GetRenderer()

    -- Stock-Klick separater Handler
    if zone == "stock" then
        E:OnStockClick()
        return
    end

    if gs.selected then
        local src = gs.selected
        local ok, delta = L:TryMove(gs, src, { zone=zone, index=idx, cardIndex=cardIdx })
        gs.selected = nil
        if ok then
            E:_PlaySound(zone == "foundation" and "foundation" or "place")
            if R then R:Refresh(gs) end
            E:_CheckPostMove(gs)
        else
            -- Ungültiger Zug: prüfen ob neue Selektion
            if L:IsSelectable(gs, zone, idx, cardIdx) then
                gs.selected = { zone=zone, index=idx, cardIndex=cardIdx }
                E:_PlaySound("invalid")
                if R then R:Refresh(gs) end
            else
                E:_PlaySound("invalid")
                if R then R:Refresh(gs) end
            end
        end
    else
        if L:IsSelectable(gs, zone, idx, cardIdx) then
            gs.selected = { zone=zone, index=idx, cardIndex=cardIdx }
            if R then R:Refresh(gs) end
        end
    end
end

-- Doppelklick → Auto-Move zur Foundation, sonst Tableau
function E:OnCardDoubleClick(zone, idx, cardIdx)
    if E.state ~= "PLAYING" then return end
    local gs = E.gameState
    local L  = GetLogic()
    local R  = GetRenderer()
    if not L:IsSelectable(gs, zone, idx, cardIdx) then return end
    gs.selected = nil

    -- 1. Versuch: Foundation
    local ok = L:TryMoveToFoundation(gs, zone, idx, cardIdx)
    if ok then
        E:_PlaySound("foundation")
        if R then R:Refresh(gs) end
        E:_CheckPostMove(gs)
        return
    end

    -- 2. Versuch: passendes Tableau
    ok = L:TryMoveToTableau(gs, zone, idx, cardIdx)
    if ok then
        E:_PlaySound("place")
        if R then R:Refresh(gs) end
        E:_CheckPostMove(gs)
        return
    end

    if L:IsSelectable(gs, zone, idx, cardIdx) then
        gs.selected = { zone=zone, index=idx, cardIndex=cardIdx }
        if R then R:Refresh(gs) end
    end
end

-- Drag abgeschlossen (Live-Ghost im Renderer)
function E:OnDragDrop(src, dst)
    if E.state ~= "PLAYING" then return end
    local gs = E.gameState
    local L  = GetLogic()
    local R  = GetRenderer()
    gs.selected = nil
    if not dst then
        if R then R:Refresh(gs) end
        return
    end
    local ok = L:TryMove(gs, src, dst)
    if ok then
        E:_PlaySound(dst.zone == "foundation" and "foundation" or "place")
        if R then R:Refresh(gs) end
        E:_CheckPostMove(gs)
    else
        if R then R:Refresh(gs) end
    end
end

-- Undo
function E:OnUndo()
    if E.state ~= "PLAYING" then return end
    local gs = E.gameState
    local L  = GetLogic()
    local ok = L:Undo(gs)
    if ok then
        E:_PlaySound("undo")
        local R = GetRenderer()
        if R then
            R:Refresh(gs)
            R:UpdateHUD(gs)
        end
    end
end

-- Auto-Complete auslösen
function E:OnAutoComplete()
    if E.state ~= "PLAYING" then return end
    -- Bereits aktiv: zweiten Klick ignorieren (verhindert timerGen-Invalidierung)
    if E._autoRunning then return end
    local gs = E.gameState
    local L  = GetLogic()
    if not L:CanAutoComplete(gs) then
        local R = GetRenderer()
        if R and R.SetAutoCompleteVisible then R:SetAutoCompleteVisible(false) end
        return
    end

    -- Move-Queue einmalig berechnen (Simulation kennt den vollständigen Lösungsweg)
    local queue = L:AutoBuildMoveQueue(gs)
    if not queue or #queue == 0 then
        local R = GetRenderer()
        if R and R.SetAutoCompleteVisible then R:SetAutoCompleteVisible(false) end
        return
    end

    E._autoRunning = true
    _timerGuard:Cancel()
    local idx = 1

    local function step()
        if not E._autoRunning then return end
        if E.state ~= "PLAYING" then E._autoRunning = false; return end

        if idx > #queue then
            E._autoRunning = false
            local R = GetRenderer()
            if R then R:Refresh(gs) end
            E:_CheckPostMove(gs)
            return
        end

        local move = queue[idx]
        idx = idx + 1

        -- Move auf echtem Spielzustand ausführen
        if move.type == "foundation" then
            local col  = gs.tableau[move.fromCol]
            local card = col[#col]
            if card then
                local fKey = move.toKey or L:FindFoundationKey(gs, card)
                if fKey then
                    table.remove(col)
                    gs.foundation[fKey][#gs.foundation[fKey]+1] = card
                    card.faceUp = true
                    gs.score = math.max(0, gs.score + (L.SCORE and L.SCORE.TABLEAU_TO_FOUND or 10))
                    E:_PlaySound("foundation")
                end
            end
        elseif move.type == "tableau" then
            local fromCol = gs.tableau[move.fromCol]
            local toCol   = gs.tableau[move.toCol]
            local card    = fromCol[#fromCol]
            if card then
                table.remove(fromCol)
                toCol[#toCol+1] = card
            end
        end

        local R = GetRenderer()
        if R then R:Refresh(gs) end

        if move.type == "foundation" and L:IsWin(gs) then
            E._autoRunning = false
            E:_Win()
            return
        end

        _autoGuard:After(0.08, step)
    end
    step()
end

-- ── Post-Move Prüfungen ───────────────────────────────────────
function E:_CheckPostMove(gs)
    local L = GetLogic()
    -- Win?
    if L:IsWin(gs) then
        E:_Win()
        return
    end
    -- Auto-Complete möglich?
    local R = GetRenderer()
    if R and L:CanAutoComplete(gs) then
        if R.SetAutoCompleteVisible then R:SetAutoCompleteVisible(true) end
    end
    -- No-Move?
    if not L:HasValidMoves(gs) then
        -- kurze Verzögerung damit Renderer zuerst aktualisiert
        _timerGuard:After(0.5, function()
            if E.state == "PLAYING" then
                E:_GameOver()
            end
        end)
    end
end

-- ── SaveAndPause ──────────────────────────────────────────────
function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("SOLITAIRE", E._sessionId)
    end
    E:_StopTimer()
    _autoGuard:Cancel()
    E._autoRunning = false
    if E.state == "PLAYING" and E.gameState then
        local S = GetSettings()
        if S then S:SaveGame(E.gameState) end
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SOLITAIRE", E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
end

-- ── StopGame ──────────────────────────────────────────────────
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SOLITAIRE", E._sessionId)
        E._sessionId = nil
    end
    E:_StopTimer()
    _autoGuard:Cancel()
    E._autoRunning = false
    E.state     = "IDLE"
    E.gameState = nil
    local R = GetRenderer()
    if R then R:SetState("IDLE") end
end
