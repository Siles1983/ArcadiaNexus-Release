-- Nether Bound: direct rounds, native runes and configurable presentation.
local A=ArcadiaNexus
local R={state='IDLE'}; A.HGM_Renderer=R
local E,S=A.HGM_Engine,A.HGM_Settings
local UI=A.UI
local function T() return A.GetLocaleTable('HANGMAN') end
local PATH='Interface\\AddOns\\ArcadiaNexus\\Games\\Hangman\\assets\\nether_bound\\'
-- Nether Bound: Games/Hangman/Renderer.lua
-- Offsets: CENTER -> CENTER, relative to the respective parent.
local CFG={
 bg_alpha=1,
 bg_h=520,
 bg_ofs_x=0,
 bg_ofs_y=0,
 bg_w=700,
 border_alpha=1,
 border_h=550,
 border_ofs_x=0,
 border_ofs_y=7,
 border_w=800,
 category_text_h=32,
 category_text_ofs_x=0,
 category_text_ofs_y=110,
 category_text_w=454,
 errors_h=20,
 errors_ofs_x=0,
 errors_ofs_y=-130,
 errors_w=220,
 feedback_text_h=24,
 feedback_text_ofs_x=0,
 feedback_text_ofs_y=-204,
 feedback_text_w=470,
 field_h=550,
 field_ofs_x=0,
 field_ofs_y=10,
 field_w=750,
 hint_text_h=30.3,
 hint_text_ofs_x=0,
 hint_text_ofs_y=5,
 hint_text_w=454,
 hints_alpha=1,
 hints_h=129.3,
 hints_ofs_x=0,
 hints_ofs_y=125,
 hints_w=476,
 keyboard_alpha=1,
 keyboard_col_step=31,
 keyboard_h=85,
 keyboard_key_h=27,
 keyboard_key_w=28,
 keyboard_ofs_x=0,
 keyboard_ofs_y=-183,
 keyboard_row_step=29,
 keyboard_w=307,
 logo_alpha=1,
 logo_h=280,
 logo_ofs_x=0,
 logo_ofs_y=0,
 logo_w=280,
 modelscene_alpha_end=1,
 modelscene_alpha_start=0.15,
 modelscene_h=128,
 modelscene_ofs_x=0,
 modelscene_ofs_y=5,
 modelscene_w=106,
 portal_alpha=1,
 portal_h=210,
 portal_image_h=188,
 portal_image_ofs_x=0,
 portal_image_ofs_y=5,
 portal_image_w=188,
 portal_ofs_x=0,
 portal_ofs_y=-23.46,
 portal_seal_h=132,
 portal_seal_ofs_x=0,
 portal_seal_ofs_y=5,
 portal_seal_w=132,
 portal_w=210,
 rune_ofs_y=5,
 rune_radius=92,
 rune_size=25,
 solution_alpha=1,
 solution_col_step=18,
 solution_h=84,
 solution_letter_h=26,
 solution_letter_w=17,
 solution_ofs_x=0,
 solution_ofs_y=200,
 solution_row_step=30,
 solution_text_h=84,
 solution_text_ofs_x=0,
 solution_text_ofs_y=-15,
 solution_text_w=476,
 solution_w=476,
 wrong_text_h=28,
 wrong_text_ofs_x=0,
 wrong_text_ofs_y=-20,
 wrong_text_w=454,
}
-- Text defaults inherit the current, manually tuned HUD geometry. Exports include
-- these keys; explicit values in CFG take precedence on subsequent reloads.
local textDefaults={
 solution_text_w=CFG.solution_w,solution_text_h=CFG.solution_h,solution_text_ofs_x=0,solution_text_ofs_y=0,
 category_text_w=CFG.hints_w-22,category_text_h=32,category_text_ofs_x=0,category_text_ofs_y=CFG.hints_h/2-26,
 hint_text_w=CFG.hints_w-22,hint_text_h=math.max(1,CFG.hints_h-99),hint_text_ofs_x=0,hint_text_ofs_y=5,
 wrong_text_w=CFG.hints_w-22,wrong_text_h=28,wrong_text_ofs_x=0,wrong_text_ofs_y=-CFG.hints_h/2+26,
 feedback_text_w=470,feedback_text_h=24,feedback_text_ofs_x=0,feedback_text_ofs_y=-204,
}
for k,v in pairs(textDefaults) do if CFG[k]==nil then CFG[k]=v end end
R.CFG=CFG
local function Texture(parent,path,w,h,x,y,layer)
 local t=parent:CreateTexture(nil,layer or 'BACKGROUND'); t:SetTexture(PATH..path); t:SetSize(w,h); t:SetPoint('CENTER',parent,'CENTER',x or 0,y or 0); return t
end
local function Label(parent,text,w,h,x,y,font)
 local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormal'); f:SetSize(w,h); f:SetPoint('CENTER',parent,'CENTER',x,y)
 f:SetText(text or ''); f:SetTextColor(.88,.94,.85); return f
end
function R:Init()
 if self.frame then return end
 local panel=_G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel and _G.ArcadiaNexusUI.GetGamesPanel(); if not panel then return end
 local vp=UI.CreateGameViewport(panel,{outerName='ArcadiaNexus_HGM_Container',designW=600,designH=498})
 self.frame=vp.outer; self._canvas=vp.canvas; A._hangmanContainer=self.frame; self.frame:Hide()
 local field=CreateFrame('Frame',nil,self._canvas); field:SetSize(CFG.field_w,CFG.field_h)
 field:SetPoint('CENTER',self._canvas,'CENTER',CFG.field_ofs_x,CFG.field_ofs_y); self._fieldFrame=field
 self._bg=Texture(field,'bg_a_v1',CFG.bg_w,CFG.bg_h,CFG.bg_ofs_x,CFG.bg_ofs_y); self._bg:SetAlpha(CFG.bg_alpha)
 self._border=Texture(field,'border_a_v1',CFG.border_w,CFG.border_h,CFG.border_ofs_x,CFG.border_ofs_y,'BORDER'); self._border:SetAlpha(CFG.border_alpha)
 self._logo=Texture(field,'logo_a_v1',CFG.logo_w,CFG.logo_h,CFG.logo_ofs_x,CFG.logo_ofs_y,'ARTWORK'); self._logo:SetAlpha(CFG.logo_alpha)
 local play=CreateFrame('Frame',nil,field); play:SetAllPoints(field); self._play=play
 local solution=CreateFrame('Frame',nil,play); self._solution=solution
 solution:SetSize(CFG.solution_w,CFG.solution_h); solution:SetPoint('CENTER',play,'CENTER',CFG.solution_ofs_x,CFG.solution_ofs_y); solution:SetAlpha(CFG.solution_alpha)
 self._solutionBG=Texture(solution,'hud_a_v1',CFG.solution_w,CFG.solution_h,0,0)
 self._solutionText=CreateFrame('Frame',nil,solution)
 self._solutionText:SetSize(CFG.solution_text_w,CFG.solution_text_h)
 self._solutionText:SetPoint('CENTER',solution,'CENTER',CFG.solution_text_ofs_x,CFG.solution_text_ofs_y)
 self._letters={}
 -- Preallocate the catalog's maximum. Rendering never creates additional frames.
 local max=0; for _,locale in ipairs({'deDE','enUS'}) do for _,id in ipairs(A.HGM_Words:GetIds()) do max=math.max(max,#A.HGM_Words:GetLocalizedWord(id,locale)) end end
 for i=1,max do
  local slot=CreateFrame('Frame',nil,self._solutionText); slot:SetSize(CFG.solution_letter_w,CFG.solution_letter_h)
  slot.text=Label(slot,'',CFG.solution_letter_w,CFG.solution_letter_h-3,0,1,'GameFontNormalLarge')
  slot.line=slot:CreateTexture(nil,'BACKGROUND'); slot.line:SetColorTexture(.48,.65,.38,.9); slot.line:SetSize(CFG.solution_letter_w-2,2); slot.line:SetPoint('BOTTOM',0,0)
  self._letters[i]=slot
 end
 self._portalHolder=CreateFrame('Frame',nil,play); self._portalHolder:SetSize(CFG.portal_w,CFG.portal_h); self._portalHolder:SetPoint('CENTER',play,'CENTER',CFG.portal_ofs_x,CFG.portal_ofs_y); self._portalHolder:SetAlpha(CFG.portal_alpha)
 self._portal=Texture(self._portalHolder,'portal_a_v1',CFG.portal_image_w,CFG.portal_image_h,CFG.portal_image_ofs_x,CFG.portal_image_ofs_y,'ARTWORK')
 self._pet=A.HGM_PetScene.Create(self._portalHolder,CFG.modelscene_w,CFG.modelscene_h,'game'); self._pet.holder:SetPoint('CENTER',self._portalHolder,'CENTER',CFG.modelscene_ofs_x,CFG.modelscene_ofs_y)
 -- A texture on the portal parent cannot cover a child ModelScene reliably.
 self._sealLayer=CreateFrame('Frame',nil,self._portalHolder); self._sealLayer:SetAllPoints(self._portalHolder)
 self._sealLayer:SetFrameLevel(self._pet.scene and self._pet.scene:GetFrameLevel()+1 or self._pet.holder:GetFrameLevel()+2)
 self._seal=Texture(self._sealLayer,'seal_a_v1',CFG.portal_seal_w,CFG.portal_seal_h,CFG.portal_seal_ofs_x,CFG.portal_seal_ofs_y,'OVERLAY'); self._seal:Hide()
 self._runes={}
 for i=1,8 do
  local f=CreateFrame('Frame',nil,self._portalHolder); f:SetSize(CFG.rune_size,CFG.rune_size)
  f.tex=f:CreateTexture(nil,'OVERLAY'); f.tex:SetAllPoints(f)
  f.marker=Label(f,'',CFG.rune_size,14,0,-CFG.rune_size*.64,'GameFontNormalSmall'); self._runes[i]=f
 end
 self._errorText=Label(play,'',CFG.errors_w,CFG.errors_h,CFG.errors_ofs_x,CFG.errors_ofs_y,'GameFontNormalSmall')
 local hints=CreateFrame('Frame',nil,play); self._hints=hints
 hints:SetSize(CFG.hints_w,CFG.hints_h); hints:SetPoint('CENTER',play,'CENTER',CFG.hints_ofs_x,CFG.hints_ofs_y); hints:SetAlpha(CFG.hints_alpha)
 self._hintsBG=Texture(hints,'hud_a_v1',CFG.hints_w,CFG.hints_h,0,0)
 self._category=Label(hints,'',CFG.category_text_w,CFG.category_text_h,CFG.category_text_ofs_x,CFG.category_text_ofs_y,'GameFontNormalSmall')
 self._hint=Label(hints,'',CFG.hint_text_w,CFG.hint_text_h,CFG.hint_text_ofs_x,CFG.hint_text_ofs_y,'GameFontNormal'); self._hint:SetJustifyV('TOP')
 self._status=Label(hints,'',CFG.wrong_text_w,CFG.wrong_text_h,CFG.wrong_text_ofs_x,CFG.wrong_text_ofs_y,'GameFontNormalSmall')
 self._keyboard=CreateFrame('Frame',nil,play); self._keyboard:SetSize(CFG.keyboard_w,CFG.keyboard_h)
 self._keyboard:SetPoint('CENTER',play,'CENTER',CFG.keyboard_ofs_x,CFG.keyboard_ofs_y); self._keyboard:SetAlpha(CFG.keyboard_alpha)
 self._keys={}
 for letter in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):gmatch('.') do
  local key=letter; local btn=UI.CreateArcadiaButton(self._keyboard,key,CFG.keyboard_key_w,CFG.keyboard_key_h)
  btn:SetScript('OnClick',function() E:GuessLetter(key) end); self._keys[key]=btn
 end
 self:_LayoutKeyboard()
 self._feedback=Label(field,'',CFG.feedback_text_w,CFG.feedback_text_h,CFG.feedback_text_ofs_x,CFG.feedback_text_ofs_y,'GameFontNormalSmall')
 self._loop=A.GameLoop.Create('ArcadiaNexus_HGM_PortalLoop',self.frame)
 self._resultLoop=A.GameLoop.Create('ArcadiaNexus_HGM_SealLoop',self.frame)
 self:_CreateControls()
 self.frame:EnableKeyboard(true)
 self.frame:SetScript('OnKeyDown',function(f,key)
  local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  local owns=E.state=='PLAYING' and self.frame:IsShown() and A.GameSession:IsSession(E,E._sessionId)
  if focus or not owns then f:SetPropagateKeyboardInput(true); return end
  if key=='ESCAPE' then f:SetPropagateKeyboardInput(false); E:StopGame()
  elseif type(key)=='string' and key:match('^[a-zA-Z]$') then f:SetPropagateKeyboardInput(false); E:GuessLetter(key)
  else f:SetPropagateKeyboardInput(true) end
 end)
 self.frame:SetPropagateKeyboardInput(true)
 self.frame:SetScript('OnHide',function()
  if A.HGM_DevLayout then A.HGM_DevLayout:Disable() end
  self:_StopVisual(); A.GameSession:HandleRendererHide('HANGMAN',E,function(engine) engine:SaveAndPause() end)
 end)
 self:EnterIdleState()
end
-- Client locale determines key positions; addon text language does not.
function R:_LayoutKeyboard()
 local locale=GetLocale and GetLocale() or 'enUS'
 local layouts={deDE={'QWERTZUIOP','ASDFGHJKL','YXCVBNM'},frFR={'AZERTYUIOP','QSDFGHJKLM','WXCVBN'}}
 local rows=layouts[locale] or {'QWERTYUIOP','ASDFGHJKL','ZXCVBNM'}
 for row,letters in ipairs(rows) do for col=1,#letters do
  local btn=self._keys[letters:sub(col,col)]; btn:ClearAllPoints()
  btn:SetPoint('CENTER',self._keyboard,'CENTER',(col-(#letters+1)/2)*CFG.keyboard_col_step,CFG.keyboard_h/2-CFG.keyboard_key_h/2-(row-1)*CFG.keyboard_row_step)
 end end
end
function R:_CreateControls()
 local bar=UI.CreateGameControlsBar(self.frame,'narrow'); local cf=bar.frame
 local pair=CreateFrame('Frame',nil,cf); pair:SetSize(250,32); pair:SetPoint('CENTER',cf,'CENTER',bar.segX[1],bar.y.dropdownOfs)
 local cats={}; for _,cat in ipairs(A.HGM_Logic:GetCategories()) do cats[#cats+1]={key=cat.id,label=cat.label} end
 self._categoryDD=UI.CreateSimpleDropdown(pair,0,0,120,'',cats,function() return S:Get('category') end,function(v) S:Set('category',v) end)
 local anchor=CreateFrame('Frame',nil,pair); anchor:SetSize(120,32); anchor:SetPoint('LEFT',pair,'LEFT',130,0)
 local opts={}; for _,d in ipairs({'easy','normal','hard'}) do opts[#opts+1]={key=d,label=T()['diff_'..d]} end
 self._difficultyDD=UI.CreateSimpleDropdown(anchor,0,0,120,'',opts,function() return S:Get('difficulty') end,function(v) S:Set('difficulty',v) end)
 local btn=UI.CreateArcadiaButton(cf,T().btn_start,144,32); btn:SetPoint('BOTTOM',cf,'BOTTOM',bar.segX[2],bar.y.button)
 btn:SetScript('OnClick',function() if E.state=='RESULT_PENDING' then E:RetryResult() elseif E.state=='PLAYING' then E:StopGame() else E:StartGame() end end)
 self._startBtn=btn
end
function R:_UpdateControlLabels()
 if not self.frame then return end
 local unlocked=not E:IsConfigLocked()
 for _,dd in ipairs({self._categoryDD,self._difficultyDD}) do dd:SetEnabled(unlocked); dd:RefreshDisplay() end
 self._startBtn:SetLabel(E.state=='PLAYING' and T().btn_exit or E.state=='RESULT_PENDING' and T().btn_book or T().btn_start)
 self._startBtn:SetEnabled(not E._layoutEditing)
end
function R:_StopVisual()
 self:_CancelResultReveal()
 if self._loop then self._loop:Stop() end; self._pulse=0
 if self._portal then self._portal:SetRotation(0); self._portal:SetAlpha(1) end
 if self._pet then self._pet.holder:Hide() end
end
function R:EnterIdleState()
 if not self.frame then return end
 self.state='IDLE'; self:_StopVisual(); self._play:Hide(); self._logo:Show(); self._feedback:SetText('')
 UI.HideResultDialog(self._fieldFrame); self:_UpdateControlLabels()
end
function R:ShowFeedback(key) if self._feedback then self._feedback:SetText(T()[key] or key) end end
-- Reflow existing regions for the DevMode preview; never rebuild the game UI.
function R:ApplyLayout(board)
 if not self.frame then return end
 local function place(region,parent,prefix)
  region:ClearAllPoints(); region:SetSize(CFG[prefix..'_w'],CFG[prefix..'_h'])
  region:SetPoint('CENTER',parent,'CENTER',CFG[prefix..'_ofs_x'],CFG[prefix..'_ofs_y'])
  if CFG[prefix..'_alpha'] then region:SetAlpha(CFG[prefix..'_alpha']) end
 end
 place(self._fieldFrame,self._canvas,'field')
 for _,p in ipairs({'bg','border','logo'}) do place(self['_'..p],self._fieldFrame,p) end
 place(self._solution,self._play,'solution'); self._solutionBG:SetSize(CFG.solution_w,CFG.solution_h)
 place(self._solutionText,self._solution,'solution_text')
 place(self._hints,self._play,'hints'); self._hintsBG:SetSize(CFG.hints_w,CFG.hints_h)
 place(self._keyboard,self._play,'keyboard'); place(self._portalHolder,self._play,'portal')
 place(self._portal,self._portalHolder,'portal_image'); place(self._seal,self._portalHolder,'portal_seal')
 place(self._pet.holder,self._portalHolder,'modelscene'); self._pet:Fit()
 place(self._errorText,self._play,'errors')
 for _,f in ipairs(self._letters) do
  f:SetSize(CFG.solution_letter_w,CFG.solution_letter_h); f.text:SetSize(CFG.solution_letter_w,CFG.solution_letter_h-3)
  f.line:SetWidth(CFG.solution_letter_w-2)
 end
 for _,f in ipairs(self._runes) do
  f:SetSize(CFG.rune_size,CFG.rune_size); f.marker:ClearAllPoints()
  f.marker:SetSize(CFG.rune_size,14); f.marker:SetPoint('CENTER',f,'CENTER',0,-CFG.rune_size*.64)
 end
 for _,btn in pairs(self._keys) do btn:SetSize(CFG.keyboard_key_w,CFG.keyboard_key_h) end
 place(self._category,self._hints,'category_text'); place(self._hint,self._hints,'hint_text')
 place(self._status,self._hints,'wrong_text'); place(self._feedback,self._fieldFrame,'feedback_text')
 self:_LayoutKeyboard()
 if board then self:RenderBoard(board) end
end
function R:_CancelResultReveal()
 if self._resultLoop then self._resultLoop:Stop() end
 self._sealResult=nil
 if self._seal then self._seal:SetAlpha(1) end
end
-- The layout is computed from pixel capacity and preserves word gaps and separators.
function R:LetterLayout(word)
 local out={}; local row,col=0,0; local capacity=math.max(1,math.floor((CFG.solution_text_w-26)/CFG.solution_col_step))
 local i=1
 while i<=#word do
  local ch=word:sub(i,i)
  if ch==' ' then
   col=col+1
   if col>=capacity then row=row+1; col=0 end
   out[i]={row=row,col=col,space=true}; i=i+1
  else
   local finish=word:find(' ',i,true) or #word+1; local len=finish-i
   if col>0 and col+math.min(len,capacity)>capacity then row=row+1; col=0 end
   for j=i,finish-1 do
    if col>=capacity then row=row+1; col=0 end
    out[j]={row=row,col=col}; col=col+1
   end
   i=finish
  end
 end
 local counts={}; for _,p in ipairs(out) do counts[p.row]=math.max(counts[p.row] or 0,p.col+1) end
 for _,p in ipairs(out) do p.x=(p.col-(counts[p.row]-1)/2)*CFG.solution_col_step; p.y=CFG.solution_text_h/2-21-p.row*CFG.solution_row_step end
 return out,row+1
end
function R:RenderBoard(board)
 if not self.frame or not board then return end
 self:_LayoutKeyboard(); self._pet:SetVisibility(CFG.modelscene_alpha_start+(CFG.modelscene_alpha_end-CFG.modelscene_alpha_start)*board.errors/board.maxErrors)
 self.state=E.state; self._seal:SetShown(board.won); self._logo:Hide(); self._play:Show(); self._feedback:SetText('')
 local layout=self:LetterLayout(board.word)
 local newGuess=self._renderedRun==E._runId and #board.guesses>(self._renderedGuesses or 0) and board.guesses[#board.guesses]
 self._renderedRun=E._runId; self._renderedGuesses=#board.guesses
 for i,f in ipairs(self._letters) do
  local p=layout[i]
  if p and not p.space then
   f:ClearAllPoints(); f:SetPoint('CENTER',self._solutionText,'CENTER',p.x,p.y); f:Show()
   local ch=board.word:sub(i,i); local letter=ch:match('[A-Z]')
   local shown=board.revealed[i] or board.lost
   f.justHit=newGuess==ch and board.revealed[i] and E.state=='PLAYING'
   if f.justHit then self._letterPulse=.3 end
   f.text:SetText(shown and ch or ''); f.text:SetTextColor(board.lost and not board.revealed[i] and 1 or .75,.95,.65)
   f.line:SetShown(letter~=nil)
  else f:Hide() end
 end
 for i,f in ipairs(self._runes) do
  if i<=board.maxErrors then
   local angle=-math.pi/2+(i-1)*2*math.pi/board.maxErrors
   f:ClearAllPoints(); f:SetPoint('CENTER',self._portalHolder,'CENTER',math.cos(angle)*CFG.rune_radius,math.sin(angle)*CFG.rune_radius+CFG.rune_ofs_y); f:Show()
   local on=i<=board.errors; local atlas=string.format('Rune-%02d-%s',i,on and 'light' or 'dark')
   if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then f.tex:SetAtlas(atlas)
   else f.tex:SetTexture('Interface\\Icons\\INV_Misc_Rune_0'..i) end
   f.tex:SetAlpha(on and 1 or .5); f.marker:SetText(on and '×' or '')
  else f:Hide() end
 end
 self._errorText:SetText(string.format(T().errors_plain,board.errors,board.maxErrors))
 self._category:SetText((T()['diff_'..board.difficulty] or board.difficulty)..' · '..board.category)
 self._hint:SetText(T().hint_plain..'\n'..board.hint)
 local wrong=A.HGM_Logic:GetWrongLetters(board)
 self._status:SetText(board.won and T().sealed or board.lost and T().opened or T().wrong_plain..table.concat(wrong,' '))
 for letter,btn in pairs(self._keys) do
  local used=board.guessed[letter]; local found=board.word:find(letter,1,true)
  btn:SetLabel(used and ('|cff'..(found and '88ee66' or 'ff7777')..letter..'|r') or letter)
  if E.state~='PLAYING' or used then btn:Disable() else btn:Enable() end
 end
 self:_UpdateControlLabels()
end
function R:ShowPlaying(board)
 if not self.frame then return end
 self:_CancelResultReveal()
 UI.HideResultDialog(self._fieldFrame); self._renderedRun=nil; self._renderedGuesses=0; self:RenderBoard(board)
 self._pet.holder:SetShown(not board.won); self._pet:SetPet(board.petId); self._phase=0; self:_Animate()
end
function R:_Animate()
 if not self._loop then return end
 if S:Get('reducedMotion') or E.state~='PLAYING' and (self._pulse or 0)<=0 then
  self._loop:Stop(); self._portal:SetRotation(0); self._portal:SetAlpha(1); return
 end
 self._loop:Start(function(dt)
  if not self.frame:IsShown() or S:Get('reducedMotion') then self._loop:Stop(); self._portal:SetRotation(0); self._portal:SetAlpha(1); return end
  self._letterPulse=math.max(0,(self._letterPulse or 0)-dt)
  for _,f in ipairs(self._letters) do if f.justHit then
   if self._letterPulse>0 then f.text:SetTextColor(1,1,.85) else f.justHit=nil; f.text:SetTextColor(.75,.95,.65) end
  end end
  self._phase=(self._phase or 0)+dt; self._pulse=math.max(0,(self._pulse or 0)-dt)
  if E.state~='PLAYING' and self._pulse==0 then self._loop:Stop(); self._portal:SetRotation(0); self._portal:SetAlpha(1); return end
  self._portal:SetRotation(E.state=='PLAYING' and math.sin(self._phase*.6)*.012 or 0)
  self._portal:SetAlpha(self._pulse>0 and .72+.28*math.abs(math.cos(self._phase*10)) or .94+.06*math.sin(self._phase*.8))
 end)
end
function R:Pulse(kind)
 if kind=='win' and self._pet then self._pet.holder:Hide() end
 self._pulse=.25
 -- A short transition never delays rules, saving, or result booking.
 if kind=='win' or kind=='loss' then self._pulse=.6 end
 self:_Animate()
end
function R:ShowPending(data)
 self:_CancelResultReveal()
 if self._loop then self._loop:Stop() end
 UI.ShowArcadeResult(self._fieldFrame,{gameId='HANGMAN',difficulty=data.difficulty,result=data.result,title=T().msg_pending,
 lines={T().pending_detail},L=T(),hideHighscore=true,isCurrent=function() return E._result==data end,
 buttons={{label=T().btn_book,onClick=function() E:RetryResult() end},{label=T().btn_exit,onClick=function() E:StopGame() end}}})
end
function R:ShowResult(data)
 if not self.frame or E._result~=data or not data.processed then return end
 if self._sealResult==data then return end
 self:_CancelResultReveal()
 if data.result~='WIN' then return self:_PresentResult(data) end
 UI.HideResultDialog(self._fieldFrame)
 self._pet.holder:Hide(); self._seal:Show()
 self._sealResult=data
 local elapsed=0; local fade=S:Get('reducedMotion') and 0 or .8
 self._seal:SetAlpha(fade==0 and 1 or 0)
 self._resultLoop:Start(function(dt)
  -- The gameplay session has already ended; guard the booked result identity.
  if self._sealResult~=data or E._result~=data or E.state~='WON' or not self.frame:IsShown() then
   self:_CancelResultReveal(); return
  end
  elapsed=elapsed+dt
  if S:Get('reducedMotion') then fade=0 end
  self._seal:SetAlpha(fade==0 and 1 or math.min(1,elapsed/fade))
  if elapsed>=fade+.35 then
   self:_CancelResultReveal(); self:_PresentResult(data)
  end
 end)
end
function R:_PresentResult(data)
 if E._result~=data or not data.processed or not self.frame:IsShown() then return end
 UI.ShowArcadeResult(self._fieldFrame,{gameId='HANGMAN',difficulty=data.difficulty,result=data.result,L=T(),
 title=data.result=='WIN' and T().sealed or T().opened,score=data.score,xp=data.awardedXP,gold=data.awardedGold,hideHighscore=true,
 lines={string.format(T().go_word,data.result=='WIN' and 'aaff88' or 'ff8844',data.board.word),
 string.format(T().go_errors,data.board.errors,data.board.maxErrors,data.board.maxErrors-data.board.errors),
 string.format(T().go_stats,S:Get('wins'),S:Get('losses')),string.format(T().perfect_count,S:GetStats().perfectWins)},
 isCurrent=function() return E._result==data and data.processed end,
 onRetry=function() E:RetryPuzzle() end,onExit=function() E:StopGame() end})
end
A.RegisterGame({
 id="HANGMAN", label="Nether Bound", renderer="HGM_Renderer", engine="HGM_Engine",
 container="_hangmanContainer", category="WORT", logo=PATH.."logo_a_v1", xp=10,
})
