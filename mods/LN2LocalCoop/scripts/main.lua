-- The Second Shadow: local co-op for Little Nightmares II.
local UE=require('UEHelpers')
local Input=require('coop_input')
local Call=require('coop_call')
local Driver=require('mono_driver')
local Actions=require('mono_actions')
local PrimaryLink=require('primary_link')
local PrimaryRecovery=require('primary_recovery')
local Death=require('coop_death')
local Separation=require('coop_separation')
local SeparationFX=require('separation_fx')
local Spawn=require('coop_spawn')
local SpawnNative=require('spawn_native')
local UI=require('coop_ui')
local Menu=require('coop_menu')
local MenuSession=require('menu_session')
local NativeInput=require('native_input')
local Bindings=require('coop_bindings')
local TPBindings=require('tp_bindings')
local Teleport=require('coop_teleport')
local TPNative=require('tp_native')
local Gamepad=require('coop_gamepad')
local Hats=require('coop_hats')
local SixAppearance=require('six_appearance')
local Camera=require('coop_camera')
local CinematicTrace=require('cinematic_trace')
local HunterTrace=require('hunter_trace')
local Cinematics=require('coop_cinematics')
local CinematicNative=require('cinematic_native')
local LedgeRescue=require('hand_rescue_native')
local RescueInput=require('rescue_input')
local Events=require('coop_events')
local ledgeRescue,primaryRecovery
local state={enabled=false,menu=false,menuPage='home',preset=1,cameraMode=1,split=false,showStatus=true,status='Desactivado',appearance={},tp={effects=true},eventRedirect=false}
local function log(s) print('[LN2LocalCoop] '..s..'\n') end
local function live(o) return o~=nil and o:IsValid() and not o:HasAnyInternalFlags(EInternalObjectFlags.PendingKill) end
local function same(a,b) return live(a) and live(b) and a:GetAddress()==b:GetAddress() end
local function world(a,b) return live(a) and live(b) and same(a:GetWorld(),b:GetWorld()) end
local call=Call.new(live,same,log)
local previousSplitLayout
local appliedSplitLayout
local previousOcclusionQueries
local function setSplit(pc,enabled)
 local layout=state.cameraMode==4 and 1 or 0 -- TwoPlayerSplitscreenLayout: horizontal / vertical.
 local changed=state.split~=enabled or (enabled and appliedSplitLayout~=layout)
 if not changed and (enabled or previousOcclusionQueries==nil) then return false end
 local viewport=UE.GetGameViewportClient()
 local context=live(pc) and pc or (live(viewport) and viewport.World or nil)
 if changed then
  local settings=UE.GetGameMapsSettings()
  if enabled then
   if not state.split then previousSplitLayout=settings.TwoPlayerSplitscreenLayout end
   settings.TwoPlayerSplitscreenLayout=layout
   appliedSplitLayout=layout
  elseif previousSplitLayout~=nil then
   settings.TwoPlayerSplitscreenLayout=previousSplitLayout
   previousSplitLayout=nil
   appliedSplitLayout=nil
  end
  settings.bUseSplitscreen=enabled
  if live(context) then UE.GetGameplayStatics():SetForceDisableSplitscreen(context,false) end
  state.split=enabled
 end
 if live(context) then
  local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
  local controller=live(pc) and pc or nil
  local variable='r.AllowOcclusionQueries'
  -- The original occlusion queries can incorrectly hide geometry in P1's split view.
  if enabled and previousOcclusionQueries==nil then
   previousOcclusionQueries=system:GetConsoleVariableIntValue(variable)
   if previousOcclusionQueries~=0 then system:ExecuteConsoleCommand(context,variable..' 0',controller) end
  elseif not enabled and previousOcclusionQueries~=nil then
   if previousOcclusionQueries~=0 then
    system:ExecuteConsoleCommand(context,variable..' '..previousOcclusionQueries,controller)
   end
   previousOcclusionQueries=nil
  end
 end
 return changed
end
local listenerError
local function restorePrimaryListener(first,second)
 if not (live(first) and live(second) and live(second.Player) and second.Player.ControllerId==1) then return end
 local visible,hidden=first.PlayerCameraManager,second.PlayerCameraManager
 if not world(visible,hidden) or same(visible,hidden) then return end
 local path=hidden:GetFullName():match('^%S+ (.+)$')
 if not path then return end
 local listener=StaticFindObject(path..'.DefaultListener')
 if not (live(listener) and same(listener:GetOuter(),hidden)) then return end
 local audio=StaticFindObject('/Script/Helios.Default__AudioSystemsBlueprintLibrary')
 if not live(audio) then return end
 local ok,err=pcall(audio.RegisterDefaultListener,audio,visible)
 if ok then
  listenerError=nil
  log('Audio espacial anclado a la camara de P1')
 elseif err~=listenerError then
  listenerError=err
  log('Oyente de audio: '..tostring(err))
 end
end
local ui=UI.new(live,Menu,log)
local menuSession=MenuSession.new(UE.GetGameplayStatics,
 function()return StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')end,live,same)
local function p1()
 local viewport=UE.GetGameViewportClient()
 if not live(viewport) or not live(viewport.World) then return end
 local pc=UE.GetGameplayStatics():GetPlayerController(viewport.World,0)
 if live(pc) and live(pc.Player) and pc.Player.ControllerId==0 then return pc end
end
local function down(pc,key) return pc:IsInputKeyDown({KeyName=FName(key)}) end
local root=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
local preferences=root and (root..'preferences.ini')
local native=NativeInput.new(root,live,log)
local function menuDown(pc,key)
 local code=RescueInput.code(key)
 if code and native.api and native.api.key_down then return native.api.key_down(code) end
 return down(pc,key)
end
local camera=Camera.new(native.api,live,log)
local savedPreferences=''
if preferences then
 local f=io.open(preferences,'r')
 if f then local data=f:read('*a'); f:close()
  local n=tonumber(data:match('preset=(%d+)')); if n and Input.presets[n] then state.preset=n end
  state.showStatus=data:match('showStatus=(%d)')~='0'
  savedPreferences=data
 end
end
local separation=Separation.new(('\n'..savedPreferences):match('\nseparation=(%d)')=='1')
state.language=('\n'..savedPreferences..'\n'):match('\nui%.language=en\r?\n') and 'en' or 'es'
state.cameraMode=tonumber(('\n'..savedPreferences..'\n'):match('\ncamera%.mode=([1234])\r?\n')) or 1
state.fillScreen=('\n'..savedPreferences..'\n'):match('\ncamera%.fill=1\r?\n')~=nil
state.airRescue=('\n'..savedPreferences..'\n'):match('\nrescue%.air=0\r?\n')==nil
state.jumpAssist=('\n'..savedPreferences..'\n'):match('\nrescue%.jump=0\r?\n')==nil
state.separation=separation
state.eventRedirect=('\n'..savedPreferences..'\n'):match('\nevents%.redirect=1\r?\n')~=nil
local controls=Bindings.new(Input.presets[state.preset],savedPreferences)
local tpControls
state.controls=controls
local gamepad=Gamepad.new(native.api and native.api.gamepad,
 function() return UE.GetGameMapsSettings() end, tonumber(savedPreferences:match('pad%.owner=(%d+)')),log)
state.gamepad=gamepad
local function p2Input(pc)
 return gamepad:input() or Input.sample(controls.bindings,function(key)
  if ledgeRescue and ledgeRescue.control.active and native.api and native.api.key_down then
   local code=RescueInput.code(key)
   return code and native.api.key_down(code)or false
  end
  return pc and down(pc,key)
 end)
end
state.tp.effects=savedPreferences:match('tp%.effects=(%d)')~='0'
for key,value in ('\n'..savedPreferences):gmatch('\nappearance%.([%w_]+)=([^\r\n]*)')do
 state.appearance[key]=value
end
local hats=Hats.new(live,same,state.appearance,log)
state.hats=hats
state.playAsSix=state.appearance.six=='1'
local sixAppearance=SixAppearance.new(live,same,log)
local function syncAppearance(second,pawn,first)
 if state.playAsSix then
  local applied,reason=sixAppearance:sync(second,pawn,first)
  state.sixAppearanceFailed=not applied and reason~=nil
  local ok,err=pcall(hats.hideForSix,hats,second,pawn,first)
  if not ok and err~=sixAppearance.hatError then log('Sombrero en modo Six: '..tostring(err)) end
  sixAppearance.hatError=not ok and err or nil
 else
  if sixAppearance.original then sixAppearance:restore() end
  hats:sync(second,pawn,first)
 end
end
local function save()
 local f=preferences and io.open(preferences,'w')
 if f then
  f:write('preset='..state.preset..'\nshowStatus='..(state.showStatus and '1' or '0')..'\n'..controls:serialize())
  if tpControls then f:write(tpControls:serialize()..'tp.effects='..(state.tp.effects and '1'or'0')..'\n')end
  f:write('pad.owner='..gamepad.owner..'\nseparation='..(separation.enabled and '1' or '0')..'\ncamera.mode='..state.cameraMode..'\n')
  f:write('camera.fill='..(state.fillScreen and '1' or '0')..'\n')
  f:write('ui.language='..state.language..'\n')
  f:write('rescue.air='..(state.airRescue and '1' or '0')..'\n')
  f:write('rescue.jump='..(state.jumpAssist and '1' or '0')..'\n')
  f:write('events.redirect='..(state.eventRedirect and '1' or '0')..'\n')
  local appearanceKeys={}
  for key,value in pairs(state.appearance)do
   if type(key)=='string'and key:match('^[%w_]+$')and type(value)=='string'and not value:find('[\r\n]')then appearanceKeys[#appearanceKeys+1]=key end
  end
  table.sort(appearanceKeys)
  for _,key in ipairs(appearanceKeys)do f:write('\nappearance.'..key..'='..state.appearance[key])end
  f:write('\n');f:close()
 end
end
local function rescue(pawn,pc)
 local at=pc.Pawn:K2_GetActorLocation()
 local right=UE.GetKismetMathLibrary():GetRightVector(pc.PlayerCameraManager:GetCameraRotation())
 at.X,at.Y=at.X+right.X*100,at.Y+right.Y*100
 pawn:K2_SetActorLocation(at,true,{},true)
end
local nativeActions=Actions.new({
 key=function(name)
  local lib=StaticFindObject('/Script/Helios.Default__ChalkboardBlueprintsLibrary')
  return lib:MakeChalkboardSectionKeyFromName(FName('/FlowControl/'..name),{mType={PinCategory=FName('bool')}})
 end,
 start=function(a,key) a:BlueprintStartAction(key) end,
 hold=function(a,key) a:BlueprintHoldAction(key) end,
 stop=function(a,key) a:BlueprintStopAction(key) end,
 jump=function(held,wasHeld) return native:jump(held,wasHeld) end,
 crouch=function(a,held) native:crouch(held) end,
 use=function(a,held) native:use(held) end,
 gadget=function(held) native:gadget(held) end,
})
local cinematics
local driver=Driver.new({live=live,same=same,sameWorld=world,
 existing=function(pc)
  local second=UE.GetGameplayStatics():GetPlayerController(pc,1)
  return live(second) and second or nil
 end,
 identity=function(pc) return pc.Player end,
 resolve=function(player)
  local pc=player.PlayerController
  return live(pc) and same(pc.Player,player) and pc or nil
 end,
 clock=function(pc) return UE.GetGameplayStatics():GetRealTimeSeconds(pc) end,
 restart=function(pc,first)
  local mode=first:GetWorld().AuthorityGameMode
  if live(mode) then mode:RestartPlayer(pc) end
 end,
 create=function(pc)
  UE.GetGameMapsSettings().bUseSplitscreen=false
  local second=UE.GetGameplayStatics():CreatePlayer(pc,1,true)
  restorePrimaryListener(pc,second)
  return second
 end,
 configure=function(second,pawn,first)
   local animator=second.mBodyAnimator
   if not live(second.Player)or second.Player.ControllerId~=1
    or not same(pawn.Controller,second)or not live(animator)or not same(animator.mPawnSelf,pawn)
    or not live(pawn.CharacterMovement)or not live(pawn.mAnimationControlComponent)then return false end
   PrimaryLink.ensure(second,{live=live,same=same,isMono=function(pawn)
    return pawn:GetFullName():find('BP_PlayerPawn_C',1,true)~=nil
   end})
   if native.api and not native:bind(second,first)then return false end
   if primaryRecovery then primaryRecovery:invalidate() end
   nativeActions:release(nil)
   second:SetActorTickEnabled(false)
   camera:stop()
   if native.api and state.cameraMode==1 then camera:start() end
   syncAppearance(second,pawn,first)
 end,
 park=function(pc)
  call:release()
  if ledgeRescue then ledgeRescue:reset()end
  if cinematics then cinematics:reset()end
  native:vent(false)
  native:cage()
  camera:stop()
  assert(live(pc.Player) and pc.Player.ControllerId==1,'No se retirara un personaje ajeno al jugador 2')
  local first=p1()
  setSplit(first,false)
  local pawn=pc.Pawn
  assert(not(first and same(pawn,first.Pawn)),'No se retirara al primer Mono')
  hats:cleanup()
  sixAppearance:restore()
  if live(pawn) then
   pc:UnPossess()
   pawn:K2_DestroyActor()
  end
 end,
 isMono=function(pawn) return pawn:GetFullName():find('BP_PlayerPawn_C',1,true)~=nil end,
 rescue=rescue,
 stop=function(pawn)
  native:vent(false)
  native.direction={X=0,Y=0,Z=0}
  native:move(0,0)
  if live(pawn.Controller) then
   local animator=pawn.Controller.mBodyAnimator
   if live(animator) then nativeActions:release(animator); animator:ClearMoveInput()
   else nativeActions:release(nil) end
  else nativeActions:release(nil)
  end
  if pawn.CharacterMovement.MovementMode==1 then pawn.CharacterMovement:StopMovementImmediately() end
 end,
 move=function(pawn,direction)
  native.direction=direction
  -- LN2's locomotion reads its animation/input chalkboard, not only Pawn input.
  local animator=pawn.Controller.mBodyAnimator
  assert(live(animator),'El segundo Mono no tiene su adaptador de locomocion')
  animator:SetMoveInput(direction)
 end,
 actions=function(pawn,input)
  native:move(input.x or 0,input.y or 0)
  nativeActions:update(pawn.Controller.mBodyAnimator,input)
  native:vent(input.grab and native:foreground())
 end,
})
local events=Events.new({live=live,same=same,p1=p1,driver=driver,native=native,log=log})
local previous
local function status(s) state.status=s; if previous~=s then previous=s; log(s) end end
local separationFX=SeparationFX.new(live,same,log,native.api)
local function clearSeparation()
 separation:reset();separationFX:clear()
end
local spawnNative=SpawnNative.new({live=live,same=same,world=world,driver=driver,p1=p1,log=log,session=state})
local spawn=Spawn.new(spawnNative:api())
local cinematicTrace=CinematicTrace.new({live=live,same=same,world=world,p1=p1,
 driver=driver,state=state,log=log,phase=function()return spawn.phase end})
cinematicTrace:install()
local hunterTrace=HunterTrace.new({live=live,same=same,world=world,p1=p1,driver=driver,state=state,log=log})
hunterTrace:install()
local death=Death.new({live=live,same=same,sameWorld=world,
 alive=function(pawn)return pawn:IsAlive()end,
 begin=function(who,_,lost)
  clearSeparation()
  state.menu=false;state.menuPage='home';controls.capture=nil
  local pc=p1();spawn:invalidate(pc and pc.Pawn)
  driver:stop();driver:remove()
  log(who..(lost and ' se perdio fuera de camara' or ' murio')..'; esperando el checkpoint para ambos')
 end,
 restart=function(pc,who)
  local lib=StaticFindObject('/Script/Helios.Default__SpawningSystemsLibrary')
  assert(live(lib),'No se encontro el sistema de reaparicion')
  lib:RespawnPlayer(pc)
  log('Reinicio compartido solicitado para '..who)
 end})
local tpNative=TPNative.new({UE=UE,live=live,same=same,world=world,p1=p1,driver=driver,
 state=state,spawn=spawn,death=death,log=log,input=function() return p2Input(p1()) end})
tpControls=TPBindings.new(controls,savedPreferences,function(key)return tpNative:primaryKeys()[key]end)
state.tp.controls=tpControls
local teleport=Teleport.new(tpNative:api())
local cinematicNative=CinematicNative.new({UE=UE,live=live,same=same,world=world,
 p1=p1,driver=driver,state=state,spawn=spawn,death=death,log=log,
 clear=function(...)return tpNative:clear(...)end,active=function()return cinematics and cinematics.active end})
cinematics=Cinematics.new(cinematicNative:api())
cinematicNative:install()
ledgeRescue=LedgeRescue.new({UE=UE,live=live,same=same,world=world,p1=p1,driver=driver,
 state=state,spawn=spawn,death=death,gamepad=gamepad,log=log,
 clock=function()local pc=p1();return pc and UE.GetGameplayStatics():GetRealTimeSeconds(pc)or os.clock()end,
 physicalKey=native.api and native.api.key_down,
 offerHeld=function(role)
  local key=role==1 and 'F1' or 'F2'
  local conflict=false
  for _,value in pairs(controls.bindings)do if value==key then conflict=true end end
  for _,value in pairs(tpControls.bindings)do if value==key then conflict=true end end
  local keyboard=not conflict and native.api and native.api.key_down and native.api.key_down(role==1 and 112 or 113)
  local pad=gamepad.owner==role and gamepad.sample
  return keyboard==true or (pad and pad.assist==true)or false
 end,
 foreground=function()return native:foreground()end,input=function()return p2Input(p1())end})
local function disable()
 ledgeRescue:reset()
 state.enabled=false; setSplit(p1(),false); clearSeparation();gamepad:restore(); death:reset();spawn:disable(); driver:stop(); driver:remove(); status('Desactivado')
end
local function toggle()
 if state.enabled then disable() else
  state.enabled=true
  local pc=p1()
  local early=not spawnNative:playingGame(pc)or not(pc and live(pc.Pawn)and pc.Pawn:GetFullName():find('BP_PlayerPawn_C',1,true))
  spawn:enable(early);status('Esperando una partida')
  if state.tp.effects then pcall(function()tpNative:prepareEffects()end)end
 end
end
local function safe(fn)
 return function(...)
  local ok,err=pcall(fn,...)
  if not ok then
   state.menu=false;pcall(menuSession.close,menuSession)
   clearSeparation()
   pcall(function() gamepad:restore() end)
   pcall(function() setSplit(p1(),false) end)
   state.enabled=false; pcall(function() spawn:disable();driver:stop(); driver:remove() end)
   status('No se pudo activar el cooperativo'); log(tostring(err))
  end
 end
end
RegisterHook('/Script/Helios.SpawningSystemsLibrary:RespawnPlayer',safe(function(_,context)
 local pc=p1();local caller=context:get()
 if state.enabled and pc and (same(caller,pc)or world(caller,pc))then
  clearSeparation();spawn:invalidate(pc.Pawn)
 end
end))
local keys,recent,held={},{},{}
local callUntil,callFirst,callSecond
local function trigger(name,fn)
 if not native:foreground() then return end
 local pc=p1()
 local level=pc and pc:GetWorld()
 local address=live(level) and level:GetAddress() or nil
 local t=pc and UE.GetGameplayStatics():GetRealTimeSeconds(pc) or os.clock()
 local last=recent[name]
 if last and last.world==address and t>=last.time and t-last.time<.25 then return end
 recent[name]={world=address,time=t}
 fn()
end
local function bind(key,name,fn)
 keys[name]=fn
 RegisterKeyBindAsync(key,function() ExecuteInGameThread(safe(function() trigger(name,fn) end),EGameThreadMethod.ProcessEvent) end)
end
local function homeMenu()return state.menu and state.menuPage=='home'end
local function playMenu()return state.menu and state.menuPage=='play'end
local function cameraMenu()return state.menu and state.menuPage=='camera'end
local function extrasMenu()return state.menu and state.menuPage=='extras'end
local function canSelectSix(pc)
 return spawnNative:gameState(pc)==4 -- EHeliosGameState::MainMenu
  and not (live(pc.Pawn) and pc.Pawn:GetFullName():find('BP_PlayerPawn_C',1,true))
end
local function selectCamera(mode)
 if state.cameraMode==mode then return end
 state.cameraMode=mode
 camera:stop()
 if mode~=3 and mode~=4 then setSplit(p1(),false) end
 if mode==1 and state.enabled and native:ready() then camera:start() end
 clearSeparation()
 save()
end
local function assignGamepad(owner)
 if state.menu and state.menuPage=='gamepad' then
  gamepad.owner=owner
  save()
 end
end
bind(Key.F6,'F6',function()
 state.menu=not state.menu;state.menuPage='home';controls.capture=nil;tpControls.capture=nil
 driver:stop(); log(state.menu and 'Menu abierto' or 'Menu cerrado')
end)
bind(Key.F7,'F7',function()if not state.menu or homeMenu() or playMenu() or state.menuPage=='gamepad' then toggle()end end)
bind(Key.ONE,'One',function()
 if homeMenu() then state.menuPage='play';driver:stop()
 elseif playMenu() then toggle()
 elseif cameraMenu() then selectCamera(1)
 elseif extrasMenu() then state.showStatus=not state.showStatus;save()
 else assignGamepad(1) end
end)
bind(Key.TWO,'Two',function()
 if homeMenu() then
  state.menuPage='camera'
  driver:stop()
 elseif cameraMenu() then
  selectCamera(2)
 elseif extrasMenu() then
  state.airRescue=not state.airRescue;save()
 else
  assignGamepad(2)
 end
end)
bind(Key.THREE,'Three',function()
 local pc=p1()
 if homeMenu() and pc and not state.playAsSix then
  state.menuPage='hats'
  hats:open(function(key) return menuDown(pc,key) end)
  driver:stop()
 elseif cameraMenu() then selectCamera(3)
 elseif extrasMenu() then state.jumpAssist=not state.jumpAssist;save()
 elseif state.menu and state.menuPage=='teleport'and not tpControls.capture then state.tp.effects=not state.tp.effects;save()end
end)
bind(Key.SEVEN,'Seven',function()
 if homeMenu() then
  state.menuPage='gamepad'
  driver:stop()
 end
end)
bind(Key.EIGHT,'Eight',function()
 if homeMenu() then
  separation.enabled=not separation.enabled
  clearSeparation();save()
 end
end)
bind(Key.FOUR,'Four',function()
 if homeMenu() then state.menuPage='extras';driver:stop()
 elseif cameraMenu() then selectCamera(4)
 elseif extrasMenu() then state.eventRedirect=not state.eventRedirect;save()
 end
end)
bind(Key.FIVE,'Five',function()
 if cameraMenu() then state.fillScreen=not state.fillScreen;save();return end
 local pc=p1()
 if extrasMenu() then
  if canSelectSix(pc) then
   state.playAsSix=not state.playAsSix
   state.appearance.six=state.playAsSix and '1' or '0'
   state.sixAppearanceFailed=false
   save()
  end
  return
 end
 if homeMenu() and pc then state.menuPage='controls';controls:open(function(name)return menuDown(pc,name)end);driver:stop() end
end)
bind(Key.SIX,'Six',function()
 if extrasMenu() then
  state.language=state.language=='en' and 'es' or 'en'
  save()
  return
 end
 local pc=p1()
 if homeMenu()and pc then
  tpNative.primary=nil
  if tpControls:reconcile()then save()end
  state.menuPage='teleport';tpControls:open(function(name)return menuDown(pc,name)end)
  driver:stop()
 end
end)
local function menuClick(action,config,pc)
 if action=='close'then keys.F6()
 elseif action=='back'then
  controls.capture,tpControls.capture=nil,nil
  state.menuPage='home'
 elseif type(action)=='number'then
  if config and not config.capture then config:beginCapture(action)
  elseif state.menuPage=='hats' then
   hats.cursor=action
   if hats:choose(driver.pc,driver.pawn,pc) then save() end
  end
 elseif action=='hatUp' or action=='hatDown'then
  local direction=action=='hatUp' and -1 or 1
  hats.cursor=(hats.cursor-1+direction)%#hats.options+1
  hats.revision=hats.revision+1
 elseif keys[action] then keys[action]() end
end
local trial={peakZ=-math.huge,peakP1Z=-math.huge,frames=0,jumpFrames=0,grabFrames=0}
local function inputState()
 local c=p1(); if not c then log('P1 controller absent'); return end
 local function name(o) return live(o) and o:GetFullName() or 'none' end
 log('P1 controller='..name(c)..' tick='..tostring(c:IsActorTickEnabled())..' ignored='..tostring(c:IsMoveInputIgnored()))
 log('P1 engine='..name(c.Pawn)..' native='..name(c.mPlayerPawn))
 local playable=live(c.Pawn) and c.Pawn:GetFullName():find('BP_PlayerPawn_C',1,true)
 if playable then log('P1 pawn owner='..name(c.Pawn.Controller)..' alive='..tostring(c.Pawn:IsAlive())) end
 local animator=c.mBodyAnimator
 log('P1 animator='..name(animator))
 if live(animator) then log('P1 animator pawn='..name(animator.mPawnSelf)) end
 log('P1 input component='..name(c.InputComponent)..' player input='..name(c.PlayerInput))
 if playable then
  log('P1 pawn input='..name(c.Pawn.InputComponent)..' isPlayer='..tostring(c.Pawn:IsPlayer()))
 end
end
local function inspect()
 cinematicTrace:mark()
 hunterTrace:mark()
 events:mark()
 inputState()
 local pc=p1(); log(Menu.version..' | '..state.status..' | spawn='..spawn.phase)
 if camera.active then
  local name=live(camera.actor) and camera.actor:GetFullName() or 'sin seguimiento compartido'
  log(string.format('Camara cooperativa: %.1f%% | %s',camera.amount*100,name))
 end
 log('Mando: preferencia P'..gamepad.owner..' | XInput '..tostring(gamepad.slot)..' | desvio P2 '..tostring(gamepad.routed))
 log('Sombrero P2: preferencia '..hats:selected()..' | aplicado '..tostring(hats.applied))
 if state.playAsSix and live(driver.pawn) then
  local ok,err=pcall(function()
   local pawn=driver.pawn
   local mesh=pawn.Mesh
   local anim=mesh:GetAnimInstance()
   local climb=anim.mCurrentClimbData
   local grab=anim.mCurrentlyActiveGrabInterface
   local input=p2Input(pc)
   log(string.format('Six P2 escalada: agarre=%s trepando=%s ritmo=%.3f eje=%.2f altura=%.2f interfaz=%s',
    tostring(input.grab),tostring(climb.mIsTraversingClimbable),climb.mAnimPlayRate,input.y,pawn:K2_GetActorLocation().Z,
    live(grab) and grab:GetClass():GetFullName() or 'ninguna'))
  end)
  if not ok then log('Diagnostico de escalada de Six: '..tostring(err)) end
 end
 local ok,err=pcall(function()
  for index,pawn in pairs({[1]=pc and pc.Pawn,[2]=driver.pawn}) do
   if live(pawn) and live(pawn.MaskComponent) then
    local component=pawn.MaskComponent.CurrentMask:Get()
    local actor=live(component) and component.ChildActor or nil
    if index==2 and live(hats.actor) then actor=hats.actor end
    log('Sombrero P'..index..' visible: '..(live(actor) and actor:GetClass():GetFullName() or 'ninguno'))
   end
  end
 end)
 if not ok then log('Diagnostico de sombreros: '..tostring(err)) end
 for index,pawn in pairs({[1]=pc and pc.Pawn,[2]=driver.pawn})do
  if live(pawn) and pawn:GetFullName():find('BP_PlayerPawn_C',1,true)then
   local inventory=pawn:GetInventoryComponent()
   if live(inventory) then
    log('Equipo P'..index..': linterna='..tostring(inventory:HasInventoryItem(1))
     ..' linterna de transmision='..tostring(inventory:HasInventoryItem(2))..' control='..tostring(inventory:HasInventoryItem(3)))
   end
  end
 end
 log('TP '..tpControls.bindings.toP1..' P2->P1 | '..tpControls.bindings.toP2..' P1->P2 | '..teleport.notice)
 if pc and live(pc.Pawn) then
  local at=pc.Pawn:K2_GetActorLocation(); log(string.format('P1 %s XYZ %.2f %.2f %.2f',pc.Pawn:GetFullName(),at.X,at.Y,at.Z))
 end
 if live(driver.pawn) then
  local at=driver.pawn:K2_GetActorLocation(); log(string.format('P2 %s XYZ %.2f %.2f %.2f',driver.pawn:GetFullName(),at.X,at.Y,at.Z))
  local a=driver.pawn.Controller.mBodyAnimator
  if live(a) then local v=a:GetMoveInput(); log(string.format('P2 native input %.3f %.3f %.3f',v.X,v.Y,v.Z)) end
  log(string.format('P2 trial peakZ=%.2f peakP1Z=%.2f frames=%d jumpFrames=%d grabFrames=%d',trial.peakZ,trial.peakP1Z,trial.frames,trial.jumpFrames,trial.grabFrames))
 end
end
bind(Key.F8,'F8',inspect)
local movementKeys={'W','A','S','D'}
pcall(function()
 local settings=StaticFindObject('/Script/Engine.Default__InputSettings')
 local mappings=settings.ActionMappings
 for i=1,#mappings do
  local mapping=mappings[i]
  if mapping.ActionName:ToString():match('^ActionLocomotion') then
   movementKeys[#movementKeys+1]=mapping.Key.KeyName:ToString()
  end
 end
end)
primaryRecovery=PrimaryRecovery.new({live=live,same=same,
 world=function(pc)
  local level=pc:GetWorld()
  return live(level) and level:GetAddress() or nil
 end,
 clock=function(pc)return UE.GetGameplayStatics():GetRealTimeSeconds(pc)end,
 intent=function(pc)
  local pad=gamepad.owner==1 and not gamepad.routed and gamepad.foreground and gamepad.sample
  if pad and (pad.x~=0 or pad.y~=0) then return true end
  for _,key in ipairs(movementKeys) do if menuDown(pc,key) then return true end end
 end,
 restore=function(pc,refocus)
  if refocus then
   local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
   lib:SetInputMode_GameOnly(pc);lib:SetFocusToGameViewport()
   log('Foco de P1 restaurado tras cargar la partida')
  end
  if not (native.api and native.api.primary_input) then return true end
  local second=world(pc,driver.pc) and same(driver.pc.Player,driver.player) and driver.pc:GetAddress() or 0
  local result=native.api.primary_input(pc:GetAddress(),second)
  if result==1 then log('Contexto nativo del teclado de P1 reconstruido') end
  if result==nil and refocus then log('Contexto nativo de P1 pendiente; se reintentará con movimiento') end
  return result~=nil
 end})
local requestCountdown=0
LoopInGameThreadWithDelay(16,safe(function()
 local pc=p1()
 local now=pc and UE.GetGameplayStatics():GetRealTimeSeconds(pc)or os.clock()
 local fg=native:foreground()
 if PrimaryLink.ensure(pc,{live=live,same=same,isMono=function(pawn)
  return pawn:GetFullName():find('BP_PlayerPawn_C',1,true)~=nil
 end,stale=function(old,current)return not world(old,current)end}) then log('Referencia nativa del primer Mono recuperada') end
 local playable=pc and live(pc.Pawn) and pc.Pawn:GetFullName():find('BP_PlayerPawn_C',1,true)
 local playing=spawnNative:playingGame(pc)
 if gamepad.read then
  local inCoop=state.enabled and pc and (playable or spawn.pending or death.pending) and playing
  local second=live(driver.player) and driver.player.ControllerId==1
  gamepad:update(now,inCoop,second,fg)
 end
 if pc then
  for name,fn in pairs(keys) do
   local pressed=((state.menu or name=='F6') and menuDown or down)(pc,name)
   if pressed and not held[name] then trigger(name,fn) end; held[name]=pressed
  end
  local page=state.menuPage
  local choice=ui:menuPointer(pc,state,state.menu and menuDown(pc,'LeftMouseButton'),fg,native.api and native.api.menu_pointer)
  local config=state.menuPage=='controls'and controls or state.menuPage=='teleport'and tpControls
  if state.menu and config and fg then
   local result=config:tick(function(name)
    if name=='LeftMouseButton' and (state.menuHover=='back' or state.menuHover=='close') then return false end
    return menuDown(pc,name)
   end)
   if result=='saved' then save()
   elseif result=='back' then state.menuPage='home' end
  end
  if state.menu and (state.menuPage=='gamepad' or playMenu() or cameraMenu() or extrasMenu()) and fg and menuDown(pc,'BackSpace') then
   state.menuPage='home'
  end
  if state.menu and state.menuPage=='hats' and fg then
   local result=hats:tick(function(key) return menuDown(pc,key) end)
   if result=='back' then state.menuPage='home'
   elseif result=='apply' and hats:choose(driver.pc,driver.pawn,pc) then save() end
  end
  if state.menu and state.menuPage==page and choice then menuClick(choice,config,pc) end
 end
 teleport:poll(function(key)return pc and down(pc,key)end,tpControls.bindings,state.enabled and not state.menu and fg)
 requestCountdown=requestCountdown-1
 if requestCountdown<=0 then
  requestCountdown=30
  restorePrimaryListener(pc,driver.pc)
  syncAppearance(driver.pc,driver.pawn,pc)
  local path=root and (root..'../native-request.txt'); local f=path and io.open(path,'r')
  if f then
   local command=f:read('*l'); f:close(); os.remove(path)
   if command=='menu' then state.menu=not state.menu end
   if command=='toggle' then toggle() end
   if command=='disable' then disable() end
   if command=='inspect' then inspect() end
   if command=='inputstate' then inputState() end
   if command=='tp21'then teleport:request('toP1')end
   if command=='tp12'then teleport:request('toP2')end
   if command=='checkpoint' and pc and state.enabled then
    StaticFindObject('/Script/Helios.Default__SpawningSystemsLibrary'):RespawnPlayer(pc)
   end
   if command=='dump' then DumpAllObjects(); log('Object metadata dumped') end
   if command=='capture' and pc then
    StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):ExecuteConsoleCommand(pc,'Shot ShowUI',pc)
   end
   if command=='enablepawn' then local c=p1(); if c and live(c.Pawn) then c.Pawn:EnableInput(c); log('Pawn input enabled') end end
   if command=='retryinput' then local c=p1(); if c and live(c.Pawn) then c:ClientRetryClientRestart(c.Pawn); log('Client input retry requested') end end
   if command=='enablelocomotion' then local c=p1(); if c and live(c.Pawn) then c.Pawn:GetLocomotionComponent():EnableInput(); log('Locomotion input enabled') end end
   if command=='modes' and live(driver.pawn) then
    local a=driver.pawn.Controller.mBodyAnimator
    local setup=a.mAnimSetupComponent
    local pawn=driver.pawn
    for _,pair in ipairs({{'mPawnSelf',nil},{'mAnimSetupComponent','mAnimationSetupComponent'},{'mAnimControlComponent','mAnimationControlComponent'},{'mAnimOverrideComponent','mAnimationOverrideComponent'},{'mFlowControl','mFlowControlComponent'}}) do
     local v=a[pair[1]]
     log('Animator '..pair[1]..'='..(live(v) and v:GetFullName() or 'none'))
     if pair[2] then local own=pawn[pair[2]]; log('Own '..pair[2]..'='..(live(own) and own:GetFullName() or 'none')) end
    end
    log('Locomotion default='..setup.DefaultLocomotionMode:ToString())
    for i=1,#setup.LocomotionModes do
     local mode=setup.LocomotionModes[i]
     log('Locomotion mode '..mode.LocomotionName:ToString())
    end
   end
   if command=='bindings' then
    local settings=StaticFindObject('/Script/Engine.Default__InputSettings')
    for i=1,#settings.ActionMappings do
     local m=settings.ActionMappings[i]
     log('BIND '..m.ActionName:ToString()..' '..m.Key.KeyName:ToString())
    end
    for i=1,#settings.AxisMappings do
     local m=settings.AxisMappings[i]
     log('AXIS '..m.AxisName:ToString()..' '..m.Key.KeyName:ToString()..' '..tostring(m.Scale))
    end
    local c=p1()
    if c then
     log('P1 tick='..tostring(c:IsActorTickEnabled())..' ignored='..tostring(c:IsMoveInputIgnored()))
     for _,key in ipairs({'LeftControl','RightControl','LeftShift','RightShift','LeftAlt','RightAlt','LeftWindows','RightWindows'}) do
      log('Modifier '..key..'='..tostring(c:IsInputKeyDown({KeyName=FName(key)})))
     end
     log('P1 input='..(live(c.InputComponent) and c.InputComponent:GetFullName() or 'none'))
     log('P1 native pawn='..(live(c.mPlayerPawn) and c.mPlayerPawn:GetFullName() or 'none'))
     if live(c.Pawn) then log('P1 pawn tick='..tostring(c.Pawn:IsActorTickEnabled())) end
    end
   end
   if command=='focus' then
    local c=p1(); local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    if c then lib:SetInputMode_GameOnly(c); lib:SetFocusToGameViewport() end
   end
   if command=='hideui' then state.menu=false; state.showStatus=false; ui:clear() end
   if command=='restartinput' then
    local c=p1()
    if c and live(c.Pawn) then c:ClientRestart(c.Pawn) end
   end
   if command=='repairpawn' then
    local c=p1()
    if c and live(c.Pawn) then c.mPlayerPawn=c.Pawn; log('P1 native pawn linked to engine pawn') end
   end
   if command=='keytest' then
    local lib=StaticFindObject('/Script/Helios.Default__ChalkboardBlueprintsLibrary')
    for _,name in ipairs({'Jump','Grab','Sneak','Sprint'}) do
     local key=lib:MakeChalkboardSectionKeyFromName(FName('/Input/'..name),{mType={PinCategory=FName('bool')}})
     log('Resolved '..name..' | '..tostring(key.mSectionKeyPath)..' | '..tostring(key.mKeyData.mSectionPath)..' | '..key.mKeyData.mKey:ToString())
    end
   end
   if command=='actions' then
    local count=0
    for _,action in pairs(FindAllOf('FlowControlAction') or {}) do
     if live(action) then
      local ok,result=pcall(function() return tostring(action.mCommand.mSectionKeyPath) end)
      if ok then log('Native action '..action:GetFullName()..' | '..result) end
      count=count+1; if count>=40 then break end
     end
    end
   end
   if command=='reload' then log('Reinicia el juego para cargar cambios; recarga en caliente deshabilitada') end
  end
 end
 local wantEvents=state.enabled and state.eventRedirect and spawn.phase=='active' and not death.pending
  and live(driver.pawn) and not state.menu and native.api
 if wantEvents~=events.enabled then events:setEnabled(wantEvents) end
 if events.enabled then events:interact() end
 local cinematicBlocked=cinematics:update(cinematicNative:snapshot())
 if playing and playable then
  primaryRecovery:update(pc,fg and not state.menu and not cinematicBlocked and not death.pending and not menuSession.pc
   and same(pc.Pawn.Controller,pc) and pc.Pawn:IsAlive()
   and not UE.GetGameplayStatics():IsGamePaused(pc) and not pc:IsMoveInputIgnored())
 else
  primaryRecovery:update(nil,false)
 end
 ledgeRescue:interrupt(cinematicBlocked)
 cinematicTrace:update(now)
 tpNative:update(now)
 state.tp.notice=teleport.notice
 state.rescueNotice=ledgeRescue:noticeText()
 local split=not cinematicBlocked and (state.cameraMode==3 or state.cameraMode==4) and state.enabled and spawn.phase=='active' and not spawn.pending and not death.pending
  and pc and world(pc,driver.pc) and world(pc.Pawn,driver.pawn) and same(driver.pc.Pawn,driver.pawn)
  and live(pc.PlayerCameraManager) and live(driver.pc.PlayerCameraManager)
  and pc.Pawn:IsAlive() and driver.pawn:IsAlive() and not pc:IsMoveInputIgnored()
 if setSplit(pc,not not split) then clearSeparation() end
 if state.split then camera:syncSplit(now,pc,state.fillScreen)
 elseif camera.split then camera:stop() end
 local first,second
 if not cinematicBlocked and state.enabled and spawn.phase=='active' and not spawn.pending and not death.pending
  and not state.menu and pc and live(pc.Pawn) and world(pc.Pawn,driver.pawn)
  and not UE.GetGameplayStatics():IsGamePaused(pc) and not pc:IsMoveInputIgnored()
  and pc.Pawn:IsAlive() and driver.pawn:IsAlive() then
  first,second=pc.Pawn,driver.pawn
 end
 local pendingCall
 if fg then pendingCall=call:observe(first,second) else call:observe(nil,nil) end
 if fg and first and second and (pendingCall or state.call) then
  local firstAddress,secondAddress=first:GetAddress(),second:GetAddress()
  if pendingCall then
   state.call,callUntil=pendingCall,now+2.5
   callFirst,callSecond=firstAddress,secondAddress
  elseif now>=callUntil or firstAddress~=callFirst or secondAddress~=callSecond then
   state.call=nil
  end
 else
  state.call=nil
 end
 if state.split then first,second=nil,nil end
 if state.menu or menuSession.pc then
  menuSession:update(pc,state.menu,state.menu and not not (playable or spawnNative:playingGame(pc)))
 end
 state.sixLocked=extrasMenu() and not canSelectSix(pc)
 local view,lost,side=ui:sync(pc,state,controls.bindings,first,second)
 camera:update(now,view)
 if not(separation.enabled and view and fg and spawnNative:playingGame(pc)) then view=nil end
 local expired=separation:update(now,lost,side,view~=nil,first and first:GetAddress(),second and second:GetAddress())
 if expired then view=nil end
 local amount=view and separation.amount or 0
 local distorted=separationFX:visual(pc,amount,now)
 local fallback=not distorted and view or nil
 if (fallback and amount>0) or ui.interferenceFrame then
  local ok,err=pcall(ui.syncInterference,ui,fallback,separation)
  if not ok and ui.interferenceError~=err then log('Estatica de separacion: '..tostring(err)) end
  ui.interferenceError=not ok and err or nil
 end
 separationFX:warningFor(pc,not expired and separation.warning and separation.elapsed)
 if expired and death:lose(pc,first,'P'..expired) then
  status('Volviendo al punto de control');return
 end
 if not state.enabled then
  death:reset()
  if driver.pc or driver.player then driver:remove() end
  return
 end
 if not pc or not live(pc.Pawn) or not pc.Pawn:GetFullName():find('BP_PlayerPawn_C',1,true) then
  spawn:update(nil,false,false,false,0)
  driver:remove(); status('Esperando una partida'); return
 end
 spawn:observe(pc.Pawn)
 if (not spawn.pending or death.pending)and not death:update(pc,pc.Pawn,driver.pawn) then
  status('Volviendo al punto de control');return
 end
 local input=p2Input(pc)
 local paused=state.menu or UE.GetGameplayStatics():IsGamePaused(pc)
 local intent=input.x~=0 or input.y~=0 or input.jump or input.grab or input.sneak or input.sprint or input.use or input.gadget
 local ready=spawn:update(pc.Pawn,spawnNative:ready(pc),paused,intent,UE.GetGameplayStatics():GetTimeSeconds(pc))
 if state.playAsSix then sixAppearance:syncVisibility() end
 if not ready then
  driver:stop();status(paused and 'Pausa' or spawn:status());return
 end
 if paused then driver:stop();status('Pausa');return end
 if cinematicBlocked then status('Secuencia del juego');return end
 if pc:IsMoveInputIgnored()then driver:stop();status('Secuencia del juego');return end
 if not death:update(pc,pc.Pawn,driver.pawn) then
  status('Volviendo al punto de control');return
 end
 local movementCamera=state.split and driver.pc.PlayerCameraManager or pc.PlayerCameraManager
 local direction=Input.direction(input.x,input.y,movementCamera:GetCameraRotation().Yaw)
 local rescuing=ledgeRescue:update(cinematicBlocked)
 local routedDirection,routedInput=ledgeRescue:route(direction,input,movementCamera:GetCameraRotation().Yaw)
 call:input(driver.pawn,fg and routedInput.call)
 driver:update(routedDirection,routedInput)
 native:cage(now)
 trial.frames=trial.frames+1
 trial.peakZ=math.max(trial.peakZ,driver.pawn:K2_GetActorLocation().Z)
 trial.peakP1Z=math.max(trial.peakP1Z,pc.Pawn:K2_GetActorLocation().Z)
 if input.jump then trial.jumpFrames=trial.jumpFrames+1 end
 if input.grab then trial.grabFrames=trial.grabFrames+1 end
 status(rescuing and 'Rescate: manten F1 / F2 o LB' or (native.api and 'Cooperativo activado' or 'Jugador 2 activo; algunas acciones no están disponibles'))
end))
log(Menu.name..' · '..Menu.version..' | F6 menú | F7 activar cooperativo')
