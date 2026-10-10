local count=0
local function check(value,message) assert(value,message); count=count+1 end
local seed=42
local function rng(n) seed=(seed*16807)%2147483647; return seed%n+1 end
dofile('FlightpathArcade/Logic.lua')
dofile('FlightpathArcade/Animation.lua')
local L=FlightpathArcade.Logic
for first=1,64 do
 local s=L.mines(rng); L.reveal(s,first); check(s.status~='lost','safe start')
 local bombs=0 for i=1,64 do if s.board[i]==-1 then bombs=bombs+1 end end check(bombs==10,'bomb count')
 for i=1,64 do if s.board[i]~=-1 then L.reveal(s,i) end end check(s.status=='won','mines win')
end
local s=L.mines(rng); L.reveal(s,1,true); L.reveal(s,1); check(not s.started,'flag blocks reveal'); L.reveal(s,1,true); L.reveal(s,1)
for i=1,64 do if s.board[i]==-1 then L.reveal(s,i); break end end check(s.status=='lost','mines lose')
s=L.memory(rng); local a,b=1,2; while s.board[a]==s.board[b] do b=b+1 end
L.flip(s,a); L.flip(s,a); check(not s.second,'same card'); L.flip(s,b); check(s.wait==0.8,'mismatch'); L.memoryTick(s,1); check(not s.first,'clear mismatch')
for v=1,8 do for i=1,16 do if s.board[i]==v then L.flip(s,i) end end end check(s.status=='won','memory win')
s=L.snake(rng); L.turn(s,'LEFT'); check(s.nextDir=='RIGHT','no reverse'); s.food=67; L.snakeTick(s); check(s.score==1 and #s.body==4,'snake eat')
for i=1,12 do L.snakeTick(s) end check(s.status=='lost','wall loss')
s=L.snake(rng); s.body={1,2,14,13}; s.dir='UP'; s.nextDir='DOWN'; L.snakeTick(s); check(s.status=='playing','vacating tail')
s=L.snake(rng); s.body={1,2,14,13,25}; s.dir='DOWN'; s.nextDir='DOWN'; L.snakeTick(s); check(s.status=='lost','body collision')
s=L.snake(rng); s.w=2; s.h=2; s.body={1,3,4}; s.dir='RIGHT'; s.nextDir='RIGHT'; s.food=2; L.snakeTick(s); check(s.status=='won','full snake board')
for iteration=1,50 do
 s=L.gems(rng); check(not next(L.matches(s.board)),'clean gems'); check(L.hasMove(s.board),'playable gems')
 local old=s.moves; check(not L.swap(s,1,36) and s.moves==old,'invalid swap')
 local moved=false
 for i=1,36 do for _,j in ipairs({i+1,i+6}) do if not moved and L.swap(s,i,j) then moved=true end end end
 check(moved and s.moves==19,'valid move'); check(not next(L.matches(s.board)),'settled board')
end
s=L.gems(function() return 1 end); check(L.hasMove(s.board),'degenerate rng bounded')
s.moves=1; s.score=0
for i=1,36 do for _,j in ipairs({i+1,i+6}) do L.swap(s,i,j) end end
check(s.status~='playing','gems terminal')
-- Minimal native UI contract mock. It does not render or emulate protected APIs.
local frames={}
local regionCount=0
local methods={}
local combat=false
local denyPropagation=false
local propagationCalls=0
local layoutCalls=0
function InCombatLockdown() return combat end
function methods:SetPropagateKeyboardInput(v)
 propagationCalls=propagationCalls+1
 assert(not combat,'restricted propagation called in combat')
 assert(not denyPropagation,'simulated restricted API rejection')
 self.propagate=v
end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:SetVertexColor(...) self.vertex={...} end
function methods:SetDrawLayer(layer) self.layer=layer end
function methods:SetAutoFocus(value) self.autoFocus=value end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:SetFocus() self.focus=true end
function methods:ClearFocus() self.focus=false end
function methods:GetText() return self.textValue or '' end
function methods:Show() self.shown=true end
function methods:Hide() local was=self.shown; self.shown=false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:EnableKeyboard(v) self.keyboard=v end
function methods:SetText(v) self.textValue=v end
function methods:CreateFontString(_,layer) regionCount=regionCount+1; return setmetatable({scripts={},shown=true,parent=self,layer=layer}, {__index=methods}) end
function methods:CreateTexture(_,layer) regionCount=regionCount+1; return setmetatable({scripts={},shown=true,parent=self,layer=layer}, {__index=methods}) end
-- Explicit supported surface: unexpected native API calls must fail.
for _,method in ipairs({'SetSize','SetFrameStrata','SetClampedToScreen','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','EnableMouse','SetMovable','RegisterForDrag','StartMoving','StopMovingOrSizing','SetFont','SetTextColor','SetWidth','SetJustifyH','RegisterForClicks','RegisterEvent','SetOwner','AddLine','SetTexture','SetTexCoord','SetAlpha','SetClipsChildren'}) do
 methods[method]=function() end
end
function methods:SetPoint(...) layoutCalls=layoutCalls+1; self.points=self.points or {}; table.insert(self.points,{...}) end
function methods:ClearAllPoints() layoutCalls=layoutCalls+1; self.points={} end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(scale) self.scale=scale end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetClampedToScreen(value) self.clamped=value end
function methods:IsEnabled() return self.enabled~=false end
function methods:SetEnabled(value)
 local changed=self:IsEnabled()~=value; self.enabled=value
 local fn=self.scripts[value and 'OnEnable' or 'OnDisable']; if changed and fn then fn(self) end
end
function methods:SetTexCoord(...) self.uv={...} end
function methods:SetTexture(path) self.texture=path end
function methods:SetOwner(owner,anchor) self.owner=owner; self.anchor=anchor end
function methods:AddLine(text) self.lines=self.lines or {}; table.insert(self.lines,text) end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetBackdropBorderColor(r,g,b,a) self.border={r,g,b,a} end
function methods:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1 or 0) end
function methods:SetFrameLevel(level)
 local delta=level-self:GetFrameLevel(); self.level=level
 for _,child in ipairs(self.children or {}) do child:SetFrameLevel(child:GetFrameLevel()+delta) end
end
function methods:SetFrameStrata(strata) self.strata=strata end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata() or 'MEDIUM') end
function methods:EnableMouse(value) self.mouse=value end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetBackdrop(value) self.backdrop=value; self.backgroundLayer='BACKGROUND'; self.borderLayer='BORDER' end
function CreateFrame(_,name,parent)
 local f=setmetatable({scripts={},shown=true,parent=parent,children={},level=parent and parent:GetFrameLevel()+1 or 0}, {__index=methods})
 if parent then table.insert(parent.children,f) end
 frames[#frames+1]=f; if name then _G[name]=f end return f
end
UIParent=CreateFrame('Frame'); Minimap=CreateFrame('Frame',nil,UIParent); UISpecialFrames={}; SlashCmdList={}; STANDARD_TEXT_FONT='font'; tinsert=table.insert; unpack=unpack or table.unpack
UIParent:SetSize(1920/0.8,1080/0.8); UIParent:SetScale(0.8)
GameTooltip=CreateFrame('Frame'); local taxi=false
function UnitOnTaxi() return taxi end
function GetBuildInfo() return '1.60.1','70009','',16001 end
dofile('FlightpathArcade/UI.lua')
dofile('FlightpathArcade/Frost/Simulation.lua'); dofile('FlightpathArcade/Frost/Animation.lua'); dofile('FlightpathArcade/Frost/UI.lua')
dofile('FlightpathArcade/Core.lua')
local A=FlightpathArcade; A:Initialize(); check(not A.window:IsShown(),'login grounded')
taxi=true; A:FlightCheck(); check(A.window:IsShown(),'flight opens'); A:Close(); A:FlightCheck(); check(not A.window:IsShown(),'dismiss persists')
taxi=false; A:FlightCheck(); taxi=true; A:FlightCheck(); check(A.window:IsShown(),'next flight opens')
A:Start('snake'); check(A.paused and not A.window.keyboard,'snake explicit focus'); A:Resume(); check(A.window.keyboard,'capture'); A:Close(); check(A.paused and not A.window.keyboard,'hide releases')
A:Open(); A:Resume(); A.db.autoClose=false; taxi=false; A:FlightCheck(); check(A.window:IsShown() and A.paused and not A.window.keyboard,'landing pause without close')
A.db.autoOpen=false; A:Close(); taxi=true; A:FlightCheck(); check(not A.window:IsShown(),'auto open disabled'); A:Toggle(); check(A.window:IsShown(),'manual flight opening')
A.db.autoClose=true; taxi=false; A:FlightCheck(); check(not A.window:IsShown(),'auto close')
A:Open(); A:Start('memory'); A:Cell(1,'LeftButton'); A:Close(); local first=A.game.first; A:Tick(9); check(A.game.first==first,'hidden game frozen'); A:Open(); check(A.paused,'reopen paused')
FlightpathArcadeDB={autoOpen=true,autoClose=false,minimap=false}; A.initialized=false; taxi=true; A:Initialize(); check(A.window:IsShown() and not A.minimap:IsShown(),'reload in flight settings')
for _,kind in ipairs({'mines','gems','snake','memory'}) do A:Start(kind); A:Render(); A.game.status='won'; A:Render(); check(A.paused and not A.window.keyboard,'terminal focus '..kind) end
A:Start('snake'); combat=true; local calls=propagationCalls
check(A:Resume()==false and A.paused and not A.window.keyboard,'combat resume refused')
check(propagationCalls==calls,'combat does not call restricted API')
A.directions[2].scripts.OnClick(); check(not A.paused and not A.window.keyboard,'combat mouse controls')
A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED'); check(A.paused and not A.window.keyboard,'combat event pause')
combat=false; A:Resume(); check(A.window.keyboard and A.keyboardCaptured,'out of combat capture')
combat=true; calls=propagationCalls; A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED')
check(A.paused and not A.window.keyboard and not A.keyboardCaptured,'combat releases capture')
check(propagationCalls==calls,'combat release avoids restricted API')
combat=false; denyPropagation=true; check(A:Resume()==false and A.paused and not A.window.keyboard,'failed capture atomic')
denyPropagation=false; A:Resume(); combat=true; A:Tick(0.2)
check(A.paused and not A.window.keyboard,'combat tick fallback releases')
combat=false; A:Resume(); A.directions[2].scripts.OnClick()
check(not A.paused and not A.window.keyboard,'mouse controls release existing capture')
A:Close(); check(A:Resume()==false and not A.window.keyboard,'hidden resume refused')
check(not pcall(function() A.window:UnknownNativeMethod() end),'unknown mock API fails')
-- Stub only the rule step so timing can be measured beyond a board's walls.
local originalTick=L.snakeTick
for _,fps in ipairs({15,30,45,60}) do
 local steps=0; L.snakeTick=function() steps=steps+1 end
 A:Open(); A:Start('snake'); A:Resume(); local before=layoutCalls
 for frame=1,fps*10 do A:Tick(1/fps) end
 check(steps==55,'consistent snake timing at '..fps..' FPS')
 check(layoutCalls==before,'snake frames do not repeat layout')
end
local steps=0; L.snakeTick=function() steps=steps+1 end
A.elapsed=0; A:Tick(2); check(steps==1,'hitch performs at most one step')
check(A.elapsed<0.18,'hitch retains fractional remainder only')
L.snakeTick=originalTick
A:Start('gems'); A:Cell(1,'LeftButton'); local cell=A.cells[1]
check(cell.border[1]==1 and cell.border[2]==1,'selected gem border')
cell.scripts.OnEnter(cell); cell.scripts.OnLeave(cell); A:Render()
check(cell.border[1]==1 and cell.border[2]==1 and cell.border[3]==1,'hover preserves selection border with cached paint')
A:Cell(1,'LeftButton'); cell.scripts.OnLeave(cell)
check(cell.border[1]==0.25 and cell.border[2]==0.34,'deselected gem restores normal border')
local function boardKey(b) return table.concat(b,',') end
local function moveFor(s,wantValid)
 for i=1,36 do for _,j in ipairs({i+1,i+6}) do
  if j<=36 and (j-i==6 or math.floor((i-1)/6)==math.floor((j-1)/6)) then
   s.board[i],s.board[j]=s.board[j],s.board[i]; local valid=next(L.matches(s.board))~=nil; s.board[i],s.board[j]=s.board[j],s.board[i]
   if valid==wantValid then return i,j end
  end
 end end
 error('test board has no requested move')
end
local function finish(s,dt) local ticks=0; while s.animation do L.animationTick(s,dt); ticks=ticks+1; assert(ticks<10000) end end
-- Compare animated resolution to the same authoritative rules/RNG stream.
for n=1,100 do
 seed=n*29; local a=L.gems(rng); local i,j=moveFor(a,true); local rngState=seed
 local b={kind='gems',board={},rng=rng,status='playing',moves=a.moves,score=a.score}
 for k=1,36 do b.board[k]=a.board[k] end
 check(L.planSwap(a,i,j),'animation starts'); local endSeed=seed
 seed=rngState; check(L.swap(b,i,j),'reference swap'); check(seed==endSeed,'same RNG order')
 check(boardKey(a.board)==boardKey(b.board) and a.score==b.score and a.moves==b.moves and a.status==b.status,'animated outcome matches rules')
 local anim=a.animation; check(anim.phases[1].kind=='swap','swap first')
 for k=2,#anim.phases do
  local p=anim.phases[k]
  if p.kind=='highlight' then check(anim.phases[k+1].kind=='clear' and anim.phases[k+2].kind=='fall','cascade ordering') end
  if p.kind=='fall' then for cell=1,36 do check(p.origins[cell]<=math.floor((cell-1)/6),'gravity only downward') end end
 end
 check(not L.planSwap(a,i,j),'repeated clicks locked')
 finish(a,1/30); check(not next(L.matches(a.board)),'final animation board settled')
end
seed=123; s=L.gems(rng); local i,j=moveFor(s,false); local before=boardKey(s.board)
check(L.planSwap(s,i,j),'invalid adjacent swap animates'); check(#s.animation.phases==2,'invalid swap returns visibly')
check(s.score==0 and s.moves==20 and boardKey(s.board)==before,'invalid swap costs nothing')
finish(s,0.017)
for _,fps in ipairs({15,30,45,60}) do
 seed=88; s=L.gems(rng); i,j=moveFor(s,true); L.planSwap(s,i,j)
 local duration=0; for _,p in ipairs(s.animation.phases) do duration=duration+p.duration end
 local ticks=0; while s.animation do L.animationTick(s,1/fps); ticks=ticks+1 end
 check(math.abs(ticks/fps-duration)<=1/fps+0.000001,'animation duration independent of FPS')
end
-- Interrupt every phase and prove no hidden/pause work, then resume to completion.
seed=19; A:Start('gems'); A.game=L.gems(rng); i,j=moveFor(A.game,true); A:Cell(i,'LeftButton'); A:Cell(j,'LeftButton')
local pending=A.game.animation; check(pending~=nil,'UI starts animation')
local originalBoard=boardKey(A.game.board); A:Cell(2,'LeftButton'); check(boardKey(A.game.board)==originalBoard and A.game.animation==pending,'UI repeat click locked')
for phaseIndex=1,#pending.phases do
 pending.index=phaseIndex; pending.time=0.05; A:Close(); A:Tick(10); check(pending.time==0.05,'hidden animation frozen')
 A:Open(); A:Tick(10); check(pending.time==0.05 and A.paused,'reopen remains paused'); check(A:Resume(),'animation resume')
 A:Pause(); A:Tick(10); check(pending.time==0.05,'manual pause freezes')
 A:Resume(); A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED'); A:Tick(10); check(pending.time==0.05 and A.paused,'combat freezes animation')
 A:Resume(); A.inFlight=true; taxi=false; A.db.autoClose=false; A:FlightCheck(); A:Tick(10); check(pending.time==0.05 and A.paused,'landing freezes animation')
end
A:Resume(); A:Tick(1000); check(not A.game.animation,'resume resolves once even after hitch')
A:Start('gems'); i,j=moveFor(A.game,true); A:Cell(i,'LeftButton'); A:Cell(j,'LeftButton'); local old=A.game
A:Start('gems'); A:Tick(5); check(A.game~=old and not A.game.animation and A.game.score==0,'restart drops timeline')
i,j=moveFor(A.game,true); A:Cell(i,'LeftButton'); A:Cell(j,'LeftButton'); A:Start('memory'); A:Tick(5); check(A.game.kind=='memory' and not A.gemOverlay:IsShown(),'switch drops timeline and overlay')
-- Rendering contract: frame levels sort sibling Frames/Buttons. Texture draw
-- layers provide ordering only within the same owner; sibling ties are unsafe.
local layers={BACKGROUND=1,BORDER=2,ARTWORK=3,OVERLAY=4,HIGHLIGHT=5}
local function above(region,owner,layer)
 local frame=region.parent
 if frame:GetFrameStrata()~=owner:GetFrameStrata() then return false end
 if frame~=owner then return frame:GetFrameLevel()>owner:GetFrameLevel() end
 return layers[region.layer]>layers[layer]
end
local function assertMovingOrder(tag)
 check(A.gemOverlay:IsVisible(),tag..' overlay visible')
 check(A.gemOverlay.parent==A.content and A.gemOverlay.mouse==false,tag..' overlay cannot take board input')
 for cellIndex=1,36 do
  local tile=A.cells[cellIndex]; local moving=A.gemSprites[cellIndex]
  check(moving.parent==A.gemOverlay and moving.layer=='OVERLAY',tag..' sprite owner/layer')
  check(moving:IsVisible() and not tile.art:IsShown(),tag..' no duplicate stable sprite')
  check(above(moving,tile,tile.backgroundLayer) and above(moving,tile,tile.borderLayer),tag..' above tile backdrop and border')
 end
end
A:Start('gems')
check(not A.gemOverlay:IsShown(),'stable overlay hidden')
check(above(A.cells[1].art,A.cells[1],A.cells[1].backgroundLayer),'stable gem above own background')
local fixtureBoard=A.game.board; local origins={}; for k=1,36 do origins[k]=math.floor((k-1)/6)-1 end
local renderPhases={
 {kind='swap',a=1,b=2}, {kind='highlight',found={[1]=true,[2]=true,[3]=true}},
 {kind='clear',found={[1]=true,[2]=true,[3]=true}}, {kind='fall',origins=origins}, {kind='refill'}}
local frameCount=#frames
local regionsBefore=regionCount
for _,phase in ipairs(renderPhases) do
 phase.board=fixtureBoard; phase.duration=0.32; phase.score=0
 A.game.animation={phases={phase},index=1,time=0.10,score=0}; A:Render(); assertMovingOrder(phase.kind)
 A.gemOverlay:SetFrameLevel(A.cells[1]:GetFrameLevel())
 check(not above(A.gemSprites[1],A.cells[1],A.cells[1].backgroundLayer),'mock rejects ambiguous sibling-level tie')
 A:PaintAnimation(); assertMovingOrder(phase.kind..' repaired tie')
 -- Reproduce the old sibling-level tie and a native parent/tile raise.
 A.cells[7]:SetFrameLevel(A.gemOverlay:GetFrameLevel()+3); A:PaintAnimation(); assertMovingOrder(phase.kind..' raised tile')
 A.content:SetFrameLevel(A.content:GetFrameLevel()+2); A:PaintAnimation(); assertMovingOrder(phase.kind..' raised parent')
 A:Close(); check(not A.gemSprites[1]:IsVisible(),phase.kind..' hidden parent hides sprites')
 A:Open(); assertMovingOrder(phase.kind..' reopened'); check(A.paused,'reopen retains pause')
 A:Resume(); A:Tick(1)
 check(not A.gemOverlay:IsShown() and A.cells[1].art:IsVisible(),phase.kind..' returns to stable rendering')
end
check(#frames==frameCount and regionCount==regionsBefore,'render ordering fix preserves frame/texture pooling')
check(A.restart:IsVisible() and A.pause:IsVisible(),'animation leaves controls visible')
A:Cell(1,'LeftButton'); check(A.cells[1].selected,'stable selection preserved')
i,j=moveFor(A.game,true); A.game.selected=nil; A:Cell(i,'LeftButton'); A:Cell(j,'LeftButton'); assertMovingOrder('real swap')
A:Start('gems'); check(not A.gemOverlay:IsShown() and A.cells[1].art:IsVisible(),'restart clears moving overlay')
i,j=moveFor(A.game,true); A:Cell(i,'LeftButton'); A:Cell(j,'LeftButton'); A:Start('snake')
check(not A.gemOverlay:IsShown() and not A.gemSprites[1]:IsVisible(),'game switch hides moving sprites')
A.screen='lobby'; A:Open()
check(A.brand.textValue=='FLIGHTPATH ARCADE','title has no decorative slash')
check(not A.window.backdrop.edgeFile,'only asset border on window')
check(A.closeButton.points[1][2]==424 and A.closeButton.points[1][3]==-24 and A.closeButton.width==28,'close button inset geometry')
check(A.title.points[1][2]==22 and A.title.points[1][3]==-84,'lobby heading left aligns with content')
check(A.settingsButton.points[1][2]==350,'settings spacing retained')
for _,b in ipairs({A.closeButton,A.settingsButton,A.cards[1],A.back,A.restart,A.pause,A.scaleButtons[1]}) do
 check(b.skin and #b.skin==3 and b.skin[1].layer=='BACKGROUND' and b.text.layer=='OVERLAY','button skin below label')
 b:SetEnabled(true); b.hovered=false; b.pressed=false; b.scripts.OnLeave(b);check(b.skinState==1,'normal button skin')
 b.scripts.OnEnter(b);check(b.skinState==2,'hover button skin')
 b.scripts.OnMouseDown(b);check(b.skinState==3,'pressed button skin')
 b.scripts.OnMouseUp(b);check(b.skinState==2,'release restores hover')
 b:SetEnabled(false);check(b.skinState==4 and b.text.textColor[1]>=0.6,'disabled button remains readable')
 b:SetEnabled(true);b.scripts.OnLeave(b);check(b.skinState==1,'enabled button reset')
end
local sizes={{800,600},{1280,720},{1920,1080},{2560,1440},{3840,2160}}
for _,size in ipairs(sizes) do for _,gameScale in ipairs({0.64,0.8,1,1.5}) do for _,addonScale in ipairs({0.75,1,1.5}) do
 UIParent:SetSize(size[1]/gameScale,size[2]/gameScale); UIParent:SetScale(gameScale); A.db.uiScale=addonScale
 A.events.scripts.OnEvent(A.events,'UI_SCALE_CHANGED')
 local effective=A.window:GetEffectiveScale()
 check(480*effective<=size[1]-32*gameScale+0.001 and 550*effective<=size[2]-32*gameScale+0.001,'fits physical viewport via logical UI geometry')
 check(math.abs(effective-A.appliedScale*gameScale)<0.000001,'parent scale applied exactly once')
 check(A.window.points[1][1]=='CENTER' and A.window.clamped,'recenter and clamp after scale change')
 check(A.minimap:GetScale()==1,'addon scale does not resize minimap button')
 A:Start('gems');check(A.cells[1].width==A.cells[1].height,'square game cells at all scales')
end end end
A.screen='settings'; A:Render();A.db.uiScale=1.5;A.scaleButtons[2].scripts.OnClick();check(A.db.uiScale==1.5 and not A.scaleButtons[2]:IsEnabled(),'upper scale bound')
A.db.uiScale=0.75;A.scaleButtons[1].scripts.OnClick();check(A.db.uiScale==0.75 and not A.scaleButtons[1]:IsEnabled(),'lower scale bound')
A.scaleButtons[3].scripts.OnClick();check(A.db.uiScale==1,'scale reset')
A.db.uiScale=1.2;A.initialized=false;A:Initialize();check(A.db.uiScale==1.2,'saved scale survives initialization')
A.db.uiScale=0/0;A.initialized=false;A:Initialize();check(A.db.uiScale==1,'invalid scale sanitized')
local mm=A.minimap
check(mm.width==30 and mm.height==30 and mm.parent==Minimap,'minimap size and parent preserved')
check(mm.points[1][1]=='TOPLEFT' and mm.points[1][2]==Minimap and mm.points[1][4]==-7 and mm.points[1][5]==7,'minimap placement preserved')
check(mm.icon.texture=='Interface\\AddOns\\FlightpathArcade\\Media\\Minimap.tga' and mm.icon.layer=='ARTWORK','minimap texture path/layer')
check(mm.icon.uv[1]==4/64 and mm.icon.uv[2]==60/64 and mm.icon.uv[3]==4/64 and mm.icon.uv[4]==60/64,'padded minimap texture coordinates')
check(not mm.backdrop,'no duplicate square/ring backdrop')
A:Close();mm.scripts.OnClick();check(A.window:IsShown(),'minimap click opens');mm.scripts.OnClick();check(not A.window:IsShown(),'minimap click closes')
mm.scripts.OnEnter();check(GameTooltip:IsShown() and GameTooltip.owner==mm and GameTooltip.anchor=='ANCHOR_LEFT','minimap tooltip opens with correct owner')
check(GameTooltip.lines[#GameTooltip.lines]=='Click to open or close','tooltip text preserved')
mm.scripts.OnLeave();check(not GameTooltip:IsShown(),'minimap tooltip hides')
A.db.minimap=false;A:UpdateMinimap();check(not mm:IsShown(),'saved hidden minimap state respected')
SlashCmdList.FLIGHTPATHARCADE('');check(A.window:IsShown(),'slash access works while minimap hidden')
A.db.minimap=true;A:UpdateMinimap();check(mm:IsShown(),'minimap setting restores icon')
check(not mm.scripts.OnDragStart and A.window.scripts.OnDragStart==A.window.StartMoving,'existing fixed minimap and window drag behavior preserved')
-- Match-3 levels and explicit results, including all result action boundaries.
for level=1,10 do
 local normalized,target,moves=L.gemLevel(level)
 check(normalized==level and target==600+(level-1)*50 and moves==20,'bounded level curve')
 local fresh=L.gems(rng,level);check(fresh.level==level and fresh.target==target and fresh.score==0 and fresh.moves==20,'fresh level state')
 check(not next(L.matches(fresh.board)) and L.hasMove(fresh.board),'fresh level board legal')
end
for _,case in ipairs({{-99,1},{0,1},{1.9,1},{11,10},{math.huge,10},{-math.huge,1},{'bad',1},{0/0,1}}) do check(L.gemLevel(case[1])==case[2],'level input clamp') end
-- Locate a deterministic multi-cascade last-move win so the first clear passes
-- target but the result must wait through every remaining presentation phase.
local cascadeGame
for n=1,200 do
 seed=n;local trial=L.gems(rng);trial.score=590;trial.moves=1;local x,y=moveFor(trial,true);L.planSwap(trial,x,y)
 if #trial.animation.phases>=7 then cascadeGame=trial;break end
end
check(cascadeGame and cascadeGame.status=='won' and cascadeGame.moves==0,'last-move multi-cascade win outranks loss')
check(cascadeGame.animation.phases[4].score>=cascadeGame.target,'target crossed before later cascades finish')
A:Open();A:Start('gems');A.game=cascadeGame;A.gemSession=cascadeGame;A:Render()
check(not A.gemResult:IsShown(),'no result before first animation phase')
local finalScore=cascadeGame.score;local phases=cascadeGame.animation.phases
for index=1,#phases do
 cascadeGame.animation.index=index;cascadeGame.animation.time=0.01;A:Render()
 check(not A.gemResult:IsShown() and not A:ResultAction('primary'),'win panel/action waits for final cascade')
end
A:Close();A:Tick(100);A:Open();check(not A.gemResult:IsShown() and A.paused,'close/reopen during winning cascade freezes it')
A.inFlight=true;taxi=false;A.db.autoClose=false;A:FlightCheck();check(A.paused and not A.gemResult:IsShown(),'flight end does not advance result')
A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED');check(A.paused and not A.gemResult:IsShown(),'combat does not skip final cascade')
A:Resume();A:Tick(1000)
check(A.gemResult:IsVisible() and A.resultGame==cascadeGame and cascadeGame.score==finalScore,'result appears with final score after settle')
check(A.resultTitle.textValue=='Level complete!' and A.resultPrimary.text.textValue=='Next level','win result obvious')
check(A.gemResult.mouse and A.gemResult.width==258 and A.gemResult.height==258,'board-covering modal geometry')
check(A.gemResult.points[1][2]==89 and A.gemResult.points[1][3]==-55,'result overlays exact board origin')
for k=1,36 do check(A.gemResult:GetFrameLevel()>A.cells[k]:GetFrameLevel() and A.gemResult:GetFrameLevel()>A.gemOverlay:GetFrameLevel(),'result above static and animated board layers') end
for _,b in ipairs({A.resultPrimary,A.resultSecondary,A.resultBack}) do
 check(b.parent==A.gemResult and b:GetFrameLevel()>A.gemResult:GetFrameLevel(),'result buttons above panel')
 check(b.points[1][2]>=0 and b.points[1][2]+b.width<=258 and -b.points[1][3]+b.height<=258,'result controls inside board')
end
local boardBefore=boardKey(cascadeGame.board);A.paused=false;A:Cell(1,'LeftButton');check(boardKey(cascadeGame.board)==boardBefore,'modal blocks board clicks');A:Pause()
A:Close();A:Open();check(A.resultGame==cascadeGame and A.gemResult:IsVisible(),'completed result survives close/reopen')
A:Start('memory');A:SelectGame('gems');check(A.game==cascadeGame and A.gemResult:IsVisible(),'result/progress survives switching games')
check(A:ResultAction('back') and A.screen=='lobby','result lobby action');check(not A:ResultAction('primary'),'hidden stale action ignored')
A:SelectGame('gems');check(A.game==cascadeGame and A.game.level==1,'lobby return never auto-advances')
check(A:ResultAction('primary'),'next level action accepted')
check(A.game.level==2 and A.game.target==650 and A.game.score==0 and A.game.moves==20,'next level fresh state')
check(not A:ResultAction('primary') and A.game.level==2,'rapid duplicate next ignored')
check(not next(L.matches(A.game.board)) and L.hasMove(A.game.board),'next board legal')
A.game.status='won';A.game.score=740;A:Render();check(A:ResultAction('secondary') and A.game.level==2 and A.game.score==0,'retry stays on same level')
A:RestartGame();check(A.game.level==2 and A.game.moves==20,'footer retry stays on level')
local session=A.game;A:Start('snake');A:SelectGame('gems');check(A.game==session and A.paused,'in-progress round restored paused after game switch')
A.newRun.scripts.OnClick();check(A.game.level==1 and A.game.score==0,'explicit New run resets level')
A:Start('gems',10,rng);A.game.status='won';A.game.score=1050;A:Render()
check(A.resultTitle.textValue=='All levels complete!' and A.resultPrimary.text.textValue=='New run','level ten has explicit run completion')
A:ResultAction('primary');check(A.game.level==1,'final level action starts new run not level eleven')
-- Deterministic last-move loss with a tiny match and a distant level-ten target.
seed=4242;A:Start('gems',10,rng);A.game.moves=1;local lx,ly=moveFor(A.game,true);A:Cell(lx,'LeftButton');A:Cell(ly,'LeftButton');A:Tick(1000)
check(A.game.status=='lost' and A.gemResult:IsVisible() and A.resultTitle.textValue=='Out of moves','out-of-moves result')
check(A.resultPrimary.text.textValue=='Retry level','loss primary clearly retries')
A:ResultAction('primary');check(A.game.level==10 and A.game.moves==20,'loss retry current level')
A.game.status='lost';A.game.moves=0;A:Render();A:ResultAction('secondary');check(A.game.level==1,'loss New run resets')
dofile('tests/frost_integration.lua')(A,check,{
 combat=function(v) combat=v end,deny=function(v) denyPropagation=v end,
 taxi=function(v) taxi=v end,
 counts=function() return #frames,regionCount end
})
print('PASS: '..count..' deterministic logic and mock UI assertions')
