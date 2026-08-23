--[[
    ShellGame – Settings Panel
    Layout: P1 via GameSettingsBuilder (Sound | Theme + Guide)
    Theme-Box: Cup/Ball-Picker (custom build)
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local ADDON_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\ShellGame\\Assets\\"

local BALL_ASSETS = {
    { key = "random",  label_key = "ball_random",  path = nil },
    { key = "blue",    label_key = "ball_blue",    path = ADDON_PATH .. "ball\\blue_ball" },
    { key = "green",   label_key = "ball_green",   path = ADDON_PATH .. "ball\\green_ball" },
    { key = "red",     label_key = "ball_red",     path = ADDON_PATH .. "ball\\red_ball" },
    { key = "violett", label_key = "ball_violett", path = ADDON_PATH .. "ball\\violett_ball" },
    { key = "yellow",  label_key = "ball_yellow",  path = ADDON_PATH .. "ball\\yellow_ball" },
}
local BALL_PATHS = {}
for _, e in ipairs(BALL_ASSETS) do
    if e.path then BALL_PATHS[e.key] = e.path end
end
local BALL_KEYS_LIST = { "blue", "green", "red", "violett", "yellow" }

local SLOT_COORDS = {
    { 0.0, 0.5, 0.0, 0.5 }, { 0.5, 1.0, 0.0, 0.5 },
    { 0.0, 0.5, 0.5, 1.0 }, { 0.5, 1.0, 0.5, 1.0 },
}

local function MakeThemeGroup(prefix, faction, atlasCount)
    local themes, n = {}, 1
    for atlas = 1, atlasCount do
        local file = ADDON_PATH .. faction .. "\\2x2_" .. prefix .. "_atlas_0" .. atlas
        for slot = 1, 4 do
            themes[#themes + 1] = {
                key    = faction:lower():sub(1, 3) .. "_" .. string.format("%02d", n),
                label  = faction .. " " .. n,
                file   = file,
                coords = SLOT_COORDS[slot],
            }
            n = n + 1
        end
    end
    return themes
end

local THEME_GROUPS = {
    { id = "alliance", themes = MakeThemeGroup("alliance", "Alliance", 3) },
    { id = "horde",    themes = MakeThemeGroup("horde",    "Horde",    3) },
    { id = "neutral",  themes = MakeThemeGroup("neutral",  "Neutral",  1) },
}
local ALL_THEMES, THEME_MAP = {}, {}
for _, grp in ipairs(THEME_GROUPS) do
    for _, t in ipairs(grp.themes) do
        ALL_THEMES[#ALL_THEMES + 1] = t
        THEME_MAP[t.key] = t
    end
end

local DD_W       = 180
local CB_OFS_X   = DD_W + 12
local ROW_H      = 36
local ROW_START  = 6
local CUP_SIZE   = 80   -- Settings-Vorschau (im Spiel weiterhin 128)
local BALL_SIZE  = 48
local CUP_OFS_X  = 0
local CUP_OFS_Y  = 6
local BALL_OFS_X = CUP_SIZE + 12
local BALL_OFS_Y = 20

local function ThemeContentHeight()
    local ballDdY = ROW_START + #THEME_GROUPS * ROW_H + 4
    local previewY = ballDdY + ROW_H + 8
    return previewY + CUP_SIZE + 30
end

local function CreatePreviewTex(parent, x, y, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    return tex
end

local function GetBallPathForKey(key)
    if key == "random" then
        key = BALL_KEYS_LIST[math.random(1, #BALL_KEYS_LIST)]
    end
    return BALL_PATHS[key] or BALL_PATHS.yellow
end

local function ApplyCupPreview(tex, themeKey, themeGroup)
    if not tex then return end
    if themeKey == "random" then
        local prefix = (themeGroup or "alliance"):sub(1, 3)
        local pool = {}
        for _, t in ipairs(ALL_THEMES) do
            if t.key:sub(1, 3) == prefix then pool[#pool + 1] = t end
        end
        local t = pool[math.random(1, math.max(1, #pool))] or ALL_THEMES[1]
        tex:SetTexture(t.file)
        local c = t.coords
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        return
    end
    local t = THEME_MAP[themeKey]
    if not t then tex:SetTexture(nil); return end
    tex:SetTexture(t.file)
    local c = t.coords
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end

local function BuildShellGameSettingsPanel(parent)
    local S = ArcadiaNexus.SHG_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SHELLGAME") or {}

    local cupPreviewTex, ballPreviewTex
    local groupDDs, groupCBs = {}, {}
    local ballDD = nil

    local function RefreshPreviews()
        if cupPreviewTex then
            ApplyCupPreview(cupPreviewTex, S:Get("theme"), S:Get("themeGroup"))
        end
        if ballPreviewTex then
            ballPreviewTex:SetTexture(GetBallPathForKey(S:Get("ball")))
        end
    end

    local function ActivateGroup(activeId)
        S:Set("themeGroup", activeId)
        for _, grp in ipairs(THEME_GROUPS) do
            local isActive = (grp.id == activeId)
            local cb = groupCBs[grp.id]
            local dd = groupDDs[grp.id]
            if cb then cb:SetChecked(isActive) end
            if dd then
                dd:SetEnabled(isActive)
                dd:SetAlpha(isActive and 1.0 or 0.4)
            end
        end
        local cur = S:Get("theme")
        if cur ~= "random" then
            local curInGroup = false
            for _, grp in ipairs(THEME_GROUPS) do
                if grp.id == activeId then
                    for _, t in ipairs(grp.themes) do
                        if t.key == cur then curInGroup = true; break end
                    end
                end
            end
            if not curInGroup then S:Set("theme", "random") end
        end
        RefreshPreviews()
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 22,
            items = {
                { key = "soundOnReveal",   label = L.sound_reveal   },
                { key = "soundOnShuffle",  label = L.sound_shuffle  },
                { key = "soundOnLift",     label = L.sound_lift     },
                { key = "soundOnWin",      label = L.sound_win      },
                { key = "soundOnLose",     label = L.sound_lose     },
                { key = "soundOnBankrupt", label = L.sound_bankrupt },
            },
        },
        theme = {
            title     = L.box_theme,
            minHeight = ThemeContentHeight() + 32,
            build = function(c, _w, _settings, yOff, measureOnly)
                if measureOnly then return ThemeContentHeight() end

                local ballDdY = ROW_START + #THEME_GROUPS * ROW_H + 4
                local previewY = ballDdY + ROW_H + 8

                for gIdx, grp in ipairs(THEME_GROUPS) do
                    local rowY = ROW_START + (gIdx - 1) * ROW_H + yOff
                    local grpId = grp.id
                    local opts = { { key = "random", label = L.theme_random or "Zufällig" } }
                    for _, t in ipairs(grp.themes) do
                        opts[#opts + 1] = { key = t.key, label = t.label }
                    end

                    local ddAnchor = CreateFrame("Frame", nil, c)
                    ddAnchor:SetSize(DD_W, 32)
                    ddAnchor:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -rowY)

                    local dd = UI.CreateSimpleDropdown(ddAnchor, 0, 0, DD_W, "", opts,
                        function() return S:Get("theme") end,
                        function(key)
                            S:Set("theme", key)
                            RefreshPreviews()
                            local Rend = ArcadiaNexus.SHG_Renderer
                            if Rend and Rend.RefreshCupTheme then Rend:RefreshCupTheme() end
                        end
                    )
                    groupDDs[grp.id] = dd

                    local cbLabelKey = "theme_group_" .. grp.id
                    local cb = UI.CreateCheckbox(c, L[cbLabelKey] or grp.id, CB_OFS_X, rowY + 16)
                    cb:SetChecked(S:Get("themeGroup") == grp.id)
                    groupCBs[grp.id] = cb
                    cb:SetScript("OnClick", function(self)
                        self:SetChecked(true)
                        ActivateGroup(grpId)
                        local Rend = ArcadiaNexus.SHG_Renderer
                        if Rend and Rend.RefreshCupTheme then Rend:RefreshCupTheme() end
                    end)
                end

                ActivateGroup(S:Get("themeGroup") or "alliance")

                local ballOpts = {}
                for _, entry in ipairs(BALL_ASSETS) do
                    ballOpts[#ballOpts + 1] = { key = entry.key, label = L[entry.label_key] or entry.key }
                end
                local ballAnchor = CreateFrame("Frame", nil, c)
                ballAnchor:SetSize(DD_W, 32)
                ballAnchor:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(ballDdY + yOff))

                local ballGet = function() return S:Get("ball") end
                ballDD = UI.CreateSimpleDropdown(ballAnchor, 0, 0, DD_W, "", ballOpts,
                    ballGet,
                    function(key)
                        S:Set("ball", key)
                        RefreshPreviews()
                        local Rend = ArcadiaNexus.SHG_Renderer
                        if Rend and Rend.RefreshBallTex then Rend:RefreshBallTex() end
                    end
                )

                cupPreviewTex = CreatePreviewTex(c, CUP_OFS_X, previewY + CUP_OFS_Y + yOff, CUP_SIZE)
                ballPreviewTex = CreatePreviewTex(c, BALL_OFS_X, previewY + BALL_OFS_Y + yOff, BALL_SIZE)
                RefreshPreviews()
                return ThemeContentHeight()
            end,
            refresh = function()
                local group = S:Get("themeGroup") or "alliance"
                for id, cb in pairs(groupCBs) do
                    cb:SetChecked(id == group)
                end
                for _, dd in pairs(groupDDs) do
                    if dd.RefreshDisplay then dd:RefreshDisplay() end
                end
                if ballDD and ballDD.RefreshDisplay then ballDD:RefreshDisplay() end
                ActivateGroup(group)
                RefreshPreviews()
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_4", "guide_5" }, 15),
                {
                    lines = {
                        { text = L.guide_info_1, color = { 0.65, 0.60, 0.40 } },
                        { text = L.guide_info_2, color = { 0.65, 0.60, 0.40 } },
                    },
                    lineSpacing = 15,
                },
            },
        },
        rebuild = BuildShellGameSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SHELLGAME"] = BuildShellGameSettingsPanel
