--[[
    ArcadiaNexus – Arcane Barrage
    Games/BubbleShooter/Generator.lua

    Deterministischer Seed-Generator für Kampagne und Endlos.
    Validator prüft, ob ein Level mit normalen Schüssen im Limit leer wird.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Generator = {}
local G = ArcadiaNexus.BS_Generator

local CAMPAIGN_COUNT = 100
local MASTER = 0xA1C4DE
-- Campaign-wide accessibility buffer.  It applies equally to generated early
-- and late levels so a theoretically tight clear does not become a player
-- facing failure because of a difficult trajectory or an unlucky setup.
G.CAMPAIGN_SHOT_BUFFER = 5

local function Logic()
    return ArcadiaNexus.BS_Logic
end

local function MakeRng(seed)
    local L = Logic()
    local proxy = {}
    L:SeedRng(proxy, seed)
    return proxy
end

local function SameColorTouch(L, grid, row, col, color, cols, rows)
    local n = L:Neighbors(row, col, cols, rows)
    for i = 1, #n do
        local nr, nc = n[i][1], n[i][2]
        if grid[nr][nc] == color then return true end
    end
    return false
end

local function IsAnchor(L, grid, row, col, cols, rows)
    if row == 1 then return true end
    local n = L:Neighbors(row, col, cols, rows)
    for i = 1, #n do
        if grid[n[i][1]][n[i][2]] > 0 then return true end
    end
    return false
end

local function PlacePair(L, rng, grid, cols, rows, colors, maxRow)
    local empties = {}
    for r = 1, math.min(maxRow, rows - 2) do
        for c = 1, cols do
            if grid[r][c] == 0 and IsAnchor(L, grid, r, c, cols, rows) then
                empties[#empties + 1] = { r, c }
            end
        end
    end
    if #empties == 0 then return false end
    for _ = 1, 24 do
        local a = empties[L:RandInt(rng, #empties)]
        local neigh = L:Neighbors(a[1], a[2], cols, rows)
        local opts = {}
        for i = 1, #neigh do
            local nr, nc = neigh[i][1], neigh[i][2]
            if nr <= maxRow and grid[nr][nc] == 0 then
                opts[#opts + 1] = { nr, nc }
            end
        end
        if #opts > 0 then
            local b = opts[L:RandInt(rng, #opts)]
            local color = L:RandInt(rng, colors)
            if not SameColorTouch(L, grid, a[1], a[2], color, cols, rows)
                and not SameColorTouch(L, grid, b[1], b[2], color, cols, rows) then
                grid[a[1]][a[2]] = color
                grid[b[1]][b[2]] = color
                return true
            end
        end
    end
    return false
end

function G:Encode(grid, cols, rows)
    return Logic():EncodeMap(grid, cols, rows)
end

local function ClonePlay(L, state)
    return {
        grid = L:CloneGrid(state.grid),
        cols = state.cols,
        rows = state.rows,
        colorCount = state.colorCount,
        dangerRow = state.dangerRow or L.DANGER_ROW,
        queue = { state.queue and state.queue[1] or 0, state.queue and state.queue[2] or 0 },
        rngS = state.rngS,
        boardSeed = state.boardSeed,
        shotsUsed = state.shotsUsed or 0,
    }
end

local function AdjacentEmpty(L, state)
    local cells, seen = {}, {}
    for r = 1, state.rows do
        for c = 1, state.cols do
            if L:GetCell(state, r, c) > 0 then
                local n = L:Neighbors(r, c, state.cols, state.rows)
                for i = 1, #n do
                    local nr, nc = n[i][1], n[i][2]
                    local key = nr * 100 + nc
                    if not seen[key] and L:GetCell(state, nr, nc) == 0 then
                        seen[key] = true
                        cells[#cells + 1] = { nr, nc }
                    end
                end
            end
        end
    end
    return cells
end

local function BestMove(L, state)
    local cells = AdjacentEmpty(L, state)
    local colors = L:ColorsOnBoard(state)
    local best, bestScore = nil, -1
    local setup, setupScore = nil, -1
    for i = 1, #cells do
        local r, c = cells[i][1], cells[i][2]
        for k = 1, #colors do
            local color = colors[k]
            local trial = ClonePlay(L, state)
            L:SetCell(trial, r, c, color)
            local popped, dropped = L:PopAndDrop(trial, r, c)
            local pn, dn = #popped, #dropped
            if pn >= (L.POP_MIN or 3) or dn > 0 then
                local score = pn + dn * 3 + (L:CountOccupied(trial) == 0 and 50 or 0)
                if score > bestScore then
                    bestScore = score
                    best = { r = r, c = c, color = color }
                end
            else
                local g = L:FindGroup(trial, r, c)
                if #g == 2 then
                    local sc = 1
                    if sc > setupScore then
                        setupScore = sc
                        setup = { r = r, c = c, color = color }
                    end
                end
            end
        end
    end
    return best or setup
end

-- Queue-aware counterpart to BestMove.  Campaign shots do not get to choose
-- their color; the next color is drawn from the board palette.  This helper
-- therefore only evaluates legal placements for the color currently loaded
-- in the cannon.  It remains a board-strategy validator, not a projectile
-- trajectory simulator: every evaluated cell is an empty neighbour of the
-- existing board, exactly as the normal solver does above.
local function MovesForColor(L, state, color, perStateLimit)
    local cells = AdjacentEmpty(L, state)
    local moves = {}
    local occupiedBefore = L:CountOccupied(state)
    for i = 1, #cells do
        local r, c = cells[i][1], cells[i][2]
        -- A normal campaign shot that settles in the danger row immediately
        -- loses.  Do not let the validator use that as a theoretical move.
        if r < (state.dangerRow or L.DANGER_ROW) then
            local trial = ClonePlay(L, state)
            L:SetCell(trial, r, c, color)
            local group = L:FindGroup(trial, r, c)
            local popped, dropped = L:PopAndDrop(trial, r, c)
            local pn, dn = #popped, #dropped
            -- Prefer clears, then deliberate pair setups, then a placement
            -- that keeps the largest same-colour group ready for a later shot.
            local score = (occupiedBefore - L:CountOccupied(trial)) * 1000
                + pn * 100 + dn * 300 + #group * 10
            if L:CountOccupied(trial) == 0 then score = score + 100000 end
            trial.shotsUsed = (state.shotsUsed or 0) + 1
            L:ConsumeQueue(trial)
            moves[#moves + 1] = { state = trial, score = score }
        end
    end
    table.sort(moves, function(a, b) return a.score > b.score end)
    while #moves > (perStateLimit or 10) do table.remove(moves) end
    return moves
end

function G:ValidateState(state, shotLimit)
    local L = Logic()
    if not L or not state then return false, 0 end
    local work = ClonePlay(L, state)
    local shots = 0
    local cap = shotLimit or 80
    while L:CountOccupied(work) > 0 do
        if shots >= cap then return false, shots end
        local move = BestMove(L, work)
        if not move then return false, shots end
        L:SetCell(work, move.r, move.c, move.color)
        L:PopAndDrop(work, move.r, move.c)
        shots = shots + 1
    end
    return true, shots
end

function G:ValidateDef(def)
    local L = Logic()
    if not def or not L then return false, 0 end
    local state = L:NewState({
        mode = "shot", map = def.map, cols = def.cols, rows = def.rows,
        colors = def.colors, shotLimit = 999, seed = 1,
    })
    return self:ValidateState(state, def.shotLimit or 80)
end

-- Validates a concrete, game-authentic queue.  seed controls the same PRNG
-- used by Logic:NewState / PickNextColor, so results are reproducible.
function G:ValidateQueuedDef(def, seed, shotLimit)
    local L = Logic()
    if not def or not L then return false, 0 end
    local work = L:NewState({
        mode = "shot", map = def.map, cols = def.cols, rows = def.rows,
        colors = def.colors, shotLimit = shotLimit or def.shotLimit or 80, seed = seed or 1,
    })
    local cap = shotLimit or def.shotLimit or 80
    -- Beam search avoids treating one greedy setup choice as proof that a
    -- queue is impossible.  Keeping 48 candidates is small enough for the
    -- dev validator, yet covers alternative setup lanes and drop routes.
    local beam = { work }
    local furthest = 0
    for _ = 1, cap do
        local nextBeam, seen = {}, {}
        for i = 1, #beam do
            local current = beam[i]
            if L:CountOccupied(current) == 0 then return true, current.shotsUsed end
            local moves = MovesForColor(L, current, current.queue[1], 10)
            for j = 1, #moves do
                local trial = moves[j].state
                if L:CountOccupied(trial) == 0 then return true, trial.shotsUsed end
                -- Identical boards with the same next queue and PRNG state
                -- need not occupy another beam slot.
                local key = L:EncodeMap(trial.grid, trial.cols, trial.rows)
                    .. ":" .. tostring(trial.queue[1]) .. ":" .. tostring(trial.queue[2])
                    .. ":" .. tostring(trial.rngS)
                if not seen[key] then
                    seen[key] = true
                    nextBeam[#nextBeam + 1] = moves[j]
                    if trial.shotsUsed > furthest then furthest = trial.shotsUsed end
                end
            end
        end
        table.sort(nextBeam, function(a, b) return a.score > b.score end)
        beam = {}
        for i = 1, math.min(48, #nextBeam) do beam[i] = nextBeam[i].state end
        if #beam == 0 then return false, furthest end
    end
    return false, cap
end

-- Runs several fixed queue seeds.  This is deliberately separate from the
-- generation solver: it is a regression/quality check, while generation must
-- remain fast and must not turn a sampled result into a hard content gate.
function G:ValidateQueuedSamples(def, sampleCount)
    local count = math.max(1, math.floor(sampleCount or 16))
    local worstShots, failedSeed, failedShots = 0, nil, nil
    for i = 1, count do
        local seed = 0x51A7 + i * 104729
        local ok, shots = self:ValidateQueuedDef(def, seed)
        if shots > worstShots then worstShots = shots end
        if not ok and not failedSeed then
            failedSeed, failedShots = seed, shots
        end
    end
    return not failedSeed, worstShots, failedSeed, failedShots
end

function G:BuildGrid(seed, spec)
    local L = Logic()
    spec = spec or {}
    local cols = spec.cols or L.COLS
    local rows = spec.rows or L.ROWS
    local colors = spec.colors or 3
    local pairs = spec.pairs or 4
    local maxRow = spec.maxRow or 5
    local rng = MakeRng(seed)
    local grid = L:EmptyGrid(cols, rows)
    local placed = 0
    local guard = 0
    while placed < pairs and guard < pairs * 20 do
        guard = guard + 1
        if PlacePair(L, rng, grid, cols, rows, colors, maxRow) then
            placed = placed + 1
        end
    end
    return grid, placed
end

function G:CampaignSpec(index)
    index = tonumber(index) or 1
    local colors = 2 + math.min(4, math.floor((index - 1) / 12))
    local pairs = 3 + math.floor((index - 1) / 7)
    if pairs > 14 then pairs = 14 end
    local maxRow = 4 + math.min(5, math.floor((index - 1) / 14))
    local slack = (index <= 20) and 3 or ((index <= 60) and 2 or 1)
    return {
        cols = 8, rows = 12, colors = colors, pairs = pairs, maxRow = maxRow, slack = slack,
    }
end

function G:MakeCampaignLevel(index)
    local L = Logic()
    index = tonumber(index) or 1
    local spec = self:CampaignSpec(index)
    local def
    for attempt = 0, 24 do
        local seed = MASTER + index * 7919 + attempt * 104729
        local grid, placed = self:BuildGrid(seed, spec)
        if placed >= math.max(2, spec.pairs - 2) then
            local map = L:EncodeMap(grid, spec.cols, spec.rows)
            local trial = {
                id = index, nameKey = "lvl_gen", cols = spec.cols, rows = spec.rows,
                colors = spec.colors, map = map, shotLimit = 80, seed = seed,
            }
            local ok, shots = self:ValidateDef(trial)
            if ok then
                local queueSeed = L:CampaignQueueSeed(index)
                -- The full queue beam search is deliberately a developer
                -- audit, not a lazy-load task.  Campaign levels are queried
                -- while the game UI is opening, so doing hundreds of search
                -- branches here would cause a visible hitch.  Keep a fixed
                -- queue and give generated puzzles a queue-wait allowance;
                -- ValidateQueuedDef remains available to audit content
                -- offline before a release.
                local queueAllowance = (spec.colors - 1) * math.ceil(placed / 3)
                trial.queueSeed = queueSeed
                trial.solverShots = shots
                trial.shotLimit = shots + spec.slack + queueAllowance + G.CAMPAIGN_SHOT_BUFFER
                def = trial
                break
            end
        end
    end
    if not def then
        def = {
            id = index, nameKey = "lvl_gen", cols = 8, rows = 12, colors = 2,
            shotLimit = 12 + G.CAMPAIGN_SHOT_BUFFER, map = "11......|11......", solverShots = 1,
        }
    end
    return def
end

G.CAMPAIGN_COUNT = CAMPAIGN_COUNT
