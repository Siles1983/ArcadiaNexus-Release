--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Logic.lua

    Reine Spielregeln, kein UI, kein Timer.
    Hex-Layout: odd-r (ungerade Reihen um eine halbe Zelle versetzt).
    y wächst nach unten; Schuss fliegt nach oben (vy < 0).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Logic = {}
local L = ArcadiaNexus.BS_Logic

-- Arena and grid are deliberately separate: the 8-column grid sits centered inside
-- a fixed play area.  The hex grid is deliberately narrower than the
-- collision bounds, leaving a visible bubble-radius safety lane at both walls.
L.CELL        = 30
L.RADIUS      = L.CELL / 2
L.PAD         = 6
-- Kreis-Kreis: Kontakt, wenn Zentren näher als 2*RADIUS (plus etwas Klebrigkeit).
L.CONTACT_MUL = 2.02
L.HEX_W       = L.CELL
L.HEX_H       = L.CELL * math.sqrt(3) / 2
L.COLS        = 8
L.ROWS        = 12
L.DANGER_ROW  = 11
L.COLOR_COUNT = 6
L.POP_MIN     = 3
L.SHOT_SPEED  = 840
L.ARENA_W     = 335
L.ARENA_H     = 462
L.GRID_W      = L.COLS * L.HEX_W + L.HEX_W * 0.5
L.FIELD_W     = L.ARENA_W
L.GRID_LEFT   = (L.FIELD_W - L.GRID_W) * 0.5
L.GRID_H      = (L.ROWS - 1) * L.HEX_H + L.CELL
L.FIELD_H     = L.ARENA_H
L.SHOOTER_X   = L.FIELD_W / 2
L.SHOOTER_Y   = L.FIELD_H - L.PAD - L.RADIUS - 4
L.SHOT_MAX_LIFE = 2.8

L.POP_POINTS  = 10
L.DROP_POINTS = 25

L.POWER_MAX          = 100
L.POWER_PER_SUCCESS  = 22
L.OVERCHARGE_STREAK  = 5
L.OVERCHARGE_SECS    = 10
L.OVERCHARGE_SCORE   = 2
L.OVERCHARGE_POWER   = 2

L.TIME_START         = 120
L.MISS_PHASES        = { 6, 5, 4, 3 }
L.ROWS_PER_PHASE     = 4

L.POWERS = { "joker", "bomb", "lightning", "dragonfire" }

L.AIM = {
    easy   = { length = 420, bounce = true  },
    normal = { length = 180, bounce = true  },
    hard   = { length = 140, bounce = false },
}

local SQRT3_2 = math.sqrt(3) / 2

-- odd-r Nachbarn: {drow, dcol}  (1-index, ungerade Reihen versetzt)
local N_EVEN = { { 0,  1 }, { -1,  0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1,  0 } }
local N_ODD  = { { 0,  1 }, { -1,  1 }, { -1,  0 }, { 0, -1 }, { 1,  0 }, { 1,  1 } }

local function Shuffle(tbl)
    local AU = ArcadiaNexus.ArrayUtils
    if AU and AU.Shuffle then
        return AU.Shuffle(tbl)
    end
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

function L.ScoreKey(mode, difficulty)
    return (mode or "endless") .. "_" .. (difficulty or "easy")
end

function L:InBounds(row, col, cols, rows)
    cols = cols or self.COLS
    rows = rows or self.ROWS
    return row >= 1 and row <= rows and col >= 1 and col <= cols
end

function L:Neighbors(row, col, cols, rows)
    cols = cols or self.COLS
    rows = rows or self.ROWS
    local dirs = (row % 2 == 1) and N_ODD or N_EVEN
    local out = {}
    for i = 1, 6 do
        local nr, nc = row + dirs[i][1], col + dirs[i][2]
        if self:InBounds(nr, nc, cols, rows) then
            out[#out + 1] = { nr, nc }
        end
    end
    return out
end

function L:ContactDist2()
    local d = self.RADIUS * self.CONTACT_MUL
    return d * d
end

function L:CirclesOverlap(ax, ay, bx, by)
    return Dist2(ax, ay, bx, by) < self:ContactDist2()
end

function L:HexToPixel(row, col)
    local x = self.GRID_LEFT + (col - 1) * self.HEX_W + ((row % 2 == 1) and (self.HEX_W * 0.5) or 0) + self.RADIUS
    local y = self.PAD + (row - 1) * self.HEX_H + self.RADIUS
    return x, y
end

function L:PixelToHex(x, y, cols, rows)
    cols = cols or self.COLS
    rows = rows or self.ROWS
    local lx = x - self.GRID_LEFT
    local ly = y - self.PAD
    local approxRow = Clamp(math.floor((ly - self.RADIUS) / self.HEX_H + 0.5) + 1, 1, rows)
    local bestR, bestC, bestD = 1, 1, 1e18
    for r = math.max(1, approxRow - 1), math.min(rows, approxRow + 1) do
        local colOff = (r % 2 == 1) and (self.HEX_W * 0.5) or 0
        local approxCol = Clamp(math.floor((lx - self.RADIUS - colOff) / self.HEX_W + 0.5) + 1, 1, cols)
        for c = math.max(1, approxCol - 1), math.min(cols, approxCol + 1) do
            local px, py = self:HexToPixel(r, c)
            local d = Dist2(x, y, px, py)
            if d < bestD then
                bestD, bestR, bestC = d, r, c
            end
        end
    end
    return bestR, bestC
end

function L:CollisionBounds()
    local radius = self.RADIUS
    return self.PAD + radius, self.FIELD_W - self.PAD - radius,
        self.PAD + radius, self.FIELD_H - radius
end

function L:GetCell(state, row, col)
    local grid = state.grid
    if not grid or not grid[row] then return 0 end
    return grid[row][col] or 0
end

function L:SetCell(state, row, col, color)
    if not state.grid[row] then state.grid[row] = {} end
    state.grid[row][col] = color
end

function L:EmptyGrid(cols, rows)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = 0
        end
    end
    return grid
end

function L:ParseMap(map, cols, rows)
    cols = cols or self.COLS
    rows = rows or self.ROWS
    local grid = self:EmptyGrid(cols, rows)
    if not map or map == "" then return grid end
    map = map:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("|", "\n")
    local rowIdx = 1
    for line in string.gmatch(map, "[^\n]+") do
        if rowIdx > rows then break end
        for c = 1, math.min(cols, #line) do
            local ch = line:sub(c, c)
            if ch >= "1" and ch <= "9" then
                grid[rowIdx][c] = tonumber(ch)
            else
                grid[rowIdx][c] = 0
            end
        end
        rowIdx = rowIdx + 1
    end
    return grid
end

function L:EncodeMap(grid, cols, rows)
    cols = cols or self.COLS
    rows = rows or self.ROWS
    local lines = {}
    for r = 1, rows do
        local chars = {}
        for c = 1, cols do
            local v = grid[r] and grid[r][c] or 0
            chars[c] = (v > 0) and tostring(v) or "."
        end
        lines[r] = table.concat(chars)
    end
    return table.concat(lines, "|")
end

function L:SeedRng(state, seed)
    seed = math.floor(tonumber(seed) or 1)
    seed = seed % 2147483647
    if seed <= 0 then seed = 1 end
    state.rngS = seed
end

function L:Rand(state)
    if not state.rngS then self:SeedRng(state, 1) end
    local s = (state.rngS * 48271) % 2147483647
    state.rngS = s
    return s / 2147483647
end

function L:RandInt(state, n)
    if not n or n < 1 then return 1 end
    return math.floor(self:Rand(state) * n) + 1
end

-- Campaign puzzles must be replayable: the same level always begins with
-- the same two bubbles and produces the same following queue.  Endless and
-- time modes deliberately keep their per-run random seed.
function L:CampaignQueueSeed(levelIndex)
    levelIndex = math.max(1, math.floor(tonumber(levelIndex) or 1))
    return 0x5EED + levelIndex * 104729
end

-- Campaign-specific rating rule. CampaignProgress stores the result but
-- intentionally knows nothing about shots, bubbles, or this threshold.
function L:GradeCampaignStars(state)
    if not state or state.mode ~= "shot" then return 0 end
    local limit = math.max(1, tonumber(state.shotLimit) or 1)
    local remaining = math.max(0, limit - (tonumber(state.shotsUsed) or 0))
    if remaining >= math.max(3, math.ceil(limit * 0.35)) then return 3 end
    if remaining >= 1 then return 2 end
    return 1
end

function L:CountOccupied(state)
    local n = 0
    for r = 1, state.rows do
        for c = 1, state.cols do
            if self:GetCell(state, r, c) > 0 then n = n + 1 end
        end
    end
    return n
end

function L:ColorsOnBoard(state)
    local seen, list = {}, {}
    for r = 1, state.rows do
        for c = 1, state.cols do
            local v = self:GetCell(state, r, c)
            if v > 0 and not seen[v] then
                seen[v] = true
                list[#list + 1] = v
            end
        end
    end
    table.sort(list)
    return list
end

function L:PickNextColor(state)
    local colors = self:ColorsOnBoard(state)
    if #colors == 0 then
        local maxC = state.colorCount or self.COLOR_COUNT
        return self:RandInt(state, maxC)
    end
    return colors[self:RandInt(state, #colors)]
end

function L:FillQueue(state)
    state.queue = state.queue or { 0, 0 }
    if (state.queue[1] or 0) == 0 then
        state.queue[1] = self:PickNextColor(state)
    end
    if (state.queue[2] or 0) == 0 then
        state.queue[2] = self:PickNextColor(state)
    end
end

function L:ConsumeQueue(state)
    local color = state.queue[1]
    state.queue[1] = state.queue[2]
    state.queue[2] = self:PickNextColor(state)
    return color
end

function L:FindGroup(state, row, col)
    local color = self:GetCell(state, row, col)
    if color <= 0 then return {} end
    local key = function(r, c) return r * 100 + c end
    local seen, stack, group = {}, { { row, col } }, {}
    seen[key(row, col)] = true
    while #stack > 0 do
        local cell = table.remove(stack)
        group[#group + 1] = cell
        local neigh = self:Neighbors(cell[1], cell[2], state.cols, state.rows)
        for i = 1, #neigh do
            local nr, nc = neigh[i][1], neigh[i][2]
            local k = key(nr, nc)
            if not seen[k] and self:GetCell(state, nr, nc) == color then
                seen[k] = true
                stack[#stack + 1] = { nr, nc }
            end
        end
    end
    return group
end

function L:CeilingConnected(state)
    local key = function(r, c) return r * 100 + c end
    local seen, stack = {}, {}
    for c = 1, state.cols do
        if self:GetCell(state, 1, c) > 0 then
            local k = key(1, c)
            if not seen[k] then
                seen[k] = true
                stack[#stack + 1] = { 1, c }
            end
        end
    end
    while #stack > 0 do
        local cell = table.remove(stack)
        local neigh = self:Neighbors(cell[1], cell[2], state.cols, state.rows)
        for i = 1, #neigh do
            local nr, nc = neigh[i][1], neigh[i][2]
            local k = key(nr, nc)
            if not seen[k] and self:GetCell(state, nr, nc) > 0 then
                seen[k] = true
                stack[#stack + 1] = { nr, nc }
            end
        end
    end
    return seen
end

function L:IsWin(state)
    return self:CountOccupied(state) == 0
end

function L:IsLoss(state)
    if state.lost then return true end
    for c = 1, state.cols do
        if self:GetCell(state, state.dangerRow, c) > 0 then
            return true
        end
        if state.dangerRow < state.rows and self:GetCell(state, state.rows, c) > 0 then
            return true
        end
    end
    return false
end

function L:SnapCell(state, x, y, hitRow, hitCol)
    local candidates = {}
    if hitRow and hitCol and self:GetCell(state, hitRow, hitCol) > 0 then
        local neigh = self:Neighbors(hitRow, hitCol, state.cols, state.rows)
        for i = 1, #neigh do
            local nr, nc = neigh[i][1], neigh[i][2]
            if self:GetCell(state, nr, nc) == 0 then
                candidates[#candidates + 1] = { nr, nc }
            end
        end
        -- A projectile can graze the inside of a tightly packed formation after
        -- a wall bounce.  The immediate contact bubble may then have no empty
        -- neighbor even though the formation still has a legal outer edge.
        -- Search ring by ring from that contact instead of turning this into an
        -- artificial instant loss (or snapping to an unrelated cell).
        if #candidates == 0 then
            local seen = { [hitRow * 100 + hitCol] = true }
            local frontier = { { hitRow, hitCol } }
            while #frontier > 0 and #candidates == 0 do
                local nextFrontier = {}
                for i = 1, #frontier do
                    local around = self:Neighbors(frontier[i][1], frontier[i][2], state.cols, state.rows)
                    for j = 1, #around do
                        local nr, nc = around[j][1], around[j][2]
                        local key = nr * 100 + nc
                        if not seen[key] then
                            seen[key] = true
                            if self:GetCell(state, nr, nc) == 0 then
                                candidates[#candidates + 1] = { nr, nc }
                            else
                                nextFrontier[#nextFrontier + 1] = { nr, nc }
                            end
                        end
                    end
                end
                frontier = nextFrontier
            end
        end
    else
        for c = 1, state.cols do
            if self:GetCell(state, 1, c) == 0 then
                candidates[#candidates + 1] = { 1, c }
            end
        end
    end
    if #candidates == 0 then
        local r, c = self:PixelToHex(x, y, state.cols, state.rows)
        if self:GetCell(state, r, c) == 0 then
            return r, c
        end
        return nil, nil
    end
    local best, bestD, bestDot = candidates[1], 1e18, -1e18
    local hitX, hitY
    if hitRow and hitCol then
        hitX, hitY = self:HexToPixel(hitRow, hitCol)
    end
    for i = 1, #candidates do
        local px, py = self:HexToPixel(candidates[i][1], candidates[i][2])
        local d = Dist2(x, y, px, py)
        -- For a bubble contact, favor the open neighbor on the side from which
        -- the projectile arrived.  This prevents a near-corner impact from
        -- visibly jumping across the contacted bubble.
        local dot = 0
        if hitX then
            dot = (px - hitX) * (x - hitX) + (py - hitY) * (y - hitY)
        end
        if dot > bestDot or (dot == bestDot and d < bestD) then
            bestD, bestDot = d, dot
            best = candidates[i]
        end
    end
    return best[1], best[2]
end

local function ClearCells(self, state, cells)
    local removed = {}
    for i = 1, #cells do
        local r, c = cells[i][1], cells[i][2]
        local color = self:GetCell(state, r, c)
        if color > 0 then
            removed[#removed + 1] = { r, c, color }
            self:SetCell(state, r, c, 0)
        end
    end
    return removed
end

function L:PopAndDrop(state, row, col)
    local popped, dropped = {}, {}
    if row and col and self:GetCell(state, row, col) > 0 then
        local group = self:FindGroup(state, row, col)
        if #group >= self.POP_MIN then
            popped = ClearCells(self, state, group)
        end
    end
    do
        local connected = self:CeilingConnected(state)
        local falling = {}
        for r = 1, state.rows do
            for c = 1, state.cols do
                if self:GetCell(state, r, c) > 0 and not connected[r * 100 + c] then
                    falling[#falling + 1] = { r, c }
                end
            end
        end
        dropped = ClearCells(self, state, falling)
    end
    return popped, dropped
end

function L:ApplyBomb(state, row, col)
    local cells = { { row, col } }
    local neigh = self:Neighbors(row, col, state.cols, state.rows)
    for i = 1, #neigh do
        cells[#cells + 1] = neigh[i]
    end
    local destroyed = ClearCells(self, state, cells)
    local _, dropped = self:PopAndDrop(state, nil, nil)
    return destroyed, dropped
end

function L:ApplyLightning(state, x, y, color)
    local targets = {}
    for r = 1, state.rows do
        for c = 1, state.cols do
            if self:GetCell(state, r, c) == color then
                local px, py = self:HexToPixel(r, c)
                targets[#targets + 1] = { r, c, Dist2(x, y, px, py) }
            end
        end
    end
    table.sort(targets, function(a, b) return a[3] < b[3] end)
    local pick = {}
    for i = 1, math.min(6, #targets) do
        pick[#pick + 1] = { targets[i][1], targets[i][2] }
    end
    local destroyed = ClearCells(self, state, pick)
    local _, dropped = self:PopAndDrop(state, nil, nil)
    return destroyed, dropped
end

function L:ApplyDragonDestroy(state, row, col)
    local color = self:GetCell(state, row, col)
    if color <= 0 then return false end
    self:SetCell(state, row, col, 0)
    state.shot.dragonHits = (state.shot.dragonHits or 0) + 1
    state.shot.dragonRemoved = state.shot.dragonRemoved or {}
    state.shot.dragonRemoved[#state.shot.dragonRemoved + 1] = { row, col, color }
    return true
end

function L:MissLimit(state)
    local idx = math.floor((state.rowsSpawned or 0) / self.ROWS_PER_PHASE) + 1
    if idx > #self.MISS_PHASES then idx = #self.MISS_PHASES end
    return self.MISS_PHASES[idx]
end

function L:GenerateRow(state, fillChance)
    fillChance = fillChance or 0.72
    local colors = {}
    local maxC = state.colorCount or self.COLOR_COUNT
    for i = 1, maxC do colors[i] = i end
    local row = {}
    for c = 1, state.cols do
        if self:Rand(state) < fillChance then
            row[c] = colors[self:RandInt(state, #colors)]
        else
            row[c] = 0
        end
    end
    return row
end

function L:SpawnRowFromTop(state)
    for c = 1, state.cols do
        if self:GetCell(state, state.rows, c) > 0 then
            state.lost = true
            return false
        end
        if self:GetCell(state, state.dangerRow, c) > 0 then
            -- wird um eine Reihe nach unten geschoben → Verlust
            state.lost = true
            return false
        end
    end
    for r = state.rows, 2, -1 do
        for c = 1, state.cols do
            self:SetCell(state, r, c, self:GetCell(state, r - 1, c))
        end
    end
    local fresh = self:GenerateRow(state, 0.78)
    for c = 1, state.cols do
        self:SetCell(state, 1, c, fresh[c])
    end
    state.rowsSpawned = (state.rowsSpawned or 0) + 1
    if self:IsLoss(state) then
        state.lost = true
        return false
    end
    return true
end

function L:TimeBonus(popCount, dropCount)
    local t = 0
    if popCount >= 10 then
        t = 4
    elseif popCount >= 5 then
        t = 2
    elseif popCount >= 3 then
        t = 1
    end
    if dropCount >= 1 then
        t = t + math.max(1, math.floor((dropCount + 1) / 2))
    end
    return t
end

function L:DropFanfare(dropCount)
    if dropCount >= 20 then return "arcane" end
    if dropCount >= 10 then return "massive" end
    if dropCount >= 5 then return "chain" end
    if dropCount >= 1 then return "small" end
    return nil
end

function L:AimPreview(state, angle, difficulty)
    local spec = self.AIM[difficulty or "normal"] or self.AIM.normal
    local x, y = self.SHOOTER_X, self.SHOOTER_Y
    local vx, vy = math.cos(angle), math.sin(angle)
    if vy >= 0 then vy = -math.abs(vy) end
    local len = math.sqrt(vx * vx + vy * vy)
    if len < 1e-6 then vx, vy = 0, -1 else vx, vy = vx / len, vy / len end
    local remaining = spec.length
    local bounced = false
    local points = { { x, y } }
    local step = 8
    local minX, maxX, minY = self:CollisionBounds()
    while remaining > 0 do
        x = x + vx * step
        y = y + vy * step
        remaining = remaining - step
        if y <= minY then
            points[#points + 1] = { x, math.max(minY, y) }
            break
        end
        if x <= minX then
            x = minX
            if spec.bounce and not bounced then
                vx = math.abs(vx)
                bounced = true
                points[#points + 1] = { x, y }
            else
                points[#points + 1] = { x, y }
                break
            end
        elseif x >= maxX then
            x = maxX
            if spec.bounce and not bounced then
                vx = -math.abs(vx)
                bounced = true
                points[#points + 1] = { x, y }
            else
                points[#points + 1] = { x, y }
                break
            end
        else
            points[#points + 1] = { x, y }
        end
        if y >= self.FIELD_H then break end
    end
    return points, bounced
end

local function NormalizeUp(vx, vy, speed)
    local len = math.sqrt(vx * vx + vy * vy)
    if len < 1e-6 then
        return 0, -speed
    end
    vx, vy = vx / len, vy / len
    if vy > -0.12 then
        vy = -0.12
        len = math.sqrt(vx * vx + vy * vy)
        vx, vy = vx / len, vy / len
    end
    return vx * speed, vy * speed
end

function L:Fire(state, angle, power)
    if not state or state.shot and state.shot.active then return false end
    if state.won or state.lost then return false end
    power = power or state.pendingPower
    local color = state.queue[1]
    if power == "joker" then
        power = nil
    end
    if power == "bomb" or power == "lightning" or power == "dragonfire" then
        state.pendingPower = nil
        state.stats.powerUsed = (state.stats.powerUsed or 0) + 1
    else
        color = self:ConsumeQueue(state)
        power = nil
    end
    local vx, vy = NormalizeUp(math.cos(angle), math.sin(angle), self.SHOT_SPEED)
    state.shot = {
        active = true,
        x = self.SHOOTER_X,
        y = self.SHOOTER_Y,
        vx = vx,
        vy = vy,
        color = color,
        power = power,
        dragonHits = 0,
        dragonRemoved = {},
        life = 0,
    }
    state.shotsUsed = (state.shotsUsed or 0) + 1
    return true
end

function L:SetJokerColor(state, color)
    if not state or state.pendingPower ~= "joker" then return false end
    local onBoard = self:ColorsOnBoard(state)
    local ok = false
    for i = 1, #onBoard do
        if onBoard[i] == color then ok = true break end
    end
    if not ok then return false end
    state.queue[1] = color
    state.pendingPower = nil
    state.stats.powerUsed = (state.stats.powerUsed or 0) + 1
    return true
end

local function OverlapOccupied(self, state, x, y, skipSet)
    local r, c = self:PixelToHex(x, y, state.cols, state.rows)
    local thresh = self:ContactDist2()
    local hitR, hitC
    local best = thresh
    for dr = -2, 2 do
        for dc = -2, 2 do
            local nr, nc = r + dr, c + dc
            if self:InBounds(nr, nc, state.cols, state.rows) and self:GetCell(state, nr, nc) > 0 then
                local k = nr * 100 + nc
                if not (skipSet and skipSet[k]) then
                    local px, py = self:HexToPixel(nr, nc)
                    local d = Dist2(x, y, px, py)
                    if d < best then
                        best = d
                        hitR, hitC = nr, nc
                    end
                end
            end
        end
    end
    return hitR, hitC
end

function L:_FinishShot(shot, kind, bounced)
    shot.active = false
    shot.landed = true
    shot.landKind = kind
    return bounced and "bounce_landed" or "landed"
end

function L:TickShot(state, dt)
    local shot = state.shot
    if not shot or not shot.active then return "idle" end
    shot.life = (shot.life or 0) + dt
    local radius = self.RADIUS
    local minX, maxX, minY, maxY = self:CollisionBounds()
    if (shot.life or 0) >= self.SHOT_MAX_LIFE then
        return self:_FinishShot(shot, shot.power == "dragonfire" and "dragonfire" or "miss_off", false)
    end
    local speed = math.sqrt(shot.vx * shot.vx + shot.vy * shot.vy)
    local dist = speed * dt
    local step = math.max(4, radius * 0.35)
    local bounced = false
    local moved = 0
    while moved < dist do
        local s = math.min(step, dist - moved)
        local span = math.sqrt(shot.vx * shot.vx + shot.vy * shot.vy)
        if span < 1e-6 then break end
        shot.x = shot.x + shot.vx / span * s
        shot.y = shot.y + shot.vy / span * s
        moved = moved + s

        if shot.x <= minX then
            shot.x = minX
            shot.vx = math.abs(shot.vx)
            bounced = true
        elseif shot.x >= maxX then
            shot.x = maxX
            shot.vx = -math.abs(shot.vx)
            bounced = true
        end

        if shot.power == "dragonfire" then
            local hr, hc = OverlapOccupied(self, state, shot.x, shot.y)
            if hr then
                self:ApplyDragonDestroy(state, hr, hc)
                if (shot.dragonHits or 0) >= 4 then
                    return self:_FinishShot(shot, "dragonfire", bounced)
                end
            end
        else
            local hr, hc = OverlapOccupied(self, state, shot.x, shot.y)
            if hr then
                shot.hitRow, shot.hitCol = hr, hc
                return self:_FinishShot(shot, "bubble", bounced)
            end
        end

        if shot.vy < 0 and shot.y <= minY then
            shot.y = minY
            local kind = (shot.power == "dragonfire") and "dragonfire" or "ceiling"
            return self:_FinishShot(shot, kind, bounced)
        end
        if shot.vy > 0 and shot.y >= maxY then
            shot.y = maxY
            local kind = (shot.power == "dragonfire") and "dragonfire" or "miss_off"
            return self:_FinishShot(shot, kind, bounced)
        end
    end
    return bounced and "bounce" or "flying"
end

local function GrantPower(self, state)
    local fill = self.POWER_PER_SUCCESS
    if (state.overchargeLeft or 0) > 0 then
        fill = fill * self.OVERCHARGE_POWER
    end
    state.energy = (state.energy or 0) + fill
    if state.energy >= self.POWER_MAX and not state.pendingPower then
        state.energy = state.energy - self.POWER_MAX
        local bag = { "joker", "bomb", "lightning", "dragonfire" }
        Shuffle(bag)
        state.pendingPower = bag[1]
        return state.pendingPower
    end
    if state.energy > self.POWER_MAX then
        state.energy = self.POWER_MAX
    end
    return nil
end

function L:ResolveLanding(state)
    local shot = state.shot
    local result = {
        popped = {},
        dropped = {},
        destroyed = {},
        placed = nil,
        scoreDelta = 0,
        combo = state.combo or 1,
        miss = false,
        win = false,
        loss = false,
        timeBonus = 0,
        powerGranted = nil,
        power = nil,
        overchargeStarted = false,
        rowSpawned = false,
        fanfare = nil,
        snapRow = nil,
        snapCol = nil,
    }
    if not shot or not shot.landed then
        return result
    end

    local power = shot.power
    result.power = power
    local popped, dropped, destroyed = {}, {}, {}

    if shot.power == "dragonfire" or shot.landKind == "dragonfire" then
        destroyed = shot.dragonRemoved or {}
        local _, gravDrop = self:PopAndDrop(state, nil, nil)
        dropped = gravDrop
        if #destroyed == 0 and #dropped == 0 then
            result.miss = true
        end
    elseif shot.landKind == "miss_off" then
        result.miss = true
    elseif power == "bomb" then
        local sr, sc = self:SnapCell(state, shot.x, shot.y, shot.hitRow, shot.hitCol)
        if not sr then
            sr, sc = shot.hitRow, shot.hitCol
        end
        result.snapRow, result.snapCol = sr, sc
        if sr and sc then
            destroyed, dropped = self:ApplyBomb(state, sr, sc)
        end
    elseif power == "lightning" then
        destroyed, dropped = self:ApplyLightning(state, shot.x, shot.y, shot.color)
    else
        local sr, sc = self:SnapCell(state, shot.x, shot.y, shot.hitRow, shot.hitCol)
        result.snapRow, result.snapCol = sr, sc
        if not sr then
            state.lost = true
            result.loss = true
        else
            if sr >= state.dangerRow then
                self:SetCell(state, sr, sc, shot.color)
                state.lost = true
                result.placed = { sr, sc, shot.color }
                result.loss = true
            else
                self:SetCell(state, sr, sc, shot.color)
                result.placed = { sr, sc, shot.color }
                popped, dropped = self:PopAndDrop(state, sr, sc)
            end
        end
    end

    result.popped = popped
    result.dropped = dropped
    result.destroyed = destroyed

    local popN = #popped
    local dropN = #dropped
    local destN = #destroyed
    local success = popN > 0 or dropN > 0 or destN > 0

    if result.loss then
        success = false
    end

    if success then
        local combo = state.combo or 1
        local oc = ((state.overchargeLeft or 0) > 0) and self.OVERCHARGE_SCORE or 1
        local delta = (popN * self.POP_POINTS + dropN * self.DROP_POINTS) * combo * oc
        if destN > 0 and popN == 0 then
            delta = delta + destN * self.POP_POINTS * combo * oc
        end
        state.score = (state.score or 0) + delta
        result.scoreDelta = delta
        result.popScore = (popN * self.POP_POINTS + ((destN > 0 and popN == 0) and destN * self.POP_POINTS or 0)) * combo * oc
        result.dropScore = dropN * self.DROP_POINTS * combo * oc
        state.combo = combo + 1
        if state.combo > (state.stats.maxCombo or 0) then
            state.stats.maxCombo = state.combo
        end
        state.successStreak = (state.successStreak or 0) + 1
        if dropN > (state.stats.maxDrop or 0) then
            state.stats.maxDrop = dropN
        end
        result.powerGranted = GrantPower(self, state)
        if (state.overchargeLeft or 0) <= 0 and state.successStreak >= self.OVERCHARGE_STREAK then
            state.overchargeLeft = self.OVERCHARGE_SECS
            state.stats.overchargeCount = (state.stats.overchargeCount or 0) + 1
            result.overchargeStarted = true
        end
        if state.mode == "time" then
            result.timeBonus = self:TimeBonus(popN, dropN)
            state.timeLeft = (state.timeLeft or 0) + result.timeBonus
        end
        result.fanfare = self:DropFanfare(dropN)
        state.misses = 0
    else
        if not result.loss then
            result.miss = true
            state.combo = 1
            state.successStreak = 0
            if state.mode == "endless" then
                state.misses = (state.misses or 0) + 1
                if state.misses >= self:MissLimit(state) then
                    state.misses = 0
                    result.rowSpawned = self:SpawnRowFromTop(state)
                    if state.lost then result.loss = true end
                end
            end
        end
    end

    if state.mode == "shot" and state.shotLimit and not result.loss then
        local remain = state.shotLimit - (state.shotsUsed or 0)
        if remain <= 0 and not self:IsWin(state) then
            state.lost = true
            result.loss = true
        end
    end

    if self:IsWin(state) then
        state.won = true
        result.win = true
        result.loss = false
        state.lost = false
    elseif self:IsLoss(state) then
        state.lost = true
        result.loss = true
    end

    result.combo = state.combo
    shot.active = false
    shot.landed = false
    return result
end

function L:TickTimers(state, dt)
    if not state or state.won or state.lost then return end
    if (state.overchargeLeft or 0) > 0 then
        state.overchargeLeft = state.overchargeLeft - dt
        if state.overchargeLeft < 0 then state.overchargeLeft = 0 end
    end
    if state.mode == "time" then
        state.timeLeft = (state.timeLeft or 0) - dt
        if state.timeLeft <= 0 then
            state.timeLeft = 0
            state.lost = true
        end
    end
end

function L:GridHasBubbles(grid)
    for _, row in pairs(grid or {}) do
        for _, v in pairs(row) do
            if (tonumber(v) or 0) > 0 then return true end
        end
    end
    return false
end

function L:CloneGrid(grid)
    local g = {}
    for r, row in pairs(grid or {}) do
        g[r] = {}
        for c, v in pairs(row) do
            g[r][c] = v
        end
    end
    return g
end

function L:Serialize(state)
    return {
        mode           = state.mode,
        difficulty     = state.difficulty,
        levelIndex     = state.levelIndex,
        cols           = state.cols,
        rows           = state.rows,
        colorCount     = state.colorCount,
        shotLimit      = state.shotLimit,
        dangerRow      = state.dangerRow,
        grid           = self:CloneGrid(state.grid),
        queue          = { state.queue[1], state.queue[2] },
        score          = state.score,
        combo          = state.combo,
        energy         = state.energy,
        pendingPower   = state.pendingPower,
        shotsUsed      = state.shotsUsed,
        misses         = state.misses,
        rowsSpawned    = state.rowsSpawned,
        boardSeed      = state.boardSeed,
        rngS           = state.rngS,
        timeLeft       = state.timeLeft,
        successStreak  = state.successStreak,
        overchargeLeft = state.overchargeLeft,
        stats          = {
            maxCombo        = state.stats.maxCombo,
            maxDrop         = state.stats.maxDrop,
            powerUsed       = state.stats.powerUsed,
            overchargeCount = state.stats.overchargeCount,
        },
    }
end

function L:ApplySerialized(state, data)
    if not data then return state end
    state.grid           = self:CloneGrid(data.grid)
    state.queue          = { data.queue and data.queue[1] or 1, data.queue and data.queue[2] or 1 }
    state.score          = data.score or 0
    state.combo          = data.combo or 1
    state.energy         = data.energy or 0
    state.pendingPower   = data.pendingPower
    state.shotsUsed      = data.shotsUsed or 0
    state.misses         = data.misses or 0
    state.rowsSpawned    = data.rowsSpawned or 0
    state.boardSeed      = data.boardSeed or state.boardSeed
    state.rngS           = data.rngS or state.rngS
    state.timeLeft       = data.timeLeft
    state.successStreak  = data.successStreak or 0
    state.overchargeLeft = data.overchargeLeft or 0
    state.stats          = data.stats or state.stats
    return state
end

local function SeedBoard(self, state, fillRows)
    fillRows = fillRows or 5
    for r = 1, fillRows do
        local row = self:GenerateRow(state, 0.82)
        for c = 1, state.cols do
            -- vermeide initiale 3er am Start
            local v = row[c]
            if v > 0 then
                local left1 = c > 1 and row[c - 1] == v
                local left2 = c > 2 and row[c - 2] == v
                if left1 and left2 then
                    v = (v % (state.colorCount or 6)) + 1
                    row[c] = v
                end
            end
            self:SetCell(state, r, c, row[c])
        end
    end
end

function L:NewState(cfg)
    cfg = cfg or {}
    local cols = cfg.cols or self.COLS
    local rows = cfg.rows or self.ROWS
    local state = {
        mode           = cfg.mode or "endless",
        difficulty     = cfg.difficulty or "easy",
        levelIndex     = cfg.levelIndex or 1,
        cols           = cols,
        rows           = rows,
        colorCount     = cfg.colors or cfg.colorCount or self.COLOR_COUNT,
        shotLimit      = cfg.shotLimit,
        dangerRow      = cfg.dangerRow or self.DANGER_ROW,
        grid           = self:EmptyGrid(cols, rows),
        queue          = { 0, 0 },
        score          = cfg.score or 0,
        combo          = 1,
        energy         = 0,
        pendingPower   = nil,
        shotsUsed      = 0,
        misses         = 0,
        rowsSpawned    = 0,
        timeLeft       = (cfg.mode == "time") and self.TIME_START or nil,
        successStreak  = 0,
        overchargeLeft = 0,
        shot           = nil,
        won            = false,
        lost           = false,
        stats          = {
            maxCombo        = 1,
            maxDrop         = 0,
            powerUsed       = 0,
            overchargeCount = 0,
        },
    }
    local seed = cfg.boardSeed or cfg.seed
    if not seed and cfg.mode == "shot" then
        local def = cfg.levelDef
        if not def then
            local Levels = ArcadiaNexus.BS_Levels
            if Levels and Levels.Get then def = Levels:Get(cfg.levelIndex or 1) end
        end
        seed = (def and def.queueSeed) or self:CampaignQueueSeed(cfg.levelIndex)
    end
    if not seed and time then seed = time() end
    state.boardSeed = seed or 1
    self:SeedRng(state, state.boardSeed)
    if cfg.grid then
        state.grid = self:CloneGrid(cfg.grid)
    elseif cfg.map then
        state.grid = self:ParseMap(cfg.map, cols, rows)
    elseif cfg.mode == "shot" then
        local Levels = ArcadiaNexus.BS_Levels
        local def = cfg.levelDef
        if not def and Levels and Levels.Get then
            def = Levels:Get(state.levelIndex)
        end
        if def then
            state.cols = def.cols or cols
            state.rows = def.rows or rows
            state.colorCount = def.colors or state.colorCount
            state.shotLimit = def.shotLimit or state.shotLimit
            state.grid = self:ParseMap(def.map, state.cols, state.rows)
            if not state.grid[1] then
                state.grid = self:EmptyGrid(state.cols, state.rows)
            end
        end
    else
        SeedBoard(self, state, cfg.fillRows or 5)
    end
    self:FillQueue(state)
    if cfg.midGame and self:GridHasBubbles(cfg.midGame.grid) then
        self:ApplySerialized(state, cfg.midGame)
        self:FillQueue(state)
    end
    return state
end
