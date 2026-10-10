-- Runs inside the strict shared mock via an explicit context, never in WoW.
return function(A,check,env)
 local S=A.FrostSim
 local function down(k) A.window.scripts.OnKeyDown(A.window,k) end
 local function up(k) A.window.scripts.OnKeyUp(A.window,k) end
 local function key(k) down(k);up(k) end
 local function lobby() A:Pause();A.screen='lobby';A:Open() end
 local function settings() A:Pause();A.screen='settings';A:Open() end
 local function enter() settings();A.frostSecret.scripts.OnClick() end
 env.combat(false);A.db.frostUnlocked=false;lobby()
 check(#A.cards==4 and not A.frostCard:IsShown(),'four-game lobby unchanged while locked')
 check(not A.frostArtLoaded and not A.frostTerrain[1].texture,'locked lobby does not load Frost atlases')
 check(not A.window.keyboard and not A.keyboardCaptured and A.LobbyKey==nil and A.UpdateLobbyInput==nil,'lobby keyboard listener removed')
 check(not A.frostSecret:IsShown(),'skier entry absent from lobby')
 check(not A:Start('frost'),'locked game rejects direct selection')
 for _,k in ipairs({'UP','UP','DOWN','DOWN','LEFT','RIGHT','LEFT','RIGHT','B','A'}) do key(k) end
 check(not A.codeOpen and not A.window.keyboard,'former sequence has no effect')
 A.frostSecret.scripts.OnClick();check(not A.codeOpen,'stale hidden button click ignored outside settings')
 settings();check(A.frostSecret:IsVisible() and A.frostSecret:IsEnabled(),'settings exposes clickable skier')
 check(A.frostSecret.width==32 and A.frostSecret.height==32 and A.frostSecretIcon.width==24,'small sprite with usable hit target')
 check(A.frostSecretIcon.texture:find('skier.tga',1,true),'entry uses shipped skier sprite')
 check(not A.window.keyboard,'settings has no keyboard capture')
 local p=A.frostSecret.points[1]
 check(p[2]==426 and p[3]==-506 and p[2]+32<=458 and -p[3]+32<=538,'entry inset in bottom right')
 check(506>120+250+34 and 506>488+13,'entry clears scale controls and status line')
 A.frostSecret.scripts.OnClick();check(A.codeOpen and A.codePanel:IsVisible() and A.codeInput.focus,'click opens focused prompt')
 check(not A.window.keyboard and not A.keyboardCaptured,'prompt leaves parent keyboard disabled')
 check(not A.options[1]:IsShown() and not A.scaleButtons[1]:IsShown() and not A.frostSecret:IsShown(),'prompt hides unrelated settings actions')
 A.codeInput:SetText('forthehorde!');A.codeInput.scripts.OnEnterPressed()
 check(not A.db.frostUnlocked and A.codeOpen,'Enter rejects wrong case')
 check(A.codeFeedback.textValue=='Incorrect code. Try again.' and A.codeInput:GetText()=='','clear incorrect-code feedback')
 A.codeInput:SetText('ForTheHorde! ');check(not A:SubmitCode(),'trailing characters rejected')
 A.codeCancel.scripts.OnClick();check(not A.codeOpen and not A.codeInput.focus and A.screen=='settings' and A.frostSecret:IsVisible(),'Cancel restores settings and releases edit focus')
 enter();A.codeInput.scripts.OnEscapePressed();check(not A.codeOpen and A.screen=='settings' and not A.window.keyboard,'Escape cancels safely')
 enter();A.back.scripts.OnClick();check(not A.codeOpen and not A.codeInput.focus and A.screen=='lobby' and not A.frostSecret:IsShown(),'leaving settings releases prompt focus')
 enter();A.codeInput:SetText('ForTheHorde!');A:Close();check(not A.codeOpen and not A.codeInput.focus and not A.window.keyboard,'closing prompt releases everything')
 A:Open();check(not A.codeOpen and A.codeInput:GetText()=='' and A.frostSecret:IsVisible(),'reopen restores Settings without typed code')
 enter();env.combat(true);A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED')
 check(not A.codeOpen and not A.codeInput.focus and not A.window.keyboard and not A.frostSecret:IsEnabled(),'combat cancels prompt and disables entry')
 A.frostSecret.scripts.OnClick();check(not A.codeOpen and not A:OpenCode(),'combat cannot open prompt')
 env.combat(false);A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_ENABLED');check(A.frostSecret:IsEnabled() and not A.window.keyboard,'combat end restores button without keyboard listener')
 enter();A.db.autoClose=false;env.taxi(true);A:FlightCheck();env.taxi(false);A:FlightCheck()
 check(not A.codeOpen and not A.codeInput.focus,'flight transitions cancel prompt')
 for _,size in ipairs({{800,600},{1280,720},{1920,1080},{3840,2160}}) do
  for _,scale in ipairs({.64,1,1.5}) do for _,addonScale in ipairs({.75,1,1.5}) do
   UIParent:SetSize(size[1]/scale,size[2]/scale);UIParent:SetScale(scale);A.db.uiScale=addonScale;settings();A:FitWindow(true)
   local e=A.window:GetEffectiveScale();check(458*e<=size[1] and 538*e<=size[2],'settings sprite remains inside scaled viewport')
   A.frostSecret.scripts.OnClick();check(A.codeInput.focus and A.codePanel:IsVisible(),'scaled click focuses prompt');A:CancelCode()
  end end
 end
 enter();A.codeInput:SetText('ForTheHorde!');A.codeInput.scripts.OnEnterPressed()
 check(A.db.frostUnlocked and not A.codeOpen and A.screen=='lobby' and A.frostCard:IsVisible(),'correct Enter saves unlock and reveals game')
 check(not A.window.keyboard and not A.codeInput.focus,'successful unlock releases all focus')
 A.initialized=false;A:Initialize();A.screen='lobby';A:Open();check(A.db.frostUnlocked and A.frostCard:IsVisible(),'unlock survives initialization/reload')
 settings();A.frostSecret.scripts.OnClick();check(A.game.kind=='frost' and A.paused and not A.codeOpen,'already unlocked sprite starts fresh paused run without code')
 lobby()
 A.frostCard.scripts.OnClick();local g=A.game
 check(g.kind=='frost' and g.paused and A.paused and not A.window.keyboard,'selection starts paused')
 check(A.frostScene:IsVisible() and not A.cells[1]:IsShown(),'Frost replaces grid only in shared content')
 check(A.pause.text.textValue=='Ski','explicit capture action labeled Ski')
 local beforeFrames,beforeRegions=env.counts()
 local seeds={}
 for i=1,100 do
  A:RestartGame();check(not seeds[A.game.seed],'fresh restart seed');seeds[A.game.seed]=true
  check(A.game.time==0 and A.game.distance==0 and A.game.bonus==0 and A.game.hp==3 and A.game.paused,'restart resets state paused')
 end
 g=A.game;check(A:Resume() and A.window.keyboard and not A.window.propagate,'Ski captures after permission check')
 key('SPACE');check(g.jump>0 and g.bonus==0,'Space jumps without farmable bonus')
 down('A');down('LEFT');up('A');check(A.frostKeys.left,'dual steering keys retain remaining hold');up('LEFT');check(not A.frostKeys.left,'last steering key releases')
 down('RIGHT');A:Tick(.1);check(g.time>0 and g.x>240,'held input advances fixed-step course')
 key('P');local frozen=g.time;check(A.paused and not A.window.keyboard and not next(A.frostHeld),'P pauses and clears held keys')
 A:Tick(1);check(g.time==frozen,'paused simulation frozen')
 A:Resume();A:Close();A:Tick(1);check(g.time==frozen and not A.window.keyboard,'hidden simulation and capture frozen')
 A:Open();check(A.game==g and A.paused,'reopen retains run paused')
 env.deny(true);check(not A:Resume() and A.paused and not A.window.keyboard,'failed capture remains paused');env.deny(false)
 A:Resume();env.combat(true);A:Tick(.1);check(A.paused and not A.window.keyboard and not next(A.frostHeld),'combat tick fallback releases')
 check(not A:Resume(),'combat blocks Ski');env.combat(false)
 for _,event in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_CONTROL_LOST','PLAYER_ENTERING_WORLD'}) do
  A:Resume();A.events.scripts.OnEvent(A.events,event);check(A.paused and not A.window.keyboard,'interrupt releases '..event)
 end
 for _,autoClose in ipairs({false,true}) do
  A:Open();A.db.autoOpen=true;A.db.autoClose=autoClose;env.taxi(true);A:FlightCheck();A:Resume()
  env.taxi(false);A:FlightCheck();check(A.paused and not A.window.keyboard,'landing always releases')
  check(A.window:IsShown()==not autoClose,'landing obeys visibility setting')
 end
 A:Open();A:Resume();A.settingsButton.scripts.OnClick();check(not A.window.keyboard and not A.frostScene:IsShown(),'settings pauses and hides scene')
 A:Start('gems');local gems=A.game;A:Start('frost');A:SelectGame('gems');check(A.game==gems and not A.frostScene:IsShown(),'game switching preserves gem session')
 for _,kind in ipairs({'mines','gems','snake','memory'}) do
  A:Start('frost');A:Resume();down('A');A:Start(kind)
  check(not A.keyboardCaptured and not A.frostScene:IsShown() and not next(A.frostHeld),'switch clears Frost keys '..kind)
 end
 A:Start('frost');A:Resume();key('ESCAPE');check(A.paused and not A.window.keyboard,'Escape releases')
 A:Resume();local old=A.game;key('R');check(A.game~=old and A.game.paused and not A.window.keyboard,'R starts fresh paused run')
 A:Resume();g=A.game;g.distance=123.99;g.bonus=35;S.finish(g,'RUN OVER');A:Tick(.1);A:Render()
 -- External finish is rendered safely as well as the normal tick finish.
 A:Pause();A:Render();check(g.finalDistance==123 and g.finalScore==158 and A.frostNotice.textValue:find('123m + Bonus 35 = 158',1,true),'whole metre result plus combined bonus')
 check(not A.pause:IsShown(),'terminal run cannot resume')
 -- Every sprite, including its baked shadow, crops at every edge. A narrow
 -- sliver remains visible until the complete image has left the playfield.
 local function bounded(t,bw,bh)
  if not t:IsShown() then return end
  local p=t.points[1];local x,y=p[4],-p[5]
  check(x>=0 and y>=0 and x+t.width<=bw+1e-8 and y+t.height<=bh+1e-8,'texture rectangle inside bounds')
  for _,u in ipairs(t.uv) do check(u>=0 and u<=1,'cropped texture coordinates bounded') end
 end
 for _,name in ipairs({'tree','treeTall','deadTree','rock','stump','snowman','ramp','flagRed','flagBlue','skier','skierAir','monster','monster2','monsterAttack'}) do
  local height=(S.hazards[name] and S.hazards[name].height) or 32
  for _,x in ipairs({-20,-16,-15,0,8,16,240,479,480,495,496,500}) do
   for _,y in ipairs({-65,-48,-32,-17,-16,-15,0,1,15,16,32,47,48,519,520,535,536,550,600}) do
    local t=A.frostPool[1];A:DrawFrostSprite(t,name,x,y)
    local visible=x+16>0 and x-16<480 and y+16>0 and y+16-height<520
    check(t:IsShown()==visible,'partial sprite visibility '..name)
    if visible then
     bounded(t,480,520)
     check(math.abs(t.width-32*(t.uv[2]-t.uv[1]))<1e-8 and math.abs(t.height-height*(t.uv[4]-t.uv[3]))<1e-8,'crop preserves aspect and pixel mapping')
    end
   end
  end
 end
 A:DrawFrostSprite(A.frostPool[1],'treeTall',240,16)
 check(A.frostPool[1].height==32 and A.frostPool[1].uv[3]==.5,'top half of tall tree clipped exactly at boundary')
 A:DrawFrostSprite(A.frostPool[1],'treeTall',240,-15)
 check(A.frostPool[1]:IsShown() and A.frostPool[1].height==1,'last visible pixel not retired prematurely')
 A:Start('frost');g=A.game
 for _,pixels in ipairs({0,247,248,500,767,768,1536}) do
  g.distance=pixels*.12
  for i,o in ipairs(g.objects) do o.active=true;o.kind=i%2==0 and 'treeTall' or 'deadTree';o.x=(i%5)*120;o.y=(i%4)*180-15 end
  for i,gate in ipairs(g.gates) do gate.active=true;gate.x=i%2==0 and 1 or 479;gate.y=i%2==0 and 0 or 535;gate.resolved=i%2==0 end
  g.monster='lunge';g.lane=0;g.gap=-100;g.jump=.5;g.jumpDuration=1.1;A:Render()
  for _,t in ipairs(A.frostPool) do bounded(t,480,520) end
  for _,pair in ipairs(A.frostGates) do for _,t in ipairs(pair) do bounded(t,480,520) end end
  for _,t in ipairs(A.frostTerrain) do bounded(t,480,520) end
  for _,t in ipairs(A.frostDecor) do bounded(t,584,520) end
  bounded(A.frostSkier,480,520);bounded(A.frostBeast,480,520)
 end
 for _,o in ipairs(g.objects) do o.active=false end
 for _,gate in ipairs(g.gates) do gate.active=false end
 g.monster='quiet';A:Render()
 for _,t in ipairs(A.frostPool) do check(not t:IsShown(),'inactive pool sprite hidden') end
 for _,pair in ipairs(A.frostGates) do for _,t in ipairs(pair) do check(not t:IsShown(),'inactive gate hidden') end end
 check(not A.frostBeast:IsShown(),'inactive beast hidden')
 check(A.frostMessages:GetFrameLevel()>A.frostField:GetFrameLevel(),'notices above all field regions')
 for _,size in ipairs({{800,600},{1280,720},{1920,1080},{3840,2160}}) do
  for _,scale in ipairs({.64,1,1.5}) do for _,addonScale in ipairs({.75,1,1.5}) do
   UIParent:SetSize(size[1]/scale,size[2]/scale);UIParent:SetScale(scale);A.db.uiScale=addonScale;A:FitWindow(true);A:Render()
   check(480*A.window:GetEffectiveScale()<=size[1] and 550*A.window:GetEffectiveScale()<=size[2],'shared window fits with Frost')
   check(42.8+584*A.frostScene:GetScale()<=436 and 38+520*A.frostScene:GetScale()<=355,'scene including shoulders fits content')
  end end
 end
 local endFrames,endRegions=env.counts()
 check(endFrames==beforeFrames and endRegions==beforeRegions,'Frost rendering/restarts allocate no frames or regions')
 A:Close();check(not A.frostScene:IsVisible() and not A.window.keyboard,'final close releases and hides all')
end
