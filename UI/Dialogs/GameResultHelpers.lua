--[[
    ArcadiaNexus – UI/Dialogs/GameResultHelpers.lua
    Arcade-Result-Dialog Helper (baut auf GameResultDialog.lua auf).

    API:
      UI.ResolveArcadeTitle(L, result, opts?)  → title, titleColor
      UI.ShowArcadeResult(parent, opts)
      UI.HideArcadeResult(parent)

    opts (ShowArcadeResult):
      gameId, difficulty, result ("WIN"|"LOSS"|"DRAW")
      score, highscore, newHighscore, gold, goldLabel, subtitle
      lines ({string}) oder stats ({string}, Alias für lines)
      title, titleColor          – optional, überschreibt Standard-Map
      titleKeys, titleColors, titleFallbacks – optional pro result
      L, onRetry, onExit
      buttons                – optional, ersetzt Arcade-Preset (Labels/Callbacks pro Spiel)
]]

ArcadiaNexus    = ArcadiaNexus or {}
ArcadiaNexus.UI = ArcadiaNexus.UI or {}

local UI = ArcadiaNexus.UI

local DEFAULT_TITLE_COLORS = {
    WIN  = { 1, 0.84, 0 },
    LOSS = { 1, 0.3, 0.3 },
    DRAW = { 0.8, 0.8, 0.8 },
}

local DEFAULT_TITLE_KEYS = {
    WIN  = { "lbl_win", "result_win_title", "state_win", "popup_win", "win_title" },
    LOSS = { "lbl_loss", "result_loss_title", "state_gameover", "state_loss", "popup_loss" },
    DRAW = { "lbl_draw", "result_draw", "state_draw" },
}

local DEFAULT_TITLE_FALLBACKS = {
    WIN  = "Sieg!",
    LOSS = "Niederlage!",
    DRAW = "Unentschieden!",
}

local function ResolveLabel(L, key)
    if not L or not key then return nil end
    local val = L[key]
    if val == nil or val == "" or val == key or val == ("[" .. key .. "]") then
        return nil
    end
    return val
end

local function FirstLabel(L, keys, fallback)
    if keys then
        for _, key in ipairs(keys) do
            local val = ResolveLabel(L, key)
            if val then return val end
        end
    end
    return fallback
end

function UI.ResolveArcadeTitle(L, result, opts)
    opts = opts or {}
    local r = result or "LOSS"
    local keys = (opts.titleKeys and opts.titleKeys[r]) or DEFAULT_TITLE_KEYS[r]
    local fallback = (opts.titleFallbacks and opts.titleFallbacks[r])
        or DEFAULT_TITLE_FALLBACKS[r]
        or r
    local title = FirstLabel(L, keys, fallback)
    local color = (opts.titleColors and opts.titleColors[r])
        or DEFAULT_TITLE_COLORS[r]
        or DEFAULT_TITLE_COLORS.LOSS
    return title, color
end

function UI.ShowArcadeResult(parent, opts)
    if not parent or not opts then return end

    local title, titleColor
    if opts.title then
        title = opts.title
        titleColor = opts.titleColor
            or DEFAULT_TITLE_COLORS[opts.result or "LOSS"]
            or DEFAULT_TITLE_COLORS.LOSS
    else
        title, titleColor = UI.ResolveArcadeTitle(opts.L, opts.result, opts)
    end

    local function wrap(fn)
        return function()
            UI.HideResultDialog(parent)
            if fn then fn() end
        end
    end

    local lines = opts.lines or opts.stats

    local buttons
    if opts.buttons then
        buttons = {}
        for i, b in ipairs(opts.buttons) do
            buttons[i] = {
                label   = b.label,
                onClick = wrap(b.onClick),
                width   = b.width,
                height  = b.height,
                variant = b.variant,
            }
        end
    else
        buttons = UI.ResultDialogButtons.Arcade(
            opts.L, wrap(opts.onRetry), wrap(opts.onExit))
    end

    UI.ShowResultDialog({
        parent       = parent,
        title        = title,
        titleColor   = titleColor,
        subtitle     = opts.subtitle,
        score        = opts.score,
        scoreLabel   = opts.scoreLabel,
        highscore    = opts.highscore,
        newHighscore = opts.newHighscore,
        gold         = opts.gold,
        goldLabel    = opts.goldLabel,
        gameId       = opts.gameId,
        difficulty   = opts.difficulty,
        result       = opts.result,
        hideHighscore = opts.hideHighscore,
        lines        = lines,
        buttons      = buttons,
        mode         = opts.mode,
        fadeIn       = opts.fadeIn,
        frameLevel   = opts.frameLevel,
        onShow       = opts.onShow,
        onHide       = opts.onHide,
    })
end

function UI.HideArcadeResult(parent)
    UI.HideResultDialog(parent)
end
