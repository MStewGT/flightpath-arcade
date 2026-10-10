-- Original deterministic Lua 5.1 simulation; no WoW API dependencies.
FlightpathArcade.FrostSim={}
local S=FlightpathArcade.FrostSim
local abs,min,max=math.abs,math.min,math.max
S.hazards={tree={radius=17},treeTall={radius=17,height=64},deadTree={radius=12,height=64},rock={radius=14,jumpable=true},stump={radius=12,jumpable=true},snowman={radius=12}}
local hazardKinds={'tree','treeTall','deadTree','rock','stump','snowman'}
function S.difficulty(distance) return min(1,max(0,distance/1600)) end
function S.spawnInterval(g)
 local d=S.difficulty(g.distance)
 return 0.80-0.50*d+S.random(g)*(0.35-0.21*d)
end
-- Rendering stays uphill even when recovery lets the simulated gap go negative.
function S.monsterY(g) return max(35,185-max(38,g.gap)) end
function S.jumpHeight(g)
 if g.jump<=0 then return 0 end
 local progress=max(0,min(1,1-g.jump/(g.jumpDuration or 0.8)))
 return 4*progress*(1-progress)*(g.jumpDuration==1.1 and 42 or 28)
end
function S.random(g)
 g.rng=(g.rng*16807)%2147483647
 return g.rng/2147483647
end
-- Private course generator: advance once per run, never reseed per click.
-- Park-Miller's nonzero cycle guarantees different seeds for rapid restarts.
function S.seedSource(initial)
 local state=math.floor(abs(tonumber(initial) or 16001))%2147483646+1
 return function() state=(state*16807)%2147483647;return state end
end
function S.new(seed)
 seed=tonumber(seed) or 16001
 seed=math.floor(abs(seed))%2147483646+1
 local g={seed=seed,rng=seed,x=240,speed=110,distance=0,time=0,acc=0,
 status='playing',paused=true,hp=3,jump=0,jumpCD=0,inv=3,hit=0,
 spawn=0.9,nextMonster=20,monster='quiet',mt=0,mx=240,gap=110,
 escaped=0,objects={},gates={},gatePoints=0,rampPoints=0,bonus=0,rampsHit=0,gatesPassed=0,gatesMissed=0,nextGate=5,gateFlash=0,message='Click Ski to capture keys',messageTime=0}
 for i=1,48 do g.objects[i]={active=false} end
 for i=1,6 do g.gates[i]={active=false} end
 g.nextMonster=20+S.random(g)*12
 return g
end
function S.pause(g) g.paused=true;g.acc=0 end
function S.jump(g)
 if g.status=='playing' and not g.paused and g.jumpCD<=0 and g.hit<=0 then
  g.jump=0.8;g.jumpDuration=0.8;g.jumpCD=1.15
 end
end
function S.spawn(g)
 for i=1,#g.objects do local o=g.objects[i]; if not o.active then
  o.active=true;o.x=28+S.random(g)*424;o.y=550
  local r=S.random(g)
  o.kind=r<0.87 and hazardKinds[math.floor(r/0.87*6)+1] or 'ramp'
  for j=1,#g.objects do local other=g.objects[j]
   if j~=i and other.active then
    local dy=abs(other.y-o.y)
    -- One obstacle per vertical band prevents walls, even when braking.
    -- Keep a clear approach and landing lane around every ramp.
    if dy<64 or ((o.kind=='ramp' or other.kind=='ramp') and dy<110 and abs(o.x-other.x)<54) then o.active=false;break end
   end
  end
  for j=1,#g.gates do local gate=g.gates[j]
   if gate.active and abs(o.y-gate.y)<90 and abs(o.x-gate.x)<92 then o.active=false;break end
  end
  return
 end end
end
function S.spawnGate(g)
 for i=1,#g.gates do local gate=g.gates[i];if not gate.active then
  gate.active=true;gate.resolved=false;gate.passed=false;gate.x=100+S.random(g)*280;gate.y=550
  -- Reserve a clear approach/exit corridor, including pole margins. Existing
  -- objects are retired; later spawns respect the same corridor.
  for j=1,#g.objects do local o=g.objects[j]
   if o.active and abs(o.y-gate.y)<90 and abs(o.x-gate.x)<92 then o.active=false end
  end
  return
 end end
end
function S.finish(g,message)
 if g.status=='over' then return end
 g.status='over';g.message=message;g.finalDistance=math.floor(g.distance);g.finalBonus=g.bonus
 g.finalScore=g.finalDistance+g.finalBonus;S.pause(g)
end
function S.hurt(g)
 if g.inv>0 then return end
 g.hp=g.hp-1;g.inv=2;g.hit=0.75;g.speed=65;g.jump=0
 g.message='WIPEOUT!';g.messageTime=1.5
 if g.hp<=0 then S.finish(g,'RUN OVER - three wipeouts') end
end
local function escaped(g)
 g.monster='quiet';g.escaped=g.escaped+1;g.nextMonster=g.time+24+S.random(g)*18
 g.message='ESCAPED!';g.messageTime=2
end
function S.tick(g,input,dt)
 g.time=g.time+dt
 for _,k in ipairs({'jump','jumpCD','inv','hit','messageTime','gateFlash'}) do g[k]=max(0,g[k]-dt) end
 local steer=(input.right and 1 or 0)-(input.left and 1 or 0)
 local target=input.brake and 95 or (steer~=0 and 165 or 225)
 if g.hit>0 then target=65;steer=0 end
 g.speed=g.speed+(target-g.speed)*min(1,dt*2)
 g.x=max(18,min(462,g.x+steer*205*dt))
 g.distance=g.distance+g.speed*dt*0.12
 g.spawn=g.spawn-dt
 if g.spawn<=0 then S.spawn(g);g.spawn=S.spawnInterval(g) end
 for i=1,#g.objects do local o=g.objects[i];if o.active then
  local oldY=o.y
  o.y=o.y-g.speed*dt
  -- Launch when the ramp lip crosses the tips of the skis. A swept crossing
  -- cannot skip the trigger at high speed or during a large direct tick.
  if o.kind=='ramp' then
   if oldY>=201 and o.y<=201 and abs(o.x-g.x)<=22 and g.hit<=0 then
    g.jump=1.1;g.jumpDuration=1.1;g.jumpCD=1.3;o.active=false
    g.rampsHit=g.rampsHit+1;g.rampPoints=g.rampPoints+10;g.bonus=g.bonus+10
    g.message='RAMP! BIG AIR! +10 BONUS';g.messageTime=1.1
   end
  elseif abs(o.y-185)<16 and abs(o.x-g.x)<S.hazards[o.kind].radius then
   if not (g.jump>0.12 and S.hazards[o.kind].jumpable) then S.hurt(g);o.active=false end
   if g.status~='playing' then return end
  end
  if o.y < -30 then o.active=false end
 end end
 if g.status~='playing' then return end
 if g.time>=g.nextGate then S.spawnGate(g);g.nextGate=g.time+8+S.random(g)*3 end
 for i=1,#g.gates do local gate=g.gates[i];if gate.active then
  local oldY=gate.y;gate.y=gate.y-g.speed*dt
  if not gate.resolved and oldY>=185 and gate.y<=185 then
   gate.resolved=true
   -- Pole centers are 120px apart. Leave 14px skier clearance at each pole.
   gate.passed=abs(g.x-gate.x)<=46 and g.hit<=0
   if gate.passed then g.gatesPassed=g.gatesPassed+1;g.gatePoints=g.gatePoints+25;g.bonus=g.bonus+25;g.gateFlash=1.2
   else g.gatesMissed=g.gatesMissed+1 end
  end
  if gate.y < -30 then gate.active=false end
 end end
 if g.monster=='quiet' and g.time>=g.nextMonster then
  g.monster='warning';g.mt=3;g.mx=g.x;g.gap=110
 elseif g.monster=='warning' then
  g.mt=g.mt-dt
  if g.mt<=0 then g.monster='chase';g.mt=0 end
 elseif g.monster=='chase' then
  g.mt=g.mt+dt;g.mx=g.mx+max(-110*dt,min(110*dt,g.x-g.mx))
  g.gap=g.gap+(g.speed-205)*dt
  if g.gap>=210 then escaped(g)
  elseif g.gap<=38 and g.hit<=0 then g.monster='lunge';g.mt=0.8;g.lane=g.x
  elseif g.mt>16 then escaped(g) end
 elseif g.monster=='lunge' then
  -- Wipeouts must never consume the player's dodge window. Keep the
  -- committed lane fixed, and grant a full window after control returns.
  -- At either boundary the opposite direction always has >34px of room.
  if g.hit>0 then g.mt=0.8 else g.mt=g.mt-dt end
  if g.mt<=0 then
   if abs(g.x-g.lane)<34 then S.finish(g,'CAUGHT BY THE SNOW BEAST!')
   else escaped(g) end
  end
 end
end
function S.update(g,input,elapsed)
 if g.paused or g.status~='playing' then return end
 -- Bound catch-up after a hitch; discard excess wall time, never teleport.
 g.acc=g.acc+max(0,min(elapsed,0.25))
 local n=0
 while g.acc+1e-9>=1/120 and n<30 do
  g.acc=g.acc-1/120;S.tick(g,input,1/120);n=n+1
  if g.paused then g.acc=0;break end
 end
end
