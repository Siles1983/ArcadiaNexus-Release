-- Hangman Engine.lua

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.HGM_Engine = {}
local E = ArcadiaNexus.HGM_Engine

E._sessionId = nil

local Logic    = ArcadiaNexus.HGM_Logic
local Settings = ArcadiaNexus.HGM_Settings

E.board = nil
E.state = "IDLE"

function E:StartGame()
    local Renderer = ArcadiaNexus.HGM_Renderer
    if not Renderer then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("HANGMAN", E._sessionId)

    local cat     = Settings:Get("category")
    local maxErr  = Settings:GetMaxErrors()
    local entry   = Logic:PickWord(cat)

    self.board = Logic:NewBoard(entry, maxErr)
    self.state = "PLAYING"

    -- Tastatur + Runen zurücksetzen, dann rendern
    Renderer:_resetKeyboard()
    Renderer:_resetRunes(maxErr)
    Renderer:RenderBoard(self.board)
    ArcadiaNexus.Engine:Emit("HGM_GAME_STARTED", {})
end

function E:GuessLetter(letter)
    if self.state ~= "PLAYING" then return end
    local Renderer = ArcadiaNexus.HGM_Renderer

    local found = Logic:GuessLetter(self.board, letter)

    if Settings:Get("soundEnabled") then
        PlaySound(found and 857 or 847)
    end

    Renderer:RenderBoard(self.board)

    if self.board.won then
        self.state = "WON"
        Settings:IncrWins()
        if Settings:Get("soundEnabled") then PlaySound(888765) end
        Renderer:ShowGameOver(true, self.board)
        ArcadiaNexus.Engine:Emit("HGM_GAME_WON", {})
        local diff = string.lower(Settings:Get("difficulty") or "Normal")
        local scoreMap = { easy = 100, normal = 150, hard = 200 }
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId = "HANGMAN", difficulty = diff,
            score = scoreMap[diff] or 150, result = "WIN",
            stats = {
                errors = self.board.errors or 0,
            },
        })
    elseif self.board.lost then
        self.state = "LOST"
        Settings:IncrLosses()
        if Settings:Get("soundEnabled") then PlaySound(846) end
        Renderer:ShowGameOver(false, self.board)
        ArcadiaNexus.Engine:Emit("HGM_GAME_LOST", {})
        local diff = string.lower(Settings:Get("difficulty") or "Normal")
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId = "HANGMAN", difficulty = diff, score = 0, result = "LOSS",
            stats = {
                errors = self.board.errors or 0,
            },
        })
    end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("HANGMAN", E._sessionId)
        E._sessionId = nil
    end
    self.board = nil
    self.state = "IDLE"
    local Renderer = ArcadiaNexus.HGM_Renderer
    if Renderer then Renderer:EnterIdleState() end
end
