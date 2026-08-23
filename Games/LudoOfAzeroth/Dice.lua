--[[
    Ludo of Azeroth – Dice.lua
    3D-Wuerfel mit 2D-Fallback (API 12 / Retail).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Dice = {}
local D = ArcadiaNexus.LOA_Dice

D.MODEL_FILE_ID = 1266984
D.NATIVE_MODEL_ID = 1266984
D.ROLL_DURATION = 2.0
D.SPIN_STEP     = 0.08
D.SPIN_COUNT    = 24
D.NATIVE_ANIM_SPEED = 0.55
D.MODEL_PROBE   = 0.05
D.MODEL_RETRIES = 40

-- Manual camera/model tuning. Angles are radians; smaller camera distance
-- values zoom in. 0.75 is deliberately tighter than automatic full framing.
D.CAMERA_DISTANCE_SCALE = 1
D.CAMERA_YAW   = 0.0
D.CAMERA_PITCH = 0.0
D.CAMERA_ROLL  = 0.0
D.MODEL_YAW    = 0.0
D.MODEL_PITCH  = 0.2
D.MODEL_ROLL   = 0.0

-- Confirmed M2 FileDataIDs from the current WoW listfile. Roll the Bones is
-- preferred; neutral dice doodads remain available as client fallbacks.
D.MODEL_CANDIDATES = {
    1266984, -- spells/cfx_rogue_rollthebones_castbasedice.m2
    1828709, -- world/.../8du_kultirasprison_dice01.m2
    5933743, -- world/.../11go_goblin_dice01.m2
    5933744, -- world/.../11go_goblin_dice02.m2
    5933745, -- world/.../11go_goblin_dice03.m2
}

D._modelVerified    = false
D._loadedFileId     = nil
D._sceneInitialized = false
D._actor            = nil
D._warmingUp        = false

function D:IsRolling()
    return self._rollTicker ~= nil
end

function D:TextureExists(path)
    if not path then return false end
    if C_Texture and C_Texture.GetFileIDFromPath then
        return C_Texture.GetFileIDFromPath(path) ~= 0
    end
    return true
end

function D:GetDiceIcon(theme, face)
    face = math.max(1, math.min(6, face or 1))
    local Themes = ArcadiaNexus.LOA_Themes
    if Themes and Themes.GetDiceIcon then
        return Themes:GetDiceIcon(face)
    end
    if theme and theme.dice then
        return theme.dice[face] or theme.dice[1]
    end
    return "Interface\\Icons\\Ability_Rogue_RollTheBones"
end

function D:ShowIcon(icon, theme, face)
    if not icon then return end
    local path = self:GetDiceIcon(theme, face)
    if not self:TextureExists(path) then
        path = "Interface\\Icons\\Ability_Rogue_RollTheBones"
    end
    icon:SetTexture(path)
    icon:Show()
end

function D:SetCameraTransform(scene, distance)
    if not scene then return end
    distance = math.max(0.05, tonumber(distance) or 3)

    local yaw   = self.CAMERA_YAW or 0
    local pitch = self.CAMERA_PITCH or 0
    local roll  = self.CAMERA_ROLL or 0
    local sy, cy = math.sin(yaw), math.cos(yaw)
    local sp, cp = math.sin(pitch), math.cos(pitch)
    local sr, cr = math.sin(roll), math.cos(roll)
    local fx, fy, fz = -sy * cp, -cy * cp, -sp
    local baseRX, baseRY, baseRZ = cy, -sy, 0
    local baseUX, baseUY, baseUZ = -sy * sp, -cy * sp, cp
    local rx = baseRX * cr + baseUX * sr
    local ry = baseRY * cr + baseUY * sr
    local rz = baseRZ * cr + baseUZ * sr
    local ux = baseUX * cr - baseRX * sr
    local uy = baseUY * cr - baseRY * sr
    local uz = baseUZ * cr - baseRZ * sr

    if scene.SetCameraPosition then
        scene:SetCameraPosition(sy * cp * distance, cy * cp * distance, sp * distance)
    end
    if scene.SetCameraOrientationByAxisVectors then
        scene:SetCameraOrientationByAxisVectors(
            fx, fy, fz,
            rx, ry, rz,
            ux, uy, uz
        )
    elseif scene.SetCameraOrientationByYawPitchRoll then
        scene:SetCameraOrientationByYawPitchRoll(math.pi + yaw, pitch, roll)
    end
end

function D:SetupManualCamera(scene)
    if not scene then return end
    if scene.SetLightVisible then scene:SetLightVisible(true) end
    if scene.SetLightAmbientColor then scene:SetLightAmbientColor(0.55, 0.55, 0.55) end
    if scene.SetLightDiffuseColor then scene:SetLightDiffuseColor(1, 1, 1) end
    if scene.SetLightDirection then scene:SetLightDirection(0.4, -0.7, -1) end
    if scene.SetCameraNearClip then scene:SetCameraNearClip(0.01) end
    if scene.SetCameraFarClip then scene:SetCameraFarClip(100) end
    if scene.SetCameraFieldOfView then scene:SetCameraFieldOfView(0.48) end
    if scene.SetPaused then scene:SetPaused(false, true) end
    if scene.SetAlpha then scene:SetAlpha(1) end
    self:SetCameraTransform(scene, 3)
end

function D:SetupActor(actor)
    if not actor then return end
    if actor.SetUseCenterForOrigin then
        actor:SetUseCenterForOrigin(true, true, true)
    end
    if actor.SetPosition then actor:SetPosition(0, 0, 0) end
    if actor.SetScale then actor:SetScale(1.0) end
    if actor.SetAlpha then actor:SetAlpha(1) end
    if actor.SetDesaturation then actor:SetDesaturation(0) end
    if actor.SetYaw then actor:SetYaw(self.MODEL_YAW or 0) end
    if actor.SetPitch then actor:SetPitch(self.MODEL_PITCH or 0) end
    if actor.SetRoll then actor:SetRoll(self.MODEL_ROLL or 0) end
    if actor.SetAnimation then
        actor:SetAnimation(0, 0, self.NATIVE_ANIM_SPEED, 0)
    end
end

function D:FitModelToView(scene, actor)
    if not scene or not actor or not actor.GetActiveBoundingBox then return end

    -- Depending on the Retail build, the API returns either two vector3
    -- objects or six plain numbers (minX, minY, minZ, maxX, maxY, maxZ).
    local a, b, c, d, e, f = actor:GetActiveBoundingBox()
    if a == nil and actor.GetMaxBoundingBox then
        a, b, c, d, e, f = actor:GetMaxBoundingBox()
    end

    local minX, minZ, maxX, maxZ
    if type(a) == "table" and type(b) == "table" then
        minX, minZ = a.x or 0, a.z or 0
        maxX, maxZ = b.x or 0, b.z or 0
    elseif type(a) == "number" and type(f) == "number" then
        minX, minZ = a, c
        maxX, maxZ = d, f
    else
        return
    end

    local width  = math.abs(maxX - minX)
    local height = math.abs(maxZ - minZ)
    local extent = math.max(width, height, 0.1)
    local fov = scene.GetCameraFieldOfView and scene:GetCameraFieldOfView() or 0.48
    local distance = ((extent * 0.5) / math.tan(fov * 0.5))
        * (self.CAMERA_DISTANCE_SCALE or 1)

    self:SetCameraTransform(scene, distance)
end

function D:EnsureScene(scene)
    if not scene then return nil end

    if not self._sceneInitialized then
        self:SetupManualCamera(scene)

        local actor
        if scene.CreateActor then
            local ok, created = pcall(scene.CreateActor, scene, nil, "ModelSceneActorTemplate")
            actor = ok and created or scene:CreateActor()
        end
        if not actor and scene.GetActorAtIndex then
            actor = scene:GetActorAtIndex(1)
        end

        self._actor = actor
        self._sceneInitialized = true
    end

    return self._actor
end

function D:IsModelReady(actor, fileId)
    if not actor then return false end
    if actor.IsLoaded then
        local ok, loaded = pcall(actor.IsLoaded, actor)
        if not ok or not loaded then return false end
    elseif actor.IsGeoReady and not actor:IsGeoReady() then
        return false
    end
    if actor.GetModelFileID then
        local id = actor:GetModelFileID()
        if id and id > 0 then
            return not fileId or id == fileId
        end
    end
    -- Older clients may not expose GetModelFileID on the actor.
    return actor.IsLoaded == nil and actor.IsGeoReady and actor:IsGeoReady() or false
end

function D:TryLoadFileId(actor, fileId)
    if not actor or not actor.SetModelByFileID then return false end
    actor:ClearModel()
    local ok = actor:SetModelByFileID(fileId)
    if ok == false then return false end
    self:SetupActor(actor)
    return true
end

function D:EnsureModelLoaded(actor)
    if not actor then return false end
    if self._loadedFileId and self:IsModelReady(actor, self._loadedFileId) then
        self:SetupActor(actor)
        return true
    end
    if self._loadedFileId and self:TryLoadFileId(actor, self._loadedFileId) then
        return self:IsModelReady(actor, self._loadedFileId)
    end
    return false
end

function D:Hide3D(scene)
    if scene then scene:Hide() end
end

-- Show the verified model and remove the fallback icon from the render path.
function D:Show3D(scene, actor, icon)
    actor = actor or self._actor
    if not scene or not actor then return false end
    if not self._modelVerified and not self:EnsureModelLoaded(actor) then
        return false
    end
    self:SetupManualCamera(scene)
    self:SetupActor(actor)
    self:FitModelToView(scene, actor)
    self._iconTicker = nil
    if icon then icon:Hide() end
    scene:Show()
    return true
end

function D:CollectCandidates()
    local list, seen = {}, {}
    local function add(id)
        id = tonumber(id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    for _, id in ipairs(self.MODEL_CANDIDATES) do add(id) end
    add(self.MODEL_FILE_ID)
    return list
end

function D:ProbeModel(scene, callback)
    if not scene or not callback then return end

    local actor = self:EnsureScene(scene)
    if not actor then
        callback(false, nil, nil)
        return
    end

    scene:Show()
    local candidates = self:CollectCandidates()
    local idx = 1

    local function tryNext()
        if idx > #candidates then
            callback(false, actor, nil)
            return
        end

        local fileId = candidates[idx]
        idx = idx + 1

        if not self:TryLoadFileId(actor, fileId) then
            tryNext()
            return
        end

        local attempts = 0
        local function waitReady()
            attempts = attempts + 1
            if self:IsModelReady(actor, fileId) then
                self._modelVerified = true
                self._loadedFileId = fileId
                callback(true, actor, fileId)
            elseif attempts >= self.MODEL_RETRIES then
                tryNext()
            else
                C_Timer.After(self.MODEL_PROBE, waitReady)
            end
        end
        C_Timer.After(self.MODEL_PROBE, waitReady)
    end

    tryNext()
end

function D:ShowFace(scene, resultFS, icon, theme, value)
    value = math.max(1, math.min(6, value or 1))
    self:Hide3D(scene)
    self._iconTicker = nil
    self:ShowIcon(icon, theme, value)
    if resultFS then
        resultFS:SetText(tostring(value))
        resultFS:Show()
    end
end

function D:ShowIdle(scene, resultFS, icon, theme, game)
    if self:IsRolling() then return end

    if game and game.dice and game.dice > 0 and game.rolled then
        self:ShowFace(scene, resultFS, icon, theme, game.dice)
        return
    end

    if resultFS then resultFS:Hide() end
    self:Hide3D(scene)
    self:ShowIcon(icon, theme, 1)
end

function D:Warmup(scene, onReady)
    if not scene then return end
    if self._modelVerified then
        if onReady then onReady(true, self._actor, self._loadedFileId) end
        return
    end
    if self._warmingUp then return end
    self._warmingUp = true
    self:ProbeModel(scene, function(ok, actor, fileId)
        self._warmingUp = false
        if ok then self._actor = actor end
        self:Hide3D(scene)
        if onReady then onReady(ok, actor, fileId) end
    end)
end

function D:CancelRoll()
    self._rollTicker = nil
    self._spinTicker = nil
    self._iconTicker = nil
end

function D:SpinActor(actor, token, running)
    if not actor then return end
    local step = 0
    local function Step()
        if self._spinTicker ~= token or not running() then return end
        step = step + 1
        if actor.SetYaw then
            actor:SetYaw((step / self.SPIN_COUNT) * math.pi * 6)
        end
        if actor.SetRoll then
            actor:SetRoll((step % 4) * 0.35)
        end
        if step < self.SPIN_COUNT then
            C_Timer.After(self.SPIN_STEP, Step)
        end
    end
    self._spinTicker = token
    C_Timer.After(0, Step)
end

function D:RunIconShuffle(icon, theme, token, running)
    if not icon then return end
    local step = 0
    local function Step()
        if self._rollTicker ~= token or self._iconTicker ~= token or not running() then return end
        step = step + 1
        self:ShowIcon(icon, theme, ((step - 1) % 6) + 1)
        if step < self.SPIN_COUNT then
            C_Timer.After(self.SPIN_STEP, Step)
        end
    end
    self._iconTicker = token
    C_Timer.After(0, Step)
end

function D:Start3DAnimation(actor, token, running)
    if not actor then return end
    if self._loadedFileId == self.NATIVE_MODEL_ID then
        -- Roll the Bones already contains its own animation. Rotating the
        -- complete effect actor as well makes the sequence unnaturally fast.
        self._spinTicker = nil
        return
    end
    self:SpinActor(actor, token, running)
end

function D:AnimateRoll(renderer, theme, finalVal, callback)
    self:CancelRoll()

    local scene    = renderer._diceScene
    local icon     = renderer._diceIcon
    local resultFS = renderer._diceResultFS
    local running  = function() return renderer._running end
    local token    = {}
    self._rollTicker = token

    if resultFS then resultFS:Hide() end

    -- 3D is the primary path. Only animate the icon while no verified model
    -- is available; once a late probe succeeds, switch to 3D immediately.
    local actor = renderer._diceActor or self._actor
    if self._modelVerified and actor and scene then
        if self:Show3D(scene, actor, icon) then
            self:Start3DAnimation(actor, token, running)
        end
    elseif scene then
        self:Hide3D(scene)
        self:ShowIcon(icon, theme, 1)
        self:RunIconShuffle(icon, theme, token, running)
        self:ProbeModel(scene, function(ok, newActor)
            if not ok or self._rollTicker ~= token or not running() then return end
            renderer._diceActor = newActor
            self._actor = newActor
            if self:Show3D(scene, newActor, icon) then
                self:Start3DAnimation(newActor, token, running)
            end
        end)
    else
        self:ShowIcon(icon, theme, 1)
        self:RunIconShuffle(icon, theme, token, running)
    end

    C_Timer.After(self.ROLL_DURATION, function()
        if self._rollTicker ~= token or not running() then return end
        self._rollTicker = nil
        self._spinTicker = nil
        self._iconTicker = nil
        self:ShowFace(scene, resultFS, icon, theme, finalVal)
        if callback then callback() end
    end)
end

function D:ResetScene()
    self._modelVerified = false
    self._loadedFileId = nil
    self._sceneInitialized = false
    self._actor = nil
end

function D:DebugProbe(scene, renderer)
    if not scene then
        print("|cff00ccff[LOA Dice]|r Kein ModelScene-Frame.")
        return
    end

    print("|cff00ccff[LOA Dice]|r Starte 3D-Probe …")
    self:ResetScene()
    if renderer and renderer._diceFrame then
        renderer._diceFrame:Show()
    end
    self:ProbeModel(scene, function(ok, actor, fileId)
        if ok then
            print(string.format("|cff00ccff[LOA Dice]|r 3D OK – FileDataID %s", tostring(fileId)))
            self._actor = actor
            if renderer then
                renderer._diceActor = actor
                if renderer._diceResultFS then renderer._diceResultFS:Hide() end
                self:Show3D(scene, actor, renderer._diceIcon)
                C_Timer.After(3, function()
                    if self:IsRolling() then return end
                    local theme = ArcadiaNexus.LOA_Themes:GetTheme()
                    self:ShowIdle(scene, renderer._diceResultFS, renderer._diceIcon, theme, renderer._game)
                end)
            end
        else
            print("|cffff8800[LOA Dice]|r 3D fehlgeschlagen – 2D-Fallback aktiv.")
            if actor and actor.GetModelFileID then
                print("|cffaaaaaa[LOA Dice]|r GetModelFileID = " .. tostring(actor:GetModelFileID()))
            end
            if renderer then
                local theme = ArcadiaNexus.LOA_Themes:GetTheme()
                self:ShowIdle(scene, renderer._diceResultFS, renderer._diceIcon, theme, renderer._game)
            end
        end
    end)
end
