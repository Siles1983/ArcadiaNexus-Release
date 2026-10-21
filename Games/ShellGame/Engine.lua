-- ============================================================
--  ShellGame – Engine.lua
--  Spielfluss, State-Machine, Runden-Verwaltung.
--
--  State-Machine:
--    IDLE → BETTING → REVEAL → SHUFFLE → GUESSING → RESULT
--                                                  ↘ GAMEOVER
--
--  Regeln:
--  - TimerGuard (Core/TimerGuard) für Reveal/Result-Delays und Sequenzen
--  - OnHide → offene Runde einmal verlieren, dann Kapitalpartie speichern
--  - Genau ein GAME_RESULT pro Einsatzrunde, einschließlich Abbruch
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SHG_Engine = {}
local E = ArcadiaNexus.SHG_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

-- ── Sound-Hilfsfunktion ───────────────────────────────────────
local SND_REVEAL   = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774
local SND_SHUFFLE  = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774
local SND_LIFT     = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774
local SND_WIN      = SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK      or 888
local SND_LOSE     = SOUNDKIT and SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847
local SND_BANKRUPT = SOUNDKIT and SOUNDKIT.IG_QUEST_ABANDON                 or 847

local SND_KEYS = {
    reveal   = { key="soundOnReveal",   id=SND_REVEAL  },
    shuffle  = { key="soundOnShuffle",  id=SND_SHUFFLE },
    lift     = { key="soundOnLift",     id=SND_LIFT    },
    win      = { key="soundOnWin",      id=SND_WIN     },
    lose     = { key="soundOnLose",     id=SND_LOSE    },
    bankrupt = { key="soundOnBankrupt", id=SND_BANKRUPT},
}

local function PlaySHGSound(event)
    local S = ArcadiaNexus.SHG_Settings
    if not S or not S:Get("soundEnabled") then return end
    local entry = SND_KEYS[event]
    if entry and S:Get(entry.key) then
        PlaySound(entry.id, "Master")
    end
end

-- ── Timer-Infrastruktur ───────────────────────────────────────
function E:_InvalidateTimers()
    _timerGuard:Cancel()
    local R=ArcadiaNexus.SHG_Renderer
    if R and R.CancelAnimations then R:CancelAnimations() end
end

function E:_RunSequence(steps, onDone)
    _timerGuard:RunSequence(steps, onDone)
end

-- ── State-Setter ──────────────────────────────────────────────
function E:_SetState(newState)
    E.state = newState
    if E.gameState then E.gameState.phase=newState end
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:OnStateChanged(newState) end
end

-- ── Init / Lifecycle ──────────────────────────────────────────
function E:StartGame(config)
    if self.gameState then return false end
    config=type(config)=="table" and config or {}
    local S     = ArcadiaNexus.SHG_Settings
    local diff  = (config and config.difficulty) or (S and S:Get("difficulty")) or "easy"
    local Logic = ArcadiaNexus.SHG_Logic
    S:EnsureMigration()
    local slot,mode=config.slot or 1,config.mode or "new"
    if not Logic:IsUnits(slot) or slot<1 or slot>3 or mode~="new" and mode~="continue" then return false end
    local save,gs=S:LoadSlot(slot)
    if mode=="continue" then
        if not self:CanContinueSave(save) then return false end
        gs=Logic:Copy(save)
    else
        if not Logic:IsDifficulty(diff) or save and not config.overwrite then return false end
        gs=Logic:NewGameState(diff,100,0)
    end
    local sid=ArcadiaNexus.Lifecycle:ClaimRestart("SHELLGAME",E._sessionId)
    if not sid then return false end
    if not gs.runId then gs.runId=ArcadiaNexus.LocalResults:NewRun("SHELLGAME"); gs.tableId=gs.runId end
    E._sessionId=sid
    self:_InvalidateTimers()
    E.gameState,self.activeSlot=gs,slot
    E.state=gs.phase; self:_Snapshot()
    if gs.phase=="REVEAL" or gs.phase=="SHUFFLE" or gs.phase=="GUESSING" then
        Logic:Settle(gs,nil,"ABORT"); E.state=gs.phase; self:_Snapshot()
    end
    local R = ArcadiaNexus.SHG_Renderer
    if R then
        R:OnGameStarted(gs)
        R:OnStateChanged(gs.phase)
    end
    if gs.phase=="RESULT_PENDING" then self:RetryResult()
    elseif R and (gs.phase=="RESULT" or gs.phase=="GAMEOVER") then R:ShowSavedResult(gs) end
    ArcadiaNexus.LocalResults:Prune(); return true
end

function E:_Snapshot()
    if self.gameState then ArcadiaNexus.SHG_Settings:SaveSlot(self.activeSlot,ArcadiaNexus.SHG_Logic:Copy(self.gameState)) end
end
function E:_IsRound(sid,gs,runId)
    return ArcadiaNexus.GameSession:IsSession(E,sid) and E.gameState==gs and gs.runId==runId
end
function E:_Schedule(delay,fn)
    local sid,gs=self._sessionId,self.gameState; local runId=gs and gs.runId
    _timerGuard:After(delay,function() if E:_IsRound(sid,gs,runId) then fn() end end)
end
function E:CanContinueSave(save)
    local LR=ArcadiaNexus.LocalResults
    if not ArcadiaNexus.SHG_Logic:ValidateSave(save) then return false end
    local serial,tableSerial=LR:GetSerial("SHELLGAME",save.runId),LR:GetSerial("SHELLGAME",save.tableId)
    if not serial or not tableSerial or tableSerial>serial then return false end
    local j,r=LR:GetJournal(),LR:GetReceipt(save.runId)
    if not r and not j.issued[save.runId] and serial<=j.retiredThrough then return false end
    if (save.phase=="RESULT" or save.phase=="GAMEOVER" and save.roundNo>0) and not r then return false end
    if r and (not save.settled or r.gameId~="SHELLGAME" or r.difficulty~="round_"..save.difficulty
        or r.tableId~=save.tableId or r.roundNo~=save.roundNo or r.finalChips2~=save.chips2
        or r.startChips2~=save.startChips2 or r.stake2~=save.bet2 or r.return2~=save.return2 or r.reason~=save.reason) then return false end
    return true
end
function E:ResetBet()
    if not self.gameState or not ArcadiaNexus.SHG_Logic:ResetBet(self.gameState) then return false end
    self:_Snapshot()
    local R=ArcadiaNexus.SHG_Renderer; if R then R:UpdateBetDisplay(self.gameState) end
    return true
end

function E:StopGame()
    return self:SaveAndPause()
end

function E:SaveAndPause()
    self:_InvalidateTimers()
    local gs=E.gameState
    if gs then
        if gs.phase=="REVEAL" or gs.phase=="SHUFFLE" or gs.phase=="GUESSING" then
            ArcadiaNexus.SHG_Logic:Settle(gs,nil,"ABORT"); E.state=gs.phase; self:_Snapshot()
        end
        if gs.phase=="RESULT_PENDING" then self:RetryResult(true) end
        self:_Snapshot()
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("SHELLGAME",E._sessionId)
        ArcadiaNexus.Lifecycle:EndGame("SHELLGAME", E._sessionId)
        E._sessionId = nil
    end
    self:_InvalidateTimers()

    local R = ArcadiaNexus.SHG_Renderer
    if R then R:OnGameStopped() end
    E.gameState = nil
    self.activeSlot=nil
    E.state     = "IDLE"
    return true
end

-- ── Einsatz-Verwaltung (BETTING-State, Blackjack-Pattern) ────────────
-- Chip hinzufügen (Linksklick)
function E:AddBet(amount)
    if E.state ~= "BETTING" or type(amount)~="number" or amount<=0 then return false end
    local gs = E.gameState
    if not gs then return end
    if not gs or not ArcadiaNexus.SHG_Logic:AdjustBet(gs,amount*2) then return false end
    self:_Snapshot()
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:UpdateBetDisplay(gs) end
    return true
end

-- Chip einer Farbe entfernen (Rechtsklick)
function E:RemoveBetOfColor(color, amount)
    if E.state ~= "BETTING" or type(amount)~="number" or amount<=0 then return false end
    local gs = E.gameState
    if not gs then return end
    if not gs or not ArcadiaNexus.SHG_Logic:AdjustBet(gs,-amount*2) then return false end
    self:_Snapshot()
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:UpdateBetDisplay(gs) end
    return true
end

-- ── Runde starten ─────────────────────────────────────────────
function E:StartRound()
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    local Logic = ArcadiaNexus.SHG_Logic
    if not Logic:BeginRound(gs) then return false end
    self:_InvalidateTimers(); self:_Snapshot()

    self:_SetState("REVEAL")
    self:_EnterReveal()
    return true
end

-- ── Phase 1: REVEAL ───────────────────────────────────────────
function E:_EnterReveal()
    local R = ArcadiaNexus.SHG_Renderer
    local gs,sid=E.gameState,E._sessionId; local runId=gs.runId
    PlaySHGSound("reveal")

    _timerGuard:Cancel()

    -- Schritt 1: Ball + angehobenen Cup sofort anzeigen
    if R then R:ShowRevealOpen(E.gameState) end

    -- Schritt 2: 1.8s warten (Ball sichtbar)
    self:_Schedule(1.8, function()
        -- Schritt 3: Cup fällt herunter, danach Shuffle
        if R then
            R:AnimateCupClose(gs, function()
                if E:_IsRound(sid,gs,runId) then self:_EnterShuffle() end
            end)
        else
            self:_EnterShuffle()
        end
    end)
end

-- ── Phase 2: SHUFFLE ──────────────────────────────────────────
function E:_EnterShuffle()
    if E.state ~= "REVEAL" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.SHG_Logic
    if not gs then return end

    gs.sequence = Logic:GenerateSequence(gs.difficulty)

    self:_SetState("SHUFFLE")
    PlaySHGSound("shuffle")

    local R = ArcadiaNexus.SHG_Renderer
    if R then R:HideReveal() end
    self:_ShuffleStep(1)
end

function E:_ShuffleStep(index)
    local gs=E.gameState
    if not gs or gs.phase~="SHUFFLE" then return end
    local step=gs.sequence[index]
    if not step then self:_EnterGuessing(); return end
    local sid,runId=E._sessionId,gs.runId; local completed=false
    local function done()
        if completed or not E:_IsRound(sid,gs,runId) or gs.phase~="SHUFFLE" then return end
        completed=true; ArcadiaNexus.SHG_Logic:ApplyStep(gs,step)
        E:_Schedule(step.pause,function() E:_ShuffleStep(index+1) end)
    end
    local R=ArcadiaNexus.SHG_Renderer
    if R and R.AnimateShuffleStep then R:AnimateShuffleStep(step,done)
    else self:_Schedule(step.duration,done) end
end

-- ── Phase 3: GUESSING ─────────────────────────────────────────
function E:_EnterGuessing()
    self:_SetState("GUESSING")
    -- OnStateChanged("GUESSING") aktiviert die Becher-Buttons im Renderer
end

-- ── Spieler-Tipp ─────────────────────────────────────────────
function E:MakeGuess(cupIndex)
    if E.state ~= "GUESSING" then return false end
    local gs = E.gameState
    if not gs then return end

    if not ArcadiaNexus.SHG_Logic:Settle(gs,cupIndex,"GUESS") then return false end
    self:_InvalidateTimers(); self:_SetState("RESULT_PENDING"); self:_Snapshot()
    self:_EvaluateResult()
    return true
end

-- ── Phase 4: RESULT ───────────────────────────────────────────
function E:_EvaluateResult()
    return self:RetryResult()
end

function E:RetryResult(silent)
    local gs=E.gameState
    if not gs or gs.phase~="RESULT_PENDING" then return false end
    local data={gameId="SHELLGAME",difficulty="round_"..gs.difficulty,runId=gs.runId,ruleVersion=2,
        score=0,result=gs.net2>0 and "WIN" or "LOSS",tableId=gs.tableId,roundNo=gs.roundNo,
        startChips2=gs.startChips2,stake2=gs.bet2,return2=gs.return2,finalChips2=gs.chips2,net2=gs.net2,reason=gs.reason,
        stats={finalChips=gs.chips2/2,roundsPlayed=1,roundsWon=gs.net2>0 and 1 or 0,roundsLost=gs.net2>0 and 0 or 1}}
    ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
    local R=ArcadiaNexus.SHG_Renderer
    if not data.processed then self:_Snapshot(); if R and not silent then R:ShowResultPending(gs) end; return false end
    gs.resultData=data; self:_SetState(gs.chips2<50 and "GAMEOVER" or "RESULT"); self:_Snapshot()
    if not silent then
        if not data.localReplay then PlaySHGSound(gs.phase=="GAMEOVER" and "bankrupt" or data.result=="WIN" and "win" or "lose") end
        if R then
            if gs.reason=="ABORT" then R:ShowSavedResult(gs)
            else R:ShowResult(gs,data.result=="WIN",gs.net2/2,gs.phase=="GAMEOVER") end
        end
    end
    return true
end

-- Spieler wählt: Weiter spielen
function E:ContinuePlaying()
    local gs = E.gameState
    if not gs or not ArcadiaNexus.SHG_Logic:ResetRound(gs) then return false end
    self:_InvalidateTimers(); gs.runId=ArcadiaNexus.LocalResults:NewRun("SHELLGAME")
    self:_Snapshot()
    self:_SetState("BETTING")
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:OnNewRound(gs) end
    return true
end

-- Spieler wählt: Spiel beenden
function E:EndGame()
    return self:SaveAndPause()
end

-- ── Bankrott ──────────────────────────────────────────────────
function E:_GameOver()
    return E.state=="GAMEOVER"
end

-- ── Schwierigkeit ändern (nur ohne aktive Kapitalpartie) ──────
function E:SetDifficulty(diff)
    if E.gameState or not ArcadiaNexus.SHG_Logic:IsDifficulty(diff) then return false end
    local S = ArcadiaNexus.SHG_Settings
    return S and S:Set("difficulty",diff)
end
