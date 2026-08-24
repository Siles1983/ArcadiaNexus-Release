-- ============================================================
--  Azeroth's Tiny Guardians – PetData.lua
--  Pet-Arten, 3D-Modelle, 2D-Icons (Stall/Adoption), Default-Namen
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ATG_PetData = {}
local P = ArcadiaNexus.ATG_PetData

P.types = {
    MURLOC     = { localeKey = "pet_murloc",     defaultName = "Mrgl" },
    DRAGON     = { localeKey = "pet_dragon",     defaultName = "Ember" },
    UNDEAD     = { localeKey = "pet_undead",     defaultName = "Rotgrins" },
    MECHAGNOME = { localeKey = "pet_mechagnome", defaultName = "Bolts" },
    FROSTWOLF  = { localeKey = "pet_frostwolf",  defaultName = "Snowpaw" },
    QUILBOAR   = { localeKey = "pet_quilboar",   defaultName = "Spike" },
}

P.icons = {
    MURLOC = {
        BABY  = "Interface\\Icons\\Ability_Creature_Poison_05",
        YOUTH = "Interface\\Icons\\INV_Misc_Fish_30",
        ADULT = "Interface\\Icons\\INV_Misc_MonsterHead_04",
    },
    DRAGON = {
        BABY  = "Interface\\Icons\\INV_Misc_Head_Dragon_Red",
        YOUTH = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        ADULT = "Interface\\Icons\\Spell_Fire_Fireball02",
    },
    UNDEAD = {
        BABY  = "Interface\\Icons\\Spell_Shadow_RaiseDead",
        YOUTH = "Interface\\Icons\\Spell_Shadow_DeathCoil",
        ADULT = "Interface\\Icons\\Ability_Racial_Cannibalize",
    },
    MECHAGNOME = {
        BABY  = "Interface\\Icons\\INV_Misc_Gear_01",
        YOUTH = "Interface\\Icons\\INV_Gizmo_02",
        ADULT = "Interface\\Icons\\INV_Misc_EngGizmos_05",
    },
    FROSTWOLF = {
        BABY  = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
        YOUTH = "Interface\\Icons\\Ability_Mount_WhiteDireWolf",
        ADULT = "Interface\\Icons\\INV_Misc_MonsterFang_01",
    },
    QUILBOAR = {
        BABY  = "Interface\\Icons\\Ability_Warrior_Charge",
        YOUTH = "Interface\\Icons\\Ability_Hunter_Pet_Boar",
        ADULT = "Interface\\Icons\\INV_Misc_Bone_06",
    },
}

P.adoptionOrder = { "MURLOC", "DRAGON", "UNDEAD", "MECHAGNOME", "FROSTWOLF", "QUILBOAR" }

-- 3D-Hauptansicht (Play-Panel).
-- speciesID  = BattlePetSpecies (wowhead.com/battle-pet/ID) — bevorzugt
-- creatureID / displayID = Fallback, falls das Pet Journal die Species nicht auflöst
-- zoom / camScale / rotation sind Feintuning-Werte
P.models = {
    MURLOC = {
        BABY  = { speciesID = 107,  creatureID = 15186,  displayID = 15369, rotation = 0.40, zoom = 0.25, camScale = 1.2 }, -- Murky
        YOUTH = { speciesID = 1940, creatureID = 113983, displayID = 73351, rotation = 0.40, zoom = 0.25, camScale = 1.2 }, -- Knight-Captain Murky
        ADULT = { speciesID = 1939, creatureID = 113984, displayID = 73352, rotation = 0.40, zoom = 0.25, camScale = 1.2 }, -- Legionnaire Murky
    },
    DRAGON = {
        BABY  = { speciesID = 819,  creatureID = 65321,  displayID = 43874,  rotation = 0.35, zoom = 0.25, camScale = 1.35 }, -- Wild Crimson Hatchling
        YOUTH = { speciesID = 320,  creatureID = 54027,  displayID = 38614,  rotation = 0.35, zoom = 0.25, camScale = 1.20 }, -- Lil' Tarecgosa
        ADULT = { speciesID = 4261, creatureID = 208637, displayID = 113664, rotation = 0.35, zoom = 0.20, camScale = 2.50 }, -- Obsidian Warwhelp
    },
    UNDEAD = {
        BABY  = { speciesID = 264,  creatureID = 45128,  displayID = 34262, rotation = 0.40, zoom = 0.85, camScale = 1.25 }, -- Crawling Claw
        YOUTH = { speciesID = 188,  creatureID = 28883,  displayID = 28456, rotation = 0.40, zoom = 0.55, camScale = 1.25 }, -- Frosty
        ADULT = { speciesID = 1871, creatureID = 105499, displayID = 48650, rotation = 0.40, zoom = 0.25, camScale = 1.00 }, -- Harbinger of Dark
    },
    MECHAGNOME = {
        BABY  = { speciesID = 1142, creatureID = 68601,  displayID = 46882, rotation = 0.35, zoom = 0.10, camScale = 1.5 }, -- Clock'em
        YOUTH = { speciesID = 3077, creatureID = 175785, displayID = 92192, rotation = 0.35, zoom = 0.10, camScale = 1.25 }, -- Kostos
        ADULT = { speciesID = 923,  creatureID = 66445,  displayID = 45586, rotation = 0.35, zoom = 0.10, camScale = 1.9 }, -- Hatewalker
    },
    FROSTWOLF = {
        BABY  = { speciesID = 3070, creatureID = 175778, displayID = 93750, rotation = 0.80, zoom = 0.15, camScale = 1.10 }, -- Briarpaw
        YOUTH = { speciesID = 928,  creatureID = 66469,  displayID = 45637, rotation = 0.50, zoom = 0.10, camScale = 0.95 }, -- Frostmaw
        ADULT = { speciesID = 1266, creatureID = 71942,  displayID = 49846, rotation = 0.80, zoom = 0.70, camScale = 1.80 }, -- Xu-Fu
    },
    QUILBOAR = {
        BABY  = { speciesID = 226,  creatureID = 33529,  displayID = 25384, rotation = 0.60, zoom = 0.15, camScale = 1.8 }, -- Curious Wolvar Pup
        YOUTH = { speciesID = 2417, creatureID = 143197, displayID = 76383, rotation = 0.60, zoom = 0.15, camScale = 1.65 }, -- Ranishu Runt
        ADULT = { speciesID = 1688, creatureID = 94927,  displayID = 64222, rotation = 0.60, zoom = 0.15, camScale = 1.3 }, -- Crusher
    },
}

-- M2-Animations-IDs (wowdev.wiki/M2/AnimationList)
P.ANIM = {
    idle       = 0,   -- Stand
    walk       = 4,   -- Walk
    run        = 5,   -- Run
    attack     = 16,  -- AttackUnarmed
    loot       = 50,  -- Loot
    precast    = 51,  -- ReadySpellDirected
    cast       = 32,  -- SpellCast
    castDir    = 53,  -- SpellCastDirected
    talk       = 60,  -- EmoteTalk
    eat        = 61,  -- EmoteEat
    use        = 63,  -- EmoteUseStanding
    wave       = 67,  -- EmoteWave
    cheer      = 68,  -- EmoteCheer
    emoteSleep = 71,  -- EmoteSleep
    sit        = 97,  -- SitGround
    sleepDown  = 99,  -- SleepDown
    sleep      = 100, -- Sleep (Lie Down)
}

-- Globale Defaults: ids[1] zuerst (kreaturen-tauglich), Rest = Fallbacks zum Tunen.
-- visualFallback = true → bei fehlender Liege-Anim: Idle + Alpha/Emote (Renderer).
P.actionAnimDefaults = {
    feed = {
        ids      = { 16, 50, 61, 0 },
        duration = 2.5,
    },
    pet = {
        ids      = { 68, 67, 60, 0 },
        duration = 2.0,
    },
    sleep = {
        ids         = { 99, 100, 71, 97, 0 },
        duration    = 1.2,
        phaseSleep  = { 100, 71, 97, 0 },
        visualFallback = true,
    },
    wash = {
        ids      = { 32, 53, 63, 0 },
        duration = 2.5,
    },
    train = {
        ids      = { 5, 4, 16, 0 },
        duration = 2.5,
    },
    heal = {
        ids      = { 53, 32, 51, 0 },
        duration = 2.5,
    },
}

-- Pro-Pet-Overrides (nach Ingame-Test eintragen — ersetzt/ergänzt Defaults).
-- Beispiel:
--   MURLOC = { feed = { ids = { 16 }, duration = 2.0 } },
P.petActionAnims = {}

P.phaseAnimDefaults = {
    idle = { ids = { 0 } },
    sleep = {
        ids            = { 100, 71, 97, 0 },
        visualFallback = true,
    },
}

P.traitTints = {
    GREEDY        = { 0.78, 1.0,  0.68, 1.0 },
    PICKY         = { 0.88, 0.92, 1.0,  1.0 },
    WARRIOR       = { 1.0,  0.45, 0.35, 1.0 },
    CLINGY        = { 1.0,  0.72, 0.88, 1.0 },
    HYPOCHONDRIAC = { 0.72, 1.0,  0.72, 1.0 },
    LAZY          = { 0.65, 0.65, 0.65, 0.6 },
    BALANCED      = { 1.0,  0.85, 0.35, 1.0 },
}

P.titles = {
    MURLOC = {
        default = "title_murloc_default",
        GREEDY = "title_murloc_greedy", PICKY = "title_murloc_picky",
        WARRIOR = "title_murloc_warrior", CLINGY = "title_murloc_clingy",
        HYPOCHONDRIAC = "title_murloc_hypochondriac", LAZY = "title_murloc_lazy",
        BALANCED = "title_murloc_balanced",
    },
    DRAGON = {
        default = "title_dragon_default",
        GREEDY = "title_dragon_greedy", PICKY = "title_dragon_picky",
        WARRIOR = "title_dragon_warrior", CLINGY = "title_dragon_clingy",
        HYPOCHONDRIAC = "title_dragon_hypochondriac", LAZY = "title_dragon_lazy",
        BALANCED = "title_dragon_balanced",
    },
    UNDEAD = {
        default = "title_undead_default",
        GREEDY = "title_undead_greedy", PICKY = "title_undead_picky",
        WARRIOR = "title_undead_warrior", CLINGY = "title_undead_clingy",
        HYPOCHONDRIAC = "title_undead_hypochondriac", LAZY = "title_undead_lazy",
        BALANCED = "title_undead_balanced",
    },
    MECHAGNOME = {
        default = "title_mechagnome_default",
        GREEDY = "title_mechagnome_greedy", PICKY = "title_mechagnome_picky",
        WARRIOR = "title_mechagnome_warrior", CLINGY = "title_mechagnome_clingy",
        HYPOCHONDRIAC = "title_mechagnome_hypochondriac", LAZY = "title_mechagnome_lazy",
        BALANCED = "title_mechagnome_balanced",
    },
    FROSTWOLF = {
        default = "title_frostwolf_default",
        GREEDY = "title_frostwolf_greedy", PICKY = "title_frostwolf_picky",
        WARRIOR = "title_frostwolf_warrior", CLINGY = "title_frostwolf_clingy",
        HYPOCHONDRIAC = "title_frostwolf_hypochondriac", LAZY = "title_frostwolf_lazy",
        BALANCED = "title_frostwolf_balanced",
    },
    QUILBOAR = {
        default = "title_quilboar_default",
        GREEDY = "title_quilboar_greedy", PICKY = "title_quilboar_picky",
        WARRIOR = "title_quilboar_warrior", CLINGY = "title_quilboar_clingy",
        HYPOCHONDRIAC = "title_quilboar_hypochondriac", LAZY = "title_quilboar_lazy",
        BALANCED = "title_quilboar_balanced",
    },
}

local function GetLocale(key)
    local loc = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("AZEROTHTINYGUARDIANS") or {}
    return loc[key] or key
end

function P:GetTitleKey(petType, traitId)
    local byType = self.titles[petType]
    if not byType then return "title_default" end
    if traitId and byType[traitId] then return byType[traitId] end
    return byType.default or "title_default"
end

function P:GetTitle(petType, traitId)
    return GetLocale(self:GetTitleKey(petType, traitId))
end

function P:GetTraitTint(traitId)
    local tint = self.traitTints[traitId]
    if not tint then return 1, 1, 1, 1 end
    return tint[1], tint[2], tint[3], tint[4]
end

function P:_ClientLang()
    local loc = _G.GetLocale and GetLocale() or "enUS"
    if loc == "deDE" then return "deDE" end
    return "enUS"
end

function P:_PickFromBilingual(set)
    if not set then return nil end
    local lang = self:_ClientLang()
    local lines = set[lang] or set.enUS or set.deDE
    if not lines or #lines == 0 then return nil end
    return lines[math.random(#lines)]
end

function P:PickComment(petType, context, dominantTrait)
    if not petType or not context then return nil end
    local lines = self.comments and self.comments[petType]
    local set = lines and lines[context]

    if dominantTrait and self.traitComments and self.traitComments[petType] then
        local byTrait = self.traitComments[petType][dominantTrait]
        if byTrait and byTrait[context] then
            set = byTrait[context]
        end
    end

    return self:_PickFromBilingual(set)
end

function P:IsValidType(petType)
    return petType ~= nil and self.types[petType] ~= nil
end

function P:GetDefaultName(petType)
    local info = self.types[petType]
    return info and info.defaultName or "Pet"
end

function P:GetIcon(petType, stage)
    local byType = self.icons[petType]
    if not byType then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    return byType[stage or "BABY"] or byType.BABY
end

function P:GetModelDef(petType, stage)
    local byType = self.models[petType]
    if not byType then return nil end
    return byType[stage or "BABY"] or byType.BABY
end

function P:_CopyIdList(list)
    if not list then return nil end
    local copy = {}
    for i, id in ipairs(list) do
        copy[i] = id
    end
    return copy
end

function P:_CopyAnimDef(def)
    if not def then return nil end
    return {
        ids            = self:_CopyIdList(def.ids),
        duration       = def.duration,
        phaseSleep     = self:_CopyIdList(def.phaseSleep),
        visualOnly     = def.visualOnly,
        visualFallback = def.visualFallback,
    }
end

function P:_MergeAnimDef(base, override)
    local merged = self:_CopyAnimDef(base)
    if not merged or not override then return merged end
    if override.ids then merged.ids = self:_CopyIdList(override.ids) end
    if override.duration ~= nil then merged.duration = override.duration end
    if override.phaseSleep then merged.phaseSleep = self:_CopyIdList(override.phaseSleep) end
    if override.visualOnly ~= nil then merged.visualOnly = override.visualOnly end
    if override.visualFallback ~= nil then merged.visualFallback = override.visualFallback end
    return merged
end

function P:GetActionAnimation(petType, action)
    local def = self.actionAnimDefaults[action]
    if not def then return nil end
    local byPet = petType and self.petActionAnims[petType]
    local override = byPet and byPet[action]
    if override then
        return self:_MergeAnimDef(def, override)
    end
    return self:_CopyAnimDef(def)
end

function P:GetPhaseAnimation(petType, phase)
    if phase == "SLEEPING" then
        local sleepDef = self:GetActionAnimation(petType, "sleep")
        if sleepDef and sleepDef.phaseSleep then
            return {
                ids            = self:_CopyIdList(sleepDef.phaseSleep),
                visualFallback = sleepDef.visualFallback,
            }
        end
        return self:_CopyAnimDef(self.phaseAnimDefaults.sleep)
    end
    return self:_CopyAnimDef(self.phaseAnimDefaults.idle)
end

function P:GetPrimaryAnimId(animDef)
    if not animDef or animDef.visualOnly then return nil end
    local ids = animDef.ids
    if not ids or #ids == 0 then return nil end
    return ids[1]
end

function P:_PositiveId(value)
    return type(value) == "number" and value > 0 and value or nil
end

function P:ResolveModelIds(def)
    if not def then return nil, nil end
    if def._resolved then
        return def._resolvedDisplayID, def._resolvedCompanionID
    end

    local displayID = self:_PositiveId(def.displayID)
    local companionID = self:_PositiveId(def.creatureID)
    local speciesID = self:_PositiveId(def.speciesID)

    if speciesID and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
        local ok, info = pcall(function()
            return { C_PetJournal.GetPetInfoBySpeciesID(speciesID) }
        end)
        if ok and type(info) == "table" then
            companionID = self:_PositiveId(info[4]) or companionID
            displayID = self:_PositiveId(info[12]) or displayID
        end
    end

    def._resolvedDisplayID = displayID
    def._resolvedCompanionID = companionID
    def._resolved = true
    return displayID, companionID
end

-- Viewport-Größe (CFG play_model / stall_model w/h) skaliert nur das Widget.
-- zoom / camScale steuern den Kamerausschnitt unabhängig davon.
-- zoom     SetPortraitZoom: kleiner = mehr Körper, größer = Portrait/Kopf
-- camScale SetCamDistanceScale: größer = Kamera weiter weg, Pet wirkt kleiner
-- zoom = 0 ist gültig (nicht mit `if def.zoom` prüfen — 0 ist in Lua falsch).
function P:ApplyCamera(modelFrame, def)
    if not modelFrame or not def then return end

    -- RefreshCamera zuerst, sonst überschreibt es die Feintuning-Werte.
    if modelFrame.RefreshCamera then
        modelFrame:RefreshCamera()
    end
    if def.rotation ~= nil and modelFrame.SetRotation then
        modelFrame:SetRotation(def.rotation)
    end
    if def.zoom ~= nil and modelFrame.SetPortraitZoom then
        modelFrame:SetPortraitZoom(def.zoom)
    end
    if def.camScale ~= nil and modelFrame.SetCamDistanceScale then
        modelFrame:SetCamDistanceScale(def.camScale)
    end
end

function P:_EnsureCameraHook(modelFrame)
    if not modelFrame or modelFrame._atgCamHooked then return end
    modelFrame._atgCamHooked = true
    pcall(function()
        modelFrame:HookScript("OnModelLoaded", function(self)
            local PD = ArcadiaNexus.ATG_PetData
            if PD and PD.ApplyCamera and self._atgCamDef then
                PD:ApplyCamera(self, self._atgCamDef)
            end
        end)
    end)
end

function P:ApplyModel(modelFrame, petType, stage)
    if not modelFrame then return false end
    local def = self:GetModelDef(petType, stage)
    if not def then return false end

    local displayID, companionID = self:ResolveModelIds(def)
    if modelFrame.ClearModel then
        modelFrame:ClearModel()
    end

    local loaded = false
    if displayID and modelFrame.SetDisplayInfo then
        loaded = pcall(modelFrame.SetDisplayInfo, modelFrame, displayID)
    end
    if not loaded and companionID and modelFrame.SetCreature then
        if displayID then
            loaded = pcall(modelFrame.SetCreature, modelFrame, companionID, displayID)
        else
            loaded = pcall(modelFrame.SetCreature, modelFrame, companionID)
        end
    end
    if not loaded then
        return false
    end

    modelFrame._atgCamDef = def
    self:_EnsureCameraHook(modelFrame)
    self:ApplyCamera(modelFrame, def)

    return true
end
