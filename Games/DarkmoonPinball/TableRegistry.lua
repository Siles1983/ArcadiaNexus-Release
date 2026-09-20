-- Darkmoon Pinball – TableDefinition-Registry.
-- Kein UI. Neue Tische: Register oder Clone, ohne Logic/Engine-Duplikat.

ArcadiaNexus.DMP_TableRegistry = {}
local TR = ArcadiaNexus.DMP_TableRegistry
ArcadiaNexus.DMP_Tables = ArcadiaNexus.DMP_Tables or {}

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local n = {}
    for k, val in pairs(v) do
        n[k] = DeepCopy(val)
    end
    return n
end

local function Merge(dst, src)
    if type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            Merge(dst[k], v)
        else
            dst[k] = DeepCopy(v)
        end
    end
    return dst
end

function TR.Normalize(raw)
    local d = DeepCopy(raw or {})
    d.version = d.version or 1
    d.theme = d.theme or "darkmoon"
    d.labelKey = d.labelKey or ("dmp_table_" .. (d.id or "table"))
    d.width = d.width or 280
    d.height = d.height or 440
    d.playfieldBounds = d.playfieldBounds or { x = 0, y = 0, w = d.width, h = d.height }
    d.gravity = d.gravity or 820
    d.maxSpeed = d.maxSpeed or 980
    d.ballRadius = d.ballRadius or 7
    d.restitution = d.restitution or 0.72
    d.physicsProfile = d.physicsProfile or {
        gravity = d.gravity,
        maxSpeed = d.maxSpeed,
        restitution = d.restitution,
        ballRadius = d.ballRadius,
    }
    d.spawn = d.spawn or d.ballSpawn
    d.ballSpawn = d.ballSpawn or d.spawn
    d.drain = d.drain or (d.drainZones and d.drainZones[1])
    d.drainZones = d.drainZones or (d.drain and { d.drain } or {})
    d.walls = d.walls or {}
    d.rails = d.rails or {}
    d.bumpers = d.bumpers or {}
    d.slingshots = d.slingshots or {}
    d.posts = d.posts or {}
    d.kickers = d.kickers or {}
    d.targets = d.targets or {}
    d.rollovers = d.rollovers or d.inlanes or {}
    d.ramps = d.ramps or {}
    d.lanes = d.lanes or {}
    d.sensors = d.sensors or {}
    d.flippers = d.flippers or {}
    d.inlanes = d.inlanes or d.rollovers
    d.outlanes = d.outlanes or {}
    local function HasSensorType(typ)
        for i = 1, #d.sensors do
            if d.sensors[i].type == typ then return true end
        end
        return false
    end
    if d.lock and not HasSensorType("lock") then
        d.sensors[#d.sensors + 1] = {
            id = d.lock.id or "lock", type = "lock",
            x1 = d.lock.x1, y1 = d.lock.y1, x2 = d.lock.x2, y2 = d.lock.y2,
        }
    end
    if d.jackpot and not HasSensorType("jackpot") then
        d.sensors[#d.sensors + 1] = {
            id = d.jackpot.id or "jp", type = "jackpot",
            x1 = d.jackpot.x1, y1 = d.jackpot.y1, x2 = d.jackpot.x2, y2 = d.jackpot.y2,
        }
    end
    if not d.launchLane then
        d.launchLane = { x = d.shooterX or 246, skillshot = false }
    end
    d.shooterX = d.shooterX or d.launchLane.x or 246
    d.lightGroups = d.lightGroups or {}
    d.missionDefinitions = d.missionDefinitions or {}
    d.multiballDefinitions = d.multiballDefinitions or {
        balls = 3,
        save = d.mbSave or 1,
        spawns = d.mbSpawns,
        jackpotEvery = 3,
    }
    d.mbSave = d.mbSave or d.multiballDefinitions.save or 1
    d.lockDark = d.lockDark or 18
    d.mbSpawns = d.mbSpawns or d.multiballDefinitions.spawns
    d.kickbackDefinitions = d.kickbackDefinitions or d.kickbacks
    d.powerUpRules = d.powerUpRules or {
        frenzyTime = d.frenzyTime or 8,
        frenzyMul = d.frenzyMul or 2,
        magnetTime = d.magnetTime or 3,
    }
    d.scoringRules = d.scoringRules or {}
    d.scoringRules.ramp = d.scoringRules.ramp or 150
    d.scoringRules.target = d.scoringRules.target or 120
    d.scoringRules.lock = d.scoringRules.lock or 200
    d.scoringRules.extraBallBank = d.scoringRules.extraBallBank or 2500
    d.extraBallMax = d.extraBallMax or 1
    d.assets = d.assets or { id = d.theme, version = 1 }
    d.audioProfile = d.audioProfile or { id = "default" }
    d.fxProfile = d.fxProfile or { id = "default" }
    d.highscoreCategory = d.highscoreCategory or d.id
    d.debugOptions = d.debugOptions or { colliders = true }
    d.magnet = d.magnet or { x = d.width * 0.5, y = 180 }
    d.bumperBank = d.bumperBank or { missionId = "bumper_overdrive" }
    d.targetBank = d.targetBank or { missionId = "target_hunt" }
    d.rampModule = d.rampModule or { missionId = "ramp_run" }
    return d
end

function TR.Validate(def)
    if type(def) ~= "table" then return false, "not a table" end
    if type(def.id) ~= "string" or def.id == "" then return false, "id" end
    if not def.spawn and not def.ballSpawn then return false, "spawn" end
    if not def.drain and not (def.drainZones and def.drainZones[1]) then return false, "drain" end
    if type(def.flippers) ~= "table" or #def.flippers < 1 then return false, "flippers" end
    if type(def.walls) ~= "table" or #def.walls < 1 then return false, "walls" end
    return true
end

TR._order = {}
TR._byId = {}

function TR.Register(raw)
    local ok, err = TR.Validate(raw)
    if not ok then
        error("DMP TableDefinition invalid: " .. tostring(err))
    end
    local def = TR.Normalize(raw)
    if not TR._byId[def.id] then
        TR._order[#TR._order + 1] = def.id
    end
    TR._byId[def.id] = def
    ArcadiaNexus.DMP_Tables[def.id] = def
    return def
end

function TR.Get(tableId)
    if tableId and TR._byId[tableId] then return TR._byId[tableId] end
    local fallback = ArcadiaNexus.DMP_Logic and ArcadiaNexus.DMP_Logic.DEFAULT_TABLE or "darkmoon_midway"
    return TR._byId[tableId] or TR._byId[fallback] or TR._byId[TR._order[1]]
end

function TR.List()
    local list = {}
    for i = 1, #TR._order do
        list[i] = TR._byId[TR._order[i]]
    end
    return list
end

function TR.Clone(sourceId, overlay)
    local src = TR.Get(sourceId)
    if not src then error("DMP Clone: missing " .. tostring(sourceId)) end
    local copy = DeepCopy(src)
    if overlay then Merge(copy, overlay) end
    return TR.Register(copy)
end

function TR.Mission(def, id)
    if not def or not id then return nil end
    local list = def.missionDefinitions
    if not list then return nil end
    for i = 1, #list do
        if list[i].id == id then return list[i] end
    end
    return nil
end

function TR.ShooterX(def)
    if not def then return 246 end
    return def.shooterX or (def.launchLane and def.launchLane.x) or 246
end
