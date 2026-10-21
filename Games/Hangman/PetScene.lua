-- Reusable Idle-only ModelScene, shared by the game and its settings preview.
local A=ArcadiaNexus
local M={}; A.HGM_PetScene=M
local function Call(obj,name,...)
 if obj and obj[name] then return pcall(obj[name],obj,...) end
 return false
end
function M.Create(parent,width,height,context)
 local holder=CreateFrame('Frame',nil,parent); holder:SetSize(width,height)
 local fallback=holder:CreateTexture(nil,'ARTWORK'); fallback:SetSize(40,40); fallback:SetPoint('CENTER')
 fallback:SetTexture('Interface\\Icons\\Spell_Shadow_SummonVoidWalker')
 local scene
 for _,template in ipairs({'NonInteractableModelSceneMixinTemplate','ModelSceneMixinTemplate',false}) do
  local ok,f=pcall(CreateFrame,'ModelScene',nil,holder,template or nil)
  if ok and f and f.CreateActor then scene=f; break end
 end
 local actor
 if scene then
  scene:SetAllPoints(holder); scene:EnableMouse(false)
  M._nextActor=(M._nextActor or 0)+1
  local actorName='ArcadiaNexus_NetherBoundPet_'..M._nextActor
  local ok,a=pcall(scene.CreateActor,scene,actorName,'ModelSceneActorTemplate')
  if ok then actor=a end
  if not actor then ok,a=pcall(scene.CreateActor,scene,actorName); if ok then actor=a end end
  Call(scene,'SetLightVisible',true); Call(scene,'SetLightAmbientColor',.6,.65,.55)
  Call(scene,'SetLightDiffuseColor',1,1,1); Call(scene,'SetLightDirection',.4,-.7,-1)
  Call(scene,'SetCameraNearClip',.01); Call(scene,'SetCameraFarClip',80); Call(scene,'SetCameraFieldOfView',.7)
  Call(scene,'SetCameraPosition',0,4,1)
  Call(scene,'SetCameraOrientationByAxisVectors',0,-1,0,1,0,0,0,0,1)
 end
 local view={holder=holder,scene=scene,actor=actor,fallback=fallback,revision=0,context=context or 'game',visibility=1}
 function view:GetProfile()
  local profile=A.HGM_PetCameras and A.HGM_PetCameras[self.petId] or {}
  if self.context=='preview' and profile.preview then return setmetatable({}, {__index=function(_,k)
   if profile.preview[k]~=nil then return profile.preview[k] end; return profile[k]
  end}) end
  return profile
 end
 function view:SetVisibility(alpha)
  self.visibility=math.max(0,math.min(1,tonumber(alpha) or 1))
  Call(self.actor,'SetAlpha',self.visibility); self.fallback:SetAlpha(self.visibility)
 end
 function view:Fit()
  local a=self.actor; if not a or not self.holder:IsShown() then return end
  local p=self:GetProfile()
  Call(scene,'SetCameraNearClip',p.near_clip or .01); Call(scene,'SetCameraFarClip',p.far_clip or 80)
  Call(scene,'SetCameraFieldOfView',p.fov or .7)
  Call(scene,'SetCameraPosition',p.camera_x or 0,p.camera_y or 4,p.camera_z or 1)
  if p.camera_yaw~=nil then
   Call(scene,'SetCameraOrientationByYawPitchRoll',p.camera_yaw,p.camera_pitch or 0,p.camera_roll or 0)
  else Call(scene,'SetCameraOrientationByAxisVectors',0,-1,0,1,0,0,0,0,1) end
  Call(a,'SetAnimation',0,0,1,0); Call(a,'SetYaw',p.yaw or math.pi/2)
  -- Normalize the previous pet's scale before measuring native bounds.
  if p.auto_fit~=false then Call(a,'SetScale',1) end
  local ok,x,y,z,X,Y,Z=Call(a,'GetActiveBoundingBox')
  if ok and (type(x)=='table' or type(x)=='userdata') and (type(y)=='table' or type(y)=='userdata') then
   local lo,hi=x,y
   if lo.GetXYZ and hi.GetXYZ then x,y,z=lo:GetXYZ(); X,Y,Z=hi:GetXYZ() else x,y,z,X,Y,Z=lo.x,lo.y,lo.z,hi.x,hi.y,hi.z end
  end
  local scale,cx,cy,cz=p.model_scale or 1,0,0,0
  if p.auto_fit~=false then
   if ok and type(z)=='number' and type(Z)=='number' and Z>z and type(x)=='number' and type(X)=='number'
    and type(y)=='number' and type(Y)=='number' then
    local aspect=self.holder:GetHeight()/math.max(1,self.holder:GetWidth())
    local span=math.max(Z-z,(X-x)*aspect,(Y-y)*aspect,.1)
    scale=scale*(p.fit_height or 1.65)/span; cx=-(x+X)*.5*scale; cy=-(y+Y)*.5*scale; cz=-z*scale+.12
   else scale=scale*.6 end
  end
  Call(a,'SetScale',scale); Call(a,'SetPosition',cx+(p.model_x or 0),cy+(p.model_y or 0),cz+(p.model_z or 0))
  self:SetVisibility(self.visibility)
  if Call(a,'GetModelFileID') then
   local _,id=Call(a,'GetModelFileID'); if type(id)=='number' and id>0 then self.fallback:Hide() end
  end
 end
 function view:SetPet(id)
  local pet=A.HGM_Pets:Get(id); if not pet then pet=A.HGM_Pets:Get('imp') end
  self.petId=pet.id; self.revision=self.revision+1; self.fallback:Show()
  local rev=self.revision
  if self.actor then
   Call(self.actor,'ClearModel')
   Call(self.actor,'SetScript','OnModelLoaded',function()
    if self.revision==rev and self.holder:IsShown() then self:Fit() end
   end)
   local ok,loaded=Call(self.actor,'SetModelByCreatureDisplayID',pet.displayID)
   if ok and loaded~=false then self:Fit() end
  end
 end
 holder:SetScript('OnHide',function()
  view.revision=view.revision+1; Call(scene,'SetPaused',true,false); Call(actor,'SetScript','OnModelLoaded',nil)
 end)
 holder:SetScript('OnShow',function()
  Call(scene,'SetPaused',false,false); if view.petId then view:SetPet(view.petId) end
 end)
 return view
end
