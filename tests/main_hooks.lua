-- Execute the actual entry point with an engine boundary stub. In particular,
-- native hook arguments must survive the production safe() wrapper.
local hooks,keys,logs={},{},{}
local removals=0
local loop,view,saved;local clock=1;local pressed={}
local paused,mouseChoice=false,nil
local gameState=4
local function obj(address)
 return {IsValid=function()return true end,HasAnyInternalFlags=function()return false end,
 GetAddress=function()return address end}
end
local world=obj(1);local pc=obj(2);local player=obj(3);local pawn=obj(4)
pc.Player=player;player.ControllerId=0;pc.Pawn=pawn
pc.GetWorld=function()return world end
pc.IsInputKeyDown=function(_,key)return pressed[key.KeyName]or false end
pawn.GetFullName=function()return 'BP_PlayerPawn_C test' end
local viewport=obj(5);viewport.World=world
local driver={stop=function()end,remove=function()removals=removals+1 end}
local stubs={UEHelpers={GetGameViewportClient=function()return viewport end,
 GetGameplayStatics=function()return {GetPlayerController=function()return pc end,GetRealTimeSeconds=function()return clock end,
  IsGamePaused=function()return paused end,SetGamePaused=function(_,_,value)paused=value;return true end}end},
 mono_driver={new=function()return driver end},
 native_input={new=function()return {foreground=function()return true end}end},
 spawn_native={new=function(context)return {playingGame=function()return gameState==5 end,gameState=function()return gameState end,
 api=function()return {cancel=function()end,cleanup=function()driver:remove()end,
 live=context.live,same=context.same}end}end},
 coop_ui={new=function()return {sync=function(_,_,state)view=state end,menuPointer=function()
  local choice=mouseChoice;mouseChoice=nil;return choice
 end}end}}
local function open(path,mode)
 if not path:find('preferences.ini',1,true)then return end
 if mode=='r'and saved then return {read=function()return saved end,close=function()end}end
 if mode=='w'then
  saved=''
  return {write=function(self,text)saved=saved..text;return self end,close=function()end}
 end
end
local env=setmetatable({io={open=open},FName=function(name)return name end,
 print=function(s)logs[#logs+1]=s end,require=function(name)return stubs[name]or require(name)end,
 Key=setmetatable({},{__index=function(_,name)return name end}),
 EInternalObjectFlags={PendingKill=1},EGameThreadMethod={ProcessEvent=1},
 RegisterHook=function(path,fn)hooks[path]=fn end,
 RegisterKeyBindAsync=function(key,fn)keys[key]=fn end,
 LoopInGameThreadWithDelay=function(_,fn)loop=fn end,
 ExecuteInGameThread=function(fn)fn()end,
 StaticFindObject=function()return {IsValid=function()return true end,
 HasAnyInternalFlags=function()return false end,GetHeliosGameState=function()return 4 end,
 SetInputMode_GameAndUIEx=function()end,SetInputMode_GameOnly=function()end,SetFocusToGameViewport=function()end}end},
 {__index=_G})
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
keys.F7()
local callback=assert(hooks['/Script/Helios.SpawningSystemsLibrary:RespawnPlayer'])
local context={get=function()return pc end}
callback(context,context)
assert(removals==1,'actual entry point must forward native event parameters and invalidate once')
callback(context,context)
assert(removals==1,'duplicate native notification must not repeat cleanup')
clock=2;keys.F7();keys.F6();keys.SIX()
pressed.Enter=true;loop();pressed={};loop();pressed.F11=true;loop();pressed={}
assert(saved and saved:find('tp.toP1=F11',1,true)and saved:find('tp.toP2=F10',1,true),'actual menu capture must write both TP keys')
assert(saved:find('bind.up=I',1,true),'saving TP keys must preserve P2 controls')
keys.THREE()
assert(saved:find('tp.effects=0',1,true),'effect toggle uses the production preference writer')
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
keys.F6();keys.SIX();loop()
assert(view.tp.controls.bindings.toP1=='F11'and view.tp.controls.bindings.toP2=='F10','fresh mod instance restores saved TP directions')
assert(not view.tp.effects and view.controls.bindings.up=='I','fresh instance restores effects without resetting P2 controls')
clock=3;keys.F6();clock=4;keys.F6();keys.SEVEN();keys.TWO();loop()
assert(view.menuPage=='gamepad' and view.gamepad.owner==2,'F6 gamepad selection assigns P2')
assert(saved:find('pad.owner=2',1,true) and saved:find('tp.toP1=F11',1,true),'gamepad preference preserves teleport settings')
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(view.gamepad.owner==2,'gamepad assignment survives restart')
local previousFindFirstOf=FindFirstOf
FindFirstOf=function() return nil end
keys.F6();keys.THREE()
pressed.Down=true;loop();pressed={};loop();pressed.Enter=true;loop();pressed={}
FindFirstOf=previousFindFirstOf
assert(view.menuPage=='hats' and view.appearance.hat=='bare','F6 3 now selects the P2 hat')
assert(saved:find('appearance.hat=bare',1,true) and saved:find('pad.owner=2',1,true),
 'changing P2 appearance preserves the controller preference')
assert(not view.separation.enabled,'offscreen loss defaults to off')
clock=5;keys.F6();clock=6;keys.F6();keys.EIGHT();loop()
assert(view.separation.enabled and saved:find('separation=1',1,true),'F6 8 enables and saves offscreen loss')
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(view.separation.enabled,'offscreen loss preference survives restart')
clock=7;keys.F6();keys.TWO();loop()
assert(view.menuPage=='camera' and view.cameraMode==1,'F6 2 opens camera modes with stabilized sharing by default')
clock=8;keys.TWO();loop()
assert(view.cameraMode==2 and saved:find('camera.mode=2',1,true),'camera menu selects and saves original sharing')
keys.THREE();loop()
assert(view.cameraMode==3 and not view.split and saved:find('camera.mode=3',1,true),
 'split is selected without dividing the viewport before P2 is ready')
assert(saved:find('bind.up=I',1,true) and saved:find('pad.owner=2',1,true),
 'changing camera mode preserves controls and controller assignment')
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(view.cameraMode==3 and not view.split,'saved split preference returns without splitting the title screen')
clock=9;keys.F6();keys.TWO();keys.FOUR();loop()
assert(view.cameraMode==4 and not view.split and saved:find('camera.mode=4',1,true),
 'vertical split saves without dividing the title screen')
assert(not view.fillScreen,'fill screen is opt-in for existing preferences')
keys.FIVE();loop()
assert(view.fillScreen and saved:find('camera.fill=1',1,true) and view.cameraMode==4,
 'camera option 5 saves fill screen without changing orientation')
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(view.cameraMode==4 and not view.split,'vertical split survives restart')
assert(view.fillScreen,'fill-screen preference survives restart')
-- Exercise the production layout switch with only the engine boundary replaced.
local function findUpvalue(fn,wanted,seen)
 seen=seen or {};if seen[fn] then return end;seen[fn]=true
 for i=1,100 do
  local name,value=debug.getupvalue(fn,i);if not name then break end
  if name==wanted then return value end
  if type(value)=='function' then
   local found=findUpvalue(value,wanted,seen);if found then return found end
  end
 end
end
local setSplit=assert(findUpvalue(loop,'setSplit'))
assert(not keys.F5 and not keys.F11,'hand rescue does not require selecting a ledge or take fullscreen')
local rescue=assert(findUpvalue(loop,'ledgeRescue'))
local sampleP2=assert(findUpvalue(loop,'p2Input'))
local nativeInput=assert(findUpvalue(loop,'native'))
local nativeAPI=nativeInput.api
local pad=assert(findUpvalue(loop,'gamepad'))
local oldPadInput=pad.input
pad.input=function()return nil end
nativeInput.api={key_down=function(code)return code==79 or code==73 end}
rescue.control.active={}
pressed={}
local physicalSample=sampleP2(pc)
assert(physicalSample.grab and physicalSample.y==1,'real entry point reads physical P2 input while P1 tick is suspended')
rescue.control.active=nil;nativeInput.api=nativeAPI;pad.input=oldPadInput
local settings={TwoPlayerSplitscreenLayout=1,bUseSplitscreen=false}
local refreshes=0
stubs.UEHelpers.GetGameMapsSettings=function()return settings end
local oldStatics=stubs.UEHelpers.GetGameplayStatics
stubs.UEHelpers.GetGameplayStatics=function()
 local result=oldStatics()
 result.SetForceDisableSplitscreen=function()refreshes=refreshes+1 end
 return result
end
local oldFind=env.StaticFindObject
env.StaticFindObject=function(name)
 if name=='/Script/Engine.Default__KismetSystemLibrary' then
  return {GetConsoleVariableIntValue=function()return 0 end}
 end
 return oldFind(name)
end
assert(setSplit(pc,true) and settings.TwoPlayerSplitscreenLayout==1 and settings.bUseSplitscreen,
 'vertical mode applies the side-by-side layout')
view.cameraMode=3
assert(setSplit(pc,true) and settings.TwoPlayerSplitscreenLayout==0,'live switch to horizontal')
assert(not setSplit(pc,true) and refreshes==2,'unchanged layout does not refresh every frame')
view.cameraMode=4
assert(setSplit(pc,true) and settings.TwoPlayerSplitscreenLayout==1,'live switch back to vertical')
view.cameraMode=3;setSplit(pc,true)
assert(setSplit(pc,false) and settings.TwoPlayerSplitscreenLayout==1 and not settings.bUseSplitscreen,
 'leaving split restores the original layout after repeated switches')
env.StaticFindObject=oldFind
view.cameraMode=4
clock=10;keys.F6();keys.TWO();keys.ONE();loop()
assert(view.cameraMode==1 and saved:find('camera.mode=1',1,true),'first camera option restores stabilized sharing')
clock=11;keys.F6();clock=12;keys.F6();keys.FOUR();loop()
assert(view.menuPage=='extras' and view.showStatus and view.airRescue,'F6 4 opens Extras with current settings')
keys.ONE();keys.TWO();loop()
assert(not view.showStatus and not view.airRescue and saved:find('showStatus=0',1,true)
 and saved:find('rescue.air=0',1,true),'Extras saves both settings independently')
pressed.BackSpace=true;loop();pressed={}
assert(view.menuPage=='home','Backspace returns from Extras')
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(not view.airRescue and not view.showStatus,'Extras preferences survive restart')
clock=13;keys.F6();keys.FOUR();keys.TWO();loop()
assert(view.airRescue and not view.showStatus and saved:find('rescue.air=1',1,true),
 're-enabling aerial rescue preserves the indicator setting')
assert(view.jumpAssist,'jump assist defaults to enabled')
keys.THREE();loop()
assert(not view.jumpAssist and saved:find('rescue.jump=0',1,true) and view.airRescue,
 'jump assist has its own Extras preference')
paused,pc.bShowMouseCursor=false,false
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(not view.jumpAssist and view.airRescue,'jump assist preference survives restart')
clock=14;keys.F6();keys.ONE();loop()
assert(view.menuPage=='play' and not view.enabled,'F6 1 opens the mode selector without starting local coop')
keys.TWO();loop()
assert(view.menuPage=='play' and not view.enabled,'online is inert')
clock=15;keys.ONE()
assert(view.enabled,'Local enables the existing coop')
clock=16;keys.ONE()
assert(not view.enabled,'Local can also remove P2')
pressed.BackSpace=true;loop();pressed={}
assert(view.menuPage=='home','Backspace returns from the mode selector')
keys.FOUR();loop()
assert(view.sixLocked,'Extras locks Six while a playable pawn is present')
local previousPrefs=saved
keys.FIVE();loop()
assert(view.menuPage=='extras' and not view.playAsSix and saved==previousPrefs,'the Six option cannot change during gameplay')
assert(paused and pc.bShowMouseCursor,'opening F6 pauses the engine and shows the pointer')
mouseChoice='back';loop()
assert(view.menuPage=='home','mouse can go back')
mouseChoice='Two';loop()
assert(view.menuPage=='camera','mouse opens a submenu')
mouseChoice='Four';loop()
assert(view.cameraMode==4,'mouse selects a camera mode')
mouseChoice='back';loop();mouseChoice='Five';loop();mouseChoice=2;loop()
assert(view.menuPage=='controls' and view.controls.capture==view.controls.actions[2].id,'clicking a binding starts capture')
mouseChoice='close';loop()
assert(not view.menu and not paused and not pc.bShowMouseCursor and not view.controls.capture,'closing cancels capture and restores gameplay')
paused=true;pc.bShowMouseCursor=true
clock=17;keys.F6();loop();clock=18;keys.F6();loop()
assert(not view.menu and paused and pc.bShowMouseCursor,'closing F6 preserves pre-existing pause and cursor')
paused,pc.bShowMouseCursor=false,false
world=obj(7);viewport.World=world
clock=1;keys.F6();loop()
assert(view.menu and paused,'F6 accepts a new press after loading a world with a reset clock')
clock=1.1;keys.F6();loop()
assert(view.menu,'same-world duplicate presses are still filtered')
clock=1.4;keys.F6();loop()
assert(not view.menu and not paused,'F6 closes again in the new world')
clock=2;keys.F6();keys.FOUR();loop()
assert(view.language=='es','existing preferences default to Spanish')
keys.SIX();loop()
assert(view.language=='en' and saved:find('ui.language=en',1,true),'Extras language shortcut saves English')
clock=3;keys.F6();loop()
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(view.language=='en','English survives a fresh mod instance')
clock=4;keys.F6();keys.FOUR();loop()
mouseChoice='Six';loop()
assert(view.language=='es' and saved:find('ui.language=es',1,true),'the language row also switches by mouse')
pc.Pawn=nil
gameState=5;clock=5;loop()
keys.FIVE();loop()
assert(view.sixLocked and not view.playAsSix,'Six stays locked during gameplay without a pawn')
gameState=4;clock=6;loop()
mouseChoice='Five';loop()
assert(not view.sixLocked and view.playAsSix and saved:find('appearance.six=1',1,true),
 'the main menu can select Six and save the choice')
mouseChoice='back';loop();keys.THREE();loop()
assert(view.menuPage=='home','Six mode blocks the hat submenu')
clock=7;keys.F6();loop()
assert(loadfile('mods/LN2LocalCoop/scripts/main.lua','t',env))()
loop()
assert(view.playAsSix,'Six appearance survives a fresh mod instance')
clock=8;keys.F6();keys.FOUR();keys.FIVE();loop()
assert(not view.playAsSix and saved:find('appearance.six=0',1,true)
 and saved:find('appearance.hat=bare',1,true),'returning to Mono keeps the saved hat')
for _,line in ipairs(logs)do assert(not line:find('Error:',1,true),table.concat(logs,'\n'))end
print('PASS: production entry point forwards native hook arguments and deduplicates reload notifications.')
print('PASS: production TP menu capture, preference writer and restoration in a fresh mod instance.')
print('PASS: production camera menu selection, persistence and split readiness.')
print('PASS: production Extras menu navigation, independent toggles and preference restoration.')
print('PASS: mode selector, local toggle, and inert online entry.')
print('PASS: F6 pause ownership and mouse navigation.')
print('PASS: F6 accepts presses after a world change and clock reset.')
print('PASS: Extras language selection by keyboard and mouse, including persistence.')
print('PASS: Six selection only at the main menu, disabled hats, and persistence.')
