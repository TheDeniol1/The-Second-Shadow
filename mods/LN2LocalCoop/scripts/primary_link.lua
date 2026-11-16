-- Helios keeps a native pawn reference alongside Unreal's Controller.Pawn.
-- Repair an absent or old-world reference to the controller's own playable pawn.
local M={}
function M.ensure(pc,api)
 if not api.live(pc) or not api.live(pc.Pawn) then return false end
 if not api.isMono(pc.Pawn) or not api.same(pc.Pawn.Controller,pc) then return false end
 if api.live(pc.mPlayerPawn) and not (api.stale and api.stale(pc.mPlayerPawn,pc.Pawn)) then return false end
 pc.mPlayerPawn=pc.Pawn
 return true
end
return M
