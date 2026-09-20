--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Levels.lua

    Puzzle-Kampagne (SHOT-Modus).

    Every level is generated deterministically by Generator.lua.  This keeps
    the opening campaign on the same solvability and shot-budget contract as
    the later pages instead of retaining a separate set of hand-authored,
    potentially tighter boards.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Levels = {}
local Levels = ArcadiaNexus.BS_Levels

Levels.LIST = {}
Levels.HAND_COUNT = 0
Levels.COUNT = (ArcadiaNexus.BS_Generator and ArcadiaNexus.BS_Generator.CAMPAIGN_COUNT) or 100

local _genCache = {}

function Levels:Get(index)
    index = tonumber(index) or 1
    if index < 1 then index = 1 end
    if index > self.COUNT then index = self.COUNT end
    if _genCache[index] then return _genCache[index] end
    local Gen = ArcadiaNexus.BS_Generator
    if Gen and Gen.MakeCampaignLevel then
        _genCache[index] = Gen:MakeCampaignLevel(index)
        return _genCache[index]
    end
    return nil
end
