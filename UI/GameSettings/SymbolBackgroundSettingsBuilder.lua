--[[
    SymbolBackgroundSettingsBuilder
    Symbol-Sektion (rechts) für TicTacToe und ArcadiaRows.
    Hintergrund-Optionen wurden entfernt: es gibt keine Themen-Hintergründe,
    nur Symbole. Layout: Sound | Symbole + Anleitung via GS.Build.
]]

ArcadiaNexus.SymbolBackgroundSettings = ArcadiaNexus.SymbolBackgroundSettings or {}
local SB = ArcadiaNexus.SymbolBackgroundSettings
local UI = ArcadiaNexus.UI

local SYMBOL_CONTENT_H = 150

function SB.BuildSymbolSection(content, innerW, S, L, yOff, measureOnly)
    yOff = yOff or 0
    if measureOnly then return SYMBOL_CONTENT_H end
    if not content or not S or not L then return SYMBOL_CONTENT_H end

    local settings = S.GetAll and S:GetAll() or {}
    local ddW = math.max(80, (innerW or 200) - 24)

    local cbSymAuto = UI.CreateCheckbox(content, L.sym_auto, 0, yOff)
    cbSymAuto:SetChecked(settings.symbolAutoDetect)

    local ddSymPlayer = UI.CreateSimpleDropdown(content, 0, yOff + 90, ddW, L.sym_player_label,
        {
            { key = "ALLIANCE", label = L.sym_alliance },
            { key = "HORDE",    label = L.sym_horde    },
        },
        function() local v = S:Get("player1Symbol") return (v ~= "" and v) or "ALLIANCE" end,
        function(value) S:Set("player1Symbol", value) end
    )

    local ddSymMode = UI.CreateSimpleDropdown(content, 0, yOff + 32, ddW, L.sym_set_label,
        {
            { key = "STANDARD", label = L.sym_standard },
            { key = "FACTION",  label = L.sym_faction  },
        },
        function() return S:Get("symbolMode") end,
        function(value)
            S:Set("symbolMode", value)
            local isFaction = (value == "FACTION")
            ddSymPlayer:SetAlpha(isFaction and 1 or 0.4)
            if isFaction then ddSymPlayer:SetEnabled(true)
            else ddSymPlayer:SetEnabled(false) end
        end
    )

    local function ApplySymbolEnabled()
        local autoDetect = S:Get("symbolAutoDetect")
        if autoDetect then
            ddSymMode:SetAlpha(0.4);   ddSymMode:SetEnabled(false)
            ddSymPlayer:SetAlpha(0.4); ddSymPlayer:SetEnabled(false)
        else
            ddSymMode:SetAlpha(1); ddSymMode:SetEnabled(true)
            local isFaction = (S:Get("symbolMode") == "FACTION")
            ddSymPlayer:SetAlpha(isFaction and 1 or 0.4)
            if isFaction then ddSymPlayer:SetEnabled(true)
            else ddSymPlayer:SetEnabled(false) end
        end
    end

    ApplySymbolEnabled()

    cbSymAuto:SetScript("OnClick", function(self)
        S:Set("symbolAutoDetect", self:GetChecked())
        ApplySymbolEnabled()
    end)

    local hintA = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintA:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(yOff + 132))
    hintA:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(yOff + 132))
    hintA:SetText(L.sym_hint)
    hintA:SetJustifyH("LEFT")
    hintA:SetTextColor(0.80, 0.75, 0.60)

    local GS = ArcadiaNexus.GameSettings
    if GS and GS.RegisterRefresh then
        GS.RegisterRefresh(content, function()
            cbSymAuto:SetChecked(S:Get("symbolAutoDetect") and true or false)
            if ddSymMode.RefreshDisplay then ddSymMode:RefreshDisplay() end
            if ddSymPlayer.RefreshDisplay then ddSymPlayer:RefreshDisplay() end
            ApplySymbolEnabled()
        end)
    end

    return SYMBOL_CONTENT_H
end

function SB.Build(parent, config)
    local S = config.settings
    local L = config.locale
    if not parent or not S or not L then return end
    local GS = ArcadiaNexus.GameSettings
    if not GS or not GS.Build then return end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnWin",  label = L.sound_win  },
                { key = "soundOnLoss", label = L.sound_loss },
                { key = "soundOnDraw", label = L.sound_draw },
            },
        },
        theme = {
            title     = L.box_symbols,
            minHeight = 200,
            build = function(c, innerW, _settings, yOff, measureOnly)
                return SB.BuildSymbolSection(c, innerW, S, L, yOff, measureOnly)
            end,
        },
        guide = config.guide,
    })
end
