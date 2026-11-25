-- Final oculto: condición de Dark Six en la caja de música y escena del puente.
local Secret=require('secret_ending')
local function pawn(path,at)
 local p={path=path,at=at,anim=nil}
 function p:GetFullName() return self.path end
 function p:K2_GetActorLocation() return self.at end
 return p
end
local tower='/Game/Levels/Transmission/PLVL_Transmission.PersistentLevel.BP_PlayerPawn_C'
local gap={X=-809,Y=14000,Z=28700}
local function setup(unlocked)
 local calls={pull=0,frame={},fade=0,card=0,credits=0,release=0,logs={}}
 local api={live=function(v) return v~=nil end,same=function(a,b) return a==b end,
  log=function(s) calls.logs[#calls.logs+1]=s end,
  animation=function(p) return p.anim end,unlocked=function() return unlocked end,
  pull=function() calls.pull=calls.pull+1 return 2 end,
  frame=function(_,progress) calls.frame[#calls.frame+1]=progress end,
  fade=function() calls.fade=calls.fade+1 end,card=function() calls.card=calls.card+1 end,
  credits=function() calls.credits=calls.credits+1 return calls.creditsWork~=false end,
  release=function() calls.release=calls.release+1 end}
 return Secret.new(api),calls
end
local first,second=pawn(tower,{X=0,Y=0,Z=0}),pawn(tower,{X=0,Y=0,Z=0})

local s=setup(true)
second.anim='ANIM_Player_HittingMusicBoxVoidLong';s:observe(first,second,true,true)
second.anim=nil;first.anim='ANIM_Player_WakeUpAfterLastHitMusicBox';s:observe(first,second,true,true)
assert(s:darkSixRetired(true) and s.armed,'the last hit by Dark Six with the achievement arms the hidden ending')

local p1=setup(true)
second.anim='ANIM_Player_HittingMusicBoxVoidLong';p1:observe(first,second,true,true)
second.anim=nil;first.anim='ANIM_Player_HittingMusicBoxRecoil';p1:observe(first,second,true,true)
assert(not p1:darkSixRetired(true),'a final hit by P1 keeps the normal ending')

-- El juego reproduce el último golpe en P1 aunque el hacha la lleve P2.
local carried,ccalls=setup(true)
ccalls.held=second
carried.api.holdsWeapon=function(p) return p==ccalls.held end
first.anim='ANIM_Player_HittingMusicBoxRecoil';second.anim=nil;carried:observe(first,second,true,true)
assert(carried.lastHitter==2,'a hit played on P1 while P2 holds the axe counts for Dark Six')
first.anim=nil;carried:observe(first,second,true,true)
ccalls.held=first;first.anim='ANIM_Player_HittingMusicBoxRecoil';carried:observe(first,second,true,true)
assert(carried.lastHitter==1,'a hit while P1 holds the axe counts for P1')
ccalls.held=second;carried:observe(first,second,true,true)
assert(carried.lastHitter==1,'the hitter is decided when the swing starts')
first.anim=nil

local swinging=setup(true)
swinging.api.p2Swing=function() return true end
first.anim='ANIM_Player_HittingMusicBoxRecoil';swinging:observe(first,second,true,true)
assert(swinging.lastHitter==2,'the P2 event swing signal credits Dark Six')
first.anim=nil

local locked=setup(false)
first.anim=nil;second.anim='ANIM_Player_HittingMusicBoxVoidLong';locked:observe(first,second,true,true)
assert(not locked:darkSixRetired(true),'without the hidden achievement the ending stays normal')

local mono=setup(true)
mono:observe(first,second,true,false)
assert(not mono:darkSixRetired(false),'two-Mono mode never opens the hidden ending')

-- Escena del puente.
local hero=pawn(tower,gap)
local scene,calls=setup(true)
scene.armed=true
assert(scene:update(hero,10,true,false)==nil,'the scene waits for Six to catch Mono')
hero.anim='ANIM_Player_GapHelpSixBetrayal'
assert(scene:update(hero,11,true,false)=='hold' and calls.pull==1 and scene.phase=='pull','Six pulls Mono up instead of dropping him')
assert(scene:update(hero,12,true,true)=='hold' and scene.phase=='pull','pausing holds the scene')
scene:update(hero,13.5,true,false)
calls.hugs=0;scene.api.hug=function() calls.hugs=calls.hugs+1 end
assert(scene.phase=='together','after the pull both stay together on the bridge')
scene:update(hero,14,true,false)
assert(calls.hugs==1,'the together shot poses the hug')
scene:update(hero,13.5+Secret.timing.together,true,false)
assert(scene.phase=='fade' and calls.fade==1,'the shot fades to black')
scene:update(hero,13.5+Secret.timing.together+Secret.timing.fade,true,false)
assert(scene.phase=='card' and calls.card==1,'the ending text appears in the dark')
scene:update(hero,40,true,false)
assert(scene.phase=='done' and calls.credits==1 and not scene.armed and calls.release==0,'the game credits close the hidden ending')
assert(calls.frame[#calls.frame]==1,'the camera finishes the push-in before the fade')

local failing,fcalls=setup(true)
fcalls.creditsWork=false
failing.armed=true;hero.anim='ANIM_Player_GapHelpSixBetrayal'
for t=1,60 do failing:update(hero,t,true,false) end
assert(failing.phase=='done' and fcalls.release==1,'if the credits cannot open the game gets its camera back')

local menu,mcalls=setup(true)
menu.armed=true;menu:update(hero,1,true,false)
menu:update(hero,2,false,false)
assert(menu.armed and not menu.phase and mcalls.release==1,'returning to the menu stops the scene but keeps the ending for a retry')

-- El final queda guardado entre sesiones y se borra al verlo.
local disk=false
local function stored()
 local api={live=function(v) return v~=nil end,same=function(a,b) return a==b end,log=function() end,
  animation=function(p) return p.anim end,unlocked=function() return true end,
  pull=function() return 2 end,frame=function() end,fade=function() end,card=function() end,
  credits=function() return true end,release=function() end,
  restore=function() return disk end,store=function(on) disk=on end}
 return Secret.new(api)
end
local saving=stored()
second.anim='ANIM_Player_HittingMusicBoxVoidLong';saving:observe(first,second,true,true);second.anim=nil
saving:darkSixRetired(true)
assert(disk==true and stored().armed,'an armed ending survives closing the game')
local replay=stored()
first.anim='ANIM_Player_HittingMusicBoxRecoil';replay:observe(first,second,true,true);first.anim=nil
replay:darkSixRetired(true)
assert(disk==false and not replay.armed,'a later final hit by P1 clears the saved ending')
disk=true
local watched=stored()
for t=1,60 do watched:update(hero,t,true,false) end
assert(watched.phase=='done' and disk==false,'watching the ending clears it')

local away=setup(true)
away.armed=true
local elsewhere=pawn('/Game/Levels/School/PLVL_School.X',gap);elsewhere.anim='ANIM_Player_GapHelpSixBetrayal'
assert(away:update(elsewhere,1,true,false)==nil and away.armed,'the scene only starts on the Tower bridge')
print('PASS: hidden ending needs the hidden achievement, Six mode and the last hit by Dark Six, then plays the bridge scene and credits.')
