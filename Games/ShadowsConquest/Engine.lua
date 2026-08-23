-- Games/ShadowsConquest/Engine.lua

local E = {}
ArcadiaNexus.SC_Engine = E

E._sessionId = nil

E.state        = "IDLE"
E._gameState   = nil
E._puzzleIndex = 1

local SOUNDS = {
    toggle = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 850,
    win    = SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK     or 888,
    lose   = SOUNDKIT and SOUNDKIT.IG_QUEST_ABANDON               or 842,
}

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================
local function GetSettings()  return ArcadiaNexus.SC_Settings  end
local function GetLogic()     return ArcadiaNexus.SC_Logic     end
local function GetLevels()    return ArcadiaNexus.SC_Levels    end
local function GetRenderer()  return ArcadiaNexus.SC_Renderer  end

local function PlaySound(key)
    local S = GetSettings()
    if not S or not S:Get("soundEnabled") then return end
    if key == "toggle" and not S:Get("soundOnToggle") then return end
    if key == "win"    and not S:Get("soundOnWin")    then return end
    if key == "lose"   and not S:Get("soundOnLose")   then return end
    local id = SOUNDS[key]
    if id then C_Sound.PlaySound(id, "Master") end
end

-- ============================================================
-- SPIELSTART
-- ============================================================
function E:StartGame(diff)
    local S = GetSettings()
    local Logic = GetLogic()
    if not S or not Logic then return end

    self.state = "PLAYING"
    self._puzzleIndex = S:GetPuzzleIndex(diff)

    local entry, realIdx = ArcadiaNexus.LevelPool.GetEntry(GetLevels(), diff, self._puzzleIndex)
    if not entry then return end
    self._puzzleIndex = realIdx

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("SHADOWSCONQUEST", E._sessionId)

    local moveLimitActive = S:Get("moveLimitActive")
    local gs = Logic:NewState(diff, entry, false, moveLimitActive)
    gs.puzzleIndex = self._puzzleIndex
    gs.score = Logic:CalcScore(gs)
    self._gameState = gs

    local R = GetRenderer()
    if R then R:RenderGame(gs) end
end

-- ============================================================
-- KLICK-HANDLER
-- ============================================================
function E:HandleClick(row, col)
    if self.state ~= "PLAYING" then return end
    local gs = self._gameState
    local Logic = GetLogic()
    if not gs or not Logic then return end

    Logic:Toggle(gs, row, col)
    gs.score = Logic:CalcScore(gs)
    PlaySound("toggle")

    local R = GetRenderer()
    if R then R:UpdateGrid(gs, row, col) end

    if Logic:IsWon(gs) then
        self:_Win()
    elseif Logic:IsMoveLimitReached(gs) then
        self:_GameOver("moves")
    end

    if R and R.UpdateHUD then R:UpdateHUD(gs) end
end

-- ============================================================
-- WIN
-- ============================================================
function E:_Win()
    self.state = "WIN"

    local gs = self._gameState
    local Logic = GetLogic()
    local S = GetSettings()

    gs.finalScore = Logic:CalcScore(gs)
    PlaySound("win")

    if S then
        local levels = GetLevels()
        local pool = levels and levels[gs.difficulty]
        local nextIdx = self._puzzleIndex + 1
        if pool and nextIdx > #pool then nextIdx = 1 end
        S:SetPuzzleIndex(gs.difficulty, nextIdx)
        S:IncrementPuzzlesSolved()
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "SHADOWSCONQUEST",
        difficulty = gs.difficulty,
        score      = gs.finalScore,
        result     = "WIN",
        stats      = {
            puzzlesSolved = S and S:GetPuzzlesSolved() or 0,
            moveCount     = gs.moveCount or 0,
        },
    })

    local R = GetRenderer()
    if R then
        if R.ShowOverlay then R:ShowOverlay("WIN", gs) end
        if R._UpdateControlLabels then R:_UpdateControlLabels() end
    end
end

function E:_GameOver(reason)
    self.state = "GAMEOVER"
    local gs = self._gameState
    PlaySound("lose")

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "SHADOWSCONQUEST",
        difficulty = gs and gs.difficulty or "easy",
        score      = 0,
        result     = "LOSS",
    })

    local R = GetRenderer()
    if R then
        if R.ShowOverlay then R:ShowOverlay("GAMEOVER_MOVES", gs) end
        if R._UpdateControlLabels then R:_UpdateControlLabels() end
    end
end

-- ============================================================
-- RESET (Grid auf Ausgangszustand)
-- ============================================================
function E:ResetPuzzle()
    if self.state ~= "PLAYING" then return end
    local gs = self._gameState
    local Logic = GetLogic()
    if not gs or not Logic then return end

    gs.grid      = Logic:CloneGrid(gs.startGrid)
    gs.moveCount = 0
    gs.score     = Logic:CalcScore(gs)

    local R = GetRenderer()
    if R then R:RenderGame(gs) end
    if R and R.UpdateHUD then R:UpdateHUD(gs) end
end

-- ============================================================
-- STOP
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SHADOWSCONQUEST", E._sessionId)
        E._sessionId = nil
    end
    self.state      = "IDLE"
    self._gameState = nil
end

-- ============================================================
-- NEUES PUZZLE (nach Win, Overlay-Button)
-- ============================================================
function E:NextPuzzle()
    local gs   = self._gameState
    local diff = (gs and gs.difficulty) or
        (GetSettings() and GetSettings():Get("difficulty")) or "easy"
    self:StartGame(diff)
end
