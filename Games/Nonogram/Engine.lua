-- Games/Nonogram/Engine.lua

local ArcadiaNexus = _G.ArcadiaNexus
local E = {}
ArcadiaNexus.NON_Engine = E

E._sessionId = nil

E.state      = "IDLE"
E._gameState = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()

local SOUNDS = {
    fill  = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON   or 850,
    mark  = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON   or 850,
    error = SOUNDKIT and SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 846,
    win   = SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK       or 888,
    lose  = SOUNDKIT and SOUNDKIT.IG_QUEST_ABANDON                 or 842,
}

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================
local function GetLogic()    return ArcadiaNexus.NON_Logic    end
local function GetSettings() return ArcadiaNexus.NON_Settings end
local function GetLevels()   return ArcadiaNexus.NON_Levels   end
local function GetRenderer() return ArcadiaNexus.NON_Renderer end

local function PlayGameSound(key)
    local S = GetSettings()
    if not S or not S:Get("soundEnabled") then return end
    local keyMap = { fill="soundOnFill", mark="soundOnMark", error="soundOnError", win="soundOnWin", lose="soundOnLose" }
    local settingKey = keyMap[key]
    if settingKey and not S:Get(settingKey) then return end
    local id = SOUNDS[key]
    if id then C_Sound.PlaySound(id, "Master") end
end

-- ============================================================
-- TIMER
-- ============================================================
function E:_StartTimer()
    _timerGuard:Cancel()
    _timerGuard:EveryAfter(1, function()
        if E.state ~= "PLAYING" then return false end
        E:_TickTimer()
        return E.state == "PLAYING"
    end)
end

function E:_StopTimer()
    _timerGuard:Cancel()
end

function E:_TickTimer()
    local gs = E._gameState
    if not gs or not gs.timerActive then return end
    gs.timeLeft = math.max(0, gs.timeLeft - 1)
    local R = GetRenderer()
    if R and R.UpdateHUD then R:UpdateHUD(gs) end
    if gs.timeLeft <= 0 then
        E:_GameOver("time")
    end
end

-- ============================================================
-- SPIELSTART
-- ============================================================
function E:StartGame(diff, mode)
    local S = GetSettings()
    local Logic = GetLogic()
    if not S or not Logic then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("NONOGRAM", E._sessionId)

    diff = diff or S:Get("difficulty") or "easy"
    mode = mode or S:Get("defaultMode") or "free"
    S:Set("difficulty", diff)

    local R = GetRenderer()
    if R and R.frame then R.frame:EnableKeyboard(true) end

    local levels = GetLevels()
    local pool   = levels and levels[diff]
    local count  = pool and #pool or 0
    if count == 0 then return end
    local realIdx = math.random(1, count)
    local entry   = pool[realIdx]
    if not entry then return end

    local gs = Logic:CreateState(diff, mode, realIdx, entry)
    E._gameState = gs
    E.state = "PLAYING"

    if R then R:ShowPlaying(gs) end
    E:_StartTimer()
end

-- ============================================================
-- ZELL-KLICK
-- ============================================================
function E:HandleClick(row, col, action)
    if E.state ~= "PLAYING" then return end
    local gs = E._gameState
    if not gs then return end
    local Logic = GetLogic()
    if not Logic then return end

    gs.cursorR = row
    gs.cursorC = col

    local result = Logic:HandleClick(gs, row, col, action)

    if result == "gameover" then
        PlayGameSound("error")
        E:_GameOver("errors")
        return
    elseif result == "error" then
        PlayGameSound("error")
    elseif action == "FILL" then
        PlayGameSound("fill")
    elseif action == "MARK" then
        PlayGameSound("mark")
    end

    local R = GetRenderer()
    if R then R:UpdateBoard(gs) end

    if Logic:CheckWin(gs) then
        E:_Win()
    end
end

-- ============================================================
-- CURSOR-NAVIGATION
-- ============================================================
function E:MoveCursor(dr, dc)
    if E.state ~= "PLAYING" then return end
    local gs = E._gameState
    if not gs then return end
    local Logic = GetLogic()
    if Logic then Logic:MoveCursor(gs, dr, dc) end
    local R = GetRenderer()
    if R then R:UpdateCursor(gs) end
end

function E:HandleKeyAction(action)
    if E.state ~= "PLAYING" then return end
    local gs = E._gameState
    if not gs then return end
    if action == "FILL" then
        E:HandleClick(gs.cursorR, gs.cursorC, "FILL")
    elseif action == "MARK" then
        E:HandleClick(gs.cursorR, gs.cursorC, "MARK")
    elseif action == "TOGGLE_MODE" then
        local Logic = GetLogic()
        if Logic then Logic:ToggleInputMode(gs) end
        local R = GetRenderer()
        if R then R:UpdateInputModeLabel(gs) end
    end
end

-- ============================================================
-- SIEG
-- ============================================================
function E:_Win()
    E:_StopTimer()
    local gs = E._gameState
    if not gs then return end
    local Logic = GetLogic()
    local S     = GetSettings()

    gs.won        = true
    gs.finalScore = Logic:CalcScore(gs)
    E.state = "WIN"

    PlayGameSound("win")
    S:RecordResult("WIN")

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "NONOGRAM",
        difficulty = gs.difficulty,
        score      = gs.finalScore,
        result     = "WIN",
        stats      = { puzzlesSolved = S:GetStats().puzzlesSolved, mode = gs.mode },
    })

    local R = GetRenderer()
    if R then R:ShowWin(gs) end
end

-- ============================================================
-- GAME OVER
-- ============================================================
function E:_GameOver(reason)
    E:_StopTimer()
    local gs = E._gameState
    if not gs then return end
    local S = GetSettings()

    E.state = "GAMEOVER"
    PlayGameSound("lose")
    S:RecordResult("LOSS")

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "NONOGRAM",
        difficulty = gs.difficulty,
        score      = 0,
        result     = "LOSS",
    })

    local R = GetRenderer()
    if R then R:ShowGameOver(gs, reason) end
end

-- ============================================================
-- STOP
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("NONOGRAM", E._sessionId)
        E._sessionId = nil
    end
    E:_StopTimer()
    E.state      = "IDLE"
    E._gameState = nil
    local R = GetRenderer()
    if R then
        R:EnterIdleState()
    end
end
