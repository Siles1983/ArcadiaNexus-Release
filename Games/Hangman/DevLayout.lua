-- Runtime-only layout diagnostics. No SavedVariables, runs, rewards or file writes.
local A=ArcadiaNexus
local R,E,S=A.HGM_Renderer,A.HGM_Engine,A.HGM_Settings
local D={}; A.HGM_DevLayout=D
local C=R.CFG
local function allowed() return A.IsDevMode and A.IsDevMode()==true end
local function de() return A.ActiveLocale=='deDE' end
local function tr(a,b) return de() and a or b end
local function message(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff88ee66Nether Bound:|r '..s) end end
local elements={
 {id='field',label='Spielfeld / Field',region='_fieldFrame',parent='_canvas'},
 {id='bg',label='Hintergrund / Background',region='_bg',parent='_fieldFrame'},
 {id='border',label='Rahmen / Border',region='_border',parent='_fieldFrame'},
 {id='logo',label='Logo',region='_logo',parent='_fieldFrame'},
 {id='keyboard',label='Tastatur / Keyboard',region='_keyboard',parent='_play',minW=100,minH=40},
 {id='modelscene',label='ModelScene',parent='_portalHolder'},
 {id='portal',label='Portal-Gruppe / Portal group',region='_portalHolder',parent='_play'},
 {id='portal_image',label='Portalbild / Portal image',region='_portal',parent='_portalHolder'},
 {id='portal_seal',label='Siegel / Seal',region='_seal',parent='_portalHolder'},
 {id='solution',label='Lösungsrahmen / Solution frame',region='_solution',parent='_play',minW=60,minH=40},
 {id='hints',label='Hinweise / Hints',region='_hints',parent='_play',minW=60,minH=110},
 {id='errors',label='Aktive Runen / Active runes',region='_errorText',parent='_play',minH=10,text=true},
 {id='solution_text',label='Lösungstext / Solution text',region='_solutionText',parent='_solution',minW=60,minH=40,text=true},
 {id='category_text',label='Kategorie / Category',region='_category',parent='_hints',minH=10,text=true},
 {id='hint_text',label='Hinweistext / Hint text',region='_hint',parent='_hints',minH=1,text=true},
 {id='wrong_text',label='Fehlbuchstaben / Wrong letters',region='_status',parent='_hints',minH=10,text=true},
 {id='feedback_text',label='Meldung / Feedback',region='_feedback',parent='_fieldFrame',minH=10,text=true},
}
local function region(e) return e.id=='modelscene' and R._pet.holder or R[e.region] end
local function copy(t) local out={}; for k,v in pairs(t) do out[k]=v end return out end
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function label(parent,text,x,y,w)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormalSmall'); f:SetSize(w or 320,24)
 f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); f:SetText(text); f:SetJustifyH('LEFT'); return f
end
local function window(name,w,h)
 local f=CreateFrame('Frame',name,UIParent); f:SetSize(w,h); f:SetPoint('CENTER',UIParent,'CENTER',0,0)
 f:SetFrameStrata('FULLSCREEN_DIALOG'); f:SetFrameLevel(200); f:SetClampedToScreen(true); f:EnableMouse(true)
 f:SetMovable(true); f:RegisterForDrag('LeftButton'); f:SetScript('OnDragStart',f.StartMoving); f:SetScript('OnDragStop',f.StopMovingOrSizing)
 local bg=f:CreateTexture(nil,'BACKGROUND'); bg:SetAllPoints(f); bg:SetColorTexture(.025,.035,.025,.97)
 f:Hide(); return f
end
local function button(parent,text,w,x,y,fn)
 local b=A.UI.CreateArcadiaButton(parent,text,w,24); b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); b:SetScript('OnClick',fn); return b
end
function D:IsEditable() return self.active and allowed() and E.state=='IDLE' and R.frame and R.frame:IsShown() end
function D:ExportText()
 if not self:IsEditable() then return nil end
 local keys={}; for k in pairs(C) do keys[#keys+1]=k end; table.sort(keys)
 local out={'-- Nether Bound: Games/Hangman/Renderer.lua', '-- Offsets: CENTER -> CENTER, relative to the respective parent.', 'local CFG={'}
 for _,k in ipairs(keys) do out[#out+1]=' '..k..'='..string.format('%.6f',C[k]):gsub('0+$',''):gsub('%.$','')..',' end
 out[#out+1]='}'
 return table.concat(out,'\n')
end
function D:Refresh()
 R:ApplyLayout(self.preview)
 R._logo:SetShown(self.selected and self.selected.id=='logo')
 R._seal:SetShown(self.selected and self.selected.id=='portal_seal')
 -- Preview the chosen pet fully; gameplay transparency is not a layout edit.
 R._pet:SetVisibility(1)
 R._feedback:SetText(self.selected and self.selected.id=='feedback_text' and tr('Meldung – Layoutvorschau','Feedback – layout preview') or '')
 for _,e in ipairs(elements) do
  local selected=e==self.selected; e.overlay:EnableMouse(selected); e.grip:SetShown(selected)
  e.overlay:SetShown(self.active and (not self.hideOtherFrames or selected))
  e.tint:SetColorTexture(selected and .3 or .1,selected and 1 or .65,.3,selected and .12 or .03)
  e.caption:SetText((selected and '> ' or '')..e.label)
  if e.text then e.caption:SetShown(selected) end
 end
 self.framesButton:SetLabel(self.hideOtherFrames and tr('Alle Rahmen zeigen','Show all frames') or tr('Rahmen ausblenden','Hide frames'))
 if self.selected then
  local id=self.selected.id
  self.selectionLabel:SetText(id..'  →  '..self.selected.parent)
  for key,box in pairs(self.inputs) do box:SetText(string.format('%.2f',C[id..key])) end
 end
end
function D:ToggleFrames()
 if not self:IsEditable() then return false end
 self.hideOtherFrames=not self.hideOtherFrames; self:Refresh(); return true
end
function D:Select(id)
 if not self:IsEditable() then return false end
 self.drag=nil
 for _,e in ipairs(elements) do if e.id==id then self.selected=e; self:Refresh(); return true end end
 return false
end
function D:SetGeometry(x,y,w,h)
 if not self:IsEditable() or not self.selected then return false end
 local e=self.selected; local id=e.id
 if not finite(x) or not finite(y) or not finite(w) or not finite(h)
  or math.abs(x)>4096 or math.abs(y)>4096 or w<(e.minW or 16) or h<(e.minH or 16) or w>4096 or h>4096 then return false end
 local sx,sy=w/C[id..'_w'],h/C[id..'_h']
 if id=='keyboard' then
  for _,k in ipairs({'keyboard_key_w','keyboard_col_step'}) do C[k]=C[k]*sx end
  for _,k in ipairs({'keyboard_key_h','keyboard_row_step'}) do C[k]=C[k]*sy end
 elseif id=='portal' then
  -- Resizing the group scales its contents; child selection edits them independently.
  for _,p in ipairs({'modelscene','portal_image','portal_seal'}) do
   for _,suffix in ipairs({'_w','_ofs_x'}) do C[p..suffix]=C[p..suffix]*sx end
   for _,suffix in ipairs({'_h','_ofs_y'}) do C[p..suffix]=C[p..suffix]*sy end
  end
  C.rune_radius=C.rune_radius*math.min(sx,sy); C.rune_size=C.rune_size*math.min(sx,sy); C.rune_ofs_y=C.rune_ofs_y*sy
 end
 C[id..'_ofs_x'],C[id..'_ofs_y'],C[id..'_w'],C[id..'_h']=x,y,w,h
 self:Refresh(); return true
end
function D:BeginDrag(resize)
 if not self:IsEditable() then return end
 local e=self.selected; local x,y=GetCursorPosition(); local id=e.id
 self.drag={resize=resize,cursorX=x,cursorY=y,x=C[id..'_ofs_x'],y=C[id..'_ofs_y'],w=C[id..'_w'],h=C[id..'_h'],scale=R[e.parent]:GetEffectiveScale()}
end
function D:Tick(released)
 if not self:IsEditable() then self:Disable(); return end
 local d=self.drag; if not d then return end
 if not released and IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self.drag=nil; return end
 local x,y=GetCursorPosition(); local dx,dy=(x-d.cursorX)/d.scale,(y-d.cursorY)/d.scale
 if d.resize then
  -- Top-left stays fixed while dragging the bottom-right grip.
  local e=self.selected; local w=math.max(e.minW or 16,math.min(4096,d.w+dx)); local h=math.max(e.minH or 16,math.min(4096,d.h-dy))
  self:SetGeometry(d.x+(w-d.w)/2,d.y-(h-d.h)/2,w,h)
 else self:SetGeometry(d.x+dx,d.y+dy,d.w,d.h) end
end
function D:Reset()
 if not self:IsEditable() then return false end
 self.drag=nil; for k,v in pairs(self.baseline) do C[k]=v end; self:Refresh(); return true
end
-- Model edits share the game profile, but never change saved pet selection.
local modelFields={
 {'model_x',0},{'model_y',0},{'model_z',0},{'model_scale',1},
 {'yaw',math.pi/2},{'fit_height',1.65},{'camera_x',0},{'camera_y',4},
 {'camera_z',1},{'fov',.7},{'near_clip',.01},{'far_clip',80},
 {'camera_yaw'},{'camera_pitch'},{'camera_roll'},
}
local function clone(t)
 local out={}; for k,v in pairs(t) do out[k]=type(v)=='table' and clone(v) or v end; return out
end
local function numberText(n) return string.format('%.17g',n) end
local function serialize(v,depth)
 if type(v)=='number' then return numberText(v) end
 if type(v)=='boolean' then return tostring(v) end
 if type(v)=='string' then return string.format('%q',v) end
 local keys={}; for k in pairs(v) do keys[#keys+1]=k end; table.sort(keys)
 local out={'{'}
 for _,k in ipairs(keys) do out[#out+1]=string.rep(' ',depth+1)..'['..string.format('%q',k)..']='..serialize(v[k],depth+1)..',' end
 out[#out+1]=string.rep(' ',depth)..'}'; return table.concat(out,'\n')
end
function D:ModelExportText()
 if not self:IsEditable() then return nil end
 return '-- Nether Bound: replace Games/Hangman/PetCameras.lua\nlocal A=ArcadiaNexus\nA.HGM_PetCameras='..serialize(A.HGM_PetCameras,0)..'\n'
end
function D:RefreshModel()
 if not self.modelPanel then return end
 local pet=A.HGM_Pets:Get(self.preview.petId); local p=A.HGM_PetCameras[pet.id]
 self.modelLabel:SetText((de() and pet.de or pet.en)..'  ('..pet.id..')')
 for _,field in ipairs(modelFields) do
  local value=p[field[1]]; if value==nil then value=field[2] end
  self.modelInputs[field[1]]:SetText(value~=nil and numberText(value) or '')
 end
 self.autoFitButton:SetLabel('Auto-Fit: '..(p.auto_fit~=false and tr('Ein','On') or tr('Aus','Off')))
end
function D:SelectPet(id)
 if not self:IsEditable() or not A.HGM_Pets:Get(id) then return false end
 self.preview.petId=id; R._pet:SetPet(id); R._pet:SetVisibility(1); self:RefreshModel(); return true
end
function D:SetModelValues(values)
 if not self:IsEditable() then return false end
 local p=A.HGM_PetCameras[self.preview.petId]; local nextProfile=clone(p)
 for _,field in ipairs(modelFields) do
  local key=field[1]; local value=values[key]
  if value=='' and field[2]==nil then nextProfile[key]=nil
  else
   value=tonumber(value)
   if not finite(value) or math.abs(value)>4096 then return false end
   if (key=='model_scale' or key=='fit_height' or key=='near_clip' or key=='far_clip') and value<=0 then return false end
   if key=='fov' and (value<=0 or value>=math.pi) then return false end
   nextProfile[key]=value
  end
 end
 if nextProfile.far_clip<=nextProfile.near_clip then return false end
 for _,field in ipairs(modelFields) do p[field[1]]=nextProfile[field[1]] end
 R._pet:Fit(); R._pet:SetVisibility(1); self:RefreshModel(); return true
end
function D:SetAutoFit(enabled)
 if not self:IsEditable() or type(enabled)~='boolean' then return false end
 A.HGM_PetCameras[self.preview.petId].auto_fit=enabled
 R._pet:Fit(); self:RefreshModel(); return true
end
function D:ResetModel()
 if not self:IsEditable() then return false end
 local id=self.preview.petId; local p=A.HGM_PetCameras[id]
 for k in pairs(p) do p[k]=nil end
 for k,v in pairs(clone(self.modelBaseline[id])) do p[k]=v end
 R._pet:Fit(); self:RefreshModel(); return true
end
function D:ShowModelEditor()
 if not self:IsEditable() then return false end
 if not self.modelPanel then
  local f=window('ArcadiaNexus_HGM_ModelEditor',500,620); self.modelPanel=f
  f:ClearAllPoints(); f:SetPoint('RIGHT',UIParent,'RIGHT',-24,0)
  label(f,tr('Nether Bound — Modelle / Kamera','Nether Bound — Models / Camera'),14,-8,440)
  button(f,'X',28,458,-8,function() f:Hide() end)
  self.modelLabel=label(f,'',60,-42,380)
  local function cycle(delta)
   local list=A.HGM_Pets:GetList()
   for i,pet in ipairs(list) do if pet.id==self.preview.petId then self:SelectPet(list[(i-1+delta)%#list+1].id); return end end
  end
  button(f,'<',32,14,-42,function() cycle(-1) end); button(f,'>',32,452,-42,function() cycle(1) end)
  label(f,tr('Modellkoordinaten; Winkel in Radiant. Enter übernimmt alle Felder.','Model coordinates; angles in radians. Enter applies all fields.'),14,-72,472)
  self.modelInputs={}
  local function apply()
   local values={}; for k,box in pairs(self.modelInputs) do values[k]=box:GetText() end
   if not self:SetModelValues(values) then message(tr('Ungültige Modellwerte: Zahlen ±4096; Größen/Clips > 0; Nah < Fern; 0 < FOV < π.','Invalid model values: numbers ±4096; scales/clips > 0; near < far; 0 < FOV < pi.')) end
  end
  for i,field in ipairs(modelFields) do
   local x=14+((i-1)%2)*242; local y=-106-math.floor((i-1)/2)*48
   label(f,field[1],x,y,228)
   local box=CreateFrame('EditBox',nil,f,'InputBoxTemplate'); box:SetSize(216,22); box:SetPoint('TOPLEFT',f,'TOPLEFT',x+4,y-23)
   box:SetAutoFocus(false); box:SetMaxLetters(24); self.modelInputs[field[1]]=box
   box:SetScript('OnEnterPressed',function(b) apply(); b:ClearFocus() end)
   box:SetScript('OnEscapePressed',function(b) b:ClearFocus(); self:RefreshModel() end)
  end
  self.autoFitButton=button(f,'',216,256,-465,function() self:SetAutoFit(A.HGM_PetCameras[self.preview.petId].auto_fit==false) end)
  label(f,tr('camera_yaw leer: frontale Standardkamera.','Empty camera_yaw: default frontal camera.'),14,-500,472)
  label(f,tr('Auto-Fit Ein: Position = berechnete Zentrierung + Offset.','Auto-Fit On: position = computed centering + offset.'),14,-524,472)
  button(f,tr('Übernehmen','Apply'),144,14,-560,apply)
  button(f,'Pet Export',144,176,-560,function() self:ShowExport(true) end)
  button(f,tr('Pet zurücksetzen','Reset pet'),144,338,-560,function() self:ResetModel() end)
  f:SetScript('OnHide',function() for _,box in pairs(self.modelInputs) do box:ClearFocus() end end)
 end
 self:RefreshModel(); self.modelPanel:Show(); return true
end
function D:ShowExport(models)
 local text=models and self:ModelExportText() or self:ExportText(); if not text then return false end
 if not self.exportFrame then
  local f=window('ArcadiaNexus_HGM_LayoutExport',560,480); self.exportFrame=f
  self.exportTitle=label(f,'',14,-8,430)
  self.exportHelp=label(f,'',14,-35,530)
  button(f,'X',28,516,-8,function() f:Hide() end)
  local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',f,'TOPLEFT',14,-68); scroll:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-34,14)
  local edit=CreateFrame('EditBox',nil,scroll); self.exportEdit=edit
  edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject('GameFontHighlightSmall'); edit:SetWidth(500)
  edit:SetScript('OnEscapePressed',function(b) b:ClearFocus() end)
  edit:SetScript('OnTextChanged',function(b) local _,lines=b:GetText():gsub('\n',''); b:SetHeight(math.max(380,(lines+1)*14+20)) end)
  f:SetScript('OnHide',function() edit:ClearFocus() end)
  scroll:SetScrollChild(edit)
 end
 self.exportTitle:SetText(models and 'Nether Bound — Pet Export' or 'Nether Bound — CFG Export')
 self.exportHelp:SetText(models and tr('Strg+A, Strg+C; PetCameras.lua vollständig ersetzen.','Ctrl+A, Ctrl+C; replace all of PetCameras.lua.') or tr('Strg+A, Strg+C; CFG-Block in Renderer.lua ersetzen.','Ctrl+A, Ctrl+C; replace the CFG block in Renderer.lua.'))
 self.exportFrame:Show(); self.exportEdit:SetText(text); self.exportEdit:SetFocus(); self.exportEdit:HighlightText(); return true
end
function D:Build()
 if self.panel then return end
 local f=window('ArcadiaNexus_HGM_LayoutEditor',360,574); self.panel=f
 f:ClearAllPoints(); f:SetPoint('LEFT',UIParent,'LEFT',24,0)
 label(f,'Nether Bound — Dev Layout',14,-8)
 label(f,tr('Auswahl → ziehen; Ecke rechts unten → Größe.','Select → drag; bottom-right corner → resize.'),14,-34)
 local list=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate'); self.elementList=list
 list:SetPoint('TOPLEFT',f,'TOPLEFT',14,-64); list:SetSize(306,306)
 local content=CreateFrame('Frame',nil,list); content:SetSize(306,#elements*26); list:SetScrollChild(content)
 for i,e in ipairs(elements) do
  button(content,e.label,306,0,-(i-1)*26,function() self:Select(e.id) end)
  local overlay=CreateFrame('Frame',nil,R._canvas); e.overlay=overlay; overlay:SetAllPoints(region(e))
  overlay:SetFrameStrata('DIALOG'); overlay:SetFrameLevel(100+i); overlay:EnableMouse(false)
  local tint=overlay:CreateTexture(nil,'BACKGROUND'); tint:SetAllPoints(overlay); e.tint=tint
  for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
   local line=overlay:CreateTexture(nil,'OVERLAY'); line:SetColorTexture(.2,1,.3,.8)
   if side=='TOP' or side=='BOTTOM' then line:SetHeight(1); line:SetPoint(side..'LEFT',overlay,side..'LEFT'); line:SetPoint(side..'RIGHT',overlay,side..'RIGHT')
   else line:SetWidth(1); line:SetPoint('TOP'..side,overlay,'TOP'..side); line:SetPoint('BOTTOM'..side,overlay,'BOTTOM'..side) end
  end
  e.caption=label(overlay,e.label,2,e.text and 24 or -2,220)
  overlay:SetScript('OnMouseDown',function(_,b) if b=='LeftButton' then self:BeginDrag(false) end end)
  overlay:SetScript('OnMouseUp',function() self:Tick(true); self.drag=nil end)
  local grip=CreateFrame('Button',nil,overlay); e.grip=grip; grip:SetSize(18,18); grip:SetPoint('BOTTOMRIGHT',overlay,'BOTTOMRIGHT',0,0)
  local t=grip:CreateTexture(nil,'OVERLAY'); t:SetAllPoints(grip); t:SetColorTexture(.3,1,.3,.8)
  grip:SetScript('OnMouseDown',function(_,b) if b=='LeftButton' then self:BeginDrag(true) end end)
  grip:SetScript('OnMouseUp',function() self:Tick(true); self.drag=nil end)
  overlay:Hide()
 end
 self.selectionLabel=label(f,'',14,-379)
 self.inputs={}
 for i,key in ipairs({'_ofs_x','_ofs_y','_w','_h'}) do
  local x=14+(i-1)*84; label(f,({'X','Y','W','H'})[i],x,-405,75)
  local box=CreateFrame('EditBox',nil,f,'InputBoxTemplate'); box:SetSize(72,24); box:SetPoint('TOPLEFT',f,'TOPLEFT',x+4,-429)
  box:SetAutoFocus(false); box:SetMaxLetters(16); box:SetScript('OnEscapePressed',function(b) b:ClearFocus(); self:Refresh() end); self.inputs[key]=box
 end
 local function apply()
  local t=self.inputs
  if not self:SetGeometry(tonumber(t._ofs_x:GetText()),tonumber(t._ofs_y:GetText()),tonumber(t._w:GetText()),tonumber(t._h:GetText())) then
   message(tr('Ungültige Werte: Position ±4096; Größe 16–4096 (HUD-Mindestmaße beachten).','Invalid values: position ±4096; size 16–4096 (HUD minimum sizes apply).'))
  end
 end
 for _,box in pairs(self.inputs) do box:SetScript('OnEnterPressed',function(b) apply(); b:ClearFocus() end) end
 button(f,tr('Übernehmen','Apply'),104,14,-466,apply)
 button(f,'CFG Export',104,128,-466,function() self:ShowExport() end)
 button(f,tr('Zurücksetzen','Reset'),104,242,-466,function() self:Reset() end)
 button(f,tr('Modelle / Kamera','Models / Camera'),158,14,-502,function() self:ShowModelEditor() end)
 button(f,'Pet Export',158,184,-502,function() self:ShowExport(true) end)
 self.framesButton=button(f,'',158,14,-534,function() self:ToggleFrames() end)
 button(f,tr('Schließen','Close'),158,184,-534,function() self:Disable() end)
 f:SetScript('OnHide',function() self:Disable() end)
 self.loop=A.GameLoop.Create('ArcadiaNexus_HGM_LayoutLoop',UIParent)
end
function D:Enable()
 if not allowed() then message(tr('DevMode muss aktiviert sein.','Enable DevMode first.')); return false end
 if self.active then return true end
 if not R.frame or not R.frame:IsShown() then message(tr('Öffne zuerst Nether Bound im Spiele-Tab.','Open Nether Bound in the games tab first.')); return false end
 if E.state~='IDLE' then message(tr('Beende zuerst die aktuelle Runde.','Finish or exit the current round first.')); return false end
 local item=A.HGM_Words:GetEntries(S:Get('category'),S:Get('difficulty'))[1]
 local entry=item and A.HGM_Words:ResolveId(item.id); if not entry then return false end
 local board=A.HGM_Logic:NewBoard(entry,A.HGM_Logic.ERRORS[S:Get('difficulty')]); board.difficulty=S:Get('difficulty')
 board.errors=2; for i=1,#board.word do board.revealed[i]=true end
 for letter in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):gmatch('.') do
  if not board.word:find(letter,1,true) and #board.guesses<board.errors then board.guessed[letter]=true; board.guesses[#board.guesses+1]=letter end
 end
 local pet=S:Get('petChoice'); board.petId=A.HGM_Pets:Get(pet) and pet or 'imp'
 self.preview=board; self.baseline=self.baseline or copy(C); self.modelBaseline=self.modelBaseline or clone(A.HGM_PetCameras); self:Build()
 self.active=true; E._layoutEditing=true; self.selected=self.selected or elements[5]
 R:ShowPlaying(board); self:Refresh()
 self.panel:Show(); self.loop:Start(function() self:Tick() end); return true
end
function D:Disable()
 if not self.active then return end
 self.active=false; E._layoutEditing=nil; self.drag=nil; self.preview=nil; self.loop:Stop()
 for _,box in pairs(self.inputs) do box:ClearFocus() end
 if self.modelPanel then
  self.modelPanel:StopMovingOrSizing(); self.modelPanel:Hide()
  for _,box in pairs(self.modelInputs) do box:ClearFocus() end
 end
 self.panel:StopMovingOrSizing()
 for _,e in ipairs(elements) do e.overlay:Hide() end
 self.panel:Hide(); if self.exportFrame then self.exportFrame:Hide(); self.exportEdit:ClearFocus() end
 R:EnterIdleState()
end
function D:Toggle() if self.active then self:Disable() else return self:Enable() end end
SLASH_ARCADIANETHERLAYOUT1='/anlayout'
SlashCmdList.ARCADIANETHERLAYOUT=function() D:Toggle() end
if A.RegisterDevTool then A.RegisterDevTool({id='nether_bound_layout',label='Nether Bound: Layout',order=80,
 hint='DevMode: Layout und Pet-Kamera abstimmen; CFG und Pet-Profile exportieren.',
 isAvailable=function() return allowed() end,Toggle=function() D:Toggle() end}) end
