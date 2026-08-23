--[[
    ArcadiaNexus – Core/LevelPool.lua

    Zyklisches Auswählen von Puzzle-Einträgen aus Level-Pools.

    API:
      local entry, realIndex = ArcadiaNexus.LevelPool.GetEntry(levels, difficulty, index)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LevelPool = {}
local LP = ArcadiaNexus.LevelPool

--- @param pool table  Level-Map { easy = { ... }, medium = { ... }, ... }
--- @param difficulty string  Schwierigkeits-Key
--- @param index number  1-basierter Puzzle-Index (wird zyklisch gemappt)
--- @return table|nil entry
--- @return number realIndex  Index im Pool (1-basiert), 1 wenn leer
function LP.GetEntry(pool, difficulty, index)
    if not pool then return nil, 1 end
    local subPool = pool[difficulty]
    if not subPool or #subPool == 0 then return nil, 1 end
    local idx = index or 1
    local i = ((idx - 1) % #subPool) + 1
    return subPool[i], i
end
