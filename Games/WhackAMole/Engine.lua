-- Whack-a-Mole – Games/WhackAMole/Engine.lua

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.WAM_Engine = {}
local E = ArcadiaNexus.WAM_Engine

E._sessionId = nil

E.state         = "IDLE"
E._board        = nil
E._ticker       = nil
E._spawnTicker  = nil

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(difficulty)
    self:StopGame()

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("WHACKAMOLE", E._sessionId)

    local L = ArcadiaNexus.WAM_Logic
    local R = ArcadiaNexus.WAM_Renderer
    local S = ArcadiaNexus.WAM_Settings

    self._board = L:NewBoard(difficulty)
    self._board.gameActive = true
    self.state  = "PLAYING"

    R:EnterPlayState(self._board)

    -- 1s Countdown-Ticker
    self._ticker = C_Timer.NewTicker(1, function()
        if E.state ~= "PLAYING" then return end
        local b = E._board
        b.timeLeft = b.timeLeft - 1
        R:UpdateHUD(b)
        if b.timeLeft <= 0 then
            E:_gameOver(false)
        end
    end)

    -- Spawn-Ticker
    local spawnInterval = L:GetSpawnInterval(self._board)
    self._spawnTicker = C_Timer.NewTicker(spawnInterval, function()
        if E.state ~= "PLAYING" then return end
        E:_spawnMole()
        -- Doppel-Spawn bei wenig Zeit
        if E._board and E._board.timeLeft <= 15 then
            if math.random(100) <= 35 then
                C_Timer.After(0.25, function()
                    if E.state == "PLAYING" then E:_spawnMole() end
                end)
            end
        end
    end)

    if S:Get("soundEnabled") then PlaySound(774) end
end

-- ============================================================
-- StopGame
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("WHACKAMOLE", E._sessionId)
        E._sessionId = nil
    end
    if self._ticker      then self._ticker:Cancel();      self._ticker      = nil end
    if self._spawnTicker then self._spawnTicker:Cancel(); self._spawnTicker = nil end
    self.state  = "IDLE"
    self._board = nil
end

-- ============================================================
-- _spawnMole
-- ============================================================
function E:_spawnMole()
    local b = self._board
    if not b then return end
    local L = ArcadiaNexus.WAM_Logic
    local R = ArcadiaNexus.WAM_Renderer

    local free = L:GetFreeHoles(b)
    if #free == 0 then return end

    local slot   = free[math.random(#free)]
    local r, c   = slot.r, slot.c
    local isBomb, icon = L:PickSpawnType(b)

    b.holes[r][c].active = true
    b.holes[r][c].isBomb = isBomb
    b.holes[r][c].icon   = icon

    R:ShowMole(r, c, icon, isBomb)

    -- Auto-hide nach moleSpeed
    C_Timer.After(b.moleSpeed, function()
        if E.state ~= "PLAYING" then return end
        if b.holes[r] and b.holes[r][c] and b.holes[r][c].active then
            L:MoleMissed(b, r, c)
            R:HideMole(r, c)
            R:UpdateHUD(b)
        end
    end)
end

-- ============================================================
-- OnMoleClick – von Renderer aufgerufen
-- ============================================================
function E:OnMoleClick(r, c)
    if self.state ~= "PLAYING" then return end
    local b = self._board
    if not b then return end

    local L = ArcadiaNexus.WAM_Logic
    local R = ArcadiaNexus.WAM_Renderer
    local S = ArcadiaNexus.WAM_Settings

    local result, pts = L:HitMole(b, r, c)

    if result == "bomb" then
        R:HideMole(r, c)
        R:ShowBoomEffect(r, c)
        if S:Get("soundEnabled") ~= false and S:Get("soundOnBomb") ~= false then PlaySound(8959) end
        C_Timer.After(0.6, function()
            if E.state ~= "PLAYING" then return end
            E:_gameOver(true)
        end)
    elseif result == "hit" then
        R:HideMole(r, c)
        R:ShowHitEffect(r, c, "+" .. (pts or 0))
        R:UpdateHUD(b)
        if S:Get("soundEnabled") ~= false and S:Get("soundOnHit") ~= false then PlaySound(1115) end
    end
end

-- ============================================================
-- _gameOver
-- ============================================================
function E:_gameOver(hitBomb)
    if self._ticker      then self._ticker:Cancel();      self._ticker      = nil end
    if self._spawnTicker then self._spawnTicker:Cancel(); self._spawnTicker = nil end
    self.state = "GAMEOVER"

    local b = self._board
    if not b then return end

    local S = ArcadiaNexus.WAM_Settings
    local R = ArcadiaNexus.WAM_Renderer

    -- Alle aktiven Moles verstecken
    for r = 1, b.gridSize do
        for c = 1, b.gridSize do
            if b.holes[r][c].active then
                b.holes[r][c].active = false
                R:HideMole(r, c)
            end
        end
    end

    if S:Get("soundEnabled") then PlaySound(847) end

    R:ShowGameOver(b, hitBomb)

    -- Zentraler GAME_RESULT-Event (WAM endet immer als LOSS — Timer läuft ab oder Bombe getroffen)
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "WHACKAMOLE", difficulty = b.difficulty,
        score = b.score or 0, result = "LOSS",
        stats = {
            hitCount = b.hitCount or 0,
        },
    })
end
