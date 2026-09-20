--[[
    ArcadiaNexus – Arcane Barrage
    Games/BubbleShooter/CampaignMap.lua

    Presentation data for the ten campaign-map pages. Coordinates are
    normalized within the map canvas, so final painted page assets can replace
    the placeholder backdrop without moving gameplay or progress code.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_CampaignMap = {}
local Map = ArcadiaNexus.BS_CampaignMap

local ASSETS = "Interface\\AddOns\\ArcadiaNexus\\Games\\BubbleShooter\\assets\\map\\"

Map.PAGE_SIZE = 10

local function Page(nameKey, nodes, asset)
    return { nameKey = nameKey, nodes = nodes, asset = asset }
end

-- The route deliberately leaves broad scenic areas for the final illustrations.
Map.PAGES = {
    Page("map_region_01", { { .15, .84 }, { .31, .73 }, { .20, .58 }, { .42, .49 }, { .61, .58 }, { .76, .45 }, { .62, .31 }, { .39, .28 }, { .53, .14 }, { .79, .12 } }, ASSETS .. "page_01_leyline_origin"),
    Page("map_region_02", { { .16, .80 }, { .36, .82 }, { .52, .69 }, { .38, .55 }, { .17, .47 }, { .31, .31 }, { .55, .39 }, { .74, .27 }, { .64, .13 }, { .83, .12 } }, ASSETS .. "page_02_crystal_caverns"),
    Page("map_region_03", { { .13, .83 }, { .26, .68 }, { .49, .76 }, { .70, .70 }, { .81, .52 }, { .61, .45 }, { .42, .50 }, { .25, .36 }, { .48, .21 }, { .76, .15 } }, ASSETS .. "page_03_shattered_observatory"),
    Page("map_region_04", { { .18, .82 }, { .43, .76 }, { .63, .83 }, { .79, .66 }, { .60, .58 }, { .36, .54 }, { .19, .41 }, { .39, .30 }, { .62, .25 }, { .82, .12 } }, ASSETS .. "page_04_emerald_rift"),
    Page("map_region_05", { { .14, .80 }, { .31, .69 }, { .53, .72 }, { .73, .57 }, { .57, .43 }, { .31, .46 }, { .16, .29 }, { .37, .18 }, { .61, .25 }, { .81, .12 } }, ASSETS .. "page_05_ember_chasm"),
    Page("map_region_06", { { .17, .84 }, { .38, .77 }, { .24, .63 }, { .46, .53 }, { .71, .61 }, { .81, .43 }, { .61, .35 }, { .39, .30 }, { .56, .15 }, { .80, .13 } }, ASSETS .. "page_06_void_archipelago"),
    Page("map_region_07", { { .12, .78 }, { .29, .82 }, { .47, .66 }, { .68, .77 }, { .82, .59 }, { .63, .49 }, { .41, .42 }, { .23, .30 }, { .46, .16 }, { .74, .14 } }, ASSETS .. "page_07_star_citadel"),
    Page("map_region_08", { { .17, .83 }, { .35, .70 }, { .56, .79 }, { .76, .66 }, { .62, .52 }, { .38, .55 }, { .18, .43 }, { .37, .31 }, { .59, .27 }, { .80, .12 } }, ASSETS .. "page_08_frost_peaks"),
    Page("map_region_09", { { .14, .81 }, { .33, .80 }, { .51, .65 }, { .72, .73 }, { .83, .52 }, { .64, .39 }, { .43, .47 }, { .23, .33 }, { .48, .18 }, { .77, .14 } }, ASSETS .. "page_09_dreamwood"),
    Page("map_region_10", { { .16, .84 }, { .36, .74 }, { .57, .82 }, { .78, .67 }, { .61, .55 }, { .39, .50 }, { .19, .38 }, { .38, .27 }, { .59, .21 }, { .80, .10 } }, ASSETS .. "page_10_arcane_crown"),
}

function Map:GetPage(level)
    level = math.max(1, math.floor(tonumber(level) or 1))
    local pageIndex = math.floor((level - 1) / self.PAGE_SIZE) + 1
    return self.PAGES[pageIndex], pageIndex
end
