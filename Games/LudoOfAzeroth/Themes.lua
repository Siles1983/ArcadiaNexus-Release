--[[
    Ludo of Azeroth – Themes.lua
    Einheitliches visuelles Set (keine Theme-Auswahl mehr).
    Enthält Würfel-Icons und Spielerfarben.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Themes = {}
local T = ArcadiaNexus.LOA_Themes

local DICE = {
    "Interface\\Icons\\INV_Misc_Dice_01",
    "Interface\\Icons\\INV_Misc_Dice_02",
    "Interface\\Icons\\INV_Misc_Dice_03",
    "Interface\\Icons\\INV_Misc_Dice_04",
    "Interface\\Icons\\INV_Misc_Dice_05",
    "Interface\\Icons\\INV_Misc_Dice_06",
}

T.DICE_FALLBACK = "Interface\\Icons\\Ability_Rogue_RollTheBones"

local function TextureExists(path)
    if not path then return false end
    if C_Texture and C_Texture.GetFileIDFromPath then
        return C_Texture.GetFileIDFromPath(path) ~= 0
    end
    return true
end

function T:GetDiceIcon(face)
    face = math.max(1, math.min(6, tonumber(face) or 1))
    local path = self.DEFAULT.dice[face] or self.DEFAULT.dice[1]
    if TextureExists(path) then
        return path
    end
    return self.DICE_FALLBACK
end

T.DEFAULT = {
    dice = DICE,
    pieces = {
        [1] = "Interface\\Icons\\INV_BannerPVP_02",
        [2] = "Interface\\Icons\\INV_BannerPVP_01",
        [3] = "Interface\\Icons\\Spell_Nature_HealingTouch",
        [4] = "Interface\\Icons\\Spell_Holy_HolyBolt",
    },
    colors = {
        [1] = { 0.2, 0.5, 1.0 },
        [2] = { 1.0, 0.2, 0.2 },
        [3] = { 0.2, 0.9, 0.2 },
        [4] = { 1.0, 0.85, 0.1 },
    },
}

function T:GetTheme(_key)
    return self.DEFAULT
end
