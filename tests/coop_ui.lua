local UI=require('coop_ui')
local menu=require('coop_menu')
local find,construct,ftext,fname=StaticFindObject,StaticConstructObject,FText,FName
local function identity(value) return value end
local function noop() end
local objects={}
StaticFindObject,FText,FName=identity,identity,identity
StaticConstructObject=function(class)
 local object={class=class,SetBrush=noop,SetColorAndOpacity=noop,SetFont=noop,
  SetShadowColorAndOpacity=noop,SetShadowOffset=noop}
 function object:SetVisibility(value) self.visibility=value end
 function object:SetText(value) self.text=value end
 objects[#objects+1]=object
 return object
end

local slot={SetPosition=noop,SetSize=noop,SetAutoSize=noop,SetZOrder=noop}
local world={GetAddress=function() return 1 end}
local pc={GetWorld=function() return world end}
local ui=UI.new(function(value) return value~=nil end,menu,noop)
local rootWrites=0
ui.widget={WidgetTree={},SetVisibility=function() rootWrites=rootWrites+1 end}
ui.canvas={AddChildToCanvas=function(_,object)
 return setmetatable({SetPosition=function(_,position) object.position=position end},{__index=slot})
end}
ui.contentSlot,ui.world,ui.syncMarkers=slot,world,noop
ui.layoutLib={GetViewportSize=function() return {X=1366,Y=768} end,GetViewportScale=function() return 1 end}
local preset={name='Teclado'}
local state={menu=true,menuPage='extras',status='Cooperativo',enabled=true,showStatus=true,
 separation={enabled=false},tp={notice=''}}
local function visibleText(expected)
 for _,object in ipairs(objects)do
  if object.visibility==3 and object.text==expected then return object end
 end
end

ui:sync(pc,state,preset)
local menuObjects=#objects
assert(visibleText('[2] Rescate aéreo (experimental): No'),'Extras initially shows disabled')
state.airRescue,state.jumpAssist,state.eventRedirect=true,true,true
ui:sync(pc,state,preset)
assert(visibleText('[2] Rescate aéreo (experimental): Sí'),'Extras refreshes aerial rescue')
assert(visibleText('[3] Ayuda de salto de compañero (experimental): Sí'),'Extras refreshes jump assist')
assert(visibleText('[4] Eventos de P2 (experimental): Sí'),'Extras refreshes P2 events')
assert(#objects==menuObjects,'Extras reuses its widgets')
assert(visibleText('[5] Jugar como Six: No') and visibleText('Acompaña a Mono como Six.'),'Extras shows the Six mode description')
state.sixLocked=true
ui:sync(pc,state,preset)
assert(visibleText('Bloqueado durante la partida.'),'Extras refreshes the lock when a game begins')
state.language='en'
ui:sync(pc,state,preset)
assert(visibleText('[6] Language: English') and visibleText('[2] Midair rescue (experimental): Yes'),
 'the cached menu redraws immediately in English')
assert(visibleText('Locked during gameplay.'),'the locked entry is localized')
state.language='es'
ui:sync(pc,state,preset)
assert(visibleText('[6] Idioma: Español'),'the same Extras option returns to Spanish')
local cursor={X=0,Y=0}
ui.layoutLib.GetMousePositionOnViewport=function()return cursor end
ui.layoutLib.GetViewportWidgetGeometry=function()return {} end
ui.slateLib={GetLocalSize=function()return {X=683,Y=384} end}
local firstTarget=ui.menuTargets[1]
cursor.X,cursor.Y=(firstTarget.x+5)/2,(firstTarget.y+5)/2
assert(not ui:menuPointer(pc,state,true,true),'an already held click cannot select when opening')
assert(not ui:menuPointer(pc,state,false,true),'release of a pre-existing press does not select')
assert(state.menuHover=='One','cursor coordinates map to the menu target at a different viewport scale')
assert(not ui:menuPointer(pc,state,true,true),'pointer does not select before release')
cursor.X=0
assert(not ui:menuPointer(pc,state,false,true),'dragging outside cancels the click')
cursor.X=(firstTarget.x+5)/2
ui:menuPointer(pc,state,true,true)
assert(ui:menuPointer(pc,state,false,true)=='One','clicking the same menu row selects exactly once')
assert(not ui:menuPointer(pc,state,false,true),'release is not repeated')
local softwareCursor
ui.showPointer=function(_,x,y) softwareCursor=x and {x=x,y=y} end
cursor.X,cursor.Y=0,0
local function nativePointer()return (firstTarget.x+5)*2,(firstTarget.y+5)*2,2732,1536,false end
ui:menuPointer(pc,state,true,true,nativePointer)
assert(softwareCursor and softwareCursor.x==firstTarget.x+5,'hidden system cursor uses the native position for the software cursor')
assert(ui:menuPointer(pc,state,false,true,nativePointer)=='One','native coordinates win over the paused viewport reading')
ui:menuPointer(pc,state,false,false,nativePointer)
assert(not softwareCursor,'focus loss hides the software cursor')

state.menu,state.tp.flashFrame=false,1
ui:sync(pc,state,preset)
local flashObjects=#objects
assert(flashObjects>menuObjects,'the first flash fills the image pool')
state.tp.flashFrame=2
ui:sync(pc,state,preset)
assert(#objects==flashObjects,'subsequent flash frames reuse the image pool')
state.tp.flashFrame=nil
ui:sync(pc,state,preset)
assert(visibleText('Cooperativo   [F6]') and not visibleText('Extras'),'closing the menu leaves only the badge')
local visibleImages=0
for _,object in ipairs(objects)do
 if object.class=='/Script/UMG.Image' and object.visibility==3 then visibleImages=visibleImages+1 end
end
assert(visibleImages==1,'finished flash images are hidden except the badge accent')
state.showStatus=false
local previousRootWrites=rootWrites
ui:sync(pc,state,preset)
ui:sync(pc,state,preset)
assert(rootWrites==previousRootWrites+1,'hidden HUD does not repeat visibility writes')
state.showStatus=true
ui:sync(pc,state,preset)
assert(rootWrites==previousRootWrites+2,'the HUD becomes visible again')

state.showStatus,state.split,state.cameraMode,state.call=false,true,4,1
ui:sync(pc,state,preset)
assert(visibleText('P1 te llama').position.X>683,'vertical split sends P1 call to P2 on the right')
state.cameraMode=3
ui:sync(pc,state,preset)
assert(visibleText('P1 te llama').position.Y>384,'horizontal split sends P1 call to P2 below')
state.call=2
ui:sync(pc,state,preset)
assert(visibleText('P2 te llama').position.Y<384,'horizontal split sends P2 call to P1 above')
state.language='en'
ui:sync(pc,state,preset)
assert(visibleText('P2 is calling you'),'split captions update when the language changes')
state.language='es'
state.call=nil
ui:sync(pc,state,preset)
assert(rootWrites==previousRootWrites+3,'expired call hides the split HUD when the status badge is disabled')

local markers={}
ui.showMarker=function(_,index,point,_,calling) markers[index]={point=point,calling=calling} end
local function pawn(x,y)
 return {K2_GetActorLocation=function()return {X=x,Y=y}end}
end
local projector={ProjectWorldLocationToWidgetPosition=function(_,_,location,screen)
 screen.X,screen.Y=location.X,location.Y
 return true
end}
local _,lost=UI.syncMarkers(ui,pc,projector,1366,768,pawn(660,500),pawn(710,500),1)
assert(markers[1].point and markers[1].calling and not markers[2].point and not lost,
 'visible call points at P1 without triggering separation')
_,lost=UI.syncMarkers(ui,pc,projector,1366,768,pawn(660,500),pawn(1500,500),2)
assert(markers[2].point.side=='right' and markers[2].calling and lost==2,
 'offscreen call keeps the correct arrow and separation result')

for _,viewport in ipairs({{1366,768},{800,600},{600,950},{2560,1080}})do
 local w,h=table.unpack(viewport)
 local rects,texts={},{}
 local hud={
  DrawRect=function(_,_,x,y,width,height)
   assert(x>=0 and y>=0 and x+width<=w+.001 and y+height<=h+.001,'menu geometry stays within the viewport')
   rects[#rects+1]={x=x,y=y,width=width,height=height}
  end,
  DrawText=function(_,label,_,x,y) texts[label]={x=x,y=y} end
 }
 menu.draw(hud,w,h,{menuPage='camera',cameraMode=4},{})
 local panel=rects[3]
 assert(math.abs(panel.x+panel.width/2-w/2)<.001,'menu panel stays centered')
 local footer=texts['Retroceso  volver']
 assert(footer.y<panel.y+panel.height and footer.y>texts['[4] Dividida vertical'].y,'footer stays below the camera options inside the panel')
end

StaticFindObject,StaticConstructObject,FText,FName=find,construct,ftext,fname
print('PASS: Extras toggles refresh, UMG widgets are reused, and finished TP flash images are hidden.')
print('PASS: shared call markers and receiver-only split captions.')
print('PASS: centered camera menu and footer fit standard, narrow, and ultrawide viewports.')
print('PASS: menu mouse targets, viewport scaling, and click release.')
local locale=require('coop_locale')
assert(locale.notice('en','Guardado: Raton lateral 1')=='Saved: Mouse Button 4','binding feedback localizes key names')
assert(locale.notice('en','Ya usada para Saltar del jugador 2')=='Already used for Player 2: Jump','binding conflicts localize action names')
assert(locale.notice('en','El jugador 2 se reunió con el jugador 1')=='Player 2 joined Player 1','teleport notices are localized')
print('PASS: live language updates and localized mod notices.')
