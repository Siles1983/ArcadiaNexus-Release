-- Nether Bound cosmetic theme and reusable Idle preview through shared settings.
local A=ArcadiaNexus
local GS=A.GameSettings
local CFG={preview_w=150,preview_h=126,preview_ofs_x=0,preview_ofs_y=20,content_h=184,checkbox_y=154}
A.HGM_SettingsPanelCFG=CFG
local function Build(parent)
 local S=A.HGM_Settings; if not S then return end
 local L=A.GetLocaleTable('HANGMAN'); local preview
 local function Refresh()
  if preview then
   local choice=S:Get('petChoice'); preview:SetPet(choice=='random' and 'imp' or choice)
  end
  if A.HGM_Renderer and A.HGM_Renderer._loop then A.HGM_Renderer:_Animate() end
 end
 GS.Build(parent,{settings=S,locale=L,layout='standard',
  sound={single=true,masterLabel=L.sound_enabled},
  theme={dropdown={key='petChoice',label=L.pet_choice,options=A.HGM_Pets:GetOptions(),onChange=Refresh},
   build=function(content,width,settings,y,measure)
    if measure then return CFG.content_h end
    local label=content:CreateFontString(nil,'OVERLAY','GameFontNormalSmall'); label:SetPoint('TOPLEFT',0,-y-4); label:SetText(L.pet_preview)
    preview=A.HGM_PetScene.Create(content,CFG.preview_w,CFG.preview_h,'preview'); preview.holder:SetPoint('TOP',content,'TOP',CFG.preview_ofs_x,-y-CFG.preview_ofs_y)
    local cb=A.UI.CreateCheckbox(content,L.reduced_motion,0,y+CFG.checkbox_y)
    A.UI.BindCheckboxToDB(cb,settings,'reducedMotion',Refresh)
    GS.TrackCheckbox(content,cb,settings,'reducedMotion'); Refresh(); return CFG.content_h
   end,refresh=Refresh},
  guide={sections={GS.GuideSection(nil,L,{'guide_goal','guide_input','guide_error','guide_lose','guide_hint','pet_footer'})}}})
end
A.SettingsPanel=A.SettingsPanel or {}; A.SettingsPanel._builders=A.SettingsPanel._builders or {}; A.SettingsPanel._builders.HANGMAN=Build
