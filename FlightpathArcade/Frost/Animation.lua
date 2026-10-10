-- Presentation only: no simulation fields, timers, RNG or collisions mutated.
FlightpathArcade.FrostAnimation={}
local A=FlightpathArcade.FrostAnimation
function A.new() return {lastJump=0,landingUntil=0} end
function A.monsterY(g)
 -- Keep the attack pose readable even when the skier is lifted by a jump.
 return math.min(FlightpathArcade.FrostSim.monsterY(g),185-FlightpathArcade.FrostSim.jumpHeight(g)-38)
end
function A.terrain(g)
 local offset=math.floor(g.distance/0.12)%768
 local first=math.min(520,768-offset)
 return offset,first,520-first
end
function A.sample(v,g,input)
 if v.lastJump>0 and g.jump<=0 and g.hit<=0 then v.landingUntil=g.time+0.16 end
 if g.hit>0 then v.landingUntil=0 end
 v.lastJump=g.jump
 local steer=(input.right and 1 or 0)-(input.left and 1 or 0)
 local dx=g.hit>0 and 0 or steer*(g.jump>0 and 2 or 1)
 local dy=(g.hit<=0 and g.jump<=0 and g.time<v.landingUntil) and 2 or 0
 local pose=g.jump>0 and 'skierAir' or 'skier'
 -- Recovery flashes already communicate impact; do not label arms-up as fallen.
 if g.hit>0 then dy=2 end
 local beast=g.monster=='lunge' and 'monsterAttack' or (math.floor(g.time*5)%2==0 and 'monster' or 'monster2')
 local bob=g.monster=='chase' and math.floor(g.time*10)%2 or 0
 return pose,dx,dy,beast,bob
end
