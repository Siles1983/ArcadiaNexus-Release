-- Blockdrop – Games/Blockdrop/Engine.lua

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.BLD_Engine = {}
local E  = ArcadiaNexus.BLD_Engine

-- ============================================================
-- SOUND-ASSETS
-- ============================================================
local SND_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\Blockdrop\\assets\\sounds\\"
local SND = {
    move      = SND_PATH .. "move_piece.wav",
    rotate    = SND_PATH .. "rotate_piece.wav",
    line      = SND_PATH .. "line_clear.wav",
    blockdrop = SND_PATH .. "4_lines_clear.wav",
    levelup   = SND_PATH .. "level_up.wav",
}

local function PlaySnd(key)
    local S_ = ArcadiaNexus.BLD_Settings
    if S_ and S_:Get("snd_" .. key) then
        PlaySoundFile(SND[key], "Master")
    end
end

E.state        = "IDLE"
E._board       = nil
E._timer       = nil
E._keyFrame    = nil

local L, R, S, CE

function E:Init()
    L  = ArcadiaNexus.BLD_Logic
    R  = ArcadiaNexus.BLD_Renderer
    S  = ArcadiaNexus.BLD_Settings
    CE = ArcadiaNexus.Engine
end

-- ============================================================
-- KeyFrame
-- ============================================================
function E:_setupKeyFrame()
    if self._keyFrame then return end
    local parent = R and R.frame or UIParent
    local kf = CreateFrame("Frame", nil, parent)
    kf:SetAllPoints(parent)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        if E.state ~= "PLAYING" then return end
        local b = E._board
        if key == "A" or key == "LEFT" then
            L:MoveLeft(b); R:UpdatePiece(b)
            PlaySnd("move")
        elseif key == "D" or key == "RIGHT" then
            L:MoveRight(b); R:UpdatePiece(b)
            PlaySnd("move")
        elseif key == "W" or key == "UP" then
            L:Rotate(b); R:UpdatePiece(b)
            PlaySnd("rotate")
        elseif key == "S" or key == "DOWN" then
            if L:Tick(b, b.piece) then
                R:UpdatePiece(b)
            end
        elseif key == "SPACE" then
            L:HardDrop(b)
            R:UpdatePiece(b)
            PlaySnd("move")
        end
    end)
    -- Kein OnMouseDown auf keyFrame – wuerde Buttons blockieren.
    -- Rechtsklick-Rotation wird im _gridFrame des Renderers abgefangen.
    self._keyFrame = kf
end

function E:EnableKeys(enable)
    if self._keyFrame then
        self._keyFrame:EnableKeyboard(enable)
    end
end

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(config)
    if self.state == "PLAYING" then return end
    config = config or {}
    local slot = config.slot or (S and S:GetActiveSlot()) or 1
    if S and (slot < 1 or slot > S.MAX_SLOTS) then return end
    local mode = config.mode or "new"

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("BLOCKDROP", E._sessionId)
    self:_setupKeyFrame()
    self.activeSlot = slot
    if S then S:SetActiveSlot(slot) end

    local b
    if mode == "continue" and S then
        local save = S:LoadSlot(slot)
        if save and save.midGame then
            b = L:DeserializeBoard(save.midGame)
        end
    end
    if not b then
        if S then S:ResetSlot(slot) end
        b = L:NewBoard(S and S:Get("difficulty"))
        b.nextPiece = L:NewPiece(b)
        self._board = b
        self:_spawnNext()
    else
        if not b.nextPiece then b.nextPiece = L:NewPiece(b) end
        if not b.piece then
            self._board = b
            self:_spawnNext()
        end
    end
    self._board = b

    if S then S:SaveMidGame(slot, L:SerializeBoard(b)) end

    self.state = "PLAYING"
    self:EnableKeys(true)

    R:EnterPlayState(b)
    R:FullRedraw(b)

    self:_startTick()

    if CE then CE:Emit("BLD_GAME_STARTED", {}) end
end

-- ============================================================
-- StopGame
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("BLOCKDROP", E._sessionId)
        E._sessionId = nil
    end
    self:_stopTick()
    self:EnableKeys(false)
    self.state = "IDLE"
    self._board = nil
end

function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("BLOCKDROP", E._sessionId)
    end
    local b = self._board
    if b and S and L and self.activeSlot and self.state ~= "GAMEOVER" then
        S:SaveMidGame(self.activeSlot, L:SerializeBoard(b))
    end
    self:_stopTick()
    self:EnableKeys(false)
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("BLOCKDROP", E._sessionId)
        E._sessionId = nil
    end
    self.state = "IDLE"
    self._board = nil
end

-- ============================================================
-- Pause
-- ============================================================
function E:TogglePause()
    if self.state == "PLAYING" then
        self:_stopTick()
        self:EnableKeys(false)
        self.state = "PAUSED"
        R:ShowPause()
    elseif self.state == "PAUSED" then
        self:_startTick()
        self:EnableKeys(true)
        self.state = "PLAYING"
        R:HidePause()
    end
end

-- ============================================================
-- _spawnNext
-- ============================================================
function E:_spawnNext()
    local b = self._board
    b.piece     = b.nextPiece
    b.nextPiece = L:NewPiece(b)
    if L:CheckGameOver(b, b.piece) then
        self:_gameOver()
    end
end

-- ============================================================
-- Tick-Timer
-- ============================================================
function E:_startTick()
    self:_stopTick()
    local interval = L:GetTickInterval(self._board and self._board.level or 0)
    self._timer = C_Timer.NewTicker(interval, function()
        if E.state ~= "PLAYING" then return end
        E:_tick()
    end)
end

function E:_stopTick()
    if self._timer then
        self._timer:Cancel()
        self._timer = nil
    end
end

-- ============================================================
-- Gravity-Tick
-- ============================================================
function E:_tick()
    local b = self._board
    if not b or not b.piece then return end

    local landed = not L:Tick(b, b.piece)

    if landed then
        L:LockPiece(b, b.piece)
        local cleared = L:ClearLines(b)
        local oldLevel = b.level
        L:AddScore(b, cleared)

        -- Sound
        if cleared > 0 then
            if cleared == 4 then
                PlaySnd("blockdrop")
            else
                PlaySnd("line")
            end
        end

        if b.level ~= oldLevel then
            self:_startTick()
            PlaySnd("levelup")
            if CE then CE:Emit("BLD_LEVEL_UP", { level = b.level }) end
        end

        if cleared > 0 and CE then
            CE:Emit("BLD_LINES_CLEARED", { lines = cleared, score = b.score })
        end

        self:_spawnNext()
        R:FullRedraw(b)
    else
        R:UpdatePiece(b)
    end
end

-- ============================================================
-- GameOver
-- ============================================================
function E:_gameOver()
    self:_stopTick()
    self:EnableKeys(false)
    self.state = "GAMEOVER"

    local b = self._board
    if not b then return end

    -- kein eigener Game-Over-Sound (kein Asset vorhanden)

    R:ShowGameOver(b)

    if S and self.activeSlot then S:DeleteSlot(self.activeSlot) end

    if CE then CE:Emit("BLD_GAME_OVER", { score = b.score }) end

    -- Zentraler GAME_RESULT-Event
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "BLOCKDROP", difficulty = b.difficulty,
        score = b.score or 0, result = "LOSS",
        stats = {
            linesCleared = b.lines or 0,
        },
    })
end
