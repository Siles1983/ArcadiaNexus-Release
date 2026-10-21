-- Regular completed solo and MATCH games. Facts persist through ScoreManager;
-- conditions only read the shared store and also support retroactive checks.
local A=ArcadiaNexus
local GAME_ID="GALLYWIX"
local function entries(db)
    return (db.leaderboard or {})[GAME_ID] or {}
end
local function eligible(data)
    return data.gameId==GAME_ID or data._retroactive==true
end
local function maximum(db,key)
    local value=0
    for _,entry in pairs(entries(db)) do value=math.max(value,(entry.customStats or {})[key] or 0) end
    return value
end
local function fact(key)
    return function(data,db) return eligible(data) and maximum(db,key) or 0 end
end
local groups={}
local function add(id,de,en,descDE,descEN,icon,condition,tiers,hidden)
    groups[#groups+1]={id="GWX_"..id,gameId=GAME_ID,category="WORT",
        title_de=de,title_en=en,desc_de=descDE,desc_en=descEN,
        icon="Interface\\Icons\\"..icon,condition=condition,tiers=tiers,hidden=hidden}
end
local function single(id,de,en)
    return {{id="GWX_"..id.."_GOLD",tierName="Gold",target=1,xp=25,desc_de=de,desc_en=en}}
end
local function progression(id,targets,de,en)
    local names={"Bronze","Silber","Gold"}
    local suffixes={"BRONZE","SILBER","GOLD"}
    local xp={15,30,55}
    local tiers={}
    for i,target in ipairs(targets) do
        tiers[i]={id="GWX_"..id.."_"..suffixes[i],tierName=names[i],target=target,xp=xp[i],
            desc_de=string.format(de,target),desc_en=string.format(en,target)}
    end
    return tiers
end
add("WINS","Die Bank zahlt aus","The House Pays Out",
    "Gewinne Partien in Gallywix.","Win games of Gallywix.","INV_Misc_Coin_01",
    function(data,db)
        if not eligible(data) then return 0 end
        local wins=0; for _,entry in pairs(entries(db)) do wins=wins+(entry.wins or 0) end
        return wins
    end,progression("WINS",{1,10,50},"Gewinne %d Partien.","Win %d games."))
add("ROUNDS","Wörter sind auch eine Währung","Words Are Currency Too",
    "Gewinne Rätselrunden in Gallywix.","Win puzzle rounds in Gallywix.","INV_Misc_Book_09",
    function(data,db)
        if not eligible(data) then return 0 end
        local rounds=0
        for _,entry in pairs(entries(db)) do rounds=rounds+((entry.customStats or {}).gwxRoundsTotal or 0) end
        return rounds
    end,progression("ROUNDS",{10,50,150},"Gewinne %d Rätselrunden.","Win %d puzzle rounds."))
add("CATEGORIES","In allen Geschäften zu Hause","A Trader of All Trades",
    "Gewinne eine Rätselrunde in jeder der vier Kategorien.","Win a puzzle round in each of the four categories.","INV_Misc_Map_01",
    function(data,db)
        if not eligible(data) then return 0 end
        local count=0
        for _,category in ipairs({"characters","places","weapons","lore"}) do
            if maximum(db,"gwxCategory_"..category)>0 then count=count+1 end
        end
        return count
    end,{{id="GWX_CATEGORIES_GOLD",tierName="Gold",target=4,xp=25,
        desc_de="Gewinne eine Rätselrunde in jeder der vier Kategorien.",desc_en="Win a puzzle round in each of the four categories."}})
local specials={
    {"NO_VOWELS","Vokale kosten extra","Vowels Cost Extra","gwx_noVowels","INV_Misc_Coin_02",
        "Gewinne eine Rätselrunde, ohne selbst einen Vokal zu kaufen.","Win a puzzle round without buying a vowel yourself."},
    {"CLEAN","Keine Fehlinvestition","No Bad Investments","gwxClean","INV_Misc_Gem_Pearl_01",
        "Gewinne eine Partie ohne falschen Buchstaben oder falsche Lösung.","Win a game without an incorrect letter or solution."},
    {"SWEEP","Die Konkurrenz ist sprachlos","Speechless Competition","gwxSweep","Ability_Warrior_WarCry",
        "Gewinne alle drei Rätselrunden einer Partie.","Win all three puzzle rounds in a game."},
    {"GOLD_LETTER","Dieser Buchstabe ist Gold wert","A Letter Worth Its Weight in Gold","gwx_goldLetter","INV_Misc_Coin_01",
        "Verdiene mindestens 5.000 Punkte mit einem einzigen Konsonanten.","Earn at least 5,000 points from a single consonant."},
    {"INSURED","Kleingedrucktes","The Fine Print","gwx_insured","INV_Misc_ScrollUnrolled01",
        "Bleibe durch einen Extradreh nach Bankrott am Zug. Der Zug ist versichert. Das Geld leider nicht.",
        "Use an extra spin to keep your turn after bankruptcy. Your turn is insured. Your money is not."},
    {"COMEBACK","Totgesagte drehen länger","Still Spinning","gwx_comeback","Spell_Holy_Resurrection",
        "Gewinne eine Rätselrunde, nachdem du darin Guthaben durch Bankrott verloren hast.",
        "Win a puzzle round after losing money to bankruptcy in that round."},
    {"GALLYWIX_BANKRUPT","Der Handelsprinz lässt grüßen","Regards from the Trade Prince","gwx_gallywixBankrupt","INV_Misc_Coin_02",
        "Verliere mindestens 3.000 Rundenguthaben, weil Gallywix deinen Dreh auf Bankrott verändert.",
        "Lose at least 3,000 round points when Gallywix changes your spin to bankruptcy.",true},
    {"LUCKY","Zu meinen Gunsten verrechnet","An Error in My Favor","gwx_lucky","INV_Misc_Coin_01",
        "Gallywix verändert deinen Bankrott-Stopp auf 1.000. Triff anschließend einen Konsonanten.",
        "Gallywix changes your bankruptcy stop to 1,000. Then hit a consonant."},
    {"DEFIANT","Dein Casino. Mein Gewinn.","Your Casino. My Winnings.","gwxDefiant","INV_Misc_Gem_Diamond_01",
        "Gewinne mit aktivierter Gallywix-Option, nachdem er mindestens dreimal in deine Drehungen eingegriffen hat.",
        "Win with Gallywix enabled after he interferes with at least three of your own spins."},
}
for _,entry in ipairs(specials) do
    add(entry[1],entry[2],entry[3],entry[6],entry[7],entry[5],fact(entry[4]),
        single(entry[1],entry[6],entry[7]),entry[8])
end
A.RegisterAchievements(groups)
