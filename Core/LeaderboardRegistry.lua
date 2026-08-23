--[[
    ArcadiaNexus – Core/LeaderboardRegistry.lua

    Deklarative Leaderboard-Schemas pro Spiel (analog RegisterAchievements).
    Spiele registrieren beim Laden, was die Bestenliste anzeigen soll —
    nicht die UI mit festen Win/Loss/Highscore-Spalten.

    Öffentliche API:
        ArcadiaNexus.RegisterLeaderboard(schema)   – Facade (Bootstrap.lua)
        LeaderboardRegistry.Register(schema)
        LeaderboardRegistry.GetSchema(gameId)
        LeaderboardRegistry.GetDifficulties(gameId)
        LeaderboardRegistry.ResolveRowValue(entry, rowDef)
        LeaderboardRegistry.FormatValue(value, rowDef)
        LeaderboardRegistry.MergeEntries(entries)  – Max/Summe über Difficulties
        LeaderboardRegistry.SECTION.*              – Schema-Presets
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LeaderboardRegistry = {}
local LR = ArcadiaNexus.LeaderboardRegistry

local schemas = {}

-- Bekannte Difficulty-Label-Keys (UI/Core/Language.lua)
local DIFF_LABEL_KEYS = {
    default = "lb_diff_default",
    easy    = "lb_diff_easy",
    normal  = "lb_diff_normal",
    medium  = "lb_diff_medium",
    hard    = "lb_diff_hard",
    ["1card"] = "lb_diff_1card",
    ["3card"] = "lb_diff_3card",
}

local VALUE_COLORS = {
    win     = { 0.30, 1.00, 0.30 },
    loss    = { 1.00, 0.35, 0.35 },
    gold    = { 1.00, 0.82, 0.00 },
    muted   = { 0.45, 0.43, 0.36 },
    default = { 0.85, 0.78, 0.60 },
}

-- ============================================================
-- Schema-Presets (wiederverwendbare Sektionen)
-- ============================================================

LR.SECTION = {}

function LR.SECTION.TopScores(count)
    return {
        type     = "top_scores",
        titleKey = "lb_highscores",
        count    = count or 3,
    }
end

function LR.SECTION.StatsWLD(titleKey)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_played",
        rows = {
            { field = "wins",   labelKey = "lb_wins",   valueColor = "win" },
            { field = "losses", labelKey = "lb_losses", valueColor = "loss" },
            { field = "draws",  labelKey = "lb_draws" },
            { field = "played", compute = "wins+losses+draws", labelKey = "lb_played" },
        },
    }
end

function LR.SECTION.StatsPlayed(titleKey)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_played",
        rows = {
            { field = "gamesPlayed", labelKey = "lb_played" },
        },
    }
end

function LR.SECTION.StatsWL(titleKey)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_played",
        rows = {
            { field = "wins",   labelKey = "lb_wins",   valueColor = "win" },
            { field = "losses", labelKey = "lb_losses", valueColor = "loss" },
            { field = "played", compute = "wins+losses", labelKey = "lb_played" },
        },
    }
end

function LR.SECTION.StatsWinsPlayed(titleKey)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_played",
        rows = {
            { field = "wins",        labelKey = "lb_wins", valueColor = "win" },
            { field = "gamesPlayed", labelKey = "lb_played" },
        },
    }
end

function LR.SECTION.StatsLossesPlayed(titleKey)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_played",
        rows = {
            { field = "losses",      labelKey = "lb_losses", valueColor = "loss" },
            { field = "gamesPlayed", labelKey = "lb_played" },
        },
    }
end

function LR.SECTION.BestLevel()
    return {
        field         = "bestLevel",
        fallbackStats = { "waveReached", "level" },
        labelKey      = "lb_best_level",
        valueColor    = "gold",
    }
end

function LR.SECTION.BestLevelBox(titleKey)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_best_level",
        rows     = { LR.SECTION.BestLevel() },
    }
end

function LR.SECTION.MaxCapitalRow()
    return {
        fromStats  = "finalChips",
        labelKey   = "lb_max_capital",
        valueColor = "gold",
        format     = "gold",
    }
end

function LR.SECTION.GlobalStats(titleKey, rows)
    return {
        type     = "stats",
        scope    = "global",
        titleKey = titleKey or "lb_capital",
        rows     = rows or { LR.SECTION.MaxCapitalRow() },
    }
end

function LR.SECTION.StatBox(titleKey, rows)
    return {
        type     = "stats",
        titleKey = titleKey or "lb_played",
        rows     = rows or {},
    }
end

-- ============================================================
-- Normalisierung
-- ============================================================

local function NormalizeDifficulty(item)
    if type(item) == "string" then
        return {
            id       = item,
            labelKey = DIFF_LABEL_KEYS[item] or item,
        }
    end
    if type(item) == "table" and item.id then
        return {
            id       = item.id,
            labelKey = item.labelKey or DIFF_LABEL_KEYS[item.id] or item.id,
        }
    end
    return nil
end

local function NormalizeSchema(raw)
    if not raw or not raw.gameId then return nil end

    local diffs = {}
    for _, item in ipairs(raw.difficulties or { "default" }) do
        local d = NormalizeDifficulty(item)
        if d then diffs[#diffs + 1] = d end
    end
    if #diffs == 0 then
        diffs[1] = { id = "default", labelKey = "lb_diff_default" }
    end

    local sections = {}
    for _, sec in ipairs(raw.sections or {}) do
        sections[#sections + 1] = sec
    end

    return {
        gameId       = raw.gameId,
        difficulties = diffs,
        sections     = sections,
    }
end

-- ============================================================
-- Registrierung
-- ============================================================

function LR.Register(raw)
    local schema = NormalizeSchema(raw)
    if not schema then return false end
    schemas[schema.gameId] = schema
    return true
end

function LR.RegisterPending(list)
    if not list then return end
    for _, raw in ipairs(list) do
        LR.Register(raw)
    end
end

function LR.GetSchema(gameId)
    return schemas[gameId]
end

function LR.GetDifficulties(gameId)
    local schema = schemas[gameId]
    if not schema then return { { id = "default", labelKey = "lb_diff_default" } } end
    return schema.difficulties
end

function LR.GetValueColor(name)
    return VALUE_COLORS[name] or VALUE_COLORS.default
end

-- ============================================================
-- Werte aus DB-Eintrag auflösen
-- ============================================================

function LR.ResolveRowValue(entry, rowDef)
    if not entry or not rowDef then return nil end

    if rowDef.compute == "wins+losses+draws" then
        return (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
    end
    if rowDef.compute == "wins+losses" then
        return (entry.wins or 0) + (entry.losses or 0)
    end

    if rowDef.field then
        local v = entry[rowDef.field]
        if v ~= nil then return v end
    end

    if rowDef.fromStats then
        local cs = entry.customStats
        if cs then
            local v = cs[rowDef.fromStats]
            if v ~= nil then return v end
        end
    end

    local fallback = rowDef.fallbackStats
    if type(fallback) == "table" then
        local cs = entry.customStats
        if cs then
            for i = 1, #fallback do
                local v = cs[fallback[i]]
                if v ~= nil then return v end
            end
        end
    end

    return nil
end

function LR.FormatValue(value, rowDef)
    if value == nil then return nil end

    local fmt = rowDef and rowDef.format
    if fmt == "score" then
        local F = ArcadiaNexus.Format
        if F and F.Score then return F.Score(value) end
    end
    if fmt == "time" then
        local F = ArcadiaNexus.Format
        if F and F.SecondsMMSS then return F.SecondsMMSS(value) end
    end
    if fmt == "gold" then
        local F = ArcadiaNexus.Format
        local n = (F and F.Score) and F.Score(value) or tostring(value)
        return n .. "g"
    end
    if fmt == "multiplier" then
        if type(value) == "number" then
            local s = (math.floor(value) == value)
                and tostring(value)
                or string.format("%.1f", value)
            return "x" .. s
        end
        return "x" .. tostring(value)
    end

    return tostring(value)
end

function LR.HasAnyData(entry, rowDef)
    local v = LR.ResolveRowValue(entry, rowDef)
    if v == nil then return false end
    if type(v) == "number" and v == 0 and rowDef.hideIfZero then return false end
    return true
end

-- Einträge mehrerer Difficulties zusammenführen (Kapital global, Max-Stats).
function LR.MergeEntries(entries)
    local merged = {
        highscores   = {},
        wins         = 0,
        losses       = 0,
        draws        = 0,
        gamesPlayed  = 0,
        bestLevel    = nil,
        customStats  = {},
    }
    for i = 1, #(entries or {}) do
        local e = entries[i]
        if type(e) == "table" then
            merged.wins        = merged.wins        + (e.wins or 0)
            merged.losses      = merged.losses      + (e.losses or 0)
            merged.draws       = merged.draws       + (e.draws or 0)
            merged.gamesPlayed = merged.gamesPlayed + (e.gamesPlayed or 0)
            if (e.bestLevel or 0) > (merged.bestLevel or 0) then
                merged.bestLevel = e.bestLevel
            end
            local cs = e.customStats
            if type(cs) == "table" then
                for key, val in pairs(cs) do
                    if type(val) == "number" then
                        local prev = merged.customStats[key]
                        if not prev or val > prev then
                            merged.customStats[key] = val
                        end
                    end
                end
            end
        end
    end
    return merged
end
