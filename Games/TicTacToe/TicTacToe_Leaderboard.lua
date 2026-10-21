--[[
    ArcadiaNexus - TicTacToe Leaderboard-Schema
    Games/TicTacToe/TicTacToe_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

local variants={}
for _,diff in ipairs({"easy","normal","hard"}) do
    for size=3,5 do for win=3,size do
        local id="solo_"..diff.."_"..size.."_"..win
        variants[#variants+1]={id=id,labelKey=id}
    end end
end
local solo=S.StatsWLD("lb_solo"); solo.difficulties=variants
local match=S.StatsWLD("lb_match"); match.difficulties={{id="match",labelKey="lb_match"}}
local legacy=S.StatsWLD("lb_legacy"); legacy.difficulties={"easy","normal","hard","default"}
ArcadiaNexus.RegisterLeaderboard({
    gameId = "TICTACTOE",
    difficulties = variants,
    sections = { solo, match, legacy },
})
