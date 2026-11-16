-- Collision is handled by the caller. This path never lowers the captured
-- player first: lift outside the edge, cross above it, then settle on support.
local M={}
local function copy(p)return {X=p.X,Y=p.Y,Z=p.Z}end
function M.distance2(a,b)return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2 end
function M.new(origin,target,radius)
 if M.distance2(origin,target)>300^2 or target.Z-origin.Z>230 then return end
 local top=math.max(origin.Z,target.Z+radius+8)
 return {origin=copy(origin),target=copy(target),
  lift={X=origin.X,Y=origin.Y,Z=top},cross={X=target.X,Y=target.Y,Z=top}}
end
local function mix(a,b,t)
 t=math.max(0,math.min(1,t));t=t*t*(3-2*t)
 return {X=a.X+(b.X-a.X)*t,Y=a.Y+(b.Y-a.Y)*t,Z=a.Z+(b.Z-a.Z)*t}
end
function M.at(p,t)
 if t<=.55 then return mix(p.origin,p.lift,t/.55)end
 if t<=.9 then return mix(p.lift,p.cross,(t-.55)/.35)end
 return mix(p.cross,p.target,(t-.9)/.1)
end
function M.moves(p,from,to)
 local out={}
 for _,t in ipairs({.55,.9})do if from<t and to>t then out[#out+1]=M.at(p,t)end end
 out[#out+1]=M.at(p,to);return out
end
function M.candidates(h,f,separation)
 local len=math.sqrt(f.X*f.X+f.Y*f.Y);if len<.5 then return {}end
 local x,y=f.X/len,f.Y/len;local out={}
 for _,offset in ipairs({{0,1},{0,-1},{-.6,1},{-.6,-1},{-1.2,0}})do
  out[#out+1]={X=h.X+x*offset[1]*separation-y*offset[2]*separation,
   Y=h.Y+y*offset[1]*separation+x*offset[2]*separation,Z=h.Z}
 end
 return out
end
return M
