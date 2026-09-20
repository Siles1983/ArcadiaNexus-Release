local A, L = ArcadiaNexus, ArcadiaNexus.BG_Logic
A.BG_AI = {}
-- Easy picks legal moves at random; normal and hard use stronger position scores.
function A.BG_AI.Choose(s, difficulty, turns, rng)
    if type(difficulty) == "table" then turns, difficulty = difficulty, "normal" end
    difficulty = difficulty == "easy" and "easy" or (difficulty == "hard" and "hard" or "normal")
    turns = turns or L.LegalTurns(s)
    if #turns == 0 then return nil end
    if difficulty == "easy" then return turns[(rng or math.random)(#turns)] end
    local seat, best, bestValue = s.turn, nil, -math.huge
    local sg = seat == 1 and 1 or -1
    for _, seq in ipairs(turns or L.LegalTurns(s)) do
        local board = s
        for _, move in ipairs(seq) do board = L.Step(board, seat, move) end
        local value = board.off[seat] * 100 + board.bar[3 - seat] * 22 - L.Pips(board, seat)
        if difficulty == "hard" then value = value - board.bar[seat] * 18 + L.Pips(board, 3-seat) * 0.08 end
        local run = 0
        for p = 1, 24 do
            local count = board.points[p] * sg
            if count >= 2 then
                local home = L.Distance(p, seat) <= 6
                value = value + (home and 7 or 3)
                if difficulty == "hard" then
                    value = value + (home and 5 or 1); run = run + 1
                    if run >= 2 then value = value + 5 end
                end
            elseif count == 1 then
                run = 0
                local exposed = board.bar[3 - seat] > 0
                for q = 1, 24 do
                    if board.points[q] * sg < 0 and (p - q) * sg > 0 then exposed = true; break end
                end
                if exposed then value = value - (difficulty == "hard" and 15 or 9) end
            else run = 0 end
        end
        if value > bestValue then best, bestValue = seq, value end
    end
    return best
end
