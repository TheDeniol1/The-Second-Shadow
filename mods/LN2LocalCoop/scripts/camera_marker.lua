local M = {}

function M.place(view, x, y, directionX, directionY, scale)
 local width, height = view.right-view.left, view.bottom-view.top
 local centerX, centerY = view.left+width/2, view.top+height/2
 if x then
  if x>=view.left and x<=view.right and y>=view.top and y<=view.bottom then return end
  directionX, directionY = x-centerX, y-centerY
 end
 local length = math.sqrt(directionX^2+directionY^2)
 if length<0.0001 then directionX,directionY,length=0,1,1 end
 local dx,dy=directionX/length,directionY/length
 local margin=math.min(30*scale,width/4,height/4)
 local reachX=dx==0 and math.huge or (width/2-margin)/math.abs(dx)
 local reachY=dy==0 and math.huge or (height/2-margin)/math.abs(dy)
 local reach=math.min(reachX,reachY)
 local side=reachX<=reachY and (dx<0 and 'left' or 'right') or (dy<0 and 'top' or 'bottom')
 return {x=centerX+dx*reach,y=centerY+dy*reach,dx=dx,dy=dy,angle=math.deg(math.atan(dy,dx)),side=side}
end

function M.separate(a,b,view,scale)
 if not a or not b then return end
 local gap=28*scale
 if (a.x-b.x)^2+(a.y-b.y)^2>=gap^2 then return end
 local axis,min,max='y',view.top,view.bottom
 if math.abs(a.dy)>math.abs(a.dx) then axis,min,max='x',view.left,view.right end
 if max-min<gap*3 then return end
 local center=math.max(min+gap*1.5,math.min(max-gap*1.5,(a[axis]+b[axis])/2))
 a[axis],b[axis]=center-gap/2,center+gap/2
end

return M
