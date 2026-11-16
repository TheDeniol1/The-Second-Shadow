local M={}
function M.reachable(h,v,f,falling,hanging,vz)
 local x,y,z=v.X-h.X,v.Y-h.Y,h.Z-v.Z
 local d=x*x+y*y
 local radius=hanging and 145 or 180
 return (hanging or (falling and vz<=0)) and d<=radius^2
  and z>=(hanging and 20 or -10) and z<=(hanging and 150 or 200)
  and (d<1 or (x*f.X+y*f.Y)/math.sqrt(d)>(hanging and .1 or .05))
end
function M.closeHands(a,b,hanging)
 return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2<=(hanging and 90 or 140)^2
end
function M.arrived(origin,v,h,grounded)
 return grounded and v.Z>=origin.Z+20 and math.abs(v.Z-h.Z)<=40
  and (v.X-h.X)^2+(v.Y-h.Y)^2<=180^2
end
return M
