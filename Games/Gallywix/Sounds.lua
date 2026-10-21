-- Local presentation only: settings never change rules or MATCH timing.
local A=ArcadiaNexus
A.GWX_Sounds={}
local S=A.GWX_Sounds
S.catalog={
    {key="soundWheel",kit="UI_BONUS_LOOT_ROLL_LOOP",id=31580},
    {key="soundWheelStop",kit="UI_BONUS_LOOT_ROLL_END",id=31581},
    {key="soundHit",kit="LOOT_WINDOW_COIN_SOUND",id=120},
    {key="soundMiss",kit="IG_QUEST_CANCEL",id=879},
    {key="soundVowel",kit="IG_BACKPACK_COIN_SELECT",id=864},
    {key="soundBankrupt",kit="UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER",id=43503},
    {key="soundSkip",kit="UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL",id=43501},
    {key="soundExtra",kit="UI_BONUS_EVENT_SYSTEM_VIGNETTES",id=45142},
    {key="soundRound",kit="UI_SCENARIO_STAGE_END",id=31757},
    {key="soundWin",kit="UI_SCENARIO_ENDING",id=31754},
    {key="soundLose",kit="UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL",id=43501},
    {key="soundGallywix"}, -- Existing native Goblin laugh file in Renderer CFG.
}
local events={hit="soundHit",miss="soundMiss",wrong_solution="soundMiss",
    vowel="soundVowel",bankrupt="soundBankrupt",lose_turn="soundSkip",
    extra_spin="soundExtra",round_won="soundRound"}
function S:Enabled(key)
    return A.GWX_Settings:Get("soundEnabled")==true and A.GWX_Settings:Get(key)==true
end
function S:Play(key)
    if not self:Enabled(key) or not PlaySound then return end
    for _,item in ipairs(self.catalog) do
        if item.key==key and item.id then
            local id=SOUNDKIT and SOUNDKIT[item.kit] or item.id
            if not id or id<=0 then return end
            local ok,played,handle=pcall(PlaySound,id,"Master")
            if ok and played then return handle end
            return
        end
    end
end
function S:StopWheel(landed)
    local wasSpinning=self.spinning
    self.spinning=false
    if self.wheelHandle and StopSound then StopSound(self.wheelHandle) end
    self.wheelHandle=nil
    if landed and wasSpinning then self:Play("soundWheelStop") end
end
function S:StartWheel()
    self:StopWheel(false)
    self.spinning=true
    self.wheelHandle=self:Play("soundWheel")
end
function S:Observe(state)
    local event=state.event
    if self.event==event then return end
    local first=self.event==nil
    self.event=event
    -- Initial and recovered boards establish a baseline, never replay old cues.
    if not first and state.phase~="SPINNING" and event and events[event.kind] then self:Play(events[event.kind]) end
end
function S:Result(result)
    if self.resultPlayed then return end
    self.resultPlayed=true
    if result=="WIN" then self:Play("soundWin")
    elseif result=="LOSS" then self:Play("soundLose") end
end
function S:Reset()
    self:StopWheel(false)
    self.event=nil; self.resultPlayed=false
end
