--[[
    ArcadiaNexus – Core/DevPlaytest.lua

    Stable facades for external DevTools (ArcadiaNexusEditors).
    Games/runtime stay in Arcadia; editors call only these entry points
    (plus public TD_* / catalog fields documented in docs/Core/DevTools_API.md).
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.DevTools = ArcadiaNexus.DevTools or { apiVersion = 1 }
ArcadiaNexus.DevTools.apiVersion = ArcadiaNexus.DevTools.apiVersion or 1

local DP = {}
ArcadiaNexus.DevPlaytest = DP

local ADDON_ROOT = "Interface\\AddOns\\ArcadiaNexus\\"

-- ============================================================
-- Top-Down (schema lives in Core/TopDown)
-- ============================================================

DP.TopDown = {}

function DP.TopDown.SchemaVersion()
    local Cat = ArcadiaNexus.TD_Catalog
    return Cat and Cat.SCHEMA_VERSION or 1
end

function DP.TopDown.Catalog()
    return ArcadiaNexus.TD_Catalog
end

function DP.TopDown.Serialize()
    return ArcadiaNexus.TD_Serialize
end

function DP.TopDown.Logic()
    return ArcadiaNexus.TD_Logic
end

function DP.TopDown.Tileset()
    return ArcadiaNexus.TD_Tileset
end

-- ============================================================
-- Platformer (AA / TR)
-- ============================================================

DP.Platformer = {
    GAME_AA = "AZEROTH_ASCENT",
    GAME_TR = "TINKERSREVENGE",
    --- Phase supported by shipped AA/TR runtimes (editor Catalog.CURRENT_PHASE must be <= this).
    supportedPhase = 15,
    TILE = 32,
}

function DP.Platformer.AssetRoot(kind)
    local roots = {
        shared_sprites = ADDON_ROOT .. "Shared\\Platformer\\sprites\\",
        shared_parallax = ADDON_ROOT .. "Shared\\Platformer\\parallax\\",
        aa_sprites = ADDON_ROOT .. "Games\\AzerothAscent\\assets\\sprites\\",
        aa_parallax = ADDON_ROOT .. "Games\\AzerothAscent\\assets\\parallax\\",
        tr_sprites = ADDON_ROOT .. "Games\\TinkersRevenge\\assets\\sprites\\",
        addon = ADDON_ROOT,
    }
    return roots[kind]
end

local function PlatformerLogic(gameId)
    if gameId == DP.Platformer.GAME_TR then
        return ArcadiaNexus.TR_Logic
    end
    return ArcadiaNexus.AA_Logic
end

local function PlatformerLevels(gameId)
    if gameId == DP.Platformer.GAME_TR then
        return ArcadiaNexus.TR_Levels
    end
    return ArcadiaNexus.AA_Levels
end

function DP.Platformer.NormalizeGame(gameId)
    if gameId == DP.Platformer.GAME_TR or gameId == "TR" or gameId == "TINKERS_REVENGE" then
        return DP.Platformer.GAME_TR
    end
    return DP.Platformer.GAME_AA
end

function DP.Platformer.GetLogic(gameId)
    return PlatformerLogic(DP.Platformer.NormalizeGame(gameId))
end

--- Build a playtest board. opts: difficulty, lives, score, spawnX, spawnY, level
function DP.Platformer.NewBoard(gameId, entry, opts)
    gameId = DP.Platformer.NormalizeGame(gameId)
    local Logic = PlatformerLogic(gameId)
    if not Logic or not Logic.NewBoard then return nil end
    opts = opts or {}
    return Logic:NewBoard({
        entry = entry,
        level = opts.level or 0,
        difficulty = opts.difficulty or "normal",
        lives = opts.lives or Logic.START_LIVES,
        score = opts.score or 0,
        spawnX = opts.spawnX,
        spawnY = opts.spawnY,
    })
end

function DP.Platformer.GetLevelEntry(gameId, index)
    gameId = DP.Platformer.NormalizeGame(gameId)
    local Levels = PlatformerLevels(gameId)
    if not Levels or not Levels.Get then return nil end
    return Levels.Get(index)
end

function DP.Platformer.ListLevelEntries(gameId)
    gameId = DP.Platformer.NormalizeGame(gameId)
    local Levels = PlatformerLevels(gameId)
    if not Levels then return {} end
    local maxLv = Levels.MAX_LEVEL
    if not maxLv and Levels.LIST then
        maxLv = #Levels.LIST
    end
    maxLv = maxLv or 0
    local out = {}
    for i = 1, maxLv do
        local e = Levels.Get and Levels.Get(i) or (Levels.LIST and Levels.LIST[i])
        if e then
            out[#out + 1] = {
                index = i,
                name = e.nameKey or e.name or ("Level " .. i),
                entry = e,
            }
        end
    end
    return out
end

-- ============================================================
-- Pinball (Darkmoon)
-- ============================================================

DP.Pinball = {
    GAME_ID = "DARKMOON_PINBALL",
}

local pinballLive = {
    active = false,
    tableId = nil,
    liveDef = nil,
    backup = nil,
    previousTableId = nil,
    onAction = nil,
}

local function DeepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, val in pairs(v) do
        out[DeepCopy(k, seen)] = DeepCopy(val, seen)
    end
    return out
end

local function ClearAndCopy(dst, src)
    if not dst or not src then return end
    for k in pairs(dst) do
        dst[k] = nil
    end
    for k, v in pairs(src) do
        dst[k] = DeepCopy(v)
    end
end

function DP.Pinball.GetTable(tableId)
    local Logic = ArcadiaNexus.DMP_Logic
    if Logic and Logic.GetTable then
        local def=Logic:GetTable(tableId)
        if def and (not tableId or def.id==tableId) then return def end
    end
    return nil
end

function DP.Pinball.ListTables()
    local Logic = ArcadiaNexus.DMP_Logic
    if Logic and Logic.ListTables then
        return Logic:ListTables()
    end
    return {}
end

function DP.Pinball.GetAssets()
    return ArcadiaNexus.DMP_Assets
end

--- Replace live table contents with draft (in-memory). Caller should EndLiveTest / Restore.
function DP.Pinball.ApplyDraft(tableId, draft)
    local live = DP.Pinball.GetTable(tableId)
    if not live or type(draft) ~= "table" then return false end
    ClearAndCopy(live, draft)
    local engine=ArcadiaNexus.DMP_Engine
    if engine and engine.gameState and engine.gameState.def==live then engine.gameState.devRun=true end
    return true
end

function DP.Pinball.IsLiveTestActive()
    return pinballLive.active == true
end

--- opts: { tableId, draft, onAction }
--- Applies draft to live table, starts DMP engine session for playtest.
function DP.Pinball.StartLiveTest(opts)
    opts = opts or {}
    if pinballLive.active then return false, "already_active" end
    local tableId = opts.tableId
    local draft = opts.draft
    if not tableId or type(draft) ~= "table" then return false, "bad_args" end

    local lifecycle = ArcadiaNexus.Lifecycle
    local active = lifecycle and lifecycle.GetActiveGame and lifecycle:GetActiveGame()
    if active and active ~= DP.Pinball.GAME_ID then
        return false, "other_game_active"
    end

    local engine = ArcadiaNexus.DMP_Engine
    local GR = ArcadiaNexus.GameRegistry
    if not engine or not GR then return false, "missing_runtime" end

    local liveDef = DP.Pinball.GetTable(tableId)
    if not liveDef then return false, "unknown_table" end
    local TR=ArcadiaNexus.DMP_TableRegistry
    if draft.id~=tableId or not TR or not TR.Validate(draft) then return false,"bad_draft" end

    if engine.state~="IDLE" then engine:StopGame() end
    local settings = ArcadiaNexus.DMP_Settings
    pinballLive.previousTableId = settings and settings.Get and settings:Get("tableId") or tableId
    pinballLive.backup = DeepCopy(liveDef)
    pinballLive.liveDef = liveDef
    pinballLive.tableId = tableId
    pinballLive.onAction = opts.onAction

    ClearAndCopy(liveDef, draft)
    if settings and settings.Set then
        settings:Set("tableId", tableId)
    end

    engine._devActionSink = function(act)
        if type(pinballLive.onAction) == "function" then
            pcall(pinballLive.onAction, act)
        end
    end

    pinballLive.active = true
    if GR.ShowContainer then
        GR.ShowContainer(DP.Pinball.GAME_ID)
    end
    if not engine:StartGame() then
        DP.Pinball.EndLiveTest()
        return false,"start_failed"
    end
    return true
end

function DP.Pinball.EndLiveTest()
    if not pinballLive.active then return false end

    local engine = ArcadiaNexus.DMP_Engine
    if engine then
        engine._devActionSink = nil
        if engine.state ~= "IDLE" and engine.StopGame then
            engine:StopGame()
        end
    end

    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.GetContainer then
        local container = GR.GetContainer(DP.Pinball.GAME_ID)
        if container then container:Hide() end
    end

    if pinballLive.liveDef and pinballLive.backup then
        ClearAndCopy(pinballLive.liveDef, pinballLive.backup)
    end

    local settings = ArcadiaNexus.DMP_Settings
    if settings and settings.Set then
        settings:Set("tableId", pinballLive.previousTableId or pinballLive.tableId)
    end

    pinballLive.active = false
    pinballLive.tableId = nil
    pinballLive.liveDef = nil
    pinballLive.backup = nil
    pinballLive.previousTableId = nil
    pinballLive.onAction = nil
    return true
end
