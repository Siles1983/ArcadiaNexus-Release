-- Illustration/route data only; shared CampaignMap owns dimensions and controls.
local A = _G.ArcadiaNexus
local pages = {
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\ShadowsConquest\\assets\\map\\page_01_twilight_gate", nodes={{0.3316,0.84},{0.1082,0.7445},{0.2799,0.6442},{0.3969,0.5712},{0.5322,0.55},{0.6477,0.5135},{0.6963,0.4056},{0.8209,0.3737},{0.8163,0.2734},{0.89,0.17}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\ShadowsConquest\\assets\\map\\page_02_moonlit_aqueduct", nodes={{0.1432,0.7809},{0.207,0.6746},{0.3392,0.6442},{0.5124,0.6016},{0.6674,0.5697},{0.7905,0.5074},{0.6993,0.4239},{0.8741,0.3737},{0.792,0.3053},{0.88,0.18}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\ShadowsConquest\\assets\\map\\page_03_luminous_gardens", nodes={{0.0748,0.7232},{0.2131,0.6563},{0.3377,0.6108},{0.476,0.5606},{0.6081,0.5317},{0.6188,0.4269},{0.7479,0.4102},{0.8862,0.3965},{0.8194,0.2947},{0.94,0.1929}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\ShadowsConquest\\assets\\map\\page_04_eclipse_observatory", nodes={{0.2769,0.8356},{0.0991,0.7581},{0.2374,0.673},{0.4182,0.632},{0.5838,0.594},{0.5762,0.4892},{0.7525,0.4345},{0.8026,0.3403},{0.9105,0.2841},{0.8589,0.1686}}},
    {texture="Interface\\AddOns\\ArcadiaNexus\\Games\\ShadowsConquest\\assets\\map\\page_05_dawn_beacon", nodes={{0.06,0.7323},{0.1842,0.6867},{0.3088,0.6381},{0.3969,0.5621},{0.5155,0.5196},{0.6507,0.4953},{0.6811,0.4117},{0.8133,0.3844},{0.8604,0.2825},{0.9364,0.161}}},
}
A.SC_CampaignMap = { PAGES=pages, GetPage=function(page) return pages[page] end }

