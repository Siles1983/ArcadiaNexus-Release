--[[
    Gaming Hub
    Games/Chess/Logic.lua
    Version: 1.0.0

    6×6 Mini-Schach (Silbermann-Aufstellung):
      Reihe 1 (Horde, Schwarz):  T  S  D  K  S  T
      Reihe 2 (Horde, Schwarz):  B  B  B  B  B  B
      Reihe 5 (Allianz, Weiß):   B  B  B  B  B  B
      Reihe 6 (Allianz, Weiß):   T  S  D  K  S  T

    Figuren-Codes:
      PAWN   = Bauer
      ROOK   = Turm
      KNIGHT = Springer
      QUEEN  = Dame
      KING   = König

    Farben:
      "white" = Allianz (menschlicher Spieler, zieht von unten)
      "black" = Horde (KI, zieht von oben)

    board[r][c]:
      nil   = leeres Feld
      { type, color }

    Koordinaten:
      r=1 oben (Horde), r=6 unten (Allianz)
      c=1 links,        c=6 rechts

    Öffentliche API:
      Logic:NewBoard()
      Logic:GetLegalMoves(board, r, c)         → { {fromR,fromC,toR,toC}, ... }
      Logic:GetAllLegalMoves(board, color)      → alle Züge einer Seite
      Logic:ApplyMove(board, move)              → newBoard
      Logic:IsInCheck(board, color)             → bool
      Logic:IsCheckmate(board, color)           → bool
      Logic:IsStalemate(board, color)           → bool
      Logic:GetPieceAt(board, r, c)             → piece or nil
      Logic:CopyBoard(board)                    → newBoard
      Logic:GetPieceValue(type)                 → number (für KI)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Chess_Logic = {}
local Logic = ArcadiaNexus.Chess_Logic

-- ============================================================
-- Figurenwerte (für KI-Bewertung)
-- ============================================================
local PIECE_VALUE = {
    PAWN   = 100,
    KNIGHT = 300,
    ROOK   = 500,
    QUEEN  = 900,
    KING   = 10000,
}

-- Positionsboni für Bauern (fördern Vorwärtsbewegung)
-- Weiß bewegt sich von r=6 → r=1, Schwarz von r=1 → r=6
local PAWN_BONUS_WHITE = {
    [1]=60, [2]=50, [3]=30, [4]=20, [5]=10, [6]=0
}
local PAWN_BONUS_BLACK = {
    [1]=0, [2]=10, [3]=20, [4]=30, [5]=50, [6]=60
}

-- ============================================================
-- Board erstellen
-- ============================================================

function Logic:NewBoard()
    local board = {}
    for r = 1, 6 do
        board[r] = {}
        for c = 1, 6 do
            board[r][c] = nil
        end
    end

    -- Horde (schwarz) – oben
    local backRank = { "ROOK", "KNIGHT", "QUEEN", "KING", "KNIGHT", "ROOK" }
    for c = 1, 6 do
        board[1][c] = { type = backRank[c], color = "black" }
        board[2][c] = { type = "PAWN",      color = "black" }
    end

    -- Allianz (weiß) – unten
    for c = 1, 6 do
        board[5][c] = { type = "PAWN",      color = "white" }
        board[6][c] = { type = backRank[c], color = "white" }
    end

    return board
end

-- ============================================================
-- Board kopieren
-- ============================================================

function Logic:CopyBoard(board)
    local new = {}
    for r = 1, 6 do
        new[r] = {}
        for c = 1, 6 do
            if board[r][c] then
                new[r][c] = { type = board[r][c].type, color = board[r][c].color }
            else
                new[r][c] = nil
            end
        end
    end
    return new
end

-- ============================================================
-- Figur abrufen
-- ============================================================

function Logic:GetPieceAt(board, r, c)
    if r < 1 or r > 6 or c < 1 or c > 6 then return nil end
    return board[r][c]
end

-- ============================================================
-- Zug anwenden
-- ============================================================

function Logic:ApplyMove(board, move)
    local new = self:CopyBoard(board)
    local piece = new[move.fromR][move.fromC]
    new[move.toR][move.toC]     = piece
    new[move.fromR][move.fromC] = nil

    -- Bauernumwandlung: Bauer erreicht letzte Reihe → wird Dame
    if piece and piece.type == "PAWN" then
        if piece.color == "white" and move.toR == 1 then
            new[move.toR][move.toC].type = "QUEEN"
        elseif piece.color == "black" and move.toR == 6 then
            new[move.toR][move.toC].type = "QUEEN"
        end
    end

    return new
end

-- ============================================================
-- Rohe Züge (ohne Schach-Prüfung)
-- ============================================================

local function inBounds(r, c)
    return r >= 1 and r <= 6 and c >= 1 and c <= 6
end

local function addSlideMoves(board, r, c, dirs, moves)
    local piece = board[r][c]
    for _, d in ipairs(dirs) do
        local nr, nc = r + d[1], c + d[2]
        while inBounds(nr, nc) do
            local target = board[nr][nc]
            if target then
                if target.color ~= piece.color then
                    moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
                end
                break  -- blockiert
            end
            moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
            nr = nr + d[1]; nc = nc + d[2]
        end
    end
end

local function addStepMoves(board, r, c, offsets, moves)
    local piece = board[r][c]
    for _, o in ipairs(offsets) do
        local nr, nc = r + o[1], c + o[2]
        if inBounds(nr, nc) then
            local target = board[nr][nc]
            if not target or target.color ~= piece.color then
                moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
            end
        end
    end
end

function Logic:GetRawMoves(board, r, c)
    local piece = board[r][c]
    if not piece then return {} end
    local moves = {}

    if piece.type == "PAWN" then
        local dir = (piece.color == "white") and -1 or 1  -- weiß nach oben (r-1), schwarz nach unten
        local nr = r + dir
        -- Vorwärts (nur wenn leer)
        if inBounds(nr, c) and not board[nr][c] then
            moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=c }
        end
        -- Diagonal schlagen
        for _, dc in ipairs({ -1, 1 }) do
            local nc = c + dc
            if inBounds(nr, nc) and board[nr][nc] and board[nr][nc].color ~= piece.color then
                moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
            end
        end

    elseif piece.type == "ROOK" then
        addSlideMoves(board, r, c,
            { {1,0},{-1,0},{0,1},{0,-1} }, moves)

    elseif piece.type == "KNIGHT" then
        addStepMoves(board, r, c,
            { {2,1},{2,-1},{-2,1},{-2,-1},{1,2},{1,-2},{-1,2},{-1,-2} }, moves)

    elseif piece.type == "QUEEN" then
        addSlideMoves(board, r, c,
            { {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1} }, moves)

    elseif piece.type == "KING" then
        addStepMoves(board, r, c,
            { {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1} }, moves)
    end

    return moves
end

-- ============================================================
-- Schach-Prüfung: Steht `color`s König im Schach?
-- ============================================================

function Logic:IsInCheck(board, color)
    -- König finden
    local kr, kc
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p and p.color == color and p.type == "KING" then
                kr, kc = r, c
            end
        end
    end
    if not kr then return true end  -- kein König = verloren

    -- Prüfen ob gegnerische Figur den König angreift
    local enemy = (color == "white") and "black" or "white"
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p and p.color == enemy then
                local raw = self:GetRawMoves(board, r, c)
                for _, m in ipairs(raw) do
                    if m.toR == kr and m.toC == kc then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================
-- Legale Züge (bereinigt um Selbst-Schach)
-- ============================================================

function Logic:GetLegalMoves(board, r, c)
    local piece = board[r][c]
    if not piece then return {} end

    local raw    = self:GetRawMoves(board, r, c)
    local legal  = {}

    for _, move in ipairs(raw) do
        local newBoard = self:ApplyMove(board, move)
        if not self:IsInCheck(newBoard, piece.color) then
            legal[#legal+1] = move
        end
    end
    return legal
end

-- ============================================================
-- Alle legalen Züge einer Farbe
-- ============================================================

function Logic:GetAllLegalMoves(board, color)
    local all = {}
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p and p.color == color then
                local moves = self:GetLegalMoves(board, r, c)
                for _, m in ipairs(moves) do
                    all[#all+1] = m
                end
            end
        end
    end
    return all
end

-- ============================================================
-- Schachmatt / Patt
-- ============================================================

function Logic:IsCheckmate(board, color)
    if not self:IsInCheck(board, color) then return false end
    return #self:GetAllLegalMoves(board, color) == 0
end

function Logic:IsStalemate(board, color)
    if self:IsInCheck(board, color) then return false end
    return #self:GetAllLegalMoves(board, color) == 0
end

-- ============================================================
-- Figurenwert
-- ============================================================

function Logic:GetPieceValue(pieceType)
    return PIECE_VALUE[pieceType] or 0
end

-- ============================================================
-- Board-Bewertung für KI (positiv = gut für Weiß)
-- ============================================================

function Logic:EvaluateBoard(board)
    local score = 0
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p then
                local val = PIECE_VALUE[p.type] or 0
                -- Positionsbonus für Bauern
                if p.type == "PAWN" then
                    if p.color == "white" then
                        val = val + (PAWN_BONUS_WHITE[r] or 0)
                    else
                        val = val + (PAWN_BONUS_BLACK[r] or 0)
                    end
                end
                -- Zentrumsbonus für alle Figuren (c=3,4 und r=3,4)
                if (c == 3 or c == 4) and (r == 3 or r == 4) then
                    val = val + 15
                end
                if p.color == "white" then
                    score = score + val
                else
                    score = score - val
                end
            end
        end
    end
    return score
end

-- ============================================================
-- Match (öffentliches 6×6, 2 Sitze). KI bleibt im Spiele-Tab.
-- Intent: MOVE i=from (1–36), n=to (1–36); RESIGN.
-- ============================================================

Logic.GAME_ID = "CHESS"
Logic.GAME_PROTO = 1
Logic.MP_SIZE = 6

local ENC = { PAWN = "P", ROOK = "R", KNIGHT = "N", QUEEN = "Q", KING = "K" }
local DEC = {
    P = "PAWN", R = "ROOK", N = "KNIGHT", Q = "QUEEN", K = "KING",
    p = "PAWN", r = "ROOK", n = "KNIGHT", q = "QUEEN", k = "KING",
}

function Logic.Cell(r, c)
    return (r - 1) * 6 + c
end

function Logic.RC(i)
    i = tonumber(i)
    if not i or i < 1 or i > 36 then return nil end
    local r = math.floor((i - 1) / 6) + 1
    local c = ((i - 1) % 6) + 1
    return r, c
end

function Logic.PackBoard(board)
    local t = {}
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board and board[r] and board[r][c]
            if not p then
                t[#t + 1] = "."
            else
                local ch = ENC[p.type] or "P"
                if p.color == "black" then
                    ch = string.lower(ch)
                end
                t[#t + 1] = ch
            end
        end
    end
    return table.concat(t)
end

function Logic.UnpackBoard(s)
    s = type(s) == "string" and s or ""
    if #s < 36 then
        s = s .. string.rep(".", 36 - #s)
    end
    local board = {}
    local i = 1
    for r = 1, 6 do
        board[r] = {}
        for c = 1, 6 do
            local ch = s:sub(i, i)
            i = i + 1
            if ch == "." or ch == "" then
                board[r][c] = nil
            else
                local typ = DEC[ch]
                if typ then
                    local color = (ch == string.upper(ch)) and "white" or "black"
                    board[r][c] = { type = typ, color = color }
                else
                    board[r][c] = nil
                end
            end
        end
    end
    return board
end

function Logic.UnpackLastMove(lm)
    if type(lm) ~= "string" or #lm ~= 4 then return nil end
    local a, b, c, d = lm:match("^(%d)(%d)(%d)(%d)$")
    if not a then return nil end
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not a or a < 1 or a > 6 or b < 1 or b > 6 or c < 1 or c > 6 or d < 1 or d > 6 then
        return nil
    end
    return { fromR = a, fromC = b, toR = c, toC = d }
end

local function UnpackCaptured(s, color)
    local list = {}
    if type(s) ~= "string" then return list end
    for i = 1, #s do
        local ch = s:sub(i, i)
        local typ = DEC[ch]
        if typ then
            list[#list + 1] = { type = typ, color = color }
        end
    end
    return list
end

function Logic.EmptyPublic()
    return {
        b = Logic.PackBoard(Logic:NewBoard()),
        t = 1,
        o = 0,
        w = 0,
        lm = "",
        mc = 0,
        cw = "",
        cb = "",
        over = false,
        winner = 0,
        turn = 1,
    }
end

function Logic.ApplyMatch(pub, intent, seat)
    if not pub then return false end
    if pub.over or tonumber(pub.o) == 1 then return false end
    seat = tonumber(seat) or 0
    if seat ~= 1 and seat ~= 2 then return false end
    local kind = (intent and intent.kind) or "MOVE"
    if kind == "RESIGN" then
        pub.over = true
        pub.o = 1
        pub.w = (seat == 1) and 2 or 1
        pub.winner = pub.w
        return true
    end
    if seat ~= (tonumber(pub.t) or pub.turn or 1) then return false end
    local fromR, fromC = Logic.RC(intent and intent.i)
    local toR, toC = Logic.RC(intent and intent.n)
    if not fromR or not toR then return false end
    local board = Logic.UnpackBoard(pub.b)
    local color = (seat == 1) and "white" or "black"
    local piece = Logic:GetPieceAt(board, fromR, fromC)
    if not piece or piece.color ~= color then return false end
    local legal = Logic:GetLegalMoves(board, fromR, fromC)
    local move
    for _, m in ipairs(legal) do
        if m.toR == toR and m.toC == toC then
            move = m
            break
        end
    end
    if not move then return false end
    local captured = board[toR][toC]
    board = Logic:ApplyMove(board, move)
    pub.b = Logic.PackBoard(board)
    pub.lm = string.format("%d%d%d%d", fromR, fromC, toR, toC)
    pub.mc = (tonumber(pub.mc) or 0) + 1
    if captured then
        local ch = ENC[captured.type] or "P"
        if captured.color == "black" then
            pub.cw = (pub.cw or "") .. string.lower(ch)
        else
            pub.cb = (pub.cb or "") .. ch
        end
    end
    local opp = (color == "white") and "black" or "white"
    if Logic:IsCheckmate(board, opp) then
        pub.over = true
        pub.o = 1
        pub.w = seat
        pub.winner = seat
    elseif Logic:IsStalemate(board, opp) then
        pub.over = true
        pub.o = 1
        pub.w = 0
        pub.winner = 0
    else
        pub.t = (seat == 1) and 2 or 1
        pub.turn = pub.t
    end
    return true
end

function Logic.IsFinished(pub)
    return pub and (pub.over == true or tonumber(pub.o) == 1)
end

function Logic.PackPublic(pub)
    if not pub then return {} end
    return {
        b = pub.b,
        t = pub.t or pub.turn or 1,
        o = (pub.over or tonumber(pub.o) == 1) and 1 or 0,
        w = pub.winner or pub.w or 0,
        lm = pub.lm or "",
        mc = pub.mc or 0,
        cw = pub.cw or "",
        cb = pub.cb or "",
    }
end

function Logic.UnpackPublic(pub, f)
    if not pub or not f then return end
    if f.b ~= nil and f.b ~= "" then pub.b = f.b end
    if f.t ~= nil then
        pub.t = tonumber(f.t) or pub.t
        pub.turn = pub.t
    end
    if f.o ~= nil then
        pub.o = tonumber(f.o) or 0
        pub.over = pub.o == 1
    end
    if f.w ~= nil then
        pub.w = tonumber(f.w) or 0
        pub.winner = pub.w
    end
    if f.lm ~= nil then pub.lm = f.lm end
    if f.mc ~= nil then pub.mc = tonumber(f.mc) or pub.mc end
    if f.cw ~= nil then pub.cw = f.cw end
    if f.cb ~= nil then pub.cb = f.cb end
end

function Logic.PackStart(pub)
    return Logic.PackPublic(pub)
end

function Logic.UnpackStart(pub, f)
    Logic.UnpackPublic(pub, f)
end

function Logic.CanTryStart(node)
    if not node then return false end
    local n = 0
    local max = node.maxSeats or 2
    for i = 1, max do
        local k = node.seats and node.seats[i]
        if k and k ~= "" then
            n = n + 1
            if not (node.ready and node.ready[i]) then return false end
        end
    end
    return n == 2
end

function Logic.BoardStateFromPublic(pub, localSeat)
    pub = pub or Logic.EmptyPublic()
    local board = Logic.UnpackBoard(pub.b)
    local turnSeat = tonumber(pub.t) or pub.turn or 1
    local turn = (turnSeat == 1) and "white" or "black"
    local over = pub.over == true or tonumber(pub.o) == 1
    local winner = tonumber(pub.winner or pub.w) or 0
    localSeat = tonumber(localSeat) or 1
    local result, localResult, phase
    if over then
        if winner == 0 then
            result = "stalemate"
            localResult = "DRAW"
            phase = "STALEMATE"
        else
            result = (winner == 1) and "white_wins" or "black_wins"
            localResult = (winner == localSeat) and "WIN" or "LOSS"
            phase = "CHECKMATE"
        end
    else
        phase = "PLAYING"
    end
    local inCheck = (not over) and Logic:IsInCheck(board, turn)
    return {
        board = board,
        turn = turn,
        phase = phase,
        result = result,
        localResult = localResult,
        selected = nil,
        legalMoves = {},
        lastMove = Logic.UnpackLastMove(pub.lm),
        inCheck = inCheck,
        checkColor = inCheck and turn or nil,
        moveCount = tonumber(pub.mc) or 0,
        capturedByWhite = UnpackCaptured(pub.cw, "black"),
        capturedByBlack = UnpackCaptured(pub.cb, "white"),
        localSeat = localSeat,
        gameOver = over,
    }
end

function Logic.MatchOpts(engine)
    return {
        gameId = Logic.GAME_ID,
        gameProto = Logic.GAME_PROTO,
        maxSeats = 2,
        newPublic = Logic.EmptyPublic,
        seedOnStart = function()
            return Logic.EmptyPublic()
        end,
        packPublic = Logic.PackPublic,
        unpackPublic = Logic.UnpackPublic,
        packStart = Logic.PackStart,
        unpackStart = Logic.UnpackStart,
        applyIntent = function(pub, intent, seat)
            return Logic.ApplyMatch(pub, intent, seat)
        end,
        privateForSeat = function()
            return nil
        end,
        isFinished = Logic.IsFinished,
        onState = function(_, st)
            if engine then engine:OnMatchState(st) end
        end,
        onResult = function(node, resultId)
            if engine then engine:OnMatchResult(node, resultId) end
        end,
        onReject = function(_, f)
            if engine then engine:OnMatchReject(f) end
        end,
        onPublic = function()
            if engine then engine:OnMatchPublic() end
        end,
        canTryStart = function(node)
            return Logic.CanTryStart(node)
        end,
    }
end
