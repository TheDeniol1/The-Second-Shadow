-- UMG viewport widget: independent of AHUD's optional ReceiveDrawHUD event.
local Marker=require('camera_marker')
local Locale=require('coop_locale')
local UI={}
UI.__index=UI
function UI.new(live,layout,log)
 if ModRef then
  local previous=ModRef:GetSharedVariable('LN2CoopMenu')
  if live(previous) then previous:RemoveFromParent() end
 end
 return setmetatable({live=live,layout=layout,log=log},UI)
end
function UI:clear()
 if self.live(self.widget) then self.widget:RemoveFromParent() end
 self.widget,self.canvas,self.signature,self.world=nil,nil,nil,nil
 self.root,self.contentSlot,self.markers,self.contentSize=nil,nil,nil,nil
 self.interference,self.interferenceImages,self.interferenceFrame=nil,nil,nil
 self.contentRows,self.hidden=nil,nil
 self.menuTargets,self.pointerDown,self.pointerTarget,self.mouseMode=nil,nil,nil,nil
 self.pointerWidget,self.pointerSlot,self.pointerVisible=nil,nil,nil
end

function UI:showPointer(x,y)
 if not x then
  if self.pointerVisible then self.pointerWidget:SetVisibility(1);self.pointerVisible=false end
  return
 end
 if not self.pointerWidget then
  local block=StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),self.widget.WidgetTree)
  local slot=self.root:AddChildToCanvas(block)
  slot:SetAutoSize(true)
  slot:SetAlignment({X=.5,Y=.5})
  slot:SetZOrder(20)
  block:SetText(FText('+'))
  block:SetShadowColorAndOpacity({R=0,G=0,B=0,A=1})
  block:SetShadowOffset({X=1,Y=1})
  block:SetFont({FontObject=self.font,Size=25,TypefaceFontName=FName('None')})
  self.pointerWidget,self.pointerSlot=block,slot
 end
 self.pointerSlot:SetPosition({X=x,Y=y})
 if not self.pointerVisible then self.pointerWidget:SetVisibility(3);self.pointerVisible=true end
end

function UI:menuPointer(pc,state,pressed,focused,readPointer)
 local targets=self.menuTargets
 if not (state.menu and focused and targets and targets.page==state.menuPage) then
  self.pointerDown,self.pointerTarget,state.menuHover=nil,nil,nil
  self:showPointer()
  return
 end
 local ok,x,y,width,height,visible=pcall(function()
  if readPointer then
   local px,py,w,h,shown=readPointer()
   if px then return px,py,w,h,shown end
  end
  local lib=self.layoutLib
  local slate=self.slateLib or StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary')
  self.slateLib=slate
  local size=slate:GetLocalSize(lib:GetViewportWidgetGeometry(pc))
  local position=lib:GetMousePositionOnViewport(pc)
  return position.X,position.Y,size.X,size.Y,true
 end)
 if not ok then
  if self.pointerError~=x then self.log('Ratón de F6: '..tostring(x)) end
  self.pointerError=x
  self.pointerDown,self.pointerTarget,state.menuHover=nil,nil,nil
  self:showPointer()
  return
 end
 self.pointerError=nil
 local hover
 if width>0 and height>0 then
  x,y=x*targets.width/width,y*targets.height/height
  for _,row in ipairs(targets)do
   if x>=row.x and x<row.x+row.width and y>=row.y and y<row.y+row.height then
    hover=row.action;break
   end
  end
 end
 if not visible and x>=0 and x<targets.width and y>=0 and y<targets.height then self:showPointer(x,y)
 else self:showPointer() end
 state.menuHover=hover
 if pressed and self.pointerDown==false then self.pointerTarget=hover end
 local choice
 if not pressed and self.pointerDown then
  if self.pointerTarget==hover then choice=hover end
  self.pointerTarget=nil
 end
 self.pointerDown=pressed
 return choice
end
function UI:create(pc)
 -- Native widget class stays loaded across maps; no boot-level asset dependency.
 local cls=StaticFindObject('/Script/Helios.HeliosWidget')
 assert(self.live(cls),'Clase UMG nativa no disponible')
 local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
 local widget=lib:Create(pc,cls,pc)
 assert(self.live(widget),'No se pudo crear el menu UMG')
 local tree=widget.WidgetTree
 if not self.live(tree) then
  tree=StaticConstructObject(StaticFindObject('/Script/UMG.WidgetTree'),widget)
  widget.WidgetTree=tree
 end
 local canvasClass=StaticFindObject('/Script/UMG.CanvasPanel')
 local root=StaticConstructObject(canvasClass,tree)
 tree.RootWidget=root
 local canvas=StaticConstructObject(canvasClass,tree)
 self.root,self.contentSlot=root,root:AddChildToCanvas(canvas)
 widget:SetVisibility(3) -- HitTestInvisible: never steal the game's keyboard focus.
 self.widget,self.canvas,self.world=widget,canvas,pc:GetWorld()
 local fontPath='/Game/Localization/Fonts/WesternAlphabet/Amorie-Modella-Bold_Font.Amorie-Modella-Bold_Font'
 self.font=StaticFindObject(fontPath)
 if not self.live(self.font) then LoadAsset(fontPath); self.font=StaticFindObject(fontPath) end
 widget:AddToViewport(10000)
 if ModRef then ModRef:SetSharedVariable('LN2CoopMenu',widget) end
 self.log('Menu UMG creado')
end

local markerColors={{R=.93,G=.79,B=.57,A=1},{R=.65,G=.85,B=.90,A=1}}

function UI:createMarker(index)
 local class=StaticFindObject('/Script/UMG.TextBlock')
 local function text(value)
  local block=StaticConstructObject(class,self.widget.WidgetTree)
  local slot=self.root:AddChildToCanvas(block)
  slot:SetAutoSize(true)
  slot:SetAlignment({X=.5,Y=.5})
  slot:SetZOrder(2)
  block:SetText(FText(value))
  block:SetColorAndOpacity({SpecifiedColor=markerColors[index],ColorUseRule=0})
  block:SetShadowColorAndOpacity({R=0,G=0,B=0,A=.95})
  block:SetShadowOffset({X=1,Y=1})
  block:SetVisibility(1)
  return block,slot
 end
 local arrow,arrowSlot=text('>')
 local label,labelSlot=text('P'..index)
 arrow:SetRenderTransformPivot({X=.5,Y=.5})
 return {arrow=arrow,arrowSlot=arrowSlot,label=label,labelSlot=labelSlot}
end

function UI:showMarker(index,point,scale,calling,language)
 self.markers=self.markers or {}
 local marker=self.markers[index]
 if not point then
  if marker and marker.visible then
   marker.arrow:SetVisibility(1);marker.label:SetVisibility(1)
   marker.visible=false
  end
  return
 end
 if not marker then marker=self:createMarker(index);self.markers[index]=marker end
 calling=not not calling
 if marker.calling~=calling or (calling and marker.language~=language) then
  marker.label:SetText(FText(calling and Locale.text(language,'P%d llama',index) or 'P'..index))
  marker.calling,marker.language=calling,language
 end
 if marker.scale~=scale then
  marker.arrow:SetFont({FontObject=self.font,Size=math.floor(29*scale),TypefaceFontName=FName('None')})
  marker.label:SetFont({FontObject=self.font,Size=math.floor(19*scale),TypefaceFontName=FName('None')})
  marker.scale=scale
 end
 marker.arrowSlot:SetPosition({X=point.x,Y=point.y})
 marker.labelSlot:SetPosition({X=point.x-point.dx*22*scale,Y=point.y-point.dy*22*scale})
 marker.arrow:SetRenderTransformAngle(point.angle)
 if not marker.visible then
  marker.arrow:SetVisibility(3);marker.label:SetVisibility(3)
  marker.visible=true
 end
end

function UI:syncMarkers(pc,layout,w,h,first,second,calling,language)
 local scale=math.max(.7,math.min(w/1366,h/768))
 local view={left=0,top=0,right=w,bottom=h}
 if first and second then
  local camera=pc.PlayerCameraManager
  if self.live(camera) then
   local pov=camera.CameraCachePrivate.POV
   if pov.bConstrainAspectRatio and pov.AspectRatio>0 then
    local ratio=pov.AspectRatio
    if w/h>ratio then view.left=(w-h*ratio)/2;view.right=w-view.left
    else view.top=(h-w/ratio)/2;view.bottom=h-view.top end
   end
  end
 end
 local function project(pawn)
  if not self.live(pawn) or pawn.bHidden then return end
  local location=pawn:K2_GetActorLocation()
  local screen={}
  if layout:ProjectWorldLocationToWidgetPosition(pc,location,screen) then
   if type(screen.X)~='number' or type(screen.Y)~='number' then return end
   local x=math.abs(2*(screen.X-view.left)/(view.right-view.left)-1)
   local y=math.abs(2*(screen.Y-view.top)/(view.bottom-view.top)-1)
   return Marker.place(view,screen.X,screen.Y,nil,nil,scale),true,math.max(x,y),location,screen
  end
  local camera=pc.PlayerCameraManager
  if not self.live(camera) then return end
  local rotation,origin=camera:GetCameraRotation(),camera:GetCameraLocation()
  local mathLib=self.mathLib or StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
  self.mathLib=mathLib
  local function dot(axis)
   return (location.X-origin.X)*axis.X+(location.Y-origin.Y)*axis.Y+(location.Z-origin.Z)*axis.Z
  end
  if dot(mathLib:GetForwardVector(rotation))>=0 then return end
  return Marker.place(view,nil,nil,dot(mathLib:GetRightVector(rotation)),-dot(mathLib:GetUpVector(rotation)),scale),true
 end
 local p1,seen1,edge1,at1,screen1=project(first)
 local p2,seen2,edge2,at2,screen2=project(second)
 Marker.separate(p1,p2,view,scale)
 local function callPoint(screen)
  if not screen then return end
  local inset=math.min(60*scale,(view.right-view.left)/2)
  return {x=math.max(view.left+inset,math.min(view.right-inset,screen.X)),
   y=math.max(view.top+34*scale,screen.Y-12*scale),dx=0,dy=1,angle=90}
 end
 self:showMarker(1,p1 or (calling==1 and callPoint(screen1)),scale,calling==1,language)
 self:showMarker(2,p2 or (calling==2 and callPoint(screen2)),scale,calling==2,language)
 if seen1 and seen2 then
  if edge1 and edge2 then
   view.edge,view.firstLocation,view.secondLocation=math.max(edge1,edge2),at1,at2
  end
  if p1 and not p2 then return view,1,p1.side end
  if p2 and not p1 then return view,2,p2.side end
  return view
 end
end

local solidBrush={DrawAs=3,TintColor={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0}}

function UI:syncInterference(view,separation)
 local amount,side=separation.amount,separation.side
 if not view or amount<=0 then
  if self.interferenceFrame then self.interference:SetVisibility(1);self.interferenceFrame=nil end
  return
 end
 if not self.interference then
  local tree=self.widget.WidgetTree
  local canvas=StaticConstructObject(StaticFindObject('/Script/UMG.CanvasPanel'),tree)
  local slot=self.root:AddChildToCanvas(canvas)
  slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
  slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
  slot:SetZOrder(1)
  self.interference,self.interferenceImages=canvas,{}
 end
 local frame=math.floor(separation.last*10)
 if self.interferenceFrame==frame then return end
 local images=self.interferenceImages
 local owner=self
 local index=0
 local hud={}
 function hud:DrawRect(color,x,y,width,height)
  index=index+1
  local row=images[index]
  if not row then
   local image=StaticConstructObject(StaticFindObject('/Script/UMG.Image'),owner.widget.WidgetTree)
   image:SetBrush(solidBrush)
   row={image=image,slot=owner.interference:AddChildToCanvas(image)}
   images[index]=row
  end
  row.slot:SetPosition({X=x,Y=y});row.slot:SetSize({X=width,Y=height})
  row.image:SetColorAndOpacity(color)
 end
 self.layout.separationStatic(hud,view,side,amount,frame)
 self.interference:SetVisibility(3)
 self.interferenceFrame=frame
end

function UI:sync(pc,state,preset,first,second)
 if not self.live(pc) then self:clear(); return end
 if not state.menu then self.menuTargets,self.pointerDown,self.pointerTarget=nil,nil,nil;self:showPointer() end
 if self.live(self.world) and self.world:GetAddress()~=pc:GetWorld():GetAddress() then self:clear() end
 local tp=state.tp or {}
 local splitCall=state.split and state.call
 if not state.menu and not state.showStatus and not tp.flashFrame and not splitCall and not (first and second) then
  if self.live(self.widget) and not self.hidden then self.widget:SetVisibility(1);self.hidden=true end
  return
 end
 if not self.live(self.widget) then self:clear();self:create(pc) end
 local lib=self.layoutLib or StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary')
 self.layoutLib=lib
 local viewport=lib:GetViewportSize(pc)
 local dpi=lib:GetViewportScale(pc)
 if dpi<=0 then dpi=1 end
 local w,h=viewport.X/dpi,viewport.Y/dpi
 if w<=0 or h<=0 then return end
 local size=w..'|'..h
 if self.contentSize~=size then
  self.contentSlot:SetSize({X=w,Y=h})
  self.contentSize=size
 end
 local ok,view,lost,side=pcall(self.syncMarkers,self,pc,lib,w,h,first,second,state.call,state.language)
 if not ok then
  if self.markerError~=view then self.log('Flechas de camara: '..tostring(view)) end
  self:showMarker(1,nil,1);self:showMarker(2,nil,1)
  self.markerError=view
  view=nil
 else
  self.markerError=nil
 end
 local signature
 if state.menu then
  local pad=state.gamepad or {}
  signature=table.concat({'menu',state.menuPage or 'home',state.cameraMode or 1,tostring(state.fillScreen),
   state.controls and state.controls.revision or 0,tp.controls and tp.controls.revision or 0,
   tostring(tp.effects),tp.notice or '',tp.flashFrame or '',pad.owner or 1,tostring(pad.slot),tostring(pad.routed),
   state.hats and state.hats.revision or 0,tostring(state.separation.enabled),state.status,tostring(state.enabled),
   preset.name,tostring(state.showStatus),tostring(state.airRescue),tostring(state.jumpAssist),tostring(state.eventRedirect),
   tostring(state.sixLocked),tostring(state.playAsSix),tostring(state.sixAppearanceFailed),state.menuHover or '',state.language or 'es',size},'|')
 else
  local badge=state.showStatus and (state.rescueNotice or (tp.notice and tp.notice~='' and tp.notice) or state.status)or ''
  signature=table.concat({'badge',tostring(state.showStatus),tostring(state.enabled),badge,tp.flashFrame or '',
   splitCall or '',splitCall and state.cameraMode or '',state.language or 'es',size},'|')
 end
 if self.hidden or self.mouseMode~=state.menu then
  self.widget:SetVisibility(state.menu and 4 or 3)
  self.hidden,self.mouseMode=false,state.menu
 end
 if self.signature==signature then return view,lost,side end
 local owner=self
 local rows=self.contentRows or {Image={},TextBlock={}}
 self.contentRows=rows
 local used={Image=0,TextBlock=0}
 local order=0
 local function add(class,x,y,width,height)
  used[class]=used[class]+1;order=order+1
  local row=rows[class][used[class]]
  if not row then
   local object=StaticConstructObject(StaticFindObject('/Script/UMG.'..class),owner.widget.WidgetTree)
   assert(owner.live(object),'No se pudo construir '..class)
   row={object=object,slot=owner.canvas:AddChildToCanvas(object)}
   if class=='Image' then
    object:SetBrush(solidBrush)
   else
    row.slot:SetAutoSize(true)
    object:SetShadowColorAndOpacity({R=0,G=0,B=0,A=.92})
    object:SetShadowOffset({X=1,Y=1})
   end
   rows[class][used[class]]=row
  end
  if row.order~=order then row.slot:SetZOrder(order);row.order=order end
  if row.x~=x or row.y~=y then row.slot:SetPosition({X=x,Y=y});row.x,row.y=x,y end
  if class=='Image' and (row.width~=width or row.height~=height)then
   row.slot:SetSize({X=width,Y=height});row.width,row.height=width,height
  end
  local visibility=state.menu and order==1 and 0 or 3
  if not row.visible or row.visibility~=visibility then
   row.object:SetVisibility(visibility);row.visible,row.visibility=true,visibility
  end
  return row.object
 end
 local hud={}
 local targets={page=state.menuPage,width=w,height=h}
 function hud:MenuTarget(action,x,y,width,height)
  targets[#targets+1]={action=action,x=x,y=y,width=width,height=height}
 end
 function hud:DrawRect(color,x,y,width,height)
  local image=add('Image',x,y,width,height)
  image:SetColorAndOpacity(color)
 end
 function hud:DrawText(text,color,x,y,_,scale)
  local block=add('TextBlock',x,y,w,h)
  block:SetText(FText(text))
  block:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0})
  block:SetFont({FontObject=owner.font,Size=math.max(10,math.floor(32*scale)),TypefaceFontName=FName('None')})
 end
 if state.menu then self.layout.draw(hud,w,h,state,preset,nil);self.menuTargets=targets
 elseif state.showStatus then self.layout.badge(hud,state,nil) end
 if tp.flashFrame and self.layout.static then self.layout.static(hud,w,h,tp.flashFrame)end
 if splitCall and not state.menu then
  local vertical=state.cameraMode==4
  local scale=math.min(1,w/760,h/500)
  local width,height=184*scale,35*scale
  local center=vertical and (splitCall==1 and .75 or .25) or .5
  local x=center*w-width/2
  local y=(not vertical and splitCall==1 and .56 or .06)*h
  local color=markerColors[splitCall]
  hud:DrawRect({R=.022,G=.036,B=.047,A=.94},x,y,width,height)
  hud:DrawRect(color,x,y,2*scale,height)
  hud:DrawText(Locale.text(state.language,'P%d te llama',splitCall),color,x+14*scale,y+3*scale,nil,.72*scale)
 end
 for class,list in pairs(rows)do
  for i=used[class]+1,#list do
   local row=list[i]
   if row.visible then row.object:SetVisibility(1);row.visible=false end
  end
 end
 self.signature=signature
 return view,lost,side
end
return UI
