-- Illustration/route data only; shared CampaignMap owns dimensions and controls.
local A = _G.ArcadiaNexus
local pages = {
{texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_01_emerald_valley", nodes={{0.12,0.82},{0.2359,0.749},{0.3529,0.6594},{0.5352,0.6624},{0.7662,0.6138},{0.5185,0.4634},{0.7069,0.4132},{0.8209,0.3433},{0.7905,0.2127},{0.9,0.17}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_02_sapphire_woods", nodes={{0.1295,0.84},{0.2754,0.7794},{0.4334,0.6852},{0.365,0.5971},{0.4881,0.5226},{0.599,0.4588},{0.7069,0.3935},{0.8376,0.3312},{0.7905,0.2324},{0.9242,0.1731}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_03_crystal_depths", nodes={{0.0961,0.84},{0.2556,0.787},{0.3119,0.6685},{0.4076,0.5986},{0.479,0.515},{0.6446,0.4846},{0.7464,0.4421},{0.8786,0.4071},{0.7768,0.2962},{0.8938,0.199}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_04_frost_pass", nodes={{0.1523,0.84},{0.2875,0.8159},{0.3407,0.7065},{0.5276,0.6594},{0.517,0.5545},{0.678,0.512},{0.8118,0.4603},{0.8376,0.3494},{0.906,0.2841},{0.8908,0.1686}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_05_ancient_terraces", nodes={{0.1584,0.84},{0.2815,0.7825},{0.3939,0.6776},{0.48,0.59},{0.61,0.54},{0.7251,0.4922},{0.833,0.4375},{0.8042,0.3266},{0.6887,0.2491},{0.89,0.18}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_06_ruby_forge", nodes={{0.1508,0.84},{0.2906,0.7961},{0.3453,0.6898},{0.4987,0.6442},{0.6811,0.6123},{0.7358,0.5257},{0.8589,0.4634},{0.751,0.3676},{0.8847,0.3038},{0.89,0.18}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_07_azure_isles", nodes={{0.1523,0.8235},{0.25,0.76},{0.3985,0.7156},{0.555,0.6746},{0.6112,0.5712},{0.7297,0.5241},{0.8057,0.4618},{0.6872,0.3768},{0.8665,0.3129},{0.86,0.18}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_08_amethyst_grove", nodes={{0.1386,0.84},{0.2465,0.7688},{0.3817,0.7277},{0.52,0.6943},{0.6598,0.6958},{0.7723,0.6533},{0.7996,0.5333},{0.8148,0.4102},{0.8345,0.3053},{0.89,0.18}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_09_golden_summit", nodes={{0.125,0.84},{0.2298,0.7688},{0.3757,0.7126},{0.5109,0.6913},{0.6978,0.6427},{0.5762,0.5393},{0.7191,0.4831},{0.8528,0.395},{0.7419,0.3084},{0.89,0.18}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\map\\page_10_jewel_citadel", nodes={{0.1265,0.84},{0.2663,0.7749},{0.36,0.67},{0.5428,0.7034},{0.5899,0.591},{0.7373,0.5302},{0.8467,0.4634},{0.7829,0.3646},{0.8817,0.3129},{0.8087,0.1792}}},
}
A.AJ_CampaignMap = { PAGES=pages, GetPage=function(page) return pages[page] end }

