-- Removal schema: obsolete game data is cleaned at load and after old imports.
-- Earned achievements and historical profile/rewards are deliberately untouched.
local A=_G.ArcadiaNexus
local R={VERSION=2}; A.RetiredContent=R
local deleted={MATCH3=true,Match3=true}
local ids={MATCH3=true,Match3=true,AZEROTHWORDS=true,AzerothWords=true}
-- Azeroth Words history stays in its original storage, including old imports.
function R:IsGame(id) return ids[id]==true end
function R:CleanLeaderboard(leaderboard)
    if type(leaderboard)~="table" then return end
    for id in pairs(deleted) do leaderboard[id]=nil end
end
local function cleanIds(t)
    if type(t)~="table" then return end
    for i=#t,1,-1 do if ids[t[i]] then table.remove(t,i) end end
    for id in pairs(ids) do t[id]=nil end
end
function R:CleanDB(db)
    if type(db)~="table" then return end
    for id in pairs(deleted) do
        db[id]=nil
        if type(db.gameSettings)=="table" then db.gameSettings[id]=nil end
    end
    self:CleanLeaderboard(db.leaderboard)
    cleanIds(db.leaderboardUIState); cleanIds(db.categoryGroupState)
    cleanIds(db.favorites); cleanIds(db.hiddenGames)
    local ch=db.challenges
    if type(ch)=="table" then
        for _,key in ipairs({"daily","weekly"}) do
            local bucket=ch[key]
            local active=type(bucket)=="table" and bucket.active
            if type(active)=="table" then
                for i=#active,1,-1 do
                    local task=active[i]
                    if type(task)=="table" and (ids[task.gameId] or task.id=="d_match3_1500" or task.id=="d_words_win") then table.remove(active,i) end
                end
            end
        end
        cleanIds(ch._uniqueGames); cleanIds(ch._hsGames)
    end
    db.contentMigrationVersion=self.VERSION
end
