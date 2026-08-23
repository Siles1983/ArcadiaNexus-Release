--[[
    BlockDrop – Settings Panel
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
    Sound: individuelle Checkboxen ohne Master (P11)
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local TYPES = { "I", "O", "T", "L", "J", "S", "Z" }

local function BuildBlockdropSettingsPanel(parent)
    local S = ArcadiaNexus.BLD_Settings
    local T = ArcadiaNexus.BLD_Themes
    if not S or not T then return end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")

    local previewBg, previewIcon, previewLabel = {}, {}, {}

    local function BuildPreview(themeID)
        local theme = T:Get(themeID or S:Get("theme"))
        for _, pt in ipairs(TYPES) do
            local entry = theme[pt] or { r = 0.5, g = 0.5, b = 0.5 }
            local pbg, pico, plbl = previewBg[pt], previewIcon[pt], previewLabel[pt]
            if entry.atlas then
                if pbg  then pbg:SetBackdropColor(0, 0, 0, 0) end
                if plbl then plbl:Hide() end
                if pico then
                    pico:SetTexture(entry.atlas)
                    pico:SetTexCoord(0, 1, 0, 1)
                    pico:SetVertexColor(1, 1, 1, 1)
                    pico:Show()
                end
            elseif entry.icon then
                if pbg  then pbg:SetBackdropColor(0, 0, 0, 0) end
                if plbl then plbl:Hide() end
                if pico then
                    pico:SetTexture(entry.icon)
                    pico:SetTexCoord(0, 1, 0, 1)
                    pico:SetVertexColor(1, 1, 1, 1)
                    pico:Show()
                end
            else
                if pbg  then pbg:SetBackdropColor(entry.r * 0.80, entry.g * 0.80, entry.b * 0.80, 1) end
                if pico then pico:Hide() end
                if plbl then plbl:Show() end
            end
        end
    end

    local themeOpts = {}
    for _, e in ipairs(T.LIST) do
        themeOpts[#themeOpts + 1] = { key = e.id, label = e.label }
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            individual = true,
            rowSpacing = 28,
            items = {
                { key = "snd_move",      label = L.snd_move      },
                { key = "snd_rotate",    label = L.snd_rotate    },
                { key = "snd_line",      label = L.snd_line      },
                { key = "snd_blockdrop", label = L.snd_blockdrop },
                { key = "snd_levelup",   label = L.snd_levelup   },
            },
        },
        theme = {
            minHeight = 200,
            dropdown = {
                label   = L.box_theme,
                key     = "theme",
                options = themeOpts,
                onChange = function(value)
                    BuildPreview(value)
                    local R = ArcadiaNexus.BLD_Renderer
                    if R and R.RefreshTheme then R:RefreshTheme() end
                end,
            },
            build = function(c, w, _settings, yOff, measureOnly)
                if measureOnly then return 148 end

                local bgLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                bgLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -(yOff + 4))
                bgLbl:SetText("|cffffff00" .. L.label_background .. ":|r")

                UI.CreateSimpleDropdown(c, 0, yOff + 18, w - 50, "",
                    {
                        { key = "CLASSIC",  label = L.bg_classic  },
                        { key = "ALLIANCE", label = L.bg_alliance },
                        { key = "HORDE",    label = L.bg_horde    },
                    },
                    function() return S:Get("background") or "CLASSIC" end,
                    function(value)
                        S:Set("background", value)
                        local R = ArcadiaNexus.BLD_Renderer
                        if R and R.RefreshBackground then R:RefreshBackground() end
                    end
                )

                for i, ptype in ipairs(TYPES) do
                    local f = CreateFrame("Frame", nil, c, "BackdropTemplate")
                    f:SetSize(28, 28)
                    f:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * 34, -(yOff + 64))
                    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", tile = false })
                    f:SetBackdropColor(0.5, 0.5, 0.5, 1)
                    previewBg[ptype] = f

                    local ico = f:CreateTexture(nil, "ARTWORK")
                    ico:SetAllPoints(f)
                    ico:Hide()
                    previewIcon[ptype] = ico

                    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    lbl:SetPoint("CENTER")
                    lbl:SetText(ptype)
                    lbl:SetTextColor(0, 0, 0, 1)
                    previewLabel[ptype] = lbl
                end

                local hint = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                hint:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 100))
                hint:SetText(L.hint_blocks)

                BuildPreview(S:Get("theme"))
                return 148
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_controls", "guide_keys", "guide_drop", "guide_empty",
                    "guide_scoring", "guide_score1", "guide_score2", "guide_mult",
                    "guide_empty2", "guide_levelup", "guide_highscore", "guide_sizes",
                }),
            },
        },
        rebuild   = BuildBlockdropSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["BLOCKDROP"] = BuildBlockdropSettingsPanel
