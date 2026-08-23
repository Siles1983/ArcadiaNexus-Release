--[[
    Gaming Hub
    Games/Chess/Game.lua
    Version: 1.0.0

    Phasen:
      "PLAYING"   – Spiel läuft
      "CHECKMATE" – Schachmatt
      "STALEMATE" – Patt
      "RESIGNED"  – Spieler hat aufgegeben

    Spieler = weiß (Allianz), zieht zuerst
    KI      = schwarz (Horde)

    API:
      Game:Init(config)
      Game:SelectPiece(r, c)    → "selected" | "deselected" | "invalid"
      Game:MoveSelected(r, c)   → "moved" | "captured" | "invalid" | "check" | "checkmate"
      Game:Resign()
      Game:GetBoardState()
]]

local ArcadiaNexus = _G.ArcadiaNexus

local ChessGame = {}
ChessGame.__index = ChessGame
ArcadiaNexus.Chess_Game = ChessGame

function ChessGame:New()
    return setmetatable({}, self)
end

-- ============================================================
-- Init
-- ============================================================

function ChessGame:Init(config)
    self.config      = config or {}
    self.logic       = ArcadiaNexus.Chess_Logic
    self.ai          = ArcadiaNexus.Chess_AI
    self.difficulty  = self.config.difficulty or "easy"

    self.board       = self.logic:NewBoard()
    self.turn        = "white"   -- Weiß beginnt
    self.phase       = "PLAYING"
    self.result      = nil       -- "white_wins" | "black_wins" | "stalemate"

    self.selected    = nil       -- { r, c } aktuell ausgewählte Figur
    self.legalMoves  = {}        -- Züge für ausgewählte Figur
    self.lastMove    = nil       -- { fromR, fromC, toR, toC } letzter Zug
    self.inCheck     = false     -- steht Weiß gerade im Schach?
    self.moveCount   = 0
    self.capturedByWhite = {}    -- geschlagene schwarze Figuren
    self.capturedByBlack = {}    -- geschlagene weiße Figuren
end

-- ============================================================
-- SelectPiece – Spieler klickt eine Figur an
-- ============================================================

function ChessGame:SelectPiece(r, c)
    if self.phase ~= "PLAYING" or self.turn ~= "white" then
        return "invalid"
    end

    local piece = self.logic:GetPieceAt(self.board, r, c)

    -- Klick auf eigene Figur
    if piece and piece.color == "white" then
        if self.selected and self.selected.r == r and self.selected.c == c then
            -- Dieselbe Figur nochmal → Auswahl aufheben
            self.selected   = nil
            self.legalMoves = {}
            return "deselected"
        end
        self.selected   = { r = r, c = c }
        self.legalMoves = self.logic:GetLegalMoves(self.board, r, c)
        return "selected"
    end

    -- Klick auf leeres Feld oder Gegner ohne Auswahl
    return "invalid"
end

-- ============================================================
-- MoveSelected – Spieler zieht auf Zielfeld
-- ============================================================

function ChessGame:MoveSelected(r, c)
    if self.phase ~= "PLAYING" or self.turn ~= "white" then return "invalid" end
    if not self.selected then return "invalid" end

    -- Ist (r,c) ein legaler Zug?
    local move = nil
    for _, m in ipairs(self.legalMoves) do
        if m.toR == r and m.toC == c then
            move = m; break
        end
    end

    if not move then
        -- Klick auf eigene andere Figur → neu auswählen
        local piece = self.logic:GetPieceAt(self.board, r, c)
        if piece and piece.color == "white" then
            self.selected   = { r = r, c = c }
            self.legalMoves = self.logic:GetLegalMoves(self.board, r, c)
            return "selected"
        end
        self.selected   = nil
        self.legalMoves = {}
        return "invalid"
    end

    -- Zug ausführen
    local captured = self.board[r][c]
    self.board     = self.logic:ApplyMove(self.board, move)
    self.lastMove  = move
    self.selected  = nil
    self.legalMoves= {}
    self.moveCount = self.moveCount + 1

    if captured then
        self.capturedByWhite[#self.capturedByWhite+1] = captured
    end

    self.turn = "black"

    -- Spielende prüfen für Schwarz nach Weißem Zug
    if self.logic:IsCheckmate(self.board, "black") then
        self.phase  = "CHECKMATE"
        self.result = "white_wins"
        return "checkmate"
    end
    if self.logic:IsStalemate(self.board, "black") then
        self.phase  = "STALEMATE"
        self.result = "stalemate"
        return "stalemate"
    end

    self.inCheck = self.logic:IsInCheck(self.board, "black")
    return captured and "captured" or (self.inCheck and "check" or "moved")
end

-- ============================================================
-- DoAIMove – KI führt ihren Zug aus
-- ============================================================

function ChessGame:DoAIMove()
    if self.phase ~= "PLAYING" or self.turn ~= "black" then return "invalid" end

    local move = self.ai:GetMove(self.board, self.difficulty)
    if not move then
        -- KI hat keine Züge (sollte durch vorherige Schachmatt-Prüfung abgefangen sein)
        self.phase  = "STALEMATE"
        self.result = "stalemate"
        return "stalemate"
    end

    local captured = self.board[move.toR][move.toC]
    self.board     = self.logic:ApplyMove(self.board, move)
    self.lastMove  = move

    if captured then
        self.capturedByBlack[#self.capturedByBlack+1] = captured
    end

    self.turn = "white"

    -- Spielende prüfen für Weiß nach KI-Zug
    if self.logic:IsCheckmate(self.board, "white") then
        self.phase  = "CHECKMATE"
        self.result = "black_wins"
        return "checkmate"
    end
    if self.logic:IsStalemate(self.board, "white") then
        self.phase  = "STALEMATE"
        self.result = "stalemate"
        return "stalemate"
    end

    self.inCheck = self.logic:IsInCheck(self.board, "white")
    return captured and "captured" or (self.inCheck and "check" or "moved")
end

-- ============================================================
-- Resign
-- ============================================================

function ChessGame:Resign()
    self.phase  = "RESIGNED"
    self.result = "black_wins"
end

-- ============================================================
-- GetBoardState
-- ============================================================

function ChessGame:GetBoardState()
    return {
        board            = self.board,
        turn             = self.turn,
        phase            = self.phase,
        result           = self.result,
        selected         = self.selected,
        legalMoves       = self.legalMoves,
        lastMove         = self.lastMove,
        inCheck          = self.inCheck,
        moveCount        = self.moveCount,
        capturedByWhite  = self.capturedByWhite,
        capturedByBlack  = self.capturedByBlack,
        difficulty       = self.difficulty,
    }
end
