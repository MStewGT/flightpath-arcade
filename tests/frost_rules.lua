FlightpathArcade=FlightpathArcade or {}
dofile('FlightpathArcade/Frost/Simulation.lua')
dofile('FlightpathArcade/Frost/Animation.lua')
local S=FlightpathArcade.FrostSim
local A=FlightpathArcade.FrostAnimation
for _,pixels in ipairs({0,100,247,248,500,767,768,769,1536}) do
 local scene={distance=pixels*0.12};local before=scene.distance
 local offset,first,second=A.terrain(scene)
 assert(offset>=0 and offset<768 and first>0 and first+second==520)
 assert(offset+first<=768 and second>=0 and scene.distance==before)
end
local animGame=S.new(7);local visual=A.new();local originalRNG=animGame.rng
animGame.jump=0.4;animGame.jumpDuration=0.8;animGame.monster='lunge'
local pose,dx,dy,beast=A.sample(visual,animGame,{right=true})
assert(pose=='skierAir' and dx==2 and beast=='monsterAttack')
assert(animGame.jump==0.4 and animGame.rng==originalRNG and animGame.x==240)
assert(A.monsterY(animGame)<=185-S.jumpHeight(animGame)-38)
animGame.jump=0;animGame.time=1;pose,dx,dy=A.sample(visual,animGame,{})
assert(pose=='skier' and dy==2)
for i=1,20 do local p,x,y,b=A.sample(visual,animGame,{});assert(p==pose and x==dx and y==dy and b==beast) end
animGame.time=1.2;pose,dx,dy=A.sample(visual,animGame,{});assert(dy==0)
animGame.jump=0.3;A.sample(visual,animGame,{});animGame.jump=0;animGame.hit=0.5
pose,dx,dy=A.sample(visual,animGame,{left=true});assert(pose=='skier' and dx==0 and visual.landingUntil==0)
visual=A.new();pose,dx,dy,beast=A.sample(visual,S.new(7),{});assert(pose=='skier' and dx==0 and dy==0 and beast~='monsterAttack')
for _,gap in ipairs({-69.21,-1,0,38,110,210}) do
 local visual={gap=gap}
 assert(S.monsterY(visual)==math.max(35,185-math.max(38,gap)))
 assert(S.monsterY(visual)<=147 and visual.gap==gap)
end
local function run(fps)
 local g=S.new(57);g.paused=false;g.inv=9999
 for i=1,fps*60 do S.update(g,{},1/fps) end
 return g
end
local a=run(30)
for _,fps in ipairs({15,60,144,240}) do local b=run(fps);assert(math.abs(a.distance-b.distance)<0.00001);assert(a.rng==b.rng);assert(a.escaped==b.escaped);assert(a.gatePoints==b.gatePoints and a.gatesMissed==b.gatesMissed) end
for i=1,100 do local g=S.new(16001);assert(#g.objects==48 and g.nextMonster>=20);g.paused=false;S.update(g,{},1);assert(g.time<=0.251);S.pause(g);local t=g.time;S.update(g,{},1);assert(g.time==t and g.acc==0) end
local g=S.new(1);g.paused=false;g.inv=0
S.hurt(g);assert(g.hp==2 and g.hit>0);S.hurt(g);assert(g.hp==2)
g.hit=0;S.jump(g);assert(g.jump>0);local j=g.jump;S.jump(g);assert(g.jump==j)
g.inv=0;S.hurt(g);g.inv=0;S.hurt(g);assert(g.status=='over' and g.paused)
g=S.new(1);g.paused=false;g.time=g.nextMonster;S.tick(g,{},1/120);assert(g.monster=='warning');g.mt=0;S.tick(g,{},1/120);assert(g.monster=='chase')
g.gap=37;S.tick(g,{},1/120);assert(g.monster=='lunge');g.x=g.lane+60;g.mt=0;S.tick(g,{},1/120);assert(g.escaped==1 and g.nextMonster>g.time+24)
g.monster='lunge';g.lane=g.x;g.mt=0;S.tick(g,{},1/120);assert(g.status=='over' and g.paused)
for _,kind in ipairs({'rock','tree'}) do g=S.new(1);g.paused=false;g.inv=0;g.jump=0.5;local o=g.objects[1];o.active=true;o.x=g.x;o.y=186;o.kind=kind;S.tick(g,{},1/120);assert(g.hp==(kind=='rock' and 3 or 2)) end
g=S.new(1);g.paused=false;local o=g.objects[1];o.active=true;o.kind='ramp';o.x=g.x;o.y=201.5;S.tick(g,{},1/120);assert(g.jump>1)
for _,fps in ipairs({15,30,60,144,240}) do
 for _,offset in ipairs({-22,0,22,23}) do
  g=S.new(1);g.paused=false;g.speed=225;g.spawn=99
  local ramp=g.objects[1];ramp.active=true;ramp.kind='ramp';ramp.x=g.x+offset;ramp.y=260
  for i=1,math.ceil(fps*0.5) do S.update(g,{},1/fps) end
  if offset<=22 then
   assert(g.jump>0 and g.jumpDuration==1.1 and not ramp.active)
   assert(S.jumpHeight(g)>20 and g.message=='RAMP! BIG AIR! +10 BONUS' and g.messageTime>0)
  else assert(g.jump==0 and ramp.active) end
 end
end
g=S.new(1);g.paused=false;g.speed=1000;g.spawn=99
local ramp=g.objects[1];ramp.active=true;ramp.kind='ramp';ramp.x=g.x;ramp.y=240
S.tick(g,{},0.25);assert(g.jump==1.1 and not ramp.active)
S.tick(g,{},0.1);assert(g.jump<1.1 and S.jumpHeight(g)>0)
g.jump=0.55;assert(S.jumpHeight(g)==42)
g.jump=0;assert(S.jumpHeight(g)==0)
-- Minimal WoW API contract mock: validates input lifetime, not client rendering.
-- Combined bonus, exact-once ramp rewards, no Space farming, final score.
local scored=S.new(9);scored.paused=false;scored.spawn=999;scored.nextGate=999;scored.nextMonster=999
for i=1,20 do scored.jumpCD=0;S.jump(scored) end
assert(scored.bonus==0 and scored.rampsHit==0)
local ramp=scored.objects[1];ramp.active=true;ramp.kind='ramp';ramp.x=scored.x;ramp.y=201.1
S.update(scored,{},1/120);assert(scored.bonus==10 and scored.rampPoints==10 and scored.rampsHit==1)
S.update(scored,{},0.25);assert(scored.bonus==10)
local gate=scored.gates[1];gate.active=true;gate.x=scored.x;gate.y=185.1
S.update(scored,{},1/120);assert(scored.bonus==35 and scored.gatePoints==25)
scored.distance=123.9;S.finish(scored,'TEST')
assert(scored.finalDistance==123 and scored.finalBonus==35 and scored.finalScore==158)
S.update(scored,{},1);S.finish(scored,'AGAIN');assert(scored.finalScore==158 and scored.distance==123.9)
for _,ending in ipairs({'hit','beast'}) do
 local x=S.new(4);x.paused=false;x.distance=100;x.bonus=35;x.inv=0
 if ending=='hit' then x.hp=1;S.hurt(x) else x.monster='lunge';x.lane=x.x;x.mt=0;S.tick(x,{},1/120) end
 assert(x.status=='over' and x.finalScore==135 and x.finalBonus==35)
end
for kind,info in pairs(S.hazards) do
 for _,jumping in ipairs({false,true}) do
  local x=S.new(4);x.paused=false;x.inv=0;x.jump=jumping and 0.5 or 0
  local o=x.objects[1];o.active=true;o.kind=kind;o.x=x.x;o.y=186;S.tick(x,{},1/120)
  assert(x.hp==((jumping and info.jumpable) and 3 or 2))
  x=S.new(4);x.paused=false;x.inv=0;o=x.objects[1];o.active=true;o.kind=kind;o.x=x.x+info.radius+1;o.y=186;S.tick(x,{},1/120);assert(x.hp==3)
 end
end
assert(S.difficulty(-1)==0 and S.difficulty(800)==0.5 and S.difficulty(1600)==1 and S.difficulty(999999)==1)
local counts={};local normalSpawn=S.spawn
for _,distance in ipairs({0,1600,100000}) do
 local count=0
 S.spawn=function(x)
  local empty={};for i=1,48 do empty[i]=not x.objects[i].active end
  normalSpawn(x)
  for i=1,48 do if empty[i] and x.objects[i].active then count=count+1 end end
 end
 local x=S.new(99);x.paused=false;x.inv=999;x.nextMonster=999;x.nextGate=999
 for step=1,3600 do
  x.distance=distance;S.update(x,{},1/60)
  if step%60==0 then
   assert(#x.objects==48 and #x.gates==6 and x.speed<=225)
   for i=1,48 do for j=i+1,48 do local a,b=x.objects[i],x.objects[j]
    if a.active and b.active then assert(math.abs(a.y-b.y)>=64-0.001) end
   end end
  end
 end
 counts[distance]=count
end
S.spawn=normalSpawn
assert(counts[1600]>counts[0]*1.5 and counts[1600]==counts[100000])
local corridor=S.new(10);local fixed=corridor.objects[1];fixed.active=true;fixed.kind='ramp';fixed.x=240;fixed.y=475
for i=1,300 do
 for j=2,48 do corridor.objects[j].active=false end
 S.spawn(corridor)
 for j=2,48 do local o=corridor.objects[j];assert(not o.active or math.abs(o.x-fixed.x)>=54) end
end
-- Gate scoring: once per swept crossing, safe misses, no distance inflation.
for _,fps in ipairs({15,30,60,144,240}) do
 for _,offset in ipairs({-46,0,46,47}) do
  local gateRun=S.new(5);gateRun.paused=false;gateRun.nextGate=999;gateRun.nextMonster=999;gateRun.spawn=999
  local baseline=S.new(5);baseline.paused=false;baseline.nextGate=999;baseline.nextMonster=999;baseline.spawn=999
  local gate=gateRun.gates[1];gate.active=true;gate.resolved=false;gate.x=gateRun.x+offset;gate.y=220
  for i=1,fps do S.update(gateRun,{},1/fps);S.update(baseline,{},1/fps) end
  assert(gateRun.gatePoints==(offset<=46 and 25 or 0))
  assert(gateRun.gatesPassed+gateRun.gatesMissed==1 and gate.resolved)
  assert(gateRun.hp==3 and gateRun.status=='playing' and gateRun.distance==baseline.distance)
  for i=1,fps do S.update(gateRun,{},1/fps) end
  assert(gateRun.gatePoints==(offset<=46 and 25 or 0))
 end
end
local gateRun=S.new(5);gateRun.paused=false;gateRun.hit=0.5;gateRun.spawn=999;gateRun.nextGate=999
local gate=gateRun.gates[1];gate.active=true;gate.x=gateRun.x;gate.y=185.1
S.update(gateRun,{},1/120);assert(gateRun.gatePoints==0 and gateRun.gatesMissed==1)
gateRun=S.new(5);gate=gateRun.gates[1];gate.active=true;gate.x=gateRun.x;gate.y=186
S.update(gateRun,{},1);assert(gate.y==186 and gateRun.gatePoints==0)
gateRun.paused=false;gateRun.speed=1000;gate.y=230;S.tick(gateRun,{},0.25);assert(gateRun.gatePoints==25)
-- Existing and later obstacles cannot occupy the reserved gate corridor.
gateRun=S.new(5)
for i=1,48 do local o=gateRun.objects[i];o.active=true;o.x=20+i*9;o.y=550;o.kind='tree' end
S.spawnGate(gateRun);gate=gateRun.gates[1]
assert(gate.x>=100 and gate.x<=380)
for i=1,48 do local o=gateRun.objects[i];assert(not o.active or math.abs(o.x-gate.x)>=92) end
for n=1,100 do
 for i=1,48 do gateRun.objects[i].active=false end
 S.spawn(gateRun);local o=gateRun.objects[1];assert(not o.active or math.abs(o.x-gate.x)>=92)
end
for i=1,20 do S.spawnGate(gateRun) end
assert(#gateRun.gates==6 and #gateRun.objects==48)
-- Optional gates also work in the air and during a chase without changing it.
gateRun=S.new(5);gateRun.paused=false;gateRun.jump=0.5;gateRun.monster='chase';gateRun.gap=100;gateRun.mt=0
gate=gateRun.gates[1];gate.active=true;gate.x=gateRun.x;gate.y=185.1
S.update(gateRun,{},1/120)
assert(gateRun.gatePoints==25 and gateRun.jump>0 and gateRun.monster=='chase')
gate.y=186;S.update(gateRun,{},1/60);assert(gateRun.gatePoints==25)
gate.active=false;S.spawnGate(gateRun);assert(not gate.resolved and not gate.passed)
assert(S.new(5).gatePoints==0 and S.new(5).gatesPassed==0)
-- Regression: collision at commitment, and collision during an existing lunge.
-- Center permits either dodge; edges must always permit the inward dodge.
for _,case in ipairs({{240,'left'},{240,'right'},{18,'right'},{462,'left'}}) do
 for _,phase in ipairs({'chase','lunge'}) do
  g=S.new(1);g.paused=false;g.inv=0;g.x=case[1];g.speed=205
  g.monster=phase;g.gap=38.1;g.mt=0.1;g.lane=g.x;g.spawn=99
  local o=g.objects[1];o.active=true;o.kind='tree';o.x=g.x;o.y=186
  S.tick(g,{},1/120)
  assert(g.hp==2 and g.hit>0 and g.status=='playing')
  assert((phase=='chase' and g.monster=='chase') or (phase=='lunge' and g.mt==0.8))
  local input={};input[case[2]]=true
  for i=1,210 do S.update(g,input,1/120) end
  assert(g.status=='playing' and g.hp==2 and g.escaped==1)
 end
end

print('PASS: Frost Run 0.1.6 simulation/animation regressions')
