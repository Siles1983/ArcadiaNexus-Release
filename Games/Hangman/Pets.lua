-- Stable cosmetic IDs, native CreatureDisplayInfo references. Color skins are not separate choices.
local A=ArcadiaNexus
local P={}; A.HGM_Pets=P
local catalog={
 {id='imp',displayID=64799,en='Imp',de='Wichtel'},
 {id='voidwalker',displayID=113621,en='Voidwalker',de='Leerwandler'},
 {id='succubus',displayID=77396,en='Succubus',de='Sukkubus'},
 {id='felhunter',displayID=113609,en='Felhunter',de='Teufelsjäger'},
 {id='felguard',displayID=64802,en='Felguard',de='Teufelswache'},
 {id='infernal',displayID=87778,en='Infernal',de='Höllenbestie'},
 {id='doomguard',displayID=64965,en='Doomguard',de='Verdammniswache'},
 {id='darkglare',displayID=116130,en='Darkglare',de='Dunkelblick'},
 {id='demonic_tyrant',displayID=116167,en='Demonic Tyrant',de='Dämonischer Tyrann'},
 {id='wild_imp',displayID=77405,en='Wild Imp',de='Wildwichtel'},
 {id='dreadstalker',displayID=77402,en='Dreadstalker',de='Schreckenspirscher'},
 {id='vilefiend',displayID=84424,en='Vilefiend',de='Übelhund'},
 {id='gloomhound',displayID=77262,en='Gloomhound',de='Düsterhund'},
 {id='charhound',displayID=120682,en='Charhound',de='Brandhund'},
 {id='fel_imp',displayID=44152,en='Fel Imp',de='Teufelswichtel'},
 {id='voidlord',displayID=74437,en='Voidlord',de='Leerenfürst'},
 {id='shivarra',displayID=44610,en='Shivarra',de='Shivarra'},
 {id='wrathguard',displayID=77401,en='Wrathguard',de='Zornwächter'},
 {id='observer',displayID=44153,en='Observer',de='Beobachter'},
 {id='incubus',displayID=105009,en='Incubus',de='Inkubus'},
 {id='terrorguard',displayID=65072,en='Terrorguard',de='Terrorwache'},
 {id='overlord',displayID=116523,en='Overlord',de='Oberanführer'},
 {id='mother_of_chaos',displayID=116544,en='Mother of Chaos',de='Mutter des Chaos'},
 {id='pit_lord',displayID=121664,en='Pit Lord',de='Grubenlord'},
 {id='fiend',displayID=113652,en='Fiend',de='Scheusal'},
 {id='dreadhound',displayID=113321,en='Dreadhound',de='Schreckenshund'},
 {id='voidseeker',displayID=60653,en='Voidseeker',de='Leerensucher'},
 {id='abyssal',displayID=48856,en='Abyssal',de='Abyssal'},
 {id='ancient_observer',displayID=47189,en='Ancient Observer',de='Uralter Beobachter'},
}
local byId={}; for _,entry in ipairs(catalog) do byId[entry.id]=entry end
function P:Get(id) return byId[id] end
function P:IsChoice(id) return id=='random' or byId[id]~=nil end
function P:Resolve(id) if byId[id] then return id end return catalog[math.random(#catalog)].id end
function P:GetOptions()
 local de=A.ActiveLocale=='deDE'; local opts={{key='random',label=de and 'Zufall' or 'Random'}}
 for _,e in ipairs(catalog) do opts[#opts+1]={key=e.id,label=de and e.de or e.en} end
 return opts
end
function P:GetList() local out={}; for i,e in ipairs(catalog) do out[i]=A.HGM_Logic:Copy(e) end return out end
